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

Convert RFC3339 to Unix-ms with this one-liner (BSD/macOS first, GNU fallback)
instead of re-deriving the `date` flags each time:

```bash
TS=$(date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "2026-06-03T12:00:00Z" +%s 2>/dev/null \
  || date -u -d "2026-06-03T12:00:00Z" +%s)000
```

## Step 2 — Run the Query

Every query goes through one of two HTTP patterns:

- `POST /api/ds/query` — Prometheus / VictoriaMetrics, VictoriaLogs, Tempo /
  VictoriaTraces, Pyroscope and Cloudflare. The body is a Grafana panel-query
  payload; multiple `queries[]` entries in a single POST fan out cheaply. Always
  set `Content-Type: application/json`.
- `GET /api/datasources/proxy/uid/<uid>/...` — Kubernetes proxy.

Pass the `from` / `to` window resolved in Step 1 explicitly on every request; do
not rely on Grafana defaults.

### Command Mechanics

Two rules that prevent the most common self-inflicted round-trips:

1. **Shell state does not persist between tool invocations.** Exported variables
   are gone by the next command. When resolving credentials from
   `$GRAFANA_INSTANCES`, prefix **every** command with the resolution block
   (never echo the token):

   ```bash
   GRAFANA=$(printenv GRAFANA_INSTANCES | jq -r '."<instance>".url')
   TOKEN=$(eval "$(printenv GRAFANA_INSTANCES | jq -r '."<instance>".auth.tokenCommand')")
   ```

2. **Copy templates verbatim; do not re-derive them.** The request bodies and
   the response-rendering `jq` programs in the per-datasource references are
   tested — hand-rewriting them (escaped-quote JSON bodies, ad-hoc
   frame-alignment jq) is the top source of wasted iterations. Copy the matching
   reference's snippet and change only the marked parts.

3. **Construct request bodies with `jq -n`, never with shell `-d '...'`
   interpolation.** Every datasource reference's request template uses
   `jq -n --arg expr "$QUERY" '…' | curl --data-binary @-` for a reason: the
   moment a query contains a `"` — and almost every real query does
   (`{job="api"}`, `k8s.namespace.name:="grafana"`,
   `{resource.service.name = "frontend"}`, `{ requestSource: "eyeball" }`) —
   shell interpolation closes the JSON string early, the body becomes malformed,
   and the API returns an **empty result indistinguishable from "no matches"**.
   If you find yourself debugging an empty response, first verify the body you
   actually sent is valid JSON.

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
instead of inventing your own. Trigger a dashboard search in any of these
situations:

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

Once you have the dashboard JSON, **enumerate every panel grouped by its row** —
do not stop at the first text/timeseries panel. Runbook dashboards typically
hide the operationally useful checks (resource list, recent events, container
logs, related metrics) behind collapsed rows further down. A row's nested panels
live in `panels[].panels` when the row is collapsed and as the next sibling
panels in document order when it is expanded; handle both:

```bash
curl -sS -H "Authorization: $TOKEN" "$GRAFANA/api/dashboards/uid/$UID" \
  | jq -r '
      [.dashboard.panels[]] as $top
      | $top
      | reduce .[] as $p ({row: "(no row)", out: []};
          if $p.type == "row"
            then .row = $p.title
                 | .out += [($p.panels // [])[] | {row: $p.title, title, type}]
            else .out += [{row: .row, title: $p.title, type: $p.type}]
          end)
      | .out[] | "\(.row)\t\(.type)\t\(.title)"'
```

Then run each panel's `targets[]` queries (passing the `var-*` values from the
runbook URL as `scopedVars`) so you cover the runbook's full checklist, not just
its intro.

**2. When asked to analyze the health of a service.** Search for dashboards that
already describe that service, in this order:

1. Tag match — `query=&tag=<service>` (most precise; teams tag service
   dashboards by service name).
2. Folder match — list folders via `/api/folders`, and if one matches the
   service name, list its dashboards with `query=&folderUIDs=<uid>`.
3. Free-text search — `query=<service>` as a fallback.

**3. When asked a broad / exploratory question about a system, traffic pattern,
or datasource.** Questions like "what does Cloudflare traffic look like on
prod-de1", "show me the top X by Y", "how is namespace Z doing", or "is anything
unusual on cluster N" almost always have a curated dashboard behind them. Before
crafting ad-hoc queries, search by the most prominent noun in the question
(datasource name, namespace, cluster, subsystem) using the same tag → folder →
free-text order as #2.

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

### Rolling Hourly Buckets Into Daily Totals

Multi-day rate analyses almost always want a per-day summary. Copy this jq
verbatim — it works on any single-frame `[timestamps, values]` response
(Prometheus, single-series Cloudflare, VictoriaLogs `| stats by (_time:1h)`
after `fromjson`-extracting the count into a numeric array):

```bash
jq -r '
  .results.A.frames[0].data.values as $v
  | [range(0; ($v[0] | length))]
  | map({t: $v[0][.], n: ($v[1][.] | tonumber)})
  | group_by(((.t/1000) | strftime("%Y-%m-%d")))
  | map({
      day:   (((.[0].t/1000) | strftime("%Y-%m-%d (%a)"))),
      total: (map(.n) | add),
      hours: length,
      peak:  (map(.n) | max),
      min:   (map(.n) | min)
    })
  | .[] | "\(.day)  total=\(.total)  hours=\(.hours)  peak/h=\(.peak)  min/h=\(.min)"'
```

For VictoriaLogs `| stats` results the count lives inside the `Line` JSON, so
swap the `map(...)` line for
`map({t: $v[0][.], n: ($v[1][.] | fromjson.n | tonumber)})`.

### Correlating Two Signals

When the question is "does signal A look like signal B?" (e.g. Cloudflare edge
vs Istio origin request rate, error rate vs latency, two clusters side-by-side):

1. Query **both signals into identical time buckets** — pick the same step
   (`_time:1h`, `datetimeHour`, Prometheus `step=1h`) on both sides so rows line
   up without resampling.
2. Aggregate each side to the same granularity you intend to compare at (usually
   per-day totals — reuse the day-rollup snippet above).
3. Render as a **side-by-side table** with one column per signal and a **ratio**
   column (`B/A`). The ratio is the actual insight.
4. Call out whether the ratio is **stable** across the window (expected
   relationship — e.g. ~88 % cache pass-through) or **varies** (something
   diverged on a specific day/hour — that is the lead).
5. Confirm the same shape: peak hours, weekday/weekend rhythm, and trough timing
   should match on both sides. A shape mismatch with a stable ratio is
   suspicious.

Do not just paste both tables and let the user diff them — the ratio and the
stability assessment are the work.

## Common Pitfalls

- **Wrong UID**: the Grafana UI shows datasource _names_; the API uses _UIDs_.
  Resolve UIDs first (or use the well-known UIDs from Step 0).
- **Malformed body from shell interpolation**:
  `-d '{... "expr": "'"$QUERY"'" ...}'` silently corrupts as soon as `$QUERY`
  contains a `"`. Always build the body with `jq -n --arg …` and pipe into
  `curl --data-binary @-` (see Step 2, Command Mechanics rule 3).
- **Wrong syntax dialect**: LogsQL is **not** LogQL / Loki.
  `{namespace="x"} |= "error"` returns nothing because the parser silently
  fails. Use `k8s.namespace.name:="x" AND error | sort by (_time) desc` instead.
- **Wrong unit for time**: `/api/ds/query` accepts Grafana relative times
  (`now-1h`) or Unix-ms. Mixing seconds and milliseconds silently returns empty
  results.
- **Empty result != healthy**: an empty LogsQL response can mean "no logs match"
  OR "wrong field selector". Always sanity-check with a broader query (drop the
  field filter, widen the time window).
- **Sparse series vanish in range queries**: a range query with coarse steps
  (e.g. daily `increase(metric[1d])`) can return zero or no series for a
  low-volume counter (a handful of events per day) even though the events are
  real — the evaluation timestamps miss the samples. Before trusting a zero,
  cross-check with an instant query over the whole window
  (`increase(metric[24h])` with `"instant": true`); if the instant query
  disagrees, narrow with instant queries instead of range steps.
- **Cardinality explosions**: avoid `by (pod)` aggregations across the whole
  cluster — scope to a namespace first.
- **Token redaction**: never echo the bearer token, never write it to a temp
  file, never include it in the report back to the user.

## Hand-Off

When invoked by `sre-analyze-alert`, return only the distilled findings (peak
values, top offenders, representative log lines, slowest trace) plus the exact
queries used. Do not draft conclusions about root cause — that synthesis belongs
to the calling skill.
