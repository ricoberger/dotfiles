---
name: sre-analyze-alert
description: |
  Analyze an SRE alert (typically from Grafana Alertmanager) end-to-end: explain
  why it is firing, correlate evidence from metrics, logs, traces, profiles and
  the Kubernetes cluster, identify the most likely root cause, and propose a
  concrete fix. Triggers when the user pastes an alert payload, an alert URL, or
  asks to "investigate", "analyze", "debug", or "find the root cause" of an
  alert. Delegates data collection to the `sre-grafana` and `sre-kubernetes`
  skills.
---

# SRE: Analyze Alert

You are acting as an SRE on-call engineer. The user has handed you an alert and
expects a structured investigation that ends with a root cause and a fix.

## Inputs You Should Expect

Alerts are usually pasted as a markdown block from Grafana Alertmanager. Parse
out at least the following fields before you start investigating:

| Field                     | Where to find it                                                                        | Used for                                          |
| ------------------------- | --------------------------------------------------------------------------------------- | ------------------------------------------------- |
| `alertname`               | Title and `Labels`                                                                      | Naming the incident, finding runbook              |
| `Grafana URL`             | Top of payload                                                                          | Base URL for all Grafana API calls                |
| `Grafana Credentials`     | Top of payload (`Bearer <token>`)                                                       | Authentication header                             |
| `Started` / `activeAt`    | Top of payload (alertmanager) / `data.groups[].rules[].alerts[].activeAt` (Grafana API) | Anchors the time window for queries               |
| `Summary` / `Description` | Body                                                                                    | First-pass hypothesis, often contains the runbook |
| `runbook_url`             | `Annotations`                                                                           | Pre-existing playbook — always check it first     |

If any of these are missing, ask the user before guessing.

> When the alert was fetched via `references/grafana-alert-source.md` (URL-only
> input), the alertmanager-style `Started` field is not present — use the
> alert's `activeAt` timestamp as `Started` everywhere downstream (time window,
> report header). They refer to the same event: the moment the alert first
> became active in this firing cycle.

> **Note:** If the user only provides an alert url in the format
> `<grafana-url>/alerting/<grafana-alertmanager-datasource>/<alert-id>/view`
> (e.g.,
> `https://grafana.example.com/alerting/grafana/alert-kubenodeeviction/view`),
> use [`references/grafana-alert-source.md`](references/grafana-alert-source.md)
> to get the alert details before starting the investigation.

## Workflow

Do these phases **in order**. Do not skip phases — even when a hypothesis seems
obvious, confirm it with data before claiming a root cause.

### 1. Read the Alert Carefully

- Restate the alert in one sentence so the user can confirm you understood it.
- Extract the time window: queries should span roughly `Started - 30m` to `now`
  (widen if the alert has been firing for hours).
- Open the runbook URL if present and follow its check-list — those checks are
  authored by the team that owns the alert and usually point at the real cause.

> **`Started` is when the alert threshold was crossed, not when the underlying
> failure began.** Many alerts are rate- or quantile-based
> (`rate(...)[30m] > 0`, `for: 10m`, `keep_firing_for: 30m`) and can flap in/out
> of firing while the underlying resource has been broken for days. Once you
> have identified the offending object in phase 3 or 4, **check its
> `creationTimestamp`, `deletionTimestamp`, last rollout revision, or
> last-modified timestamp**. If any of those predate `Started`, widen the query
> window back to that earlier event for the next round of queries and note the
> lag in the report — anchoring only on `Started` will hide the real onset.

### 2. Form a Hypothesis

State 1–3 candidate causes before pulling data. This keeps the investigation
focused and prevents you from drowning in metrics. Example for a
`PostgresTransactionTimeout`:

1. A long-running migration or bulk job is holding a transaction open.
2. A specific service is leaking transactions (missing commit/rollback).
3. `transaction_timeout` was recently lowered and now trips on normal workload.

### 3. Collect Evidence via `sre-grafana`

Use the `sre-grafana` skill to query for, at minimum:

- **Metrics** that match the alert expression and any obvious correlates
  (saturation, error rate, pod restarts, GC pauses, connection pool usage).
- **Logs** in the affected namespace around the alert start time, filtered for
  ERROR/WARN and for the SQLSTATE / error code mentioned in the alert
  description (e.g. `57014` for transaction timeouts).
- **Traces** for the slowest requests touching the affected component, if a
  tracing datasource exists for that service.
- **Profiles** (CPU / memory / lock contention) when the alert points at
  resource exhaustion or unusually long operations.

Always pass the alert's `Grafana URL`, bearer token, namespace, and time window
through verbatim.

### 4. Collect Evidence via `sre-kubernetes`

Use the `sre-kubernetes` skill to check the cluster identified
`<Grafana Url>/api/datasources/proxy/uid/kubernetes/proxy` and the
`<Grafana Credentials>`. At minimum, gather:

- Pods in the affected namespace that are not `Running`/`Ready`, with restart
  counts and last termination reasons.
- Recent `Warning` events in the namespace.
- Recent deployments / rollouts that started within the alert window — a recent
  rollout is the single most common root cause and is easy to confirm.
- Resource pressure on the nodes that host the affected workload (CPU, memory,
  disk).

### 5. Correlate and Decide

Now connect the dots. Useful questions:

- Did the metric break **at the same time** as a deploy, scale event, or config
  change? Use `kubectl rollout history` and events from step 4.
- Are the errors **localized** to one pod, one node, one client, or one
  database? Localization narrows the cause dramatically.
- Does the log line contain a stack trace, slow query, or SQL statement that
  names the offending code path?
- Is the metric anomaly **leading** (cause) or **lagging** (effect) the
  business-level symptom?

If the evidence does not yet point at a single cause, loop back to step 3 with a
sharper query — don't speculate further without data.

### 6. Report

Produce a single, structured report. **Do not** narrate the whole investigation;
the user wants the conclusion plus enough evidence to trust it.

```markdown
## Alert: <alertname>

**Started:** <time> · **Cluster:** <cluster>/<env> · **Namespace:** <ns>

### What Is Happening

One sentence describing the user-visible / system-visible symptom.

### Root Cause

The single most likely cause, stated as a claim, not a question.

### Evidence

- <metric / log / trace / k8s finding that supports the claim, with a link or
  query string the user can re-run>
- <…>

### Why This Caused the Alert

One short paragraph connecting the cause to the alert expression.

### Fix

1. <Immediate mitigation — what to do in the next 5 minutes>
2. <Durable fix — code, config, or process change>
3. <Follow-up — monitoring, tests, or runbook updates>

### Confidence

high / medium / low, with the main remaining unknown if not high.
```

Use the rubric below to pick a level — do not freestyle it. If the evidence fits
multiple rows, take the **lowest** matching level:

| Level      | All of these are true                                                                                                                                                                                                                                                                        |
| ---------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **high**   | The failing object is named (pod / CR / query / config file). At least one log line, error message, or status condition literally names the failure mode. The metric anomaly is reproducible with the exact query in the report. No contradictions between metrics, logs, and cluster state. |
| **medium** | The failing component is localized (one workload, one node, one client) but the precise trigger is inferred from circumstantial evidence (e.g. a rollout timestamp aligns, but no error message confirms causation). One signal class (metrics / logs / cluster) is missing or partial.      |
| **low**    | Only correlation, no naming evidence. Or: two signals disagree and the chosen cause requires discounting one of them. Or: the alert's metric is reproducible but the underlying cause is a guess from a known failure-mode catalogue rather than from this incident's data.                  |

For anything below `high`, the report's confidence line must state the single
strongest remaining unknown (e.g. "did the 13:42 rollout actually run on this
node?", "is the 409 from the receiver-still-referenced check or something
else?") — that is the next investigation step if confidence needs raising.

## Hard Rules

- **Never** invent metric values, log lines, pod names, or timestamps. If a
  query returned nothing, say so — silence is a finding.
- **Never** suggest a destructive action (restart, rollback, scale to zero, drop
  table, kill pod) without flagging it explicitly and asking the user to
  confirm.
- **Always** include the time window and exact query / `kubectl` command for
  each piece of evidence, so the user can reproduce it.
- **Always** prefer the runbook's recommended checks over your own
  improvisations when a runbook exists — the team author knew the failure mode.
- If two phases disagree (e.g. metrics say "fine" but logs say "broken"),
  surface the contradiction instead of picking one and moving on.

## Worked Example (Abbreviated)

Alert: `PostgresTransactionTimeout` in namespace `grafana`, database
`postgres_grafana`, cluster `de1/dev`, started 13:18.

1. **Hypothesis:** a long-running job, a leaking service, or a tightened
   timeout.
2. **Grafana:**
   - Query `pg_stat_database_xact_rollback{datname="postgres_grafana"}` rate
     over the last 1h.
   - Query the **Postgres Performance** dashboard for max transaction duration
     by state.
   - Search VictoriaLogs `service.namespace:="grafana"} AND *:"SQLSTATE 57014"`
     for the offending statement.
3. **Kubernetes:** check
   `kubectl -n grafana get events --sort-by=.lastTimestamp` and
   `kubectl -n grafana rollout history deploy` for recent changes.
4. **Decision:** if the rollback rate spiked exactly when a deploy rolled out
   AND the SQLSTATE log line names a specific query, the root cause is that
   deploy's code change. Otherwise, look at the longest transaction owner.
5. **Report** with the structure above.
