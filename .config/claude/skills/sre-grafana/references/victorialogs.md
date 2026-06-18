# VictoriaLogs

Use this reference for datasource `type` `victoriametrics-logs-datasource`.
Queries go through `POST /api/ds/query`.

**LogsQL is not LogQL and not Loki.** Do not emit Loki-style stream selectors
(`{namespace="foo"} |= "error"`) or pipe filters (`|=`, `!=`, `|~`) — the parser
silently fails and returns nothing. Full reference:
[https://docs.victoriametrics.com/victorialogs/logsql/](https://docs.victoriametrics.com/victorialogs/logsql/).

## Request

Build the JSON body with `jq -n` and pipe it into `curl --data-binary @-`.
**Never** interpolate `$LOGSQL` directly into a `-d '{...}'` string — exact
field matches like `k8s.namespace.name:="grafana"` contain a `"` that closes the
surrounding JSON string and silently corrupts the body; the API then returns an
empty result that looks identical to a legitimate "no logs" answer:

```bash
jq -n \
  --arg uid   "$DATASOURCEUID" \
  --arg expr  "$LOGSQL" \
  --arg from  "$FROM" \
  --arg to    "$TO" \
  --argjson maxLines "${MAXLINES:-1000}" \
  '{queries:[{refId:"A",
              datasource:{uid:$uid, type:"victoriametrics-logs-datasource"},
              expr:$expr,
              queryType:"instant",
              maxLines:$maxLines}],
    from:$from, to:$to}' \
| curl -sS -H "Authorization: $TOKEN" -H "Content-Type: application/json" \
       -X POST "$GRAFANA/api/ds/query" --data-binary @-
```

### Rendering the Response

Always end the LogsQL with an explicit projection (`| fields _time, _msg`, plus
any extra fields) — without it the column order in the response frame is
unpredictable and the rendered output interleaves the wrong fields.

Copy this tested program verbatim (expects `refId` `A`; first projected field
must be `_time`); it prints one line per entry, collapses whitespace, and
truncates long messages so a single noisy log line cannot flood the output:

```bash
curl -sS ... | jq -r '
  .results.A.frames[0] as $f
  | if $f == null then "no logs" else
      ($f.data.values | transpose[]
       | "\(.[0] / 1000 | floor | strftime("%m-%d %H:%M:%S"))  \(.[1:]
            | map(tostring | gsub("\\s+"; " ") | .[0:300]) | join("  "))")
    end'
```

For `| stats ...` queries the plugin still returns the standard log-frame shape
(`Time, Line, id, labels`) — **not** a flat table. The stats fields are packed
as a JSON object inside the `Line` column, e.g. `Line = "{\"n\":\"7523190\"}"`.
Always parse the `Line` JSON with `fromjson` before reading the stats fields; a
bare `transpose | @tsv` produces garbage.

Copy this tested program verbatim (works for any number of stat fields and for
time-bucketed `_time:Xh` stats):

```bash
curl -sS ... | jq -r '
  .results.A.frames[0] as $f
  | if $f == null then "no stats" else
      $f.data.values | transpose[]
      | (.[1] | fromjson) as $s
      | "\(.[0] / 1000 | floor | strftime("%m-%d %H:%M:%S"))\t\($s | to_entries | map("\(.key)=\(.value)") | join("  "))"
    end'
```

For non-time-bucketed stats (e.g. `| stats by (severity_text) count(*) as n`),
the dimension values land in the `labels` column instead of `Time`; replace the
`strftime` with `.[3] | to_entries | map("\(.key)=\(.value)") | join(",")`.

## LogsQL Query Patterns

LogsQL is a simple yet powerful query language for VictoriaLogs. LogsQL provides
the following features: Full-text search in any log field (defaults to `_msg` ).
Ability to combine filters into arbitrary complex logical filters. Ability to
calculate various stats over the selected log entries.

### Filter Syntax

Combine with `AND` / `OR` / `NOT`:

- `word`: matches that word anywhere in the log line (default field `_msg`).
- `"exact phrase"`: phrase match anywhere in the log line (default field
  `_msg`).
- `field:word`: word match on a specific field.
- `field:="exact value"`: exact field match (most common for labels).
- `field:"phrase"`: phrase match on a field.
- `field:~"regex"`: regex on a field.
- `severity_text:in("error","fatal","critical")`: set membership.
- `field:range(4.2, Inf)`: numeric range match on a field.
- `field:*`: field exists.
- `field:""`: field does not exist.
- `*:"word"`: word match across all fields. (prefer this when it is not clear
  which field contains the value, e.g. for error messages that may be in `_msg`
  or `error.message` or `log.error`).

### Combining Filters

Filters can be combined with logical operators `AND`, `OR`, and `NOT` to create
complex queries. The `NOT` operation has the highest priority, `AND` has the
middle priority and `OR` has the lowest priority. The priority order can be
changed with parentheses, e.g. `NOT (field:word1 OR field:word2)`.

### Pipes

Applied after filters, left to right:

- `| sort by (_time) desc` — newest first. Almost always include this.
- `| limit 100` — cap result count.
- `| stats by (severity_text) count(*) as n` — aggregate.
- `| fields _time, _msg, k8s.pod.name` — project specific fields.

### Useful Labels

- `service.namespace`: The namespace of the service. Almost always this is the
  Kubernetes namespace.
- `service.name`: The name of the service. This is often the `app`, `k8s-app` or
  `app.kubernetes.io/name` label.
- `severity_text:` The severity level of the log entry, e.g. "error", "warning",
  "info".
- `k8s.container.name`: The name of the container that emitted the log entry.
- `k8s.namespace.name`: The Kubernetes namespace of the pod that emitted the log
  entry.
- `k8s.node.name`: The name of the Kubernetes node on which the pod is running.
- `k8s.pod.name`: The name of the Kubernetes pod that emitted the log entry.
- `k8s.pod.uid`: The unique identifier of the Kubernetes pod that emitted the
  log entry.

### Severity Levels

The `severity_text` label can have one of the following values for the different
severity levels:

- `critical`: "critical", "Critical", "CRITICAL", "fatal", "Fatal", "FATAL", "F"
- `error`: "error", "Error", "ERROR", "err", "Err", "ERR", "E"
- `warning`: "warning", "Warning", "WARNING", "warn", "Warn", "WARN", "W"
- `info`: "info", "Info", "INFO", "information", "Information", "INFORMATION",
  "informational", "Informational", "INFORMATIONAL", "notice", "Notice",
  "NOTICE", "I"
- `debug`: "debug", "Debug", "DEBUG"
- `trace`: "trace", "Trace", "TRACE", "verbose", "Verbose", "VERBOSE"

### Working Examples

Errors for one service in one namespace, newest first:

```
service.namespace:="prod" AND service.name:="checkout"
  AND severity_text:in("error","fatal")
| sort by (_time) desc
| limit 200
```

Errors from one specific pod:

```
k8s.namespace.name:="prod" AND k8s.pod.name:="checkout-7d8f-abcde"
  AND (error OR panic OR fatal)
| sort by (_time) desc
| limit 200
```

Error count per minute over the window:

```
service.name:="checkout" AND severity_text:="error"
| stats by (_time:1m) count(*) as errors
```

### Wrong Syntax (Loki Syntax — NEVER EMIT)

- `{service_name="checkout"} |= "error"` ❌ Loki stream + pipe filter
- `{namespace="prod", pod=~"checkout-.*"} != "ok"` ❌ Loki regex selector
- `rate({app="checkout"}[5m])` ❌ Loki metric query

### References

- [VictoriaLogs LogsQL](https://docs.victoriametrics.com/victorialogs/logsql/)
- [LogsQL examples](https://docs.victoriametrics.com/victorialogs/logsql-examples/)
- [How to convert Loki queries to VictoriaLogs queries](https://docs.victoriametrics.com/victorialogs/logql-to-logsql/)
