---
name: sre-grafana
description: |
  Query a Grafana instance for metrics, logs, traces, and profiles to
  investigate an alert or answer related questions. Triggers when the user asks
  to "check Grafana" or "query metrics/logs/traces/profiles", references a
  Prometheus, VictoriaMetrics, VictoriaLogs, VictoriaTraces, Tempo, or
  Pyroscope datasource exposed through Grafana, or when the `sre-analyze-alert`
  skill needs supporting evidence. Selects the appropriate datasource, runs
  the query against Grafana's HTTP API, and summarizes the result.
---

# SRE: Grafana

Investigate alerts and answer observability questions by pulling metrics, logs,
traces, and profiles **through the Grafana HTTP API** — never by hitting the
underlying datasources directly.

## Inputs

Resolve every required input before running a query. If anything is missing, ask
the user — do not guess.

All requests authenticate with `Authorization: Bearer <token>`. **Never** log,
echo, or write the bearer token to disk.

### Always Required

| Input        | Example                                                                                 |
| ------------ | --------------------------------------------------------------------------------------- |
| Time range   | RFC3339 / Unix-ms `start` and `end` / relative `start` and `end` (e.g. `now-1h`, `now`) |
| Query target | Metric name, LogQL expression, trace ID, etc.                                           |

### How To Reach Grafana — One of the Following

**Option A — by instance name:** the user supplies a name and the skill resolves
the base URL and token from the `$GRAFANA_INSTANCES` environment variable. Each
entry maps a name to its base URL and a shell command that prints the bearer
token; run that command to obtain the token at query time.

| Input                 | Example           |
| --------------------- | ----------------- |
| Grafana instance name | `example-grafana` |

**Option B — by direct credentials:** the user supplies the base URL and a
bearer token explicitly.

| Input            | Example                       |
| ---------------- | ----------------------------- |
| Grafana base URL | `https://grafana.example.com` |
| Bearer token     | `Bearer glsa_…`               |

### Optional

| Input          | Example                                      |
| -------------- | -------------------------------------------- |
| Datasource UID | Resolved via `/api/datasources` if not given |

## Step 0 — Resolve the Datasource UID

Every query in the later steps is addressed to a **datasource UID**, not to a
signal type — so before running the first query against a Grafana instance you
have not yet seen this session, list its datasources and pick the UID that
matches the signal you need (metrics, logs, traces, or profiles).

If the user supplied a UID up front, skip this step and use it directly.
Otherwise, enumerate the available datasources:

```bash
curl -sS -H "Authorization: $TOKEN" "$GRAFANA/api/datasources" \
  | jq '[.[] | {uid, name, type}]'
```

Map the signal you need to a UID using the `type` field:

| Signal     | Datasource `type` values                           |
| ---------- | -------------------------------------------------- |
| Metrics    | `prometheus`, `victoriametrics-metrics-datasource` |
| Logs       | `victoriametrics-logs-datasource`                  |
| Traces     | `jaeger`, `tempo`                                  |
| Profiles   | `grafana-pyroscope-datasource`                     |
| Kubernetes | `ricoberger-kubernetes-datasource`                 |
| Cloudflare | `ricoberger-cloudflare-datasource`                 |

If more than one datasource matches a signal, prefer the one whose `name`
clearly references the environment or cluster in question; if still ambiguous,
ask the user which one to use rather than guessing.

Cache the resulting signal-to-UID mapping for the rest of the session so
follow-up queries can reuse it without re-listing the datasources.

## Step 1 — Pick a Time Window

Normalize whatever the user provided into a form Grafana accepts for `from` and
`to` — relative expressions (`now`, `now-1h`), Unix-ms strings, or RFC3339 — and
**always pass the window explicitly**; never rely on Grafana defaults.

Handle the common inputs as follows:

| User-supplied form                                             | How to pass it                                                                                                                                                                                 |
| -------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Unix-ms pair (e.g. `Start: 1780471618000, End: 1780471631000`) | Pass straight through as `from` / `to` strings — no conversion needed.                                                                                                                         |
| Human-readable timestamp (e.g. `3. Jun 2026 at 9:11`)          | Convert to RFC3339 with an explicit timezone (e.g. `2026-06-03T09:11:00+02:00`). If the user did not state a timezone, ask before assuming one.                                                |
| "Current" / no timestamp given                                 | Default to `from: now-1h`, `to: now`.                                                                                                                                                          |
| Alert payload with a `startsAt` / `Started:`                   | Anchor on `startsAt` / `Started:`: query from `startsAt - 30m` to `now` (or to `endsAt` if the alert has already cleared). If `startsAt` is older than 1h, widen the start to cover the onset. |

If only one bound is provided, fill the other from context: a lone start
defaults the end to `now`; a lone end defaults the start to `end - 1h`.

## Step 2 — Run the Query

Every query goes through one of two HTTP patterns:

- `POST /api/ds/query` — Prometheus / VictoriaMetrics, VictoriaLogs, Tempo /
  VictoriaTraces, Pyroscope and Cloudflare. The body is a Grafana panel-query
  payload; multiple `queries[]` entries in a single POST fan out cheaply. Always
  set `Content-Type: application/json`.
- `GET /api/datasources/proxy/uid/<uid>/...` — Kubernetes proxy.

Pass the `from` / `to` window resolved in Step 1 explicitly on every request; do
not rely on Grafana defaults.

The exact request body, query syntax, gotchas, and worked examples differ per
datasource. After resolving the UID in Step 0, open the matching reference and
follow it:

| Signal     | Datasource `type`                                  | Reference                                                  |
| ---------- | -------------------------------------------------- | ---------------------------------------------------------- |
| Metrics    | `prometheus`, `victoriametrics-metrics-datasource` | [`references/prometheus.md`](references/prometheus.md)     |
| Logs       | `victoriametrics-logs-datasource`                  | [`references/victorialogs.md`](references/victorialogs.md) |
| Traces     | `jaeger`, `tempo`                                  | [`references/tempo.md`](references/tempo.md)               |
| Profiles   | `grafana-pyroscope-datasource`                     | [`references/pyroscope.md`](references/pyroscope.md)       |
| Kubernetes | `ricoberger-kubernetes-datasource`                 | [`references/kubernetes.md`](references/kubernetes.md)     |
| Cloudflare | `ricoberger-cloudflare-datasource`                 | [`references/cloudflare.md`](references/cloudflare.md)     |

### Discovering Existing Dashboards

Existing dashboards capture the queries the team already trusts — reuse them
instead of inventing your own. There are two situations where you should look
for one:

**1. When investigating an alert.** Check the alert's annotations in this order:

- `__dashboardUid__` — fetch the dashboard directly by UID.
- `runbook_url` — when it points at a Grafana dashboard (path matches `/d/<uid>`
  or `/d/<uid>/<slug>`), extract the UID from the path and any `var-*` query
  parameters as label values. Example:
  `https://grafana.example.com/d/runbook-kubedeploymentrolloutstuck?var-namespace=istio-system&var-deployment=istiod`
  -> UID `runbook-kubedeploymentrolloutstuck`, variables
  `namespace=istio-system` and `deployment=istiod`. Pass the `var-*` values
  through as template variables (`scopedVars`) when running the dashboard's
  queries so they resolve to the labels the alert is actually about.

**2. When asked to analyze the health of a service.** Search for dashboards that
already describe that service, in this order:

1. Tag match — `query=&tag=<service>` (most precise; teams tag service
   dashboards by service name).
2. Folder match — list folders via `/api/folders`, and if one matches the
   service name, list its dashboards with `query=&folderUIDs=<uid>`.
3. Free-text search — `query=<service>` as a fallback.

If exactly one dashboard is found, **ask the user** whether to use it before
running its queries. If multiple are found, list them (title + folder + UID) and
ask which one to use. Never auto-pick — the wrong dashboard sends the
investigation in the wrong direction.

```bash
# Fetch a dashboard by UID
curl -sS -H "Authorization: $TOKEN" "$GRAFANA/api/dashboards/uid/$UID"

# Search by tag (preferred for service lookups)
curl -sS -G -H "Authorization: $TOKEN" "$GRAFANA/api/search" \
  --data-urlencode "tag=$SERVICE"

# List folders, then list dashboards inside a folder
curl -sS -H "Authorization: $TOKEN" "$GRAFANA/api/folders"
curl -sS -G -H "Authorization: $TOKEN" "$GRAFANA/api/search" \
  --data-urlencode "folderUIDs=$FOLDER_UID"

# Free-text search for dashboards
curl -sS -G -H "Authorization: $TOKEN" "$GRAFANA/api/search" \
  --data-urlencode "query=$TEXT"
```

## Step 3 — Summarize, Don’t Dump

Raw API output is verbose. Always reduce it before reporting:

- For metrics: report the **peak**, **current**, and **baseline** values, plus
  the labels of the top contributors.
- For logs: pull out the unique error templates (dedupe by message structure,
  not by full string), with one example timestamp each.
- For traces: report the slowest span, its service, and its error status.
- For profiles: report the top 3–5 stack frames by self-time.

When in doubt, include the exact query you ran so the user can re-execute it.

## Common Pitfalls

- **Wrong UID**: the Grafana UI shows datasource _names_; the API uses _UIDs_.
  Resolve UIDs first (or use the well-known UIDs from Step 0).
- **Wrong syntax dialect**: LogsQL is **not** LogQL / Loki.
  `{namespace="x"} |= "error"` returns nothing because the parser silently
  fails. Use `k8s.namespace.name:="x" AND error | sort by (_time) desc` instead.
- **Wrong unit for time**: `/api/ds/query` accepts Grafana relative times
  (`now-1h`) or Unix-ms. Mixing seconds and milliseconds silently returns empty
  results.
- **Empty result != healthy**: an empty LogsQL response can mean "no logs match"
  OR "wrong field selector". Always sanity-check with a broader query (drop the
  field filter, widen the time window).
- **Cardinality explosions**: avoid `by (pod)` aggregations across the whole
  cluster — scope to a namespace first.
- **Token redaction**: never echo the bearer token, never write it to a temp
  file, never include it in the report back to the user.

## Hand-Off

When invoked by `sre-analyze-alert`, return only the distilled findings (peak
values, top offenders, representative log lines, slowest trace) plus the exact
queries used. Do not draft conclusions about root cause — that synthesis belongs
to the calling skill.
