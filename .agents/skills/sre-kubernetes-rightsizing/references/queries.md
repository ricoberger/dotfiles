# Right-Sizing Queries

The exact PromQL for the 30-day usage analysis, plus the pod-selection patterns
that survive 30 days of pod churn. Run every query through the `sre-grafana`
skill against the Prometheus / VictoriaMetrics datasource on the chosen Grafana
instance. Follow `sre-grafana`'s command mechanics — resolve the datasource UID
first, build request bodies with `jq -n`, and pass `from` / `to` explicitly.

All variables below: `$NS` namespace, `$WL` workload name, `$WLTYPE` one of
`deployment` / `statefulset` / `daemonset`, `$CONTAINER` container name.

## Preferred Metric Source — `kube-prometheus` Mixin Recording Rules

If the cluster runs the standard kube-prometheus / VictoriaMetrics mixin rules
(VMRule `k8s.rules.*`), **use them instead of raw cAdvisor series** — they are
the definitions the team's own dashboards and alerts already trust, and they
normalize the cAdvisor data in ways that materially change the result:

| Need               | Recording rule                                                              | Replaces                                           |
| ------------------ | --------------------------------------------------------------------------- | -------------------------------------------------- |
| CPU cores (rate5m) | `node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate5m` | `rate(container_cpu_usage_seconds_total{...}[5m])` |
| Memory working set | `node_namespace_pod_container:container_memory_working_set_bytes`           | `container_memory_working_set_bytes{...}`          |
| Pod → workload map | `namespace_workload_pod:kube_pod_owner:relabel`                             | kind-specific pod-name regex                       |

Both metric rules already filter `image!=""` and
`sum by (cluster, namespace, pod, container)`, and every per-container stat
query below pins an explicit `container="$CONTAINER"` (a named container is
never a cgroup rollup), so you do **not** need to add `container!=""`; the CPU
rule also has no runtime `rate()` to compute. Probe for them once
(`count(<rule>{namespace="$NS"})`); if present, prefer them everywhere below.

> **Verified live why this matters.** On a workload that cycled ~2000 pods in 30
> days, the four metric×selection combinations for CPU p95 were: raw-cAdvisor +
> name-regex **0.65**, raw-cAdvisor + owner-join **0.84**, recording-rule +
> name-regex **0.84**, recording-rule + owner-join **0.84**. Only raw-cAdvisor +
> regex was off — the name-regex over-matched (**2127** pods vs the owner-join's
> **394**) and the un-normalized cAdvisor series pulled the average down. The
> recording-rule + owner-join pair is the robust combination; raw cAdvisor +
> regex is the lossy fallback for clusters without the mixin.

## Selecting the Workload’s Pods (Churn-Robust)

Over 30 days a workload's pods come and go — every rollout produces a new
ReplicaSet hash, so concrete pod names are useless across the window. Select by
**workload**, most-robust-first.

### Preferred — `kube-prometheus` Owner Relabel Rule

If the cluster runs the kube-prometheus-stack recording rules, this maps pods to
their owning workload directly and is immune to churn (and does not over-match
the way a name regex does):

```promql
namespace_workload_pod:kube_pod_owner:relabel{
  namespace="$NS", workload="$WL", workload_type="$WLTYPE"
}
```

Join it onto the metric series (recording rule preferred) by `(namespace, pod)`:

```promql
node_namespace_pod_container:container_memory_working_set_bytes{namespace="$NS", container="$CONTAINER"}
* on (namespace, pod) group_left
namespace_workload_pod:kube_pod_owner:relabel{namespace="$NS", workload="$WL", workload_type="$WLTYPE"}
```

### Fallback — Kind-Specific Pod-Name Regex

When the relabel rule is absent, match pod names by the controller's naming
scheme. **Always cross-check the resulting pod set against the live pod list**
(`sre-kubernetes`, Mode C: `/api/v1/namespaces/$NS/pods?labelSelector=...`) so
the regex is not catching a same-prefixed neighbor (it over-matches — see the
verified note above):

| Kind          | Pod-name pattern            | Regex matcher                           |
| ------------- | --------------------------- | --------------------------------------- |
| `Deployment`  | `<name>-<rshash>-<podhash>` | `pod=~"$WL-[a-f0-9]{6,10}-[a-z0-9]{5}"` |
| `StatefulSet` | `<name>-<ordinal>`          | `pod=~"$WL-[0-9]+"`                     |
| `DaemonSet`   | `<name>-<podhash>`          | `pod=~"$WL-[a-z0-9]{5}"`                |

With the raw-cAdvisor fallback always include
`container="$CONTAINER", container!=""` to drop the pod-level pause/`POD`
aggregate series.

## Collapsing 30 Days to Single Stats

Use **instant queries** with `_over_time` aggregations over `[30d]`. Do not pull
raw range series for the statistics — that is expensive and unnecessary. Set
`"instant": true`, `"range": false` in the `sre-grafana` Prometheus request
body.

> **Aggregate across the fleet at each instant, _then_ take the percentile over
> time — never per-pod-then-aggregate.** Pods churn heavily (a busy workload can
> cycle through thousands of short-lived pods in 30 days — rollouts, restarts,
> OOM kills). A per-pod `quantile_over_time(...)[30d]` then `max by (container)`
> **collapses**: each pod lives only minutes, so its own p50 ≈ p95 ≈ max, and
> the cross-pod `max` just surfaces the single hottest ephemeral pod — every
> percentile returns nearly the same number. Instead collapse the fleet to a
> single per-instant signal first:
>
> - **typical per replica** → `avg(...)` across pods at each step (the
>   request-sizing signal);
> - **hottest replica** → `max(...)` across pods at each step (the limit / peak
>   signal).
>
> Then wrap that inner instant vector in a subquery `[30d:10m]` and apply
> `quantile_over_time` / `max_over_time`.

Apply the workload selector (relabel join, or regex fallback) from the section
above inside every aggregation below. The blocks lead with the
**recording-rule + owner-join** form (preferred); the raw-cAdvisor form is the
fallback when the mixin rules are absent. In the fallback forms `$SEL`
abbreviates the raw-cAdvisor selector:
`namespace="$NS", container="$CONTAINER", container!="", pod=~"<regex>"`.

Some series further down have **no** recording-rule equivalent and are written
with `$SEL` for brevity (the `container_pressure_*` PSI metrics and the raw
replica-count). The owner-join is still preferred there — when the relabel rule
exists, select with it instead of the regex:

```promql
<raw-metric>{namespace="$NS", container="$CONTAINER"}
* on (namespace, pod) group_left
namespace_workload_pod:kube_pod_owner:relabel{namespace="$NS", workload="$WL", workload_type="$WLTYPE"}
```

and fall back to `$SEL` only when the rule is absent.

### Memory Working Set (Bytes)

Working set is what the OOM killer watches — size memory off this, not RSS or
`container_memory_usage_bytes`.

```promql
# PREFERRED: recording rule + owner-join
# typical per replica (drives the memory request): p95 of the fleet average
quantile_over_time(0.95,
  (avg(
    node_namespace_pod_container:container_memory_working_set_bytes{namespace="$NS", container="$CONTAINER"}
    * on (namespace, pod) group_left
    namespace_workload_pod:kube_pod_owner:relabel{namespace="$NS", workload="$WL", workload_type="$WLTYPE"}
  ))[30d:10m]
)

# hottest replica peak (drives the memory limit): max of the fleet max
max_over_time(
  (max(
    node_namespace_pod_container:container_memory_working_set_bytes{namespace="$NS", container="$CONTAINER"}
    * on (namespace, pod) group_left
    namespace_workload_pod:kube_pod_owner:relabel{namespace="$NS", workload="$WL", workload_type="$WLTYPE"}
  ))[30d:10m]
)

# FALLBACK (no mixin rules): raw cAdvisor + pod-name regex
quantile_over_time(0.95, (avg(container_memory_working_set_bytes{$SEL}))[30d:10m])
max_over_time((max(container_memory_working_set_bytes{$SEL}))[30d:10m])
```

Swap the quantile to `0.50` / `0.99` for p50 / p99. **Censoring caveat:** when
the working set sits at the configured limit and **either** OOM kills **or** a
sustained major-fault rate are present (see below), the observed `max` is
_clamped at the limit_ — true demand is higher and unknowable from these series.
Page-cache thrash clamps the working set **without** an OOM, so OOM-absence does
not clear the censoring — check the major-page-faults series too. Treat the
recommended limit as a **floor**, raise it, and re-measure.

### CPU Usage (Cores)

Aggregate across the fleet, then take the percentile via a subquery. The
recording rule already carries the `rate(...[5m])`, so there is no runtime rate
to compute; the raw fallback rates `container_cpu_usage_seconds_total` first.

```promql
# PREFERRED: recording rule + owner-join (no runtime rate(); image!="" baked in)
# typical per replica (drives the CPU request): p95 of the fleet average
quantile_over_time(0.95,
  (avg(
    node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate5m{namespace="$NS", container="$CONTAINER"}
    * on (namespace, pod) group_left
    namespace_workload_pod:kube_pod_owner:relabel{namespace="$NS", workload="$WL", workload_type="$WLTYPE"}
  ))[30d:10m]
)

# hottest replica at each instant (context / peak): p95 and peak of the fleet max
quantile_over_time(0.95,
  (max(
    node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate5m{namespace="$NS", container="$CONTAINER"}
    * on (namespace, pod) group_left
    namespace_workload_pod:kube_pod_owner:relabel{namespace="$NS", workload="$WL", workload_type="$WLTYPE"}
  ))[30d:10m]
)

# FALLBACK (no mixin rules): raw cAdvisor + pod-name regex
quantile_over_time(0.95, (avg(rate(container_cpu_usage_seconds_total{$SEL}[5m])))[30d:10m])
max_over_time((max(rate(container_cpu_usage_seconds_total{$SEL}[5m])))[30d:10m])
```

Base the **request** recommendation on the _typical per-replica_ p95
(`avg`-aggregated); use the _hottest-replica_ series only as context for how
spiky the workload is.

### CPU Pressure (PSI) — CPU Bottleneck Signal

> **Do not use CPU CFS throttling
> (`container_cpu_cfs_throttled_periods_total`).** It only increments when a CFS
> quota is enforced — i.e. when a CPU _limit_ is set. With CPU limits disabled
> by policy **and** `cpuCFSQuota` disabled cluster-wide, the throttling _and_
> `cfs_periods` series are never produced (verified: both return no series), so
> the ratio is structurally dead. Use CPU PSI instead.

CPU PSI measures time the container's tasks were **runnable but waiting for a
CPU**. Because the CPU _request_ sets the cgroup `cpu.weight` (the share granted
under node contention), CPU PSI is the direct signal of an under-sized request:
a starved container waits for CPU, and — importantly — its measured CPU _usage
is suppressed while it waits_, so the usage percentile **understates** true
demand exactly the way a memory limit censors working set. PSI exposes that
hidden demand. Optional (cgroup v2); probe first:

```promql
count(container_pressure_cpu_waiting_seconds_total{namespace="$NS", container="$CONTAINER"})
```

`waiting` = **some** (≥1 task waiting); `stalled` = **full** (all runnable tasks
waiting — severe). Rate gives a `0..1` fraction of wall-time:

```promql
# some-wait: p95 (chronic starvation?) and peak (bursty contention?) over 30d
quantile_over_time(0.95, (avg(rate(container_pressure_cpu_waiting_seconds_total{$SEL}[5m])))[30d:10m])
max_over_time((max(rate(container_pressure_cpu_waiting_seconds_total{$SEL}[5m])))[30d:10m])

# full-wait peak (all tasks blocked on CPU)
max_over_time((max(rate(container_pressure_cpu_stalled_seconds_total{$SEL}[5m])))[30d:10m])
```

Interpret as a CPU verdict/risk input:

| CPU PSI shape (30d)                  | Meaning                                     | Action                                                    |
| ------------------------------------ | ------------------------------------------- | --------------------------------------------------------- |
| some/full p95 high or sustained      | **chronic CPU starvation** (usage censored) | raise the **request**; usage-p95 understates real demand  |
| p95 ≈ 0 with brief peaks             | occasional node contention, not starved     | request is fine; note the contention                      |
| ≈ 0 everywhere + usage-p95 ≪ request | genuine **headroom**                        | safe to **trim** the request — PSI confirms slack is real |

CPU PSI only rises while the **node** is contended, so a quiet-period zero does
not prove peak adequacy — size the request off the usage p95 (`avg`-aggregated)
and use PSI to (a) detect real starvation episodes and (b) gate any downsizing
(never cut a CPU request without near-zero CPU PSI).

### OOMKills and Restarts

```promql
# OOMKills over the window (per container)
max by (container) (
  increase(
    kube_pod_container_status_last_terminated_reason{namespace="$NS", container="$CONTAINER", reason="OOMKilled"}[30d]
  )
)

# total restarts over the window
max by (container) (
  increase(kube_pod_container_status_restarts_total{namespace="$NS", container="$CONTAINER"}[30d])
)
```

A non-zero OOMKill count is a hard signal that the memory limit is too low — the
recommended limit must clear the observed peak with headroom regardless of the
`max × 1.25` rule.

### Memory Pressure (PSI) — Optional Bottleneck Signal

Pressure Stall Information quantifies how long tasks were _stalled waiting for
memory_ (reclaim, refault, thrashing). It is a **leading** indicator that fires
before an OOM and, unlike working set, exposes pressure that happens _between_
scrapes — so it catches bottlenecks the sampled peak misses. **Optional:**
requires cgroup v2 (kernel ≥ 4.20) and cAdvisor PSI; probe first and skip
silently if absent:

```promql
count(container_pressure_memory_stalled_seconds_total{namespace="$NS", container="$CONTAINER"})
```

Both series are counters of stall-seconds; `rate(...[5m])` yields a fraction of
wall-time in `0..1`. `waiting` = **some** (≥1 task stalled, sensitive);
`stalled` = **full** (all tasks stalled, severe — the strong signal).

```promql
# full-stall: p95 (chronic?) and peak (bursty?) over the window
quantile_over_time(0.95, (avg(rate(container_pressure_memory_stalled_seconds_total{$SEL}[5m])))[30d:10m])
max_over_time((max(rate(container_pressure_memory_stalled_seconds_total{$SEL}[5m])))[30d:10m])

# some-stall peak (early-pressure context)
max_over_time((max(rate(container_pressure_memory_waiting_seconds_total{$SEL}[5m])))[30d:10m])
```

Interpret as a **verdict/risk** input — it does not change the working-set-based
formula, it changes the _story_ and the remediation:

| full-PSI shape (30d)                 | Meaning                       | Action                                                                       |
| ------------------------------------ | ----------------------------- | ---------------------------------------------------------------------------- |
| p95 high (e.g. ≳0.05) + sustained    | **chronic** memory starvation | raise **request and limit**; the workload is genuinely under-fed             |
| p95 ≈ 0 but peaks + OOMKills present | **bursty** allocation spikes  | raise the **limit** for headroom; request may be fine; find the spike source |
| ≈ 0 everywhere + working set ≪ limit | genuine **headroom**          | safe to **trim** request/limit — PSI confirms slack is real                  |

Near-zero PSI is the prerequisite for recommending any _downsizing_ — it is the
proof the current limit is not already biting. (For the CPU equivalent — CPU
PSI, which replaces the dead CFS-throttling metric in quota-free clusters — see
the CPU pressure section above.)

### Major Page Faults — the Page-Cache-Thrash Signal (PSI/OOM Miss It)

Working set, OOMKills and memory PSI all **miss** one important failure mode: a
container whose anonymous memory (RSS) crowds out its own page cache within the
cgroup limit, so its memory-mapped pages (the executable, shared libraries, and
mmap'd data/index files) are evicted and must refault from disk. The refault I/O
is fast enough that it rarely registers as a long memory-PSI stall, and the
container never OOMs — yet it thrashes, adding latency on every faulted access.
This is the **generic** analogue of the DB/JVM page-cache degradation in
`workloads.md`, and it hits mmap-heavy services that are **not** a classified
engine (HashiCorp Vault, etcd, Loki/Mimir, BoltDB-backed Go services, SQLite, or
any binary that mmaps large files). cAdvisor exposes it directly; probe first
(`count(container_memory_failures_total{namespace="$NS", container="$CONTAINER", failure_type="pgmajfault"})`):

```promql
# major page faults per second on the hottest replica — p95 and peak over 30d
quantile_over_time(0.95,
  (max(sum by (namespace, pod) (
    rate(container_memory_failures_total{namespace="$NS", container="$CONTAINER", failure_type="pgmajfault", scope="container"}[5m])
  )))[30d:10m]
)
max_over_time(
  (max(sum by (namespace, pod) (
    rate(container_memory_failures_total{namespace="$NS", container="$CONTAINER", failure_type="pgmajfault", scope="container"}[5m])
  )))[30d:10m]
)
```

Interpret as a memory **verdict/risk** input — a downsize **guard**, like PSI:

| pgmajfault shape (30d)                             | Meaning                                 | Action                                                            |
| -------------------------------------------------- | --------------------------------------- | ----------------------------------------------------------------- |
| sustained high (e.g. ≳50/s) on a replica           | **page-cache thrash** — limit too tight | raise the **limit** for page-cache headroom even if PSI≈0, no OOM |
| brief peaks only, baseline ~0                      | warm-up / occasional cold reads         | not a sizing signal on its own                                    |
| ≈0 (after excluding warm-up) + working set ≪ limit | genuine headroom                        | the working-set/PSI headroom reading stands                       |

A sustained major-fault rate is the **proof the limit is biting** for a
page-cache-bound workload, exactly the way OOM/PSI prove it for an
anonymous-memory-bound one. **Never trust a "PSI ≈ 0, no OOM ⇒ safe to trim"
verdict on an mmap-heavy workload without checking this series first** — a quiet
PSI with a loud major-fault rate means _raise_, not trim. (Some node images keep
a small non-zero baseline of major faults for every container; compare the
candidate against a quiet sibling replica, not against an absolute zero.
Verified live: a Vault HA leader sustained ~600/s — peak 1404/s — major faults
with PSI full-p95 ≈ 0.13 % and zero OOMKills, while its working set was clamped
at the 300Mi limit; raising the limit was correct and PSI/OOM alone would have
called it "safe to trim".)

> **Analytical / scan-heavy stores whose on-disk data ≫ RAM** (VictoriaMetrics,
> ClickHouse cold partitions, Thanos/Loki store) can carry an _irreducible_
> cold-read fault floor that more memory will not remove. There the undersize
> signal is faults that **fall when headroom is added** (or rise as the working
> set nears the limit), not the absolute rate — treat a flat baseline as a
> cost/latency tradeoff, not an undersize. (Verified live: a well-provisioned
> `vmstorage` runs at ~0 major faults despite a multi-hundred-GiB dataset.)

## Variability / Trend Series (Autoscaling Gate Only)

This is the **one** place to pull a range (not instant) series — a coarse-step
trend used to decide whether load varies enough to justify autoscaling. Keep the
step coarse (1h) so a 30-day pull stays cheap.

```promql
# total CPU cores used by the workload, summed across replicas, 1h step
sum (
  rate(container_cpu_usage_seconds_total{namespace="$NS", container!=""}[5m])
  * on (namespace, pod) group_left
  namespace_workload_pod:kube_pod_owner:relabel{namespace="$NS", workload="$WL", workload_type="$WLTYPE"}
)
```

Request it as a range query with `step=1h`. Compare peak vs. trough: a peak ≥
~2× trough (or an obvious diurnal/weekly rhythm) clears the gate; a flat line
does not.

> **High-cardinality trigger / trend metrics → coarse step by default.** When
> the series is a mesh/ingress request counter (`istio_requests_total`,
> `*_http_requests_total`) or any metric with hundreds–thousands of series for
> the workload, **default the trend/threshold subquery to `[30d:1h]` with an
> inner `rate(...[5m])`** — never `[30d:10m]`/`rate[2m]`. The autoscaling gate
> and threshold check don't need 10m resolution, and the coarse step is within
> rounding of the fine one (verified: peak backend RPS 18,667 @ `[30d:10m]` vs
> 18,546 @ `[30d:1h]`) while being far cheaper and far less likely to return a
> transient empty frame (see the fan-out gotcha below).

### Replica History (for an Existing Autoscaler)

```promql
# current replica count over time (size the min/max bounds against this)
kube_horizontalpodautoscaler_status_current_replicas{namespace="$NS", horizontalpodautoscaler=~"(keda-hpa-)?$WL"}

# or, controller-agnostic
kube_deployment_status_replicas{namespace="$NS", deployment="$WL"}

# or, derived from the running pod count (works without kube-state-metrics HPA
# series; verified live) — min / avg / max running replicas over the window:
min_over_time((count(container_memory_working_set_bytes{$SEL}))[30d:10m])
avg_over_time((count(container_memory_working_set_bytes{$SEL}))[30d:10m])
max_over_time((count(container_memory_working_set_bytes{$SEL}))[30d:10m])
```

Compute the % of time at `minReplicaCount` (over-provisioned floor) and at
`maxReplicaCount` (capacity-starved ceiling) from a 1h-step range pull. **Watch
for rollout surge:** the running-pod count can briefly exceed `maxReplicaCount`
(old + new pods during a `RollingUpdate` with `maxSurge`) — that is not load
scaling, so discount short spikes above the ceiling when judging the bounds.

## Current Requests / Limits From Metrics (Cross-Check Only)

The authoritative current config comes from the **live cluster spec** (read via
`sre-kubernetes`). These series are only a cross-check / fallback:

```promql
kube_pod_container_resource_requests{namespace="$NS", container="$CONTAINER", resource="cpu"}
kube_pod_container_resource_requests{namespace="$NS", container="$CONTAINER", resource="memory"}
kube_pod_container_resource_limits{namespace="$NS",   container="$CONTAINER", resource="cpu"}
kube_pod_container_resource_limits{namespace="$NS",   container="$CONTAINER", resource="memory"}
```

If the mixin rules are present, prefer their `*:active:*` variants — they
already restrict to `Running`/`Pending` pods, so they ignore stale
terminated-pod series:
`cluster:namespace:pod_cpu:active:kube_pod_container_resource_requests`,
`cluster:namespace:pod_memory:active:kube_pod_container_resource_requests`, and
the matching `…:kube_pod_container_resource_limits`.

## Gotchas

- **Excluding cgroup rollups — `container!=""` is stricter than `image!=""`.**
  Besides the real per-container series, cAdvisor emits two non-container
  rollups per pod that double-count: the pod-level total
  (`container="", image=""`) and the sandbox/pause
  (`container="", image=<set>`). `container!=""` drops both; `image!=""` drops
  only the image-less total and **keeps the sandbox** — the mixin rules use
  `image!=""`, so their output still carries a summed `container=""` group. You
  don't hit either rollup when you pin an explicit `container="$CONTAINER"`
  (every per-container stat query does), so no extra filter is needed there. You
  **do** need `container!=""` only when summing across _all_ of a workload's
  containers without naming one (the variability/trend query) — and there it
  must be `container!=""`, not `image!=""`, to also drop the sandbox.
- **Empty result ≠ zero usage.** A bad selector returns the same empty frame as
  a genuinely idle container. If a percentile comes back empty, widen: drop the
  `container` filter, then the workload join, to find where the match breaks.
- **Subquery cost.** `(avg(rate(...[5m])))[30d:10m]` materializes one
  fleet-level point every 10m (4320 over 30d) — cheap. Coarsen to `[30d:15m]`
  only if it strains; do **not** drop to per-pod range pulls.
- **Transient timeouts on large fan-outs.** On workloads with many pods over the
  window — large DaemonSets (one pod per node, 50–100+ nodes) but equally a
  high-replica or heavily-scaled Deployment / StatefulSet — the heavier
  `max_over_time((max(...)))[30d:15m]` queries can occasionally time out even
  though they succeed on a retry (verified: a 93-pod DaemonSet timed out once,
  returned cleanly the second time). The same hits **high-cardinality trigger /
  trend queries** — a mesh/ingress counter like `istio_requests_total` can carry
  thousands of series for one workload, and a `sum(rate(...[2m]))[30d:10m]`
  subquery over it can return an **empty frame with HTTP 200** (no error) when
  bundled with other heavy queries in the same batch, while the lighter queries
  in that batch succeed (verified:
  `istio_requests_total{destination_workload= "backend"}` = 1564 series — empty
  once in a 4-query batch, returned **18.7k RPS** on isolated retry;
  `[30d:1h]`/`rate[5m]` gave 18.5k, within rounding). Treat a lone timeout /
  empty / `NO SERIES` on these as transient: **retry once**, and if it persists
  coarsen the step (`[30d:30m]` or `[30d:1h]`), raise the client timeout, or
  scope/split the query. Do not record a retryable timeout as "no data".
- **Don't let an empty-result fallback mask a timeout.** A scripted
  `jq '... // "EMPTY"'` (or any "default if null") collapses two very different
  outcomes into the same string: a genuine no-match and a 200-with-empty-frame
  from a transient timeout. If a query over a metric you have **already
  confirmed is present** (via a `count(...)` probe) comes back empty, that is a
  retry signal, not a finding — re-run it in isolation (and/or check the
  per-refId `.results.<id>.error` / `.status`) before reporting anything. Never
  report "empty" for a known-present series without a clean isolated retry.
- **Working set, not RSS.** Size memory off
  `container_memory_working_set_bytes`; `container_memory_usage_bytes` includes
  reclaimable cache and over-estimates.
- **Pod churn collapses per-pod percentiles.** A `quantile_over_time(...)[30d]`
  evaluated per pod and then aggregated with `max by (container)` returns the
  same value for p50/p95/p99/max on a high-churn workload (each pod lives only
  minutes). Always aggregate across the fleet **at each instant** first
  (`avg(...)` for the typical replica, `max(...)` for the hottest), then take
  the percentile over time with a `[30d:10m]` subquery. Verified live: a
  workload cycling ~2000 pods in 30 days returned p50 = p95 = max with the
  per-pod form, and a clean spread (p50 0.05 / p95 0.65 / peak 2.9 cores) with
  the fleet-first form.
- **Censored peaks.** If the memory working-set peak equals the configured limit
  and **either** OOM kills **or** a sustained major-fault rate are present, the
  real peak is hidden — recommend a higher limit as a floor and re-measure, do
  not trust `max × 1.25` off a clamped maximum. (A page-cache-bound workload
  clamps at the limit with no OOM at all — see the major-page-faults section.)
- **zsh eats `[5m]` as an array subscript.** When you build a PromQL string in a
  shell variable and interpolate it as `$EXPR[5m]`, zsh parses `[5m]` as a
  subscript and aborts with `bad math expression: operator expected at 'm'`.
  Brace the variable — `rate(${EXPR}[5m])` — or assemble the whole range
  selector inside the variable. (Bash is unaffected, but the default shell on
  macOS is zsh.)
