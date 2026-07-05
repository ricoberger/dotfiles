# Prometheus / VictoriaMetrics

Use this reference for datasource `type` values `prometheus` and
`victoriametrics-metrics-datasource`. Queries go through `POST /api/ds/query`.

## Request

Build the JSON body with `jq -n` and pipe it into `curl --data-binary @-`.
**Never** interpolate `$PROMQL` (or any other shell variable) directly into a
`-d '{...}'` string — any query containing a `"` (e.g. label selectors like
`{job="api"}`) silently corrupts the JSON, and the API returns an empty result
that looks identical to a legitimate "no matches" answer:

```bash
jq -n \
  --arg uid   "$DSUID" \
  --arg expr  "$PROMQL" \
  --arg from  "$FROM" \
  --arg to    "$TO" \
  --argjson instant       false \
  --argjson range         true \
  --argjson intervalMs    15000 \
  --argjson maxDataPoints "${MAXDATAPOINTS:-1000}" \
  '{queries:[{refId:"A",
              datasource:{uid:$uid, type:"prometheus"},
              expr:$expr,
              instant:$instant, range:$range,
              intervalMs:$intervalMs, maxDataPoints:$maxDataPoints}],
    from:$from, to:$to}' \
| curl -sS -H "Authorization: $TOKEN" -H "Content-Type: application/json" \
       -X POST "$GRAFANA/api/ds/query" --data-binary @-
```

For an instant query, flip `--argjson instant true --argjson range false`.

### Rendering the Response

Frames arrive as parallel `[timestamps, values]` arrays per series. Do **not**
write frame-alignment jq from scratch — copy one of the two tested programs
below (they expect `refId` `A`; adjust only that).

**Range query -> table** (one row per timestamp — union across series — one
column per series, `-` for missing samples):

```bash
curl -sS ... | jq -r '
  .results.A.frames as $f
  | if ($f // [] | length) == 0 then "no series" else
      ([$f[].schema.fields[1].labels // {} | del(.__name__)
        | to_entries | map("\(.key)=\(.value)") | join(",")
        | if . == "" then "value" else . end]) as $cols
      | ([$f[].data.values[0][]] | unique | sort) as $ts
      | ((["time"] + $cols) | @tsv),
        ($ts[] as $t
         | ([($t / 1000 | floor | strftime("%m-%d %H:%M:%S"))]
            + [$f[] | .data.values as [$tt,$vv]
               | (($tt | index($t)) as $ix
                  | if $ix == null then "-"
                    else ($vv[$ix]
                          | if type == "number" then (. * 1000 | round / 1000) else . end
                          | tostring)
                    end)])
         | @tsv)
    end'
```

**Instant query -> table** (one row per series: labels, value):

```bash
curl -sS ... | jq -r '
  .results.A.frames as $f
  | if ($f // [] | length) == 0 then "no series" else
      $f[]
      | ((.schema.fields[1].labels // {}) | del(.__name__)
         | to_entries | map("\(.key)=\(.value)") | join(",")
         | if . == "" then "value" else . end) as $l
      | "\($l)\t\(.data.values[1][-1]
           | if type == "number" then (. * 1000 | round / 1000) else . end)"
    end'
```

Gotchas baked into the programs above — keep them when modifying:

- Timestamps are Unix-**ms**; `strftime` needs integer seconds (`/ 1000 | floor`
  — passing a float raises `strftime/1 requires parsed datetime inputs`).
- Series can have **different timestamp sets**; aligning by index instead of by
  timestamp silently misattributes values.
- A missing series (`frames` empty) must render as text, not crash `@tsv` —
  never mix bare strings into rows passed to `@tsv`.
- Metric values whose timestamps are epoch **seconds** (e.g. `kube_pod_created`)
  need `| round | todate`, not `strftime` on the raw float.

## PromQL Query Patterns

PromQL is a functional query language for time series data. Every query returns
either an **instant vector** (one value per label set at a point in time), a
**range vector** (a sliding window of samples), or a **scalar**.

**Golden rule:** `rate()` and `increase()` always require a range vector. The
range must be at least 4x the scrape interval to avoid gaps. For a 60s scrape
interval, use `[5m]` minimum.

### Rate and Counter Queries

**Rate (per-second average over a window):**

```promql
rate(http_requests_total[5m])
```

**Rate with label aggregation — "sum then rate" is wrong, always rate then
sum:**

```promql
# CORRECT: rate first, then aggregate
sum(rate(http_requests_total{job="api"}[5m])) by (status_code)

# WRONG: sum first destroys the counter monotonicity
sum(http_requests_total) by (status_code)   -- do NOT then rate() this
```

**Increase (total count over a window, not per-second):**

```promql
increase(http_requests_total[1h])
```

**irate vs rate:**

- `rate()` - smooth average over the full window. Use for dashboards and alerts.
- `irate()` - instantaneous rate from the last two samples. Use only when you
  need to capture spikes that `rate()` would average away. Never use for
  alerting.

### Filtering With Label Matchers

```promql
# Exact match
http_requests_total{job="api", status_code="200"}

# Regex match (anchored automatically)
http_requests_total{status_code=~"5.."}

# Negative regex
http_requests_total{status_code!~"2.."}

# Multiple values with regex OR
http_requests_total{env=~"staging|production"}
```

### Aggregation Operators

Always aggregate after `rate()`:

```promql
# Sum across all instances, keep service label
sum(rate(http_requests_total[5m])) by (service)

# Average CPU per node, drop all other labels
avg(node_cpu_seconds_total{mode="idle"}) by (instance)

# 95th percentile request duration
histogram_quantile(0.95,
  sum(rate(http_request_duration_seconds_bucket[5m])) by (le, service)
)

# Top 5 services by request rate
topk(5, sum(rate(http_requests_total[5m])) by (service))

# Count of distinct label values
count(count(up) by (job)) by ()
```

**`without` vs `by`:**

```promql
# Keep only the labels listed
sum(rate(http_requests_total[5m])) by (service, status_code)

# Drop only the labels listed, keep everything else
sum(rate(http_requests_total[5m])) without (instance, pod)
```

### Histogram Quantiles

Native histograms (Prometheus 2.40+) and classic histograms use different
syntax.

**Classic histogram (bucket metrics with `_bucket` suffix):**

```promql
histogram_quantile(0.99,
  sum(rate(http_request_duration_seconds_bucket{job="api"}[5m])) by (le)
)
```

**Multi-service comparison:**

```promql
histogram_quantile(0.95,
  sum(rate(http_request_duration_seconds_bucket[5m])) by (le, service)
)
```

**Common mistake:** forgetting `by (le)` in the inner aggregation drops the
bucket boundaries, making `histogram_quantile` produce wrong results or NaN.

**Native histograms (simpler syntax):**

```promql
histogram_quantile(0.95, sum(rate(http_request_duration_seconds[5m])))
```

### Ratio and Error Rate

```promql
# Error ratio (errors / total)
sum(rate(http_requests_total{status_code=~"5.."}[5m]))
/
sum(rate(http_requests_total[5m]))

# Success rate as percentage
(1 -
  sum(rate(http_requests_total{status_code=~"5.."}[5m]))
  /
  sum(rate(http_requests_total[5m]))
) * 100

# Avoid division by zero with or vector(0)
sum(rate(errors_total[5m]))
/
(sum(rate(requests_total[5m])) > 0)
```

### Absence and Staleness

```promql
# Alert when a metric disappears (e.g. a job stops reporting)
absent(up{job="api"})

# Alert when a metric value hasn't changed (potential stale exporter)
changes(up{job="api"}[5m]) == 0

# Check if a metric has been present in the last window
count_over_time(up{job="api"}[5m]) > 0
```

### Time Functions and Offsets

```promql
# Compare current value to 1 hour ago
rate(http_requests_total[5m])
-
rate(http_requests_total[5m] offset 1h)

# Day-over-day comparison
rate(http_requests_total[5m])
/
rate(http_requests_total[5m] offset 1d)

# Predict value in 2 hours based on current trend (linear regression)
predict_linear(node_filesystem_avail_bytes[1h], 2 * 3600)
```

### Common Patterns

**Service availability (for use in alert rules):**

```promql
avg_over_time(up{job="api"}[5m]) < 0.9
```

**Saturation (resource near-full):**

```promql
# Disk filling up (predict full in < 4h based on 1h trend)
predict_linear(node_filesystem_avail_bytes{mountpoint="/"}[1h], 4 * 3600) < 0
```

**Throughput spike:**

```promql
# Current rate > 3x the 1-hour average
rate(http_requests_total[5m])
>
3 * avg_over_time(rate(http_requests_total[5m])[1h:5m])
```

### References

- [Prometheus querying basics](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Prometheus best practices](https://prometheus.io/docs/practices/naming/)
- [VictoriaMetrics MetricsQL](https://docs.victoriametrics.com/victoriametrics/metricsql/)
