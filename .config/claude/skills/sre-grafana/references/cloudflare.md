# Cloudflare

Use this reference for datasource `type` `ricoberger-cloudflare-datasource`.
Queries go through `/api/ds/query`.

## Request

Build the JSON body with `jq -n` and pipe it into `curl --data-binary @-`.
**Never** interpolate `$FILTER`, `$ZONE`, or `$METRICNAME` directly into a
`-d '{...}'` string — GraphQL filters always contain `"` characters (e.g.
`{ requestSource: "eyeball" }`) that close the surrounding JSON string and
silently corrupt the body; the API then returns an empty result
indistinguishable from "no data":

```bash
jq -n \
  --arg uid    "$DATASOURCEUID" \
  --arg zone   "$ZONE" \
  --arg name   "$METRICNAME" \
  --arg filter "${FILTER:-}" \
  --arg from   "$FROM" \
  --arg to     "$TO" \
  --argjson limit      "${LIMIT:-1000}" \
  --argjson dimensions "${DIMENSIONS:-[]}" \
  --argjson orderBy    "${ORDERBY:-[]}" \
  '{queries:[{refId:"A",
              datasource:{uid:$uid, type:"ricoberger-cloudflare-datasource"},
              queryType:"metrics",
              zone:$zone,
              limit:$limit,
              name:$name,
              aggregation:"count",
              filterType:"code",
              filter:$filter,
              dimensions:$dimensions,
              orderBy:$orderBy}],
    from:$from, to:$to}' \
| curl -sS -H "Authorization: $TOKEN" -H "Content-Type: application/json" \
       -X POST "$GRAFANA/api/ds/query" --data-binary @-
```

If the `$ZONE` is not specified, get a list of available Cloudflare zones using
the `zones` query type and ask the user to select one. Always use the zone id in
queries and not the zone name:

```bash
jq -n \
  --arg uid  "$DATASOURCEUID" \
  --arg from "$FROM" \
  --arg to   "$TO" \
  '{queries:[{refId:"A",
              datasource:{uid:$uid, type:"ricoberger-cloudflare-datasource"},
              queryType:"zones"}],
    from:$from, to:$to}' \
| curl -sS -H "Authorization: $TOKEN" -H "Content-Type: application/json" \
       -X POST "$GRAFANA/api/ds/query" --data-binary @-
```

### Rendering the Response

The plugin returns **one frame per dimension-value combination** (e.g. one frame
per `edgeResponseStatus`), with the dimension values in
`schema.fields[1].labels` — not one frame with dimension columns. The data
values have the same `[timestamps, values]` shape as Prometheus frames.

There are three shapes you will see, depending on what dimensions you ask for.
Copy the matching jq verbatim — do not re-derive frame alignment.

**Shape A — top-N (no datetime dim, one or more grouping dims):** one frame per
group, each frame holds a single value. Renders as a sorted table.

```bash
curl -sS ... | jq -r '
  .results.A.frames as $f
  | if ($f // [] | length) == 0 then "no series" else
      [$f[]
       | ((.schema.fields[1].labels // {})
          | to_entries | map("\(.key)=\(.value)") | join(",")
          | if . == "" then "value" else . end) as $l
       | {l: $l, v: (.data.values[1][-1] // 0)}]
      | sort_by(-.v)
      | .[] | "\(.v)\t\(.l)"
    end'
```

**Shape B — multi-series over time (datetime dim + at least one grouping dim):**
one frame per group, each frame holds `[timestamps, values]`. Renders as a wide
table with one row per timestamp and one column per group.

```bash
curl -sS ... | jq -r '
  .results.A.frames as $f
  | if ($f // [] | length) == 0 then "no series" else
      ([$f[].schema.fields[1].labels // {}
        | to_entries | map("\(.key)=\(.value)") | join(",")
        | if . == "" then "value" else . end]) as $cols
      | ([$f[].data.values[0][]] | unique | sort) as $ts
      | ((["time"] + $cols) | @tsv),
        ($ts[] as $t
         | ([($t / 1000 | floor | strftime("%m-%d %H:%M:%S"))]
            + [$f[] | .data.values as [$tt,$vv]
               | (($tt | index($t)) as $ix
                  | if $ix == null then "-" else ($vv[$ix] | tostring) end)])
         | @tsv)
    end'
```

**Shape C — single series over time (datetime dim only, or filter narrows to one
group):** exactly one frame, empty `labels: {}`. Renders as a two-column table.

```bash
curl -sS ... | jq -r '
  .results.A.frames[0] as $f
  | if $f == null then "no data" else
      $f.data.values | transpose[]
      | "\(.[0] / 1000 | floor | strftime("%m-%d %H:%M:%S"))\t\(.[1])"
    end'
```

Do not assume the requested dimensions appear as columns of a single frame —
that assumption produces tables whose label column is empty and whose counts
land in the wrong rows.

## Cloudflare Query Patterns

### Metrics

The following metrics are available:

- `httpRequests`: Returns the sampled logs of HTTP requests from Cloudflare.
- `httpRequests_visits`: Returns the visit metrics for HTTP requests from
  Cloudflare. Always prefer this over `httpRequests` for request count metrics,
  as it provides more accurate counts.

### Filter

To filter the returned logs or metrics use the `filter` field. The filter syntax
must be a valid GraphQL filter expression.

The following fields can be used within the `filter`: `botManagementDecision`,
`cacheStatus`, `clientASNDescription`, `clientAsn`, `clientCountryName`,
`clientDeviceType`, `clientIP`, `clientRefererHost`, `clientRequestHTTPHost`,
`clientRequestHTTPMethodName`, `clientRequestHTTPProtocol`, `clientRequestPath`,
`clientRequestQuery`, `clientRequestReferer`, `clientRequestScheme`,
`clientSSLProtocol`, `coloCode`, `edgeDnsResponseTimeMs`,
`edgeResponseContentTypeName`, `edgeResponseStatus`, `edgeTimeToFirstByteMs`,
`originASN`, `originASNDescription`, `originIP`, `originResponseDurationMs`,
`originResponseStatus`, `rayName`, `requestSource`, `securityAction`,
`upperTierColoName`, `userAgent`, `userAgentBrowser`, `userAgentOS`,
`verifiedBotCategory`, `wafAttackScore`, `wafAttackScoreClass`,
`wafRceAttackScore`, `wafSqliAttackScore`, `wafXssAttackScore`.

Always include the `requestSource: "eyeball"` filter when analyzing traffic
patterns, as this ensures that only traffic from real users is included in the
analysis. Exclude this filter when analyzing bot traffic or when analyzing
traffic patterns that may be affected by bots or when requested by the user.

#### Examples

- Only show logs / metrics where the `edgeResponseContentTypeName` is `json`,
  `xml`, `grpc`, or `grpcweb` and where the data is coming from an `eyeball`
  request:

```graphql
{
  OR: [
    {
      edgeResponseContentTypeName: "json"
    },
    {
      edgeResponseContentTypeName: "xml"
    },
    {
      edgeResponseContentTypeName: "grpc"
    },
    {
      edgeResponseContentTypeName: "grpcweb"
    }
  ]
},
{
  requestSource: "eyeball"
}
```

- Only show logs / metrics where the `edgeResponseStatus` is `200` and the
  `edgeResponseContentTypeName` is `html`:

```graphql
{
  requestSource: "eyeball"
},
{
  AND: [
    {
      edgeResponseStatus: 200,
      edgeResponseContentTypeName: "html"
    }
  ]
}
```

### Dimensions

The `dimensions` field is a list of fields to group the returned logs or metrics
by. The syntax is a list of field names, e.g.
`["datetimeFiveMinutes", "clientCountryName"]`.

The following fields can be used within the `dimensions` field:
`botManagementDecision`, `cacheStatus`, `clientASNDescription`, `clientAsn`,
`clientCountryName`, `clientDeviceType`, `clientIP`, `clientRefererHost`,
`clientRequestHTTPHost`, `clientRequestHTTPMethodName`,
`clientRequestHTTPProtocol`, `clientRequestPath`, `clientRequestQuery`,
`clientRequestReferer`, `clientRequestScheme`, `clientSSLProtocol`, `coloCode`,
`date`, `datetime`, `datetimeFifteenMinutes`, `datetimeFiveMinutes`,
`datetimeHour`, `datetimeMinute`, `edgeDnsResponseTimeMs`,
`edgeResponseContentTypeName`, `edgeResponseStatus`, `edgeTimeToFirstByteMs`,
`originASN`, `originASNDescription`, `originIP`, `originResponseDurationMs`,
`originResponseStatus`, `requestSource`, `securityAction`, `upperTierColoName`,
`userAgent`, `userAgentBrowser`, `userAgentOS`, `verifiedBotCategory`,
`wafAttackScore`, `wafAttackScoreClass`, `wafRceAttackScore`,
`wafSqliAttackScore`, `wafXssAttackScore`.

If the metrics should be analyzed over time always include a datetime dimension,
e.g. `datetimeFiveMinutes` or `datetimeHour`.

### Examples

- Get the number of requests per host, sorted by the number of requests (shape A
  — top-N table):

```json
{
  "queries": [
    {
      "queryType": "metrics",
      "zone": "",
      "limit": 10,
      "datasource": { "type": "", "uid": "" },
      "refId": "A",
      "name": "httpRequests_visits",
      "aggregation": "count",
      "filterType": "code",
      "filter": "{ requestSource: \"eyeball\" }",
      "dimensions": ["clientRequestHTTPHost"],
      "orderBy": ["count_DESC"]
    }
  ],
  "from": "",
  "to": ""
}
```

- Request rate for a **single host over time** (shape C — single-series time
  series; filter narrows to one host, only the datetime dim remains):

```json
{
  "queries": [
    {
      "queryType": "metrics",
      "zone": "",
      "limit": 1000,
      "datasource": { "type": "", "uid": "" },
      "refId": "A",
      "name": "httpRequests_visits",
      "aggregation": "count",
      "filterType": "code",
      "filter": "{ requestSource: \"eyeball\", clientRequestHTTPHost: \"example.com\" }",
      "dimensions": ["datetimeHour"],
      "orderBy": ["datetimeHour_ASC"]
    }
  ],
  "from": "",
  "to": ""
}
```
