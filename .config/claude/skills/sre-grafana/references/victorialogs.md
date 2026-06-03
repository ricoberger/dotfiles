# VictoriaLogs

Use this reference for datasource `type` `victoriametrics-logs-datasource`.
Queries go through `POST /api/ds/query`.

**LogsQL is not LogQL and not Loki.** Do not emit Loki-style stream selectors
(`{namespace="foo"} |= "error"`) or pipe filters (`|=`, `!=`, `|~`) — the parser
silently fails and returns nothing. Full reference:
[https://docs.victoriametrics.com/victorialogs/logsql/](https://docs.victoriametrics.com/victorialogs/logsql/).

## Request

```bash
curl -sS -H "Authorization: $TOKEN" -H "Content-Type: application/json" \
  -X POST "$GRAFANA/api/ds/query" \
  -d '{
    "queries": [{
      "refId": "A",
      "datasource": { "uid": "'"$DATASOURCEUID"'", "type": "victoriametrics-logs-datasource" },
      "expr": "'"$LOGSQL"'",
      "queryType": "instant",
      "maxLines": '"${MAXLINES:-1000}"'
    }],
    "from": "'"$FROM"'",
    "to": "'"$TO"'"
  }'
```

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
- `*:"word"`: word match across all fields.

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
