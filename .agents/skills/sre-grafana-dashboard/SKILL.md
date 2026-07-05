---
name: sre-grafana-dashboard
description: |
  Create, modify, and organise Grafana dashboards including panels, variables,
  transformations, and annotations. Dashboards are authored as local JSON files
  by default and only pushed to Grafana when explicitly requested. Use when the
  user asks to create a Grafana dashboard, add a panel, configure a time series
  or stat panel, add template variables, set up dashboard linking, use
  transformations, configure thresholds, build a dashboard for a service, add
  an annotation to a dashboard, or export dashboard JSON. Triggers on phrases
  like "create dashboard", "add panel", "time series panel", "Grafana dashboard
  JSON", "template variables", "dashboard variable", "panel transformation",
  "threshold", "stat panel", "table panel", "Grafana annotations", or
  "dashboard folder".
---

# SRE: Grafana Dashboard

Dashboards are JSON documents stored in Grafana. Every dashboard has panels,
variables, time range, and refresh settings. Understanding the JSON schema lets
you author and modify dashboards programmatically.

**Default deliverable: a local `.json` file in the current directory. Push to
Grafana via the API only when the user explicitly asks for it.**

## Workflow

1. **Understand the data first.** You cannot author a meaningful dashboard
   without knowing what data exists. Before writing any JSON, use the
   `sre-grafana` skill to discover the relevant datasources, metric/label names,
   and — critically — what the metric _values_ mean:
   - List datasources to map each signal (metrics, logs, traces) to a UID.
   - Enumerate metric names and labels (`/api/v1/label/__name__/values`,
     `/api/v1/series?match[]=...`) and run an instant query to see current
     values and cardinality.
   - For "state"/enum metrics, find the value→meaning encoding (exporter source,
     alert-rule thresholds, metric `HELP` text) instead of guessing — the number
     on the wire is rarely self-explanatory (e.g. `1=Succeeded`, `2=Failed`).
2. **Reuse before you build.** Search the target instance for existing
   dashboards (`/api/search`), library panels (`/api/library-elements`), and
   alert rules that already cover the service, and copy their shapes. Match the
   conventions they already use (datasource refs, `schemaVersion`, variable
   definitions, panel options). Hand-written JSON that ignores existing
   conventions is the top source of subtle breakage.
3. **Author locally.** Write the dashboard JSON (the bare dashboard object, not
   the API envelope) to `<uid>.json` in the current directory.
4. **Validate.** Run `jq empty <uid>.json` to catch syntax errors. If you are
   unsure whether a query is valid, validate it first using the `sre-grafana`
   skill.
5. **Push only on explicit request.** Follow the _Dashboard via API_ section
   below; prefer the `folder-temporary` folder for new dashboards and report the
   resulting dashboard URL back to the user.

To modify a dashboard that already exists in Grafana: fetch it, write
`.dashboard` to a local file, edit the file (new panels need a unique `id` and a
free `gridPos` slot), and push it back only when asked.

## Dashboard JSON Structure

```json
{
  "title": "My Dashboard",
  "uid": "my-dashboard-v1",
  "tags": ["service", "production"],
  "time": { "from": "now-1h", "to": "now" },
  "refresh": "30s",
  "timezone": "browser",
  "schemaVersion": 41,
  "templating": { "list": [] },
  "annotations": { "list": [] },
  "panels": []
}
```

**Key fields:**

- `uid` - stable identifier used in URLs and API calls; keep it short and
  meaningful
- `schemaVersion` - **detect the current value from an existing dashboard on the
  target instance** (`jq '.dashboard.schemaVersion'`) instead of hardcoding a
  number that goes stale; when modifying an existing dashboard, keep its
  existing value
- `time.from` / `to` - supports relative (`now-1h`, `now-7d`) and absolute ISO
  timestamps
- `refresh` - auto-refresh interval (`"30s"`, `"1m"`, `"5m"`, `""` for off)

## Panels

### Panel Types and When To Use Them

| Panel           | Use case                                                                |
| --------------- | ----------------------------------------------------------------------- |
| **Time series** | Any metric over time; the default choice for counters, rates, gauges    |
| **Stat**        | Single current value with optional sparkline (e.g. uptime, current RPS) |
| **Gauge**       | Percent or value against a min/max (e.g. disk usage %)                  |
| **Bar gauge**   | Compare multiple values side by side (e.g. top 10 services by RPS)      |
| **Table**       | Multi-column data (e.g. alert list with labels)                         |
| **Heatmap**     | Distribution over time (e.g. request duration histogram)                |
| **Logs**        | Log streams                                                             |
| **Traces**      | Trace search                                                            |
| **Text**        | Markdown documentation panels                                           |
| **Candlestick** | OHLC/financial data (or min/max/avg patterns)                           |
| **Node graph**  | Service dependency graphs                                               |

### Panel JSON Structure

```json
{
  "id": 1,
  "type": "timeseries",
  "title": "Request Rate",
  "gridPos": { "x": 0, "y": 0, "w": 12, "h": 8 },
  "datasource": { "type": "prometheus", "uid": "${datasource}" },
  "targets": [
    {
      "expr": "sum(rate(http_requests_total{job=~\"$job\"}[5m])) by (status_code)",
      "legendFormat": "{{status_code}}",
      "refId": "A"
    }
  ],
  "fieldConfig": {
    "defaults": {
      "unit": "reqps",
      "thresholds": {
        "mode": "absolute",
        "steps": [
          { "color": "green", "value": null },
          { "color": "yellow", "value": 1000 },
          { "color": "red", "value": 5000 }
        ]
      }
    },
    "overrides": []
  },
  "options": {
    "legend": {
      "calcs": ["mean", "max", "last"],
      "displayMode": "table",
      "placement": "bottom"
    },
    "tooltip": { "mode": "multi", "sort": "desc" }
  }
}
```

### Layout: gridPos, Rows, Repeats

- **`gridPos`:** The dashboard uses a 24-column grid. Common widths:
  full-width=24, half=12, third=8, quarter=6. Height in grid units (1 unit ≈
  30px). Panels flow top-to-bottom by ascending `y`.
- **`id`:** every panel needs a unique integer `id` within the dashboard — when
  adding a panel, use `max(existing ids) + 1`.
- **Rows:** group panels with a row panel:
  `{ "type": "row", "title": "...", "collapsed": false, "gridPos": { "x": 0, "y": 0, "w": 24, "h": 1 }, "panels": [] }`.
  Expanded rows keep their panels as siblings after the row; collapsed rows
  (`"collapsed": true`) nest them inside the row's `panels` array.
- **Repeats:** set `"repeat": "<variable>"` (plus
  `"repeatDirection": "h" | "v"`) on a panel to clone it per value of a
  multi-value variable.

**Inserting or removing panels — re-flow the layout.** Within an expanded row,
panels are placed by absolute `y`, so adding or deleting a panel means shifting
every panel below it. Treat each section's `y` as a running sum of the heights
above it (row header `h:1` + the panel heights in each band) and recompute
downward after any change — a stale `y` leaves panels overlapping or with gaps.
After editing, **verify the layout** (before the `jq empty` syntax check):

```bash
jq -r '.panels[] | "[\(.id)] y=\(.gridPos.y) x=\(.gridPos.x) w=\(.gridPos.w) h=\(.gridPos.h)  \(.type)  \(.title)"' <uid>.json
```

Scan the dump for ascending `y`, `x + w <= 24` within each row band, and no
unintended gaps or overlaps.

### Useful Unit Identifiers

```
# Rates
"reqps"      -- requests per second
"ops"        -- operations per second
"Bps"        -- bytes per second
"percentunit" -- 0.0-1.0 as percentage

# Storage
"bytes"      -- bytes (auto-scales to KB/MB/GB)
"decbytes"   -- decimal bytes (1 KB = 1000 B)

# Time
"ms"         -- milliseconds
"s"          -- seconds
"dtdurationms" -- duration in ms (shows as "1h 2m 3s")

# Counts
"short"      -- compact number (1.2k, 3.4M)
"none"       -- raw number
```

Full list: **Panel > Field > Unit** dropdown in Grafana UI, or the
[units reference](https://grafana.com/docs/grafana/latest/panels-visualizations/configure-standard-options/#unit).

### Value Mappings

Thresholds color _ranges_; value mappings map _exact values_ (or ranges) to
display text and an optional color — essential for enum/"state" metrics where a
number stands for a status. Mappings live in `fieldConfig.defaults.mappings`:

```json
"mappings": [
  {
    "type": "value",
    "options": {
      "0": { "text": "Unknown",   "color": "red",   "index": 0 },
      "1": { "text": "Succeeded", "color": "green", "index": 1 },
      "2": { "text": "Failed",    "color": "red",   "index": 2 }
    }
  }
]
```

- A mapping's `color` **overrides** the threshold color for matched values, so a
  stat/table cell can be colored purely from the mapping.
- For a **stat** panel to paint the mapped color, set `options.colorMode` to
  `"value"` or `"background"`.
- For a **table** cell, add a field override setting `custom.cellOptions.type`
  to `"color-background"` (or `"color-text"`).
- Map numeric ranges with
  `{ "type": "range", "options": { "from": 0, "to": 10, "result": { "text": "low", "color": "green" } } }`.
- On a **timeseries** panel a value mapping only relabels the tooltip/legend
  value — it does not change the plotted line; set `min`/`max`/`decimals` to
  keep the axis readable.

### Panel Examples: Stat, Table, Logs

The timeseries example above is only one panel type. Target shapes are
**datasource-specific** — when in doubt, copy a working panel of the same type +
datasource from an existing dashboard (see _Reuse before you build_).

**Stat** (single current value; mapping-driven color):

```json
{
  "id": 2,
  "type": "stat",
  "title": "Cluster State",
  "gridPos": { "x": 0, "y": 0, "w": 6, "h": 4 },
  "datasource": { "type": "prometheus", "uid": "victoriametrics" },
  "targets": [
    {
      "expr": "aks_cluster_provisioning_state",
      "instant": true,
      "range": false,
      "refId": "A"
    }
  ],
  "fieldConfig": {
    "defaults": {
      "mappings": ["...see Value Mappings..."],
      "thresholds": {
        "mode": "absolute",
        "steps": [{ "color": "red", "value": null }]
      }
    },
    "overrides": []
  },
  "options": {
    "colorMode": "background",
    "graphMode": "none",
    "textMode": "value",
    "reduceOptions": { "calcs": ["lastNotNull"], "fields": "", "values": false }
  }
}
```

**Table** (instant query + reshape; color the value column):

```json
{
  "id": 3,
  "type": "table",
  "title": "Node Pool States",
  "gridPos": { "x": 0, "y": 4, "w": 10, "h": 10 },
  "datasource": { "type": "prometheus", "uid": "victoriametrics" },
  "targets": [
    {
      "expr": "aks_nodepool_provisioning_state",
      "instant": true,
      "range": false,
      "format": "table",
      "refId": "A"
    }
  ],
  "transformations": [
    {
      "id": "organize",
      "options": {
        "excludeByName": { "Time": true, "job": true, "instance": true },
        "renameByName": { "name": "Node Pool", "Value": "State" }
      }
    },
    { "id": "sortBy", "options": { "sort": [{ "field": "Node Pool" }] } }
  ],
  "fieldConfig": {
    "defaults": { "mappings": ["...see Value Mappings..."] },
    "overrides": [
      {
        "matcher": { "id": "byName", "options": "State" },
        "properties": [
          {
            "id": "custom.cellOptions",
            "value": { "type": "color-background" }
          }
        ]
      }
    ]
  },
  "options": { "showHeader": true, "cellHeight": "sm" }
}
```

Prometheus `format: "table"` returns one column per label plus `Value`; use an
`organize` transformation to hide noise columns and rename `Value`.

**Logs** (VictoriaLogs — note the datasource `type` and LogsQL `expr`):

```json
{
  "id": 4,
  "type": "logs",
  "title": "Logs",
  "gridPos": { "x": 0, "y": 14, "w": 24, "h": 10 },
  "datasource": {
    "type": "victoriametrics-logs-datasource",
    "uid": "victorialogs"
  },
  "targets": [
    {
      "datasource": {
        "type": "victoriametrics-logs-datasource",
        "uid": "victorialogs"
      },
      "editorMode": "code",
      "expr": "service.namespace:=\"$namespace\" AND service.name:=\"my-service\"",
      "queryType": "instant",
      "refId": "A"
    }
  ],
  "options": {
    "showTime": true,
    "sortOrder": "Descending",
    "enableLogDetails": true,
    "wrapLogMessage": false,
    "dedupStrategy": "none"
  }
}
```

LogsQL is **not** LogQL/Loki — consult the `sre-grafana` skill's per-datasource
references for the correct query syntax of each signal (metrics, logs, traces).

**Kubernetes resources table** (list the custom resources an operator manages,
via the `ricoberger-kubernetes-datasource` — a common operator-dashboard panel):

```json
{
  "id": 5,
  "type": "table",
  "title": "HTTPRoutes",
  "gridPos": { "x": 0, "y": 24, "w": 24, "h": 10 },
  "datasource": {
    "type": "ricoberger-kubernetes-datasource",
    "uid": "kubernetes"
  },
  "targets": [
    {
      "datasource": {
        "type": "ricoberger-kubernetes-datasource",
        "uid": "kubernetes"
      },
      "queryType": "kubernetes-resources",
      "resourceId": "httproute.gateway.networking.k8s.io",
      "namespace": "*",
      "wide": false,
      "refId": "A"
    }
  ],
  "options": { "showHeader": true, "cellHeight": "sm" }
}
```

`resourceId` must be the exact string the datasource expects — built-ins are
bare (`pod`, `deployment`), custom resources are `<singular-kind>.<group>` (e.g.
`httproute.gateway.networking.k8s.io`, **not** the plural CRD name
`httproutes...`). Don't guess the pluralization; list the authoritative ids with
the `kubernetes-resourceids` query (the `ids` column is what goes in
`resourceId`):

```bash
jq -n '{queries:[{refId:"A",queryType:"kubernetes-resourceids",resourceId:"",namespace:"",
        datasource:{type:"ricoberger-kubernetes-datasource",uid:"kubernetes"}}]}' \
| curl -sS -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
       -X POST "$GRAFANA/api/ds/query" --data-binary @- \
| jq -r '.results.A.frames[0].data.values as $v
         | [range(0; ($v[0] | length))][] as $i | "\($v[0][$i])\t\($v[1][$i])"'
```

The frame columns are `ids`, `kinds`, `apiVersions`, `names`, `paths`,
`namespaced`; grep the `ids` output for the kind you want.

## Template Variables

Variables make dashboards reusable across environments and services.

**Query variable (populates from metric labels):**

```json
{
  "name": "pod",
  "type": "query",
  "label": "Pod",
  "datasource": { "type": "prometheus", "uid": "victoriametrics" },
  "definition": "label_values(kube_pod_info{namespace=\"$namespace\"}, pod)",
  "query": {
    "qryType": 1,
    "query": "label_values(kube_pod_info{namespace=\"$namespace\"}, pod)",
    "refId": "PrometheusVariableQueryEditor-VariableQuery"
  },
  "refresh": 2,
  "regex": "",
  "includeAll": true,
  "multi": true,
  "current": { "text": "All", "value": ["$__all"] },
  "options": []
}
```

The minimal `"query": { "query": "label_values(up, job)", "refId": "A" }` form
often works, but the Grafana editor writes the richer shape above (`qryType`,
the `definition` mirror, and the `PrometheusVariableQueryEditor-VariableQuery`
`refId`). Variable JSON drifts across schema/plugin versions just like
annotations — if a variable fails to populate or refresh, **copy the exact shape
from a working dashboard** on the same instance rather than guessing.

**Constant variable:**

```json
{
  "name": "cluster",
  "type": "constant",
  "query": "production",
  "label": "Cluster"
}
```

**Datasource variable (switch data sources without editing queries):**

```json
{
  "name": "datasource",
  "type": "datasource",
  "query": "prometheus",
  "refresh": 1,
  "regex": "",
  "includeAll": false,
  "label": "Data Source"
}
```

The `query` field holds the datasource plugin id (e.g. `prometheus`); use
`regex` to narrow the candidates when several datasources match.

**Use variables in queries:**

```promql
# Reference a variable in a PromQL query
rate(http_requests_total{job=~"$job"}[5m])

# Multi-value variable uses regex OR automatically
# When $job = ["api", "worker"], it becomes job=~"api|worker"
```

**Chain variables** (second variable filters based on first):

```json
{
  "name": "pod",
  "query": "label_values(kube_pod_info{namespace=\"$namespace\"}, pod)"
}
```

## Library Panels

Library panels are reusable panels stored once in Grafana and referenced by many
dashboards. **Reuse them instead of re-authoring** common panels (CPU, memory,
request rate, …).

List the available library panels (kind `1` = panel):

```bash
curl -sS -G -H "Authorization: Bearer $TOKEN" "$GRAFANA/api/library-elements" \
  --data-urlencode "kind=1" --data-urlencode "perPage=200" \
  | jq -r '.result.elements[] | "\(.uid)\t\(.type)\t\(.name)"'
```

Reference one from a dashboard with a thin `library-panel-ref` panel — you still
own its `id` and `gridPos`; Grafana fills in the rest by `uid` at load time:

```json
{
  "id": 13,
  "type": "library-panel-ref",
  "title": "CPU",
  "gridPos": { "x": 0, "y": 27, "w": 12, "h": 8 },
  "libraryPanel": { "uid": "panel-cpu", "name": "CPU" }
}
```

Key rules:

- **It only renders after a push.** A `library-panel-ref` is resolved
  server-side, so the panel stays blank when previewing the local `.json` — tell
  the user the panel appears only once the dashboard is in Grafana.
- **Supply the variables it needs.** A library panel's queries reference
  template variables (e.g. `$namespace`, `$pod`). Fetch the element
  (`GET /api/library-elements/<uid>`), read its `model.targets[].expr` to see
  which variables it expects, and add matching variables to the host dashboard,
  or the panel renders empty.
- **Copy the exact ref shape from a dashboard that already uses it** — find
  consumers via `GET /api/library-elements/<uid>/connections`.

## Transformations

Transformations run client-side after data is fetched, reshaping results without
changing queries.

**Common transformations:**

```json
"transformations": [
  {
    "id": "merge",
    "options": {}
  },
  {
    "id": "organize",
    "options": {
      "renameByName": { "Value #A": "Request Rate", "Value #B": "Error Rate" },
      "excludeByName": { "Time": true }
    }
  },
  {
    "id": "calculateField",
    "options": {
      "alias": "Error %",
      "mode": "reduceRow",
      "reduce": { "reducer": "last" },
      "binary": {
        "left": "errors",
        "right": "total",
        "operator": "/"
      }
    }
  },
  {
    "id": "filterByValue",
    "options": {
      "filters": [{ "fieldName": "Error %", "config": { "id": "greater", "options": { "value": 0.01 } } }],
      "type": "include",
      "match": "any"
    }
  }
]
```

**Key transformation IDs:** `merge`, `organize`, `rename`, `calculateField`,
`filterByValue`, `groupBy`, `sortBy`, `limit`, `labelsToFields`, `seriesToRows`,
`partitionByValues`.

## Dashboard Linking

**Panel link (click a panel to go somewhere):**

```json
"links": [
  {
    "title": "Go to details",
    "url": "/d/details-dashboard?var-service=${__field.labels.service}",
    "targetBlank": false
  }
]
```

**Dashboard link (top-right corner links):**

```json
"links": [
  {
    "title": "Runbook",
    "url": "https://wiki.example.com/runbook/${job}",
    "icon": "external link",
    "targetBlank": true,
    "type": "link"
  }
]
```

Optional dashboard-link fields the Grafana editor writes: `asDropdown`,
`includeVars` (append the dashboard's current template variables to the URL),
`keepTime` (carry the current time range), and `tags` (with
`type: "dashboards"`, link to all dashboards carrying a tag instead of a fixed
`url`).

**Built-in variables for links:**

- `${__value.raw}` - current data point value
- `${__field.labels.job}` - label value from current series
- `${__url.params}` - current URL query parameters (pass-through)
- `${__from}` / `${__to}` - current time range as Unix ms

## Annotations

Show events overlaid on time series panels (deployments, incidents, alerts).
Entries live in `annotations.list`; keep the built-in entry first:

```json
{
  "builtIn": 1,
  "datasource": { "type": "grafana", "uid": "-- Grafana --" },
  "enable": true,
  "hide": true,
  "iconColor": "rgba(0, 211, 255, 1)",
  "name": "Annotations & Alerts",
  "type": "dashboard"
}
```

**Query annotation (Prometheus):** the query nests under `target`:

```json
{
  "datasource": { "type": "prometheus", "uid": "${datasource}" },
  "enable": true,
  "iconColor": "red",
  "name": "Alerts",
  "target": {
    "expr": "ALERTS{alertstate=\"firing\", namespace=\"$namespace\"}",
    "interval": "30s",
    "refId": "Anno"
  },
  "titleFormat": "{{alertname}}",
  "textFormat": "{{alertstate}}"
}
```

**Tag-based annotation (displays annotations created via the API):**

```json
{
  "datasource": { "type": "datasource", "uid": "grafana" },
  "enable": true,
  "iconColor": "red",
  "name": "Incidents",
  "target": {
    "type": "tags",
    "tags": ["incident"],
    "limit": 100,
    "matchAny": false
  }
}
```

### Static Annotations at a Fixed Time (API Only)

Dashboard JSON cannot embed an annotation at a hardcoded timestamp. Create it
through the annotations API instead — this requires the dashboard to already
exist in Grafana. See _Create an Annotation_ in the _Dashboard via API_ section
below for the request; display org-wide annotations via a tag-based annotation
(see above), dashboard-scoped ones are shown by the built-in "Annotations &
Alerts" layer automatically.

## Dashboard via API — Only on Explicit Request

Resolve the Grafana base URL and token by loading the `sre-grafana` skill and
following its "How To Reach Grafana" and "Command Mechanics" sections (instance
name via `$GRAFANA_INSTANCES`, or direct credentials), including its
token-handling rules: never log, echo, or write the bearer token to disk, and
prefix every command with the resolution block because shell state does not
persist between tool invocations.

### Fetch a Dashboard

```bash
# Full JSON to a local file for editing
curl -sS -H "Authorization: Bearer $TOKEN" \
  "$GRAFANA/api/dashboards/uid/<dashboard-uid>" | jq '.dashboard' > <uid>.json

# Summary for inspection — don't dump the full JSON into context
curl -sS -H "Authorization: Bearer $TOKEN" \
  "$GRAFANA/api/dashboards/uid/<dashboard-uid>" \
  | jq '{uid: .dashboard.uid, title: .dashboard.title, version: .dashboard.version,
         panels: [.dashboard.panels[] | {id, title, type, gridPos}]}'
```

### Create or Update a Dashboard

Wrap the local file in the API envelope. New dashboards go to the
`folder-temporary` folder unless the user names another one (list folders via
`GET /api/folders`):

```bash
jq empty <uid>.json   # validate before pushing

jq -n --slurpfile d <uid>.json '{
  dashboard: $d[0],
  folderUid: "folder-temporary",
  overwrite: true,
  message: "Updated via API"
}' | curl -sS -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -X POST "$GRAFANA/api/dashboards/db" -d @-
```

The response contains `status`, `uid`, `version`, and `url` — confirm
`"status": "success"` and report the full dashboard URL (`$GRAFANA` + `url`)
back to the user.

### Create an Annotation

Attach an annotation to a dashboard (or a single panel) at a fixed time:

```bash
curl -sS -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -X POST "$GRAFANA/api/annotations" \
  -d '{
    "dashboardUID": "cIBgcSjkk",
    "panelId": 2,
    "time": 1507037197339,
    "timeEnd": 1507180805056,
    "tags": ["deploy", "production"],
    "text": "Deployment v2.1.0 completed"
  }'
```

- `time` / `timeEnd` are epoch milliseconds; omit `timeEnd` for a point
  (vertical line) instead of a region.
- Omit `panelId` to annotate all panels of the dashboard; omit `dashboardUID` as
  well for an org-wide annotation, displayed via a tag-based annotation (see the
  _Annotations_ section).

## Common Pitfalls

- **Numeric `id` vs `uid`**: strip the numeric `id` (set it to `null`) when
  creating a dashboard or copying one between instances — POSTing an `id` that
  does not exist in the target fails. The `uid` is the stable identifier.
- **Panel `id` collisions**: duplicate panel ids break editing and linking;
  always assign a fresh unique id when adding panels.
- **`uid` collisions with existing dashboards**: before claiming a `uid` for a
  **new** dashboard, confirm it is free — `GET /api/dashboards/uid/<uid>` should
  return 404. Reusing an existing uid with `overwrite: true` silently clobbers
  that dashboard. Pick a distinct uid (e.g. `<service>-monitoring`) when similar
  dashboards already exist.
- **Multi-value variables need `=~`**: an exact match like `job="$job"` breaks
  as soon as the variable is `multi` or `includeAll`; use `job=~"$job"`.
- **Datasource refs — match local convention, don't dogmatically use
  `${datasource}`**: a datasource variable only helps when the dashboard must be
  portable across instances with _different_ UIDs. When the target instance has
  a single, stable, well-known metrics UID and existing dashboards hardcode it,
  hardcode the same UID to match convention. Check how neighboring dashboards
  reference their datasource before deciding.
- **`overwrite: true` clobbers concurrent edits**: always fetch the latest
  version of an existing dashboard immediately before modifying it.
- **401 Unauthorized**: the `Authorization` header value must include the
  `Bearer ` prefix; token commands may print the raw token only, so use
  `Authorization: Bearer $TOKEN` (drop the explicit prefix if the token already
  contains it).
- **Missing permissions**: if a push fails with a permissions error, keep the
  local `.json` file as the deliverable and tell the user.
- **Invalid queries**: if you are not sure a query is valid, validate it first
  using the `sre-grafana` skill.
- **Empty/zero is not always broken**: a correct query over a low-activity
  target (e.g. an idle operator's reconcile rate, or `histogram_quantile` over
  zero-rate buckets) legitimately returns `0` or no data. Cross-check with an
  instant query over a wider window before "fixing" a query that is actually
  right, and tell the user the panel will populate once activity resumes.
- **Shape drift across schema versions**: annotation and variable JSON shapes
  vary by `schemaVersion`; when unsure, fetch a similar existing dashboard and
  copy its shape instead of guessing.

## References

- [Grafana dashboard documentation](https://grafana.com/docs/grafana/latest/dashboards/)
- [Grafana panel types reference](https://grafana.com/docs/grafana/latest/panels-visualizations/)
- [Grafana HTTP API — dashboards](https://grafana.com/docs/grafana/latest/developers/http_api/dashboard/)
- [Grafana HTTP API — annotations](https://grafana.com/docs/grafana/latest/developers/http_api/annotations/)
- [Dashboard variables](https://grafana.com/docs/grafana/latest/dashboards/variables/)
- [Transformations reference](https://grafana.com/docs/grafana/latest/panels-visualizations/query-transform-data/transform-data/)
