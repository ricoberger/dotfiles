# Report Templates

## Investigation Report

Use this after the first investigation round and update it in later rounds. Keep
it short; tables for per-cluster numbers.

```markdown
## Summary

2–3 sentences: what is broken, why, and the recommended fix.

## What happens

- **Request path:** <client → … → service>, which hop fails.
- **Volume (<window, UTC>):** <affected> of <total> (<rate>) per cluster.
- **Where:** affected endpoints / pods / pairs / episodes.
- **Evidence:** the matching or localizing finding, with query and IDs.

## Why it happens

- **Root cause:** stated as a claim.
- **Trigger:** what starts an episode.
- **Why it is this bad / why this service:** amplifying factors.
- **Not causal:** things ruled out (e.g. a recent change), with the reason.

## What we couldn't confirm

- <open point> — what would confirm it (e.g. live check, needs approval).

## What we can do

1. **Short term:** … (effect, risk, verification)
2. **Reduce blast radius:** …
3. **Durable / upstream fix:** …
4. **Not recommended:** … and why.

## Confidence

high / medium / low — the strongest remaining unknown.

<Next step question>
```

### Confidence Rubric

If the evidence fits multiple rows, take the **lowest**:

| Level      | All of these are true                                                                                                                                                          |
| ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **high**   | The failing component is named and localized. A log line, status, trace or upstream issue names the failure mode. Numbers reproduce with the given queries. No contradictions. |
| **medium** | The failing component is localized, but the trigger or mechanism is inferred from circumstantial evidence, or one signal class is missing.                                     |
| **low**    | Only correlation, or signals disagree, or the cause is a guess from a known failure-mode catalogue rather than from this incident's data.                                      |

## Postmortem

Only when the user explicitly asks for it after the incident is resolved. Mark
unknown facts (detection time, who declared the incident) as _TBD_ instead of
guessing.

```markdown
# <Ticket>: <service> <symptom> on <cluster(s)> (<date>)

## Summary

- **What happened:** <window UTC>, <symptom>.
- **Trigger:** …
- **Root cause:** …
- **Why it got worse / lasted:** …
- **Recovery:** …

## Impact

- **Duration:** <start> – <end> UTC per cluster.
- **Affected:** requests / users / tenants (count and share).
- **User-visible effect:** errors, latency, failed features.
- **Neighbours:** other services or workloads affected.
- **Not affected:** clusters, services or data that stayed fine (no data loss,
  no OOMs, …).

## Incident Timeline (UTC)

| Time | Event |
| ---- | ----- |
| …    | …     |

Include relevant changes before the incident (marked "context, not causal" if
so), onset, escalation, mitigations, recovery, detection (_TBD_ if unknown).

## Root Cause Analysis

1. **Trigger:** …
2. **Root cause:** …
3. **Contributing:** …
4. **Not causal:** …

## Resolution Steps

- What ended the incident (and what only looked like it did).
- Changes made (PRs, live changes, drift).

## Follow Ups / Action Items

| #   | Action | Owner (proposed) | Status |
| --- | ------ | ---------------- | ------ |
| 1   | …      | …                | …      |
```

## Query List

On request, list every query and lookup used in the investigation that showed or
ruled out something — **all signal types, not only metrics**. Build it from the
evidence log (`/tmp/<incident-slug>/evidence.md`), not from memory.

Group by area (e.g. edge/CDN, mesh/traffic, service, pod resources, autoscaling,
database, nodes, neighbours, cluster state, upstream).

- State the default cluster, window and datasources (UID and type) once at the
  top; give a query its own cluster/window when it differs.
- Define abbreviations for repeated label sets or filters (e.g.
  `$SVC = namespace="…", container="…"`, `$GW = k8s.pod.name:~"gateway-.*"`).
- Give each row a **Type**:

  | Type      | Example                                                     |
  | --------- | ----------------------------------------------------------- |
  | `PromQL`  | metrics query                                               |
  | `LogsQL`  | VictoriaLogs query (or LogQL)                               |
  | `Trace`   | TraceQL / trace search, or a single trace ID lookup         |
  | `Profile` | Pyroscope query (profile type, label selector)              |
  | `CDN`     | Cloudflare analytics query                                  |
  | `kubectl` | cluster lookup (events, rollout history, object state)      |
  | `Admin`   | live admin endpoint (e.g. Envoy `/clusters`), with approval |
  | `Git`     | `git log` / PR lookup that dated a change                   |

- Mark each row: 🔴 showed the problem · 🟡 indirect or misleading · ⚪ normal
  (ruled something out) · ⚫ no data.
- One-line finding per row with before → during values.

```markdown
|     | Type     | Query                                                                  | Finding                        |
| --- | -------- | ---------------------------------------------------------------------- | ------------------------------ |
| 🔴  | `PromQL` | `max(rate(container_pressure_io_stalled_seconds_total{$SVC}[5m]))`     | 0 → 0.9–1.0                    |
| 🔴  | `LogsQL` | `$GW AND http.response.flags:="DR" \| stats by (k8s.pod.name) count()` | 90 % of hangs on 2 pods        |
| 🔴  | `Trace`  | `{ resource.service.name = "x" && duration > 60s }`                    | 280–530 s spans in `transform` |
```

### Evidence IDs

List the concrete IDs behind key claims, so the user can open them directly:

| Claim                | Type           | ID                   | Cluster / time (UTC) | Finding                         |
| -------------------- | -------------- | -------------------- | -------------------- | ------------------------------- |
| Trigger              | trace ID       | `4bf92f35…`          | …                    | first request of the burst      |
| Response lost at hop | CDN ray ID     | `8c1f2a3b…-FRA`      | …                    | 200 in 23 ms at hop N, hang N−1 |
| Episode              | pod / pod pair | `gateway-…` → `10.…` | 04:10–05:10          | 50 % of requests hung           |

Include trace IDs, request IDs, CDN ray IDs, pod or pod-pair names, PR/commit
IDs and upstream issue/PR links.

### Smallest Set That Shows the Incident

End with the 3–6 rows (of any type) that together show trigger, mechanism and
impact, e.g. the backlog metric, the saturation metric, the log query that
localizes the hop and the trace ID of the trigger.
