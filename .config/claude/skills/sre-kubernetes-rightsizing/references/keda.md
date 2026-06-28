# Autoscaling: KEDA / HPA / VPA

How to read the autoscaling configuration of a workload, judge it against the
30-day data, and — for un-autoscaled Deployments with variable load — propose a
starter KEDA `ScaledObject`. All cluster reads go through the `sre-kubernetes`
skill (Mode C); all metric reads through `sre-grafana`
([`queries.md`](queries.md)).

Variables as in `queries.md`: `$NS` namespace, `$WL` workload name.

## Detecting What Manages the Workload

Check all three — they are not mutually exclusive.

### KEDA `ScaledObject`

KEDA scales `Deployment` and `StatefulSet` via the `/scale` subresource — **not
DaemonSets**. It creates a managed HPA named `keda-hpa-<scaledobject>`.

```text
/apis/keda.sh/v1alpha1/namespaces/$NS/scaledobjects
```

Find the one whose `spec.scaleTargetRef.name == $WL`. Extract:

- `spec.minReplicaCount`, `spec.maxReplicaCount`
- `spec.cooldownPeriod`, `spec.pollingInterval`
- `spec.advanced.horizontalPodAutoscalerConfig` (stabilization windows, if set)
- `spec.triggers[]` — for each `type: prometheus` trigger: `metadata.query` (the
  PromQL), `metadata.threshold`, `metadata.metricName`.

### Plain HorizontalPodAutoscaler

```text
/apis/autoscaling/v2/namespaces/$NS/horizontalpodautoscalers
```

Match `spec.scaleTargetRef.name == $WL` (or the KEDA-generated `keda-hpa-$WL`).
Read `spec.minReplicas`, `spec.maxReplicas`, `spec.metrics[]`, and
`status.currentReplicas` / `status.currentMetrics`.

### VerticalPodAutoscaler

```text
/apis/autoscaling.k8s.io/v1/namespaces/$NS/verticalpodautoscalers
```

Match `spec.targetRef.name == $WL`. The decisive field is
`spec.updatePolicy.updateMode`:

- `Auto` / `Recreate` — the cluster is actively right-sizing. **Defer**: report
  the analysis but recommend no manual resource change, and note the VPA's
  current `status.recommendation` for comparison.
- `Initial` / `Off` — the VPA is advisory only; proceed with normal resource
  recommendations and mention the VPA's recommendation alongside yours.

## Judging an Existing Autoscaler

With the config read above and the 30-day series from `queries.md`:

1. **Bounds.** From the replica-history series, compute the % of time at
   `minReplicaCount` and at `maxReplicaCount`.
   - Mostly at the floor → the floor (and likely the requests) is too high.
   - Frequently at the ceiling → capacity-starved; recommend raising
     `maxReplicaCount`.
2. **Threshold.** Run the trigger's **own** `metadata.query` over 30 days
   (instant `quantile_over_time` for the distribution, plus the 1h-step trend).
   Compare against `metadata.threshold`:
   - Metric rarely reaches the threshold → it never scales up; lower the
     threshold or the floor.
   - Metric sits above the threshold most of the time → it is pinned high; the
     threshold is too low or `maxReplicaCount` too small.

   > Trigger queries are frequently **high-cardinality** (mesh/ingress counters
   > like `istio_requests_total` — thousands of series per workload). Use a
   > coarse `[30d:1h]` subquery with `rate(...[5m])`, and if a known-present
   > metric returns an empty frame, **retry once in isolation** before
   > concluding "never triggers" — an empty there is usually a transient fan-out
   > timeout, not a real zero (see `queries.md` gotchas). Divide the aggregate
   > `sum(rate(...))` by the replica count to compare against a per-replica
   > `threshold`.

3. **Signal vs. real constraint.** If it scales on a domain metric (queue depth,
   RPS) but the 30-day data shows the pods OOMing or CPU-bound, flag that the
   autoscaler will not protect against the binding constraint — recommend either
   adding a resource-based trigger or fixing the requests/limits.
4. **Stability.** Frequent scale events with a short `cooldownPeriod` /
   stabilization window suggest flapping — recommend lengthening the
   stabilization window.

## Greenfield Proposal (Deployments Only)

Only when **no** HPA / KEDA / VPA manages the workload, the kind is
`Deployment`, and the variability gate in `queries.md` is cleared (peak ≥ ~2×
trough or a clear diurnal pattern). If load is flat, do **not** propose
autoscaling — recommend keeping fixed replicas right-sized to N.

### Choosing the Trigger Metric (Tiered)

1. **Domain metric (preferred).** Search the namespace for plausible scaling
   signals tied to this workload and offer the candidates to the user, e.g.:
   ```promql
   # request-rate style counters for the workload's pods
   sum(rate({__name__=~".*requests_total|.*http_requests_total", namespace="$NS"}[5m]))
   ```
   Surface what exists (RPS, queue depth, in-flight, consumer lag) and let the
   user pick.
2. **Ask the user.** If nothing obvious is discoverable but the workload would
   benefit from autoscaling, ask the user to name the metric before falling
   back.
3. **CPU utilization (fallback).** Only when no domain metric is available, base
   the starter trigger on CPU usage relative to the **recommended** CPU request.

### Deriving the Numbers (From the 30-Day Data)

- `minReplicaCount` ≈ replicas needed at the trough (or the current count).
- `maxReplicaCount` ≈ replicas needed at peak + headroom.
- `threshold` ≈ target utilization (~70% of the recommended CPU request, or a
  target value for the chosen domain metric).

### Starter Template

Present this filled-in, clearly labelled as **a starting point requiring
validation**. Never auto-apply it as part of "apply all" — only write it when
the user explicitly asks and says where (new file vs. appended document).

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: <workload>
  namespace: <namespace>
spec:
  scaleTargetRef:
    name: <workload>
  minReplicaCount: <trough + 0>
  maxReplicaCount: <peak + headroom>
  cooldownPeriod: 300
  pollingInterval: 30
  triggers:
    # Preferred: a domain metric chosen with the user.
    - type: prometheus
      metadata:
        serverAddress: <prometheus-url>
        metricName: <domain_metric>
        query: <domain PromQL for this workload>
        threshold: "<target value>"
    # Fallback only when no domain metric exists: CPU relative to the
    # recommended request (replace <recommended_cpu_request_cores>).
    # - type: prometheus
    #   metadata:
    #     serverAddress: <prometheus-url>
    #     metricName: cpu_utilization
    #     query: |
    #       sum(rate(container_cpu_usage_seconds_total{namespace="<ns>", container!=""}[5m]))
    #       / count(kube_pod_info{namespace="<ns>"})
    #     threshold: "<0.7 * recommended_cpu_request_cores>"
```

Fill `serverAddress` from the Prometheus datasource the metrics were queried
through. Note in the report that the trigger query and threshold must be
validated against real traffic before relying on them.

## Notes

- **KEDA does not scale DaemonSets.** For a DaemonSet, the autoscaling section
  is "not applicable (DaemonSet scales per-node, not by replica count)".
- **Read-only.** This reference only _reads_ autoscaler CRs from the cluster.
  Any change is written to a **manifest file** after user confirmation, per the
  main skill's hard rules — never to the cluster.
