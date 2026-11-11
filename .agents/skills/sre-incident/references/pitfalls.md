# Pitfalls and Patterns

Lessons from past investigations. Check here when a number looks surprising or a
hypothesis seems too obvious.

## Metric Semantics

- **Completed requests only.** Proxy request metrics (e.g.
  `istio_requests_total`, duration histograms) are recorded when a request
  finishes or is aborted. Stuck requests are invisible until they end, so the
  request rate _falls_ during a slowdown. Use connection metrics
  (`istio_tcp_connections_opened_total` − `…_closed_total`), the application's
  own queue/in-flight gauges, or the proxy's active-request gauge
  (`envoy_cluster_upstream_rq_active`, if scraped).
- **Which proxy reports.** In Istio ambient mode, L7 metrics come only from
  waypoints and gateways (`reporter="waypoint"` / the gateway as
  `reporter="source"`); `reporter="destination"` returns nothing.
- **Negative `offset`** (`offset -1d`) looks into the future. It only works for
  past ranges and silently breaks alert rules.
- **Histogram buckets** only exist at configured boundaries (e.g. 10 s, 30 s, 60
  s). "Longer than X" = `le="+Inf"` − `le="X"`; check which `le` values exist
  first.
- **Counts vs. ratios.** Absolute counts move with traffic; ratios jump when the
  denominator shrinks (nights, weekends, scaled-down fleets). Compare like with
  like (weekday vs. weekday) and show count and ratio side by side.
- **Normal noise in error flags.** Client aborts (`DR`/`DC` with status `0`)
  include legitimate cancellations (typeahead, navigation). Filter by duration
  to isolate hangs (e.g. ≥ 60 s for a service that normally answers in ms).
- **Counter resets.** Differences of raw counters across pods are approximate
  when pods restart.
- **Frontend error logs undercount.** Client-side logging misses users who close
  the tab; measure impact at the edge/gateway.

## Proxy / Mesh / CDN

- **CDN 524 / ~100 s** means the origin sent no response headers in time (e.g.
  Cloudflare's 100 s limit). At the gateway these show as status `0`, flag `DR`,
  duration ≈ the CDN timeout.
- **Envoy response flags**: `DR` downstream reset, `DC` downstream connection
  terminated, `UC` upstream connection termination, `UF` upstream connection
  failure, `UT` upstream timeout, `UAEX` ext-authz denied.
- **Find the lost hop** by matching the CDN ray ID / request ID across gateway,
  waypoint/sidecar and app logs: fast `200` at hop N + hang at hop N−1 ⇒ lost
  between them.
- **Protocol multiplexing amplifies tunnel faults.** An HTTP/2 upstream sends
  many requests over one connection (inside one tunnel stream); a stuck stream
  then blocks all of them. HTTP/1.1 upstreams use a stream per request. Check
  port names / `appProtocol` — `appProtocol` takes precedence over the port name
  for Istio protocol selection.
- **Shared proxies share failures.** Services on a shared waypoint/gateway are
  affected by triggers from their neighbours (e.g. aborted large downloads).
  Services on a dedicated proxy are a natural control group.
- **Episodes of fixed length** (e.g. exactly ~1 h) point at an idle timeout that
  releases stuck state.
- **Proxy stats may be filtered** (`proxyStatsMatcher`); live admin endpoints
  show what metrics don't.

## Resources and Saturation

- **CPU 100 % can be iowait.** Split node CPU by mode; check CPU PSI. High
  iowait + I/O PSI ≈ 1 + flat disk throughput = a disk at its provisioned cap.
- **Cloud volumes have throughput/IOPS caps** set by the storage class (e.g. 125
  MB/s). A flat line at a round number is a cap, not a coincidence.
- **Memory follows the backlog.** A queue of waiting requests grows goroutines,
  heap and temp files; page cache from temp files counts toward pressure.
- **Requests vs. limits.** A memory request doesn't limit a container; a lower
  request is a scheduling/eviction risk, not a cause of growth.
- **Neighbour impact.** A saturated pod raises iowait, evicts page cache and
  slows other pods' disks on the same node — check neighbours' PSI.
- **Connection pools** cap throughput without showing up in the database:
  database latency stays low while client errors say `context canceled`.

## Autoscaling

- Autoscalers on request rate can't see a backlog, and may **scale down** during
  a slowdown, killing in-progress work. Prefer queue / in-flight signals.
- Check every trigger's query returns data — renamed metrics leave triggers
  silently on their fallback value.
- Replay new triggers against the incident and 30 days of normal operation
  before shipping.

## Changes and Drift

- The rollout before an incident is the usual suspect, but check timing, what it
  actually touched and whether unchanged clusters show the symptom.
- Manual changes (`kubectl edit`/`scale`) are drift; resuming GitOps
  reconciliation reverts them. Suspended reconciliation means merged changes are
  **not** live.
- "Scaling fixed it" — check whether recovery started before the scale-up.

## Upstream Bugs

- Compare the fix's release with the **deployed** proxy/runtime version, not the
  chart version in the repo. Note backport labels and affected release lines.
- A matching upstream issue still needs local evidence (same flags, same
  topology, same reproduction pattern) before it is the root cause.
