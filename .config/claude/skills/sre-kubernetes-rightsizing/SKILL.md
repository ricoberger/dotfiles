---
name: sre-kubernetes-rightsizing
description: |
  Analyze the resource usage of a Kubernetes Deployment, StatefulSet, or
  DaemonSet over the last 30 days and recommend right-sized CPU/memory requests
  and limits plus autoscaling (KEDA/HPA) improvements. Triggers when the user
  asks to "right-size", "analyze resource usage", "tune requests/limits",
  "is this workload over/under-provisioned", or "improve autoscaling" for a
  named workload. Reads live cluster spec and 30-day metrics through a single
  Grafana instance (delegating to the sre-grafana and sre-kubernetes skills),
  treats the live cluster as authoritative and an optional manifest as the
  verification + apply target, and never edits cluster resources directly.
---

# SRE: Kubernetes Right-Sizing

Analyze how much CPU and memory a workload actually used over the last 30 days,
compare that against its configured requests and limits, and produce actionable
right-sizing recommendations — including autoscaling (KEDA / HPA) tuning. The
live cluster is the source of truth for the current configuration; an optional
manifest is used only to verify drift and as the target the user can choose to
apply recommendations to. **This skill never mutates cluster resources.**

## Scope

- **In scope:** `Deployment`, `StatefulSet`, `DaemonSet`.
- **Out of scope:** `CronJob` (episodic, short-lived pods — different
  methodology) and any workload kind not listed above. If asked, say so.

## Inputs

Collect — and confirm — the following before running any queries. Ask the user
for anything missing; never guess.

| Input            | Required | Notes                                                                               |
| ---------------- | -------- | ----------------------------------------------------------------------------------- |
| Grafana instance | yes      | Name resolved from `$GRAFANA_INSTANCES` (same mechanism as the `sre-grafana` skill) |
| Namespace        | yes      | e.g. `grafana`                                                                      |
| Workload name    | yes      | e.g. `grafana`                                                                      |
| Workload kind    | no       | **Auto-detected** from the cluster; only ask if the name is ambiguous               |
| Manifest file    | no       | Plain rendered YAML of the workload; unlocks drift-check + apply                    |

### How To Reach the Data

A single Grafana instance powers **both** halves of this skill — do not ask for
separate cluster credentials by default:

- **Metrics** → the Prometheus / VictoriaMetrics datasource on that Grafana,
  driven through the `sre-grafana` skill.
- **Cluster state** → the `sre-kubernetes` skill in **Mode C** (the Grafana
  Kubernetes datasource proxy, well-known UID `kubernetes`) on the _same_
  Grafana instance.

If — and only if — the user explicitly prefers direct cluster access, allow
`sre-kubernetes` Mode A (API URL + token) or Mode B (kubeconfig context) as an
override.

## Workflow

Do these phases in order. Delegate every metric query to `sre-grafana` and every
cluster read to `sre-kubernetes` — this skill decides _what_ to ask for and how
to interpret it, never re-implements API access.

### 1. Resolve the Target

Auto-detect the workload kind by looking the name up in the namespace (via
`sre-kubernetes`, Mode C). Check `Deployment`, then `StatefulSet`, then
`DaemonSet`:

```text
/apis/apps/v1/namespaces/<ns>/deployments/<name>
/apis/apps/v1/namespaces/<ns>/statefulsets/<name>
/apis/apps/v1/namespaces/<ns>/daemonsets/<name>
```

If more than one kind matches the name, ask the user which one. Record the
matched kind — it drives pod selection and autoscaling applicability.

### 2. Read the Live Spec (Authoritative Current Config)

From the matched object, extract per container (and per init container):

- `resources.requests.cpu` / `.memory`
- `resources.limits.cpu` / `.memory`
- container names (the join key for everything downstream)
- the pod selector / label set and current replica count

This live spec — **not the manifest** — is the authoritative "current
configuration" used in the report and as the baseline for recommendations.

Also detect controllers that already manage resources or scaling (see
[`references/keda.md`](references/keda.md)):

- KEDA `ScaledObject` (`scaledobjects.keda.sh`) targeting the workload.
- A plain `HorizontalPodAutoscaler` (or the KEDA-generated `keda-hpa-<name>`).
- A `VerticalPodAutoscaler` targeting the workload, and its `updateMode`.

### 3. Drift Check (Only if a Manifest Was Provided)

Parse the manifest, locate the resource by `kind` + `name`, and compare its
`resources` blocks against the live spec from step 2. Report any differences — a
manifest that disagrees with the cluster changes how the usage data should be
read (the running pods reflect the _live_ spec, not the manifest). Do not treat
the manifest as current config; it is a verification artifact and the apply
target only.

### 4. Pull 30-Day Usage via `sre-grafana`

Use the queries in [`references/queries.md`](references/queries.md). For each
container, collapse the 30-day window to single statistics with `_over_time`
instant queries (do **not** pull raw range series for the stats):

- CPU usage cores: p50, p95, p99, max.
- Memory working set bytes: p50, p95, p99, max.
- CPU pressure (PSI) — optional, when `container_pressure_cpu_*` exists
  (cgroup v2); probe first: some/full-wait p95 + peak. The CPU bottleneck signal
  that **replaces CFS throttling**, which is structurally dead here (no CPU
  limits + `cpuCFSQuota` disabled cluster-wide, so the throttling series never
  exist).
- OOMKill and restart signals.
- Memory pressure (PSI) — optional, when `container_pressure_memory_*` exists
  (cgroup v2); probe first: full-stall p95 + peak. A leading bottleneck signal
  that catches pressure happening _between_ scrapes.

Selection must be **robust to pod churn over 30 days** (rollouts change pod
names) — prefer the kube-prometheus mixin recording rules when present: the
`namespace_workload_pod:kube_pod_owner:relabel` rule for pod → workload
attribution, and the pre-normalized
`node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate5m` /
`node_namespace_pod_container:container_memory_working_set_bytes` series for
usage (they bake in `image!=""` + `sum by(pod,container)` and need no runtime
`rate()`). Fall back to raw cAdvisor + a kind-specific pod-name regex
cross-checked against the live pod list only when the rules are absent — the
regex over-matches and the un-normalized series skew the percentile (verified:
raw+regex CPU p95 0.65 vs mixin 0.84 on the same workload). **Aggregate across
the fleet at each instant before taking percentiles over time** — `avg(...)`
across pods for the typical-replica signal that sizes the request, `max(...)`
across pods for the hottest-replica signal that sizes the memory limit. Never
take a per-pod `quantile_over_time` then `max by (container)`: on a high-churn
workload each pod lives only minutes, so its own percentiles collapse (p50 ≈ p95
≈ max) and the number is meaningless. Pull a coarse-step range series **only**
for the variability/trend check used by the autoscaling gate.

The `p95` in the recommendation rules below is the **typical-replica**
(`avg`-aggregated) p95; the memory-limit `max` is the **hottest-replica**
(`max`-aggregated) peak.

### 5. Compute Resource Recommendations

Per container, judge CPU and memory independently:

| Resource       | Recommendation                     | Rule                                          |
| -------------- | ---------------------------------- | --------------------------------------------- |
| CPU request    | `p95 × 1.15`                       | Reserve for normal load; CPU is burstable     |
| CPU limit      | **none** — remove if currently set | Org policy: no CPU limits (avoid throttling)  |
| Memory request | `p95 × 1.1`                        | Schedule against typical working set          |
| Memory limit   | `max × 1.25` (never below peak)    | Memory is incompressible; clear the real peak |

Round CPU to a sane unit (e.g. nearest 10m / 50m) and memory to a sane unit
(e.g. nearest 8Mi / 16Mi). Verdict per resource:

- **over-provisioned:** request > usage-p95 × ~2 (or memory limit ≫ max),
  **and** near-zero CPU/memory PSI.
- **under-provisioned:** usage-p95 ≥ request (CPU); peak approaches limit or
  OOMKills observed (memory); **or elevated PSI** (CPU starvation / memory
  thrashing) even when the usage percentile looks adequate — PSI exposes demand
  the percentile censors.
- **appropriately sized:** otherwise.

CPU PSI replaces CFS throttling as the CPU bottleneck signal (throttling is dead
without CPU limits / CFS quota). Because the CPU request sets `cpu.weight`, a
starved container's CPU usage is suppressed while it waits — so **high CPU PSI
means raise the request even if usage-p95 looks fine**, and **never trim a CPU
request without near-zero CPU PSI**. Treat memory PSI symmetrically (see below).

When memory PSI is available, use it to **disambiguate the memory remediation**
(see `references/queries.md`): sustained full-PSI ⇒ chronic starvation, raise
request _and_ limit; PSI p95 ≈ 0 with peaks + OOMKills ⇒ bursty spikes, raise
the _limit_ for headroom (request may be fine); PSI ≈ 0 with working set well
under the limit ⇒ genuine headroom, so trimming is safe. **Never recommend
downsizing memory without near-zero PSI** — it is the proof the current limit is
not already biting.

**Init containers:** report and size separately, by per-container max — they do
not run concurrently with app containers, so never fold their usage into the
main containers' totals.

### 6. Autoscaling Analysis (Always Run)

See [`references/keda.md`](references/keda.md) for the exact reads and the
greenfield template. Always produce an autoscaling section:

- **KEDA `ScaledObject` or HPA present:** report the triggers (metric · query ·
  threshold), `minReplicaCount` / `maxReplicaCount`, and from the 30-day replica
  history the % of time pinned at the floor (over-provisioned floor) vs the
  ceiling (capacity-starved → raise max). Run the trigger's own PromQL over 30
  days to judge whether the `threshold` actually triggers, never crosses, or is
  always exceeded. Cross-check the scaling signal against the real constraint —
  if it scales on a custom metric but the pods are the thing OOMing, flag that
  the autoscaler will not protect against the binding constraint.
- **VPA present in `Auto` / `Recreate`:** the cluster is already right-sizing —
  **defer**: report findings but recommend no manual resource change to avoid
  fighting the VPA.
- **Nothing found:** a short "no HPA / KEDA / VPA found" note. Then, **for
  Deployments only**, gate on variability (step 4's trend series): if load
  varies meaningfully (e.g. peak ≥ ~2× trough or a clear diurnal pattern),
  propose a **starter KEDA `ScaledObject`** (see `references/keda.md`). Pick the
  trigger metric in tiers: (1) hunt for a discoverable domain metric (RPS, queue
  depth) and offer candidates; (2) if none is found and the workload would
  benefit, **ask the user** for a metric; (3) only then fall back to a
  CPU-utilization trigger relative to the recommended CPU request. Always label
  the proposal a starting point requiring validation. If load is essentially
  flat, recommend keeping fixed replicas right-sized to N instead.

### 7. Report

Produce the structured report below. Keep it compact — the user wants the
recommendation plus enough evidence to trust it, not a narration.

```markdown
## Right-Sizing: <kind>/<name> · namespace <ns> · cluster <cluster>

**Window:** last 30 days · **Source:** <grafana-instance> · **Replicas:**
observed <min>–<max> (current <N>)

### Drift Check <!-- only if a manifest was provided -->

Manifest vs. live cluster requests/limits — match / differ (table; differences
flagged).

### Resource Analysis <!-- per container -->

| container | resource | current req | current lim | p50 | p95 | p99 | max | verdict |
| --------- | -------- | ----------- | ----------- | --- | --- | --- | --- | ------- |

Risk flags: OOMKills (count + last seen), CPU pressure (PSI some/full %),
restarts, memory pressure (full-PSI p95 / peak %, when available).

### Recommended Resources <!-- per container -->

| container | resource | current → recommended | rule |
| --------- | -------- | --------------------- | ---- |

- CPU request X → Y (p95×1.15)
- CPU limit remove (policy) <!-- only if currently set -->
- mem request X → Y (p95×1.1)
- mem limit X → Y (max×1.25)

### Autoscaling Analysis

- Detected: KEDA ScaledObject / plain HPA / VPA / none
- If present: triggers (metric · query · threshold), min/max, % time at
  floor/ceiling, threshold verdict, recommended tweaks
- If none + Deployment + variable load: proposed starter ScaledObject
- If none + steady load: "autoscaling not beneficial — keep fixed N,
  right-sized"

### Summary of Recommendations

1. Resource changes 2. Autoscaling changes 3. Coupling caveats (HPA↔request, VPA
   deferral, QoS-class change)

### Confidence

high / medium / low + the main data-completeness caveat (metric gaps, short
history, HPA-pinned CPU).
```

#### Coupling Caveats To Always Check Before Recommending

- **HPA on CPU utilization:** the observed CPU p95 is pinned near the HPA target
  by design, and changing the CPU request changes the autoscaler's behavior. Do
  **not** auto-recommend a new CPU request for a CPU-utilization-scaled workload
  — flag the request↔target coupling and recommend memory changes only.
- **QoS class change:** if a recommendation would flip the pod's QoS class (e.g.
  removing a CPU limit, or request/limit equality changes), call it out.
- **VPA in Auto:** defer (see step 6).

### 8. Apply (Optional — Manifest Only, on Explicit Confirmation)

Only after the report, and only when the user explicitly asks to apply:

- **Always show the exact diff first** (use the `edit` tool's preview), matched
  by `kind` + `name` + container `name`. Wait for confirmation before writing.
- **Resource edits:** update each container's `resources.requests` / `.limits`
  in place; delete a `cpu` limit if present (policy).
- **Existing autoscaler tweaks:** edit `threshold` / `minReplicaCount` /
  `maxReplicaCount` in the provided/locatable `ScaledObject` (or HPA) manifest.
- **Greenfield `ScaledObject`:** treat as **opt-in / explicit** — present the
  full YAML, and only write it when the user explicitly asks and says where (new
  file vs. appended document). Never bundle it into a blanket "apply all".
- **Per-recommendation granularity:** let the user accept all or cherry-pick a
  subset of changes.
- **Templated manifests (Helm / Kustomize):** detect and **never blind-rewrite**
  — print the values to change and ask where to apply them.

## Hard Rules

- **Never mutate cluster resources.** No `apply`, `patch`, `edit`, `scale`,
  `delete`, or `kubectl rollout` against the cluster — ever. The only writes
  this skill performs are edits to a **local manifest file**, after an explicit
  user confirmation and a shown diff.
- **Live cluster is authoritative for current config; the manifest is a
  verification + apply artifact.** When they drift, report it; do not silently
  prefer one.
- **Never invent usage numbers, percentiles, or timestamps.** If a query
  returned nothing, say so — an empty metric result is a finding (and may mean a
  wrong selector, not "zero usage"). Cross-check suspicious zeros with a broader
  query.
- **Always include the time window and the exact query / API path** for each
  number, so the user can reproduce it.
- **Respect controllers.** Do not recommend changes that fight an HPA (CPU
  request coupling) or a VPA in `Auto` mode without flagging the conflict.
- **Never** echo, log, or write the Grafana bearer token to disk.
- **Flag QoS-class changes** any recommendation would cause.
