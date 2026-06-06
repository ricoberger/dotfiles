# Tempo / VictoriaTraces

Use this reference for datasource `type` values `tempo`. Queries go through
`POST /api/ds/query`.

## Request

```bash
curl -sS -H "Authorization: $TOKEN" -H "Content-Type: application/json" \
  -X POST "$GRAFANA/api/ds/query" \
  -d '{
    "queries": [{
      "refId": "A",
      "datasource": { "uid": "'"$DATASOURCEUID"'", "type": "tempo" },
      "queryType": "traceql",
      "limit": '"${LIMIT:-20}"',
      "metricsQueryType": "range",
      "query": "'"$TRACEQL"'"
    }],
    "from": "'"$FROM"'",
    "to": "'"$TO"'"
  }'
```

## TraceQL Query Patterns

TraceQL is a functional query language, which is designed for querying and
analyzing distributed tracing data. TraceQL allows you to filter, aggregate, and
visualize traces based on various attributes and conditions.

### Filter Syntax

- `{ }`: Match all traces.
- `{resource.service.name = "frontend" && name = "POST /api/orders"}`: Match
  traces where the `resource.service.name` attribute equals `frontend` and the
  span name equals `POST /api/orders`.
- `{ resource.deployment.environment = "production" } && { resource.deployment.environment = "staging" }`:
  Match traces that go through `production` and `staging` instances.
- `{ span.foo != "bar" }`: Match traces where no span has the attribute `foo`
  equal to `bar`.
- `{ span.http.request.header.Accept =~ "application.*" }`: Match traces where
  at least one span has an `http.request.header.Accept` that matches the regex
  `application.*`.
- `{ span.http.request.header.Accept !~ "application.*" }`: Match traces where
  no span has an `http.request.header.Accept` that matches the regex
  `application.*`.
- `{ resource.service.name="frontend" } >> { status = error }`: Match traces
  that include the `frontend` service, where either that service or a downstream
  service includes a span where an error is set.
- `{ } !< { resource.service.name = "productcatalogservice" }`: Match all leaf
  spans that end in the `productcatalogservice`.
- `{ resource.service.name = "productcatalogservice" } ~ { resource.service.name="frontend" }`:
  Match if `productcatalogservice` and `frontend` are siblings.
- `{ trace:duration > 5s }`: Match traces that took longer than 5 seconds.

### Pipes

- `{ resource.service.name = "frontend" } | rate() by (status)`: Match traces
  that include the `frontend` service, and count the number of spans by their
  status (e.g. `error`, `ok`).
- `{ name = "GET /:endpoint" } | quantile_over_time(duration, .99) by (span.http.target)`:
  Match traces that include a span with the name `GET /:endpoint`, and calculate
  the 99th percentile of the duration of those spans, grouped by their
  `span.http.target` attribute.

### Find a Single Trace by ID

To find a single trace by its unique identifier, you can use the following
TraceQL query: `{trace_id="fa619c7dbdf256c067fd3ce215905bc6"}`. This is useful
if you have the trace ID from a log entry or an error report and want to
retrieve the full trace for analysis.

### Useful Fields

- `trace_id`: The unique identifier for a trace.
- `name`: The operation or span name.
- `duration`: The duration of a trace.
- `status`: The status of a span, useful when looking for errors
  (`{ status="error" }`).
- `resource.service.name`: The name of the service associated with a span.

### References

- [Construct a TraceQL query](https://grafana.com/docs/tempo/latest/traceql/construct-traceql-queries/)
- [TraceQL metrics](https://grafana.com/docs/tempo/latest/metrics-from-traces/metrics-queries/)

## What To Look For

- The longest span in the trace.
- Spans with an error status.
- The call-graph branch that diverged from a healthy baseline trace.
