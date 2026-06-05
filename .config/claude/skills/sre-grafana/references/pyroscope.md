# Pyroscope

Use this reference for datasource `type` `grafana-pyroscope-datasource`. Queries
go through `/api/ds/query`.

## Request

```bash
curl -sS -H "Authorization: $TOKEN" -H "Content-Type: application/json" \
  -X POST "$GRAFANA/api/ds/query" \
  -d '{
    "queries": [{
      "refId": "A",
      "datasource": { "uid": "'"$DATASOURCEUID"'", "type": "grafana-pyroscope-datasource" },
      "labelSelector": "'"$LABELSELECTOR"'",
      "groupBy": [],
      "spanSelector": [],
      "includeExemplars": false,
      "queryType": "both",
      "profileTypeId": "'"$PROFILETYPEID"'",
      "intervalMs": 2000,
      "maxDataPoints": '"'"${MAXDATAPOINTS:-1000}"'"
    }],
    "from": "'"$FROM"'",
    "to": "'"$TO"'"
  }'
```

## Pyroscope Query Patterns

### Label Selector

- `{ service_name="frontend" }`: Match profiles from the `frontend` service.
- `{ service_name="frontend", env="production" }`: Match profiles from the
  `frontend` service in the `production` environment.
- `{ service_name=~"frontend|backend" }`: Match profiles from either `frontend`
  or `backend` services.

### Useful Labels

- `service_name`: The name of the service that generated the profile.
- `arch`: The architecture of the system (e.g., `amd64`, `arm64`).
- `span_name`: The name of the span associated with the profile (if applicable).
- `pod`: The Kubernetes pod name (if running in Kubernetes).

### Group Profiles

Use the `groupBy` field to group profiles by specific labels, e.g.
`service_name` or `arch`. This allows you to compare profiles across different
services or architectures.

### Profile Type IDs

Profile type IDs follow the format
`<name>:<sample_type>:<sample_unit>:<period_type>:<period_unit>`. Well-known
profile types include:

- `process_cpu:cpu:nanoseconds:cpu:nanoseconds`
- `memory:alloc_in_new_tlab_objects:count:space:bytes`
- `memory:alloc_in_new_tlab_bytes:bytes:space:bytes`
- `memory:alloc_outside_tlab_objects:count:space:bytes`
- `memory:alloc_outside_tlab_bytes:bytes:space:bytes`
- `mutex:contentions:count:mutex:count`
- `mutex:delay:nanoseconds:mutex:count`
- `block:contentions:count:block:count`
- `block:delay:nanoseconds:block:count`

#### CPU

- **`process_cpu:cpu:nanoseconds:cpu:nanoseconds`** — On-CPU time per stack
  frame, in nanoseconds. Shows where the process actually burns CPU cycles. The
  workhorse profile for finding hot code paths — high samples mean a function is
  consuming CPU. Sourced from Linux `perf`-style CPU sampling (Go/Rust/eBPF) or
  JFR's `jdk.ExecutionSample` event (JVM).

#### Memory (JVM-specific — TLAB = Thread-Local Allocation Buffer)

The JVM gives each thread a private slice of the Eden generation called a TLAB
so threads can bump-the-pointer allocate without locking. When an allocation
fits, it's "in new TLAB"; when it's too big, it goes directly to the shared heap
as "outside TLAB."

- **`memory:alloc_in_new_tlab_objects:count:space:bytes`** — Number of objects
  allocated that triggered a new TLAB. Counter of small/normal allocations
  sampled by the JVM.
- **`memory:alloc_in_new_tlab_bytes:bytes:space:bytes`** — Bytes allocated in
  new TLABs. Tells you _how much_ memory those normal allocations consumed —
  useful for finding allocation-heavy code paths.
- **`memory:alloc_outside_tlab_objects:count:space:bytes`** — Number of "large"
  object allocations that bypassed TLABs. These are slower and usually worth
  investigating.
- **`memory:alloc_outside_tlab_bytes:bytes:space:bytes`** — Bytes allocated
  outside TLABs. Spikes here often indicate large arrays, big buffers, or
  oversized objects causing GC pressure.

Sources: JFR events `jdk.ObjectAllocationInNewTLAB` and
`jdk.ObjectAllocationOutsideTLAB`.

#### Mutex contention

- **`mutex:contentions:count:mutex:count`** — Number of times a thread had to
  wait to acquire a mutex/lock. High counts = frequent contention on a lock.
- **`mutex:delay:nanoseconds:mutex:count`** — Total time (ns) threads spent
  blocked waiting on mutexes. A few contentions with huge delay is a long-held
  lock; many contentions with small delay is a hot but short-held lock.

#### Blocking operations (Go: channels, condvars, select, etc.)

- **`block:contentions:count:block:count`** — Number of times a goroutine/thread
  blocked on a non-mutex synchronization primitive (channel send/recv,
  `sync.Cond`, `select` etc. in Go).
- **`block:delay:nanoseconds:block:count`** — Total wait time (ns) spent on
  those blocking operations. Useful for finding goroutines stuck waiting on
  channels or I/O coordination.

#### Quick reading guide

| You want to find…                 | Look at                                                        |
| --------------------------------- | -------------------------------------------------------------- |
| CPU hot paths                     | `process_cpu:cpu:nanoseconds:...`                              |
| Allocation hotspots / GC pressure | `memory:alloc_in_new_tlab_bytes:...`                           |
| Large/unusual allocations         | `memory:alloc_outside_tlab_bytes:...`                          |
| Lock contention                   | `mutex:delay:nanoseconds:...` (then check `mutex:contentions`) |
| Goroutine wait on channels/I/O    | `block:delay:nanoseconds:...`                                  |

Rule of thumb: `*:delay:nanoseconds` answers "where is time _lost_?", while
`*:contentions:count` answers "where does it happen _often_?". Use them
together.
