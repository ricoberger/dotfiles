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

Find the one whose `spec.scaleTargetRef` matches the workload's **full
reference**: `name == $WL` **and** `kind` (omitted = `Deployment`) **and**
`apiVersion` group `apps` (omitted = `apps/v1`). A Deployment and a StatefulSet
can share a name; never assign an autoscaler by name alone. Extract:

- `spec.minReplicaCount`, `spec.maxReplicaCount`
- `spec.cooldownPeriod`, `spec.pollingInterval`
- `spec.advanced.horizontalPodAutoscalerConfig` (stabilization windows, if set)
- `spec.triggers[]` — for each `type: prometheus` trigger: `metadata.query` (the
  PromQL), `metadata.threshold`, `metadata.metricName`.

### Plain HorizontalPodAutoscaler

```text
/apis/autoscaling/v2/namespaces/$NS/horizontalpodautoscalers
```

Match `spec.scaleTargetRef` by `name == $WL` **and** `kind` **and** `apiVersion`
group `apps` (or the KEDA-generated `keda-hpa-<scaledobject>` of the matched
ScaledObject). Read `spec.minReplicas`, `spec.maxReplicas`, `spec.metrics[]`,
and `status.currentReplicas` / `status.currentMetrics`.

### VerticalPodAutoscaler

```text
/apis/autoscaling.k8s.io/v1/namespaces/$NS/verticalpodautoscalers
```

Match `spec.targetRef` by `name == $WL` **and** `kind` **and** `apiVersion`
group `apps`. The decisive field is `spec.updatePolicy.updateMode` (omitted =
`Recreate`), together with `spec.resourcePolicy.containerPolicies[]` (`mode`,
`controlledResources`, `controlledValues`), which says which
containers/resources the VPA controls:

- `Recreate`, `Auto` (deprecated alias of `Recreate`), `InPlaceOrRecreate`,
  `InPlace`, or omitted — the cluster is actively right-sizing. **Defer**:
  report the analysis but recommend no manual change to the controlled
  resources, and note the VPA's current `status.recommendation` for comparison.
- `Initial` — the VPA writes its recommendation into the controlled resources at
  pod admission, so a manual change is overwritten when the new pods are
  created. **Defer** the controlled resources (or propose switching the VPA to
  `Off` / removing it as a paired change); uncontrolled resources follow the
  normal recommendations.
- `Off` — the VPA is advisory only; proceed with normal resource recommendations
  and mention the VPA's recommendation alongside yours.

## Judging an Existing Autoscaler

With the config read above and the 30-day series from `queries.md`:

1. **Bounds.** From the replica-history series, compute the % of time at
   `minReplicaCount` and at `maxReplicaCount`. Time at a bound is a prompt to
   investigate, not a verdict:
   - Mostly at the floor → the floor (and likely the requests) _may_ be too
     high. First check whether the floor is required for availability (PDB,
     zone/topology spread, quorum, cold-start or failover capacity); lower it
     only when it is not.
   - Frequently at the ceiling → recommend raising `maxReplicaCount` only with
     evidence the cap constrains needed capacity: the trigger metric stays above
     its threshold while at max, or CPU/memory PSI, latency or errors rise
     there. A workload that sits at max but meets demand is not starved.
2. **Threshold.** Run the trigger's **own** `metadata.query` over 30 days
   (instant `quantile_over_time` for the distribution, plus the 1h-step trend).
   For an `AverageValue` trigger, divide **each sample** by the replica count at
   that time inside the subquery before taking the percentile — the percentile
   of the total divided by a single replica count is skewed when replicas
   change:

   ```promql
   quantile_over_time(0.95, (
     (<trigger query>)
     / scalar(count(kube_pod_info{namespace="$NS"} and on (namespace, pod)
         namespace_workload_pod:kube_pod_owner:relabel{namespace="$NS", workload="$WL", workload_type="$WLTYPE"}))
   )[30d:1h])
   ```

   Triggers **without a query** — HPA `Resource` / `ContainerResource` metrics
   and KEDA `cpu` / `memory` scalers — compare per-pod usage ÷ request with the
   target: compute the 30-day distribution of the workload's average CPU (or
   memory) utilization, `avg(usage) / avg(request)` per step, against the target
   percentage (`averageUtilization` / `value`); for `AverageValue` targets
   compare average usage per pod with the absolute value.

   Triggers without a query that are **not** `cpu` / `memory` (e.g. Kafka
   `lagThreshold`, RabbitMQ queue length, `cron`): the threshold is **not
   assessable** from this procedure unless the same signal is available as a
   Prometheus metric — say so; the bounds and stability checks still apply.

   Compare against the threshold:
   - Metric rarely reaches the threshold → it **rarely** scales up (rare
     crossings still scale). Check the replica history and demand first; lower
     the threshold or the floor only when the workload stays at the floor while
     demand or pressure rises.
   - Metric sits above the threshold most of the time → it is pinned high; the
     threshold is too low or `maxReplicaCount` too small.

   > Trigger queries are frequently **high-cardinality** (mesh/ingress counters
   > like `istio_requests_total` — thousands of series per workload). Use a
   > coarse `[30d:1h]` subquery with `rate(...[5m])`, and if a known-present
   > metric returns an empty frame, **retry once in isolation** before
   > concluding "never triggers" — an empty there is usually a transient fan-out
   > timeout, not a real zero (see `queries.md` gotchas). Whether to divide
   > depends on the trigger's `metricType`: with `AverageValue` (the default for
   > `prometheus` triggers) KEDA divides the query result by the replica count,
   > so divide per sample (query above) before comparing with `threshold`; with
   > `Value` KEDA compares the raw query result, so compare it undivided.

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
   # candidate request-rate counters on the workload's pods, one row per
   # metric name (`and` keeps __name__; arithmetic would drop it)
   count by (__name__) (
     {__name__=~".*requests_total|.*http_requests_total", namespace="$NS"}
     and on (namespace, pod)
     namespace_workload_pod:kube_pod_owner:relabel{namespace="$NS", workload="$WL", workload_type="$WLTYPE"}
   )
   ```

   Mesh/ingress metrics often identify the target by their own labels instead of
   `pod` (e.g. `istio_requests_total{destination_workload="$WL"}`); probe those
   separately. Show each candidate with its labels and its value for **this
   workload only**, and let the user pick.

2. **Ask the user.** If nothing obvious is discoverable but the workload would
   benefit from autoscaling, ask the user to name the metric before falling
   back.
3. **CPU utilization (fallback).** Only when no domain metric is available, use
   KEDA's native `cpu` scaler with `metricType: Utilization` relative to the
   **recommended** CPU request. Do not hand-roll a Prometheus CPU trigger: a
   namespace-wide average divided by a pod count is not scoped to the workload,
   and KEDA's default `AverageValue` target divides it by the replica count a
   second time.

### Deriving the Numbers (From the 30-Day Data)

- `minReplicaCount` ≈ replicas needed at the trough (or the current count), and
  **at least 1** when the trigger metric is scraped from the workload's own pods
  (application or mesh-sidecar metrics): at zero replicas the metric source is
  gone and KEDA cannot see new demand. Scale-to-zero only with a metric
  independent of the workload (queue depth, ingress / load-balancer metrics).
  For **HTTP** workloads that is not enough: a Service does not buffer requests
  while no pod is ready, so scale-to-zero also needs a buffering layer (e.g. the
  KEDA HTTP add-on) and an acceptable cold-start latency — otherwise keep
  `minReplicaCount ≥ 1`.
- `maxReplicaCount` ≈ replicas needed at peak + headroom.
- `threshold` ≈ target utilization (`value: "70"` for the `cpu` scaler, i.e.
  ~70% of the recommended CPU request, or a target value for the chosen domain
  metric). A Prometheus trigger uses `AverageValue` by default — its query must
  return the **workload total** (KEDA divides by the replica count), and the
  threshold is the per-replica target. With the `cpu` scaler the CPU request
  becomes coupled to scaling (see the coupling caveats in `SKILL.md`).

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
        # Fail on an empty result (lost target) instead of scaling on it.
        ignoreNullValues: "false"
    # Fallback only when no domain metric exists: KEDA's native CPU scaler,
    # utilization relative to each pod's CPU request (every container needs a
    # CPU request; set containerName for multi-container pods). The cpu scaler
    # cannot scale to zero, so keep minReplicaCount >= 1.
    # - type: cpu
    #   metricType: Utilization
    #   metadata:
    #     value: "70"
    #     containerName: <container> # optional
```

Fill `serverAddress` from the Prometheus datasource the metrics were queried
through. KEDA's `prometheus` scaler defaults to `ignoreNullValues: "true"`,
which treats an empty result (e.g. a lost scrape target during a metrics outage)
as a value and can scale the workload toward `minReplicaCount`. The template
therefore sets it to `"false"` so the scaler errors instead. Do not mask that
with `or vector(0)` — it turns a lost target back into a zero. Check that the
query returns a series at zero traffic (a scraped counter still yields
`rate = 0`); if it legitimately returns nothing when idle, say so and configure
a `spec.fallback` (`failureThreshold`, `replicas`) for the error case.
`ignoreNullValues` only catches a **total** loss: if some of several scrape
targets disappear, an aggregate returns a non-empty but understated value and
can scale down. Prefer a trigger metric from a source independent of the scaled
pods (queue, ingress / load balancer), keep `minReplicaCount` at a safe floor,
and check the trigger against scrape-target health during validation. Note in
the report that the trigger query and threshold must be validated against real
traffic before relying on them.

## Notes

- **KEDA does not scale DaemonSets.** For a DaemonSet, the autoscaling section
  is "not applicable (DaemonSet scales per-node, not by replica count)".
- **Read-only.** This reference only _reads_ autoscaler CRs from the cluster.
  Any change is written to a **manifest file** after user confirmation, per the
  main skill's hard rules — never to the cluster.
