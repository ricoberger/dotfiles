# Cloudflare

Use this reference for datasource `type` `ricoberger-cloudflare-datasource`.
Queries go through `/api/ds/query`.

## Request

```bash
curl -sS -H "Authorization: $TOKEN" -H "Content-Type: application/json" \
  -X POST "$GRAFANA/api/ds/query" \
  -d '{
    "queries": [{
      "refId": "A",
      "datasource": { "uid": "'"$DATASOURCEUID"'", "type": "grafana-pyroscope-datasource" },
      "queryType": "metrics",A
      "zone": "'"$ZONE"'",
      "limit": '"${LIMIT:-1000}"',
      "name": "'"$METRICNAME"'",
      "aggregation": "count",
      "filterType": "code",
      "filter": "",
      "dimensions": [],
      "orderBy": []
    }],
    "from": "'"$FROM"'",
    "to": "'"$TO"'"
  }'

```

If the `$ZONE` is not specified, get a list of available Cloudflare zones, using
the `zones` query type and ask the user to select one. Always use the zone id in
queries and not the zone name:

```bash
curl -sS -H "Authorization: $TOKEN" -H "Content-Type: application/json" \
  -X POST "$GRAFANA/api/ds/query" \
  -d '{
    "queries": [{
      "refId": "A",
      "datasource": { "uid": "'"$DATASOURCEUID"'", "type": "ricoberger-cloudflare-datasource" },
      "queryType": "zones"
    }],
    "from": "'"$FROM"'",
    "to": "'"$TO"'"
  }'
```

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
  `xml`, `grpc`, or `grpcweb` and where the data is comming from an `eyeball`
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

The following fields can be use within the `dimensions` field:
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

## References

- [GitHub Repository](https://github.com/ricoberger/grafana-cloudflare-plugin)
- [Cloudflare GraphQL API](https://developers.cloudflare.com/analytics/graphql-api/)
