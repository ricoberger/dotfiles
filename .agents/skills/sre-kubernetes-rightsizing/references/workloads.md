# Engine-Aware Right-Sizing

Database and JVM workloads do **not** size like stateless services. Their memory
footprint is largely a deliberate, configured ceiling — a cache or a heap — and
the observed working set is partly a _function of the limit you already gave
them_. Shrinking memory on such a workload degrades latency (cache eviction, GC
thrash, page-cache misses) while firing **neither OOMKills nor PSI** — exactly
the two downsize guards the generic method in `SKILL.md` relies on. So for these
engines, size the limit from the engine's own memory model and use the engine's
native pressure signal as the guard.

One **non-engine** category at the end of this file — page-cache-sensitive
services — shares the same OOM/PSI blind spot **without** any configurable
ceiling, and is reached only when no engine matches.

This file is consulted from three points in the main workflow:

- **Step 1** — classify the workload (detection table below).
- **Step 4** — pull the engine's signal metrics alongside the generic usage.
- **Step 5** — apply the engine's sizing rule and downsize guard.

## How This Plugs In

1. **Classify** after resolving the target. Match the container image and common
   labels (table below) to a candidate engine, then **confirm by probing** for
   that engine's exporter metric (the `Probe` query in each section). Run every
   query through `sre-grafana`, same as the generic queries.
2. **Confirmed** (probe returns series) → use the engine section: pull its
   signal metrics in step 4, apply its sizing rule + downsize guard in step 5,
   and add the engine line to the report.
3. **Candidate but probe empty** (engine detected from the image, but no
   exporter metrics) → fall back to the generic working-set method, and **state
   explicitly in the report** that the recommendation ignores the engine's
   memory model because no exporter was found. Suggest deploying the exporter
   for an accurate sizing.
4. **No match** → plain generic method. **But first check whether the workload
   is page-cache-sensitive** (stateful/mmap-heavy with `container_memory_cache`
   a large share of memory, no engine exporter — see "Page-Cache-Sensitive
   Services (Non-Engine)" below); if so, keep the generic
   `working_set_max × 1.25` sizing but add the major-page-fault downsize guard,
   since PSI and OOM miss page-cache thrash.

> An engine match never _replaces_ the generic working-set/PSI analysis — it
> **augments** it. Always still pull working set, OOMKills and PSI; the engine
> rule decides how to read them and sets the floor the generic numbers may not.

## Detection

Match on container image first, corroborate with labels, then probe. Images are
matched as substrings (ignore registry/tag). The `app.kubernetes.io/name` label
(or the operator's own label) is the most reliable corroborator.

| Engine                     | Image contains                                        | Common labels (`app.kubernetes.io/name`, operator labels) | Confirm-by-probe metric                                                    |
| -------------------------- | ----------------------------------------------------- | --------------------------------------------------------- | -------------------------------------------------------------------------- |
| MongoDB                    | `mongo`, `mongodb`, `percona-server-mongodb`          | `mongodb`, `psmdb`, `mongodb-replicaset`                  | `mongodb_ss_wt_cache_maximum_bytes_configured`                             |
| PostgreSQL                 | `postgres`, `postgresql`, `spilo`, `crunchy-postgres` | `postgresql`, `postgres`, `cluster-name` (Zalando/CNPG)   | `pg_settings_shared_buffers_bytes`                                         |
| Redis                      | `redis`, `valkey`, `redis-stack`                      | `redis`, `valkey`, `redis-cluster`                        | `redis_memory_used_bytes`                                                  |
| Kafka                      | `kafka`, `cp-kafka`, `strimzi`, `redpanda`            | `kafka`, `strimzi.io/cluster`                             | `kafka_server_replicamanager_*` or JMX heap                                |
| ClickHouse                 | `clickhouse`, `clickhouse-server`                     | `clickhouse`, `clickhouse-operator`                       | `ClickHouseMetrics_MemoryTracking`                                         |
| Elasticsearch / OpenSearch | `elasticsearch`, `opensearch`                         | `elasticsearch`, `opensearch`, `elasticsearch-master`     | `elasticsearch_jvm_memory_max_bytes` / `opensearch_jvm_mem_heap_max_bytes` |
| Generic JVM                | java app images; presence of `-Xmx`/`JAVA_OPTS`       | any; corroborate by the JVM probe                         | `jvm_memory_bytes_used` / `jvm_memory_used_bytes`                          |

Pick **Generic JVM** only when no more-specific engine matched but the JVM probe
returns series (Kafka, Elasticsearch and OpenSearch are JVM engines too — prefer
their specific section, which already covers the heap plus the engine's caches).

### Selecting an Exporter’s Series

Exporter metrics carry the exporter's **own** target labels, not cAdvisor's
container labels. They are usually selectable by `namespace="$NS"` plus a
pod/instance label that matches the workload:

- **Sidecar exporter** (mongodb_exporter, redis_exporter, JMX agent in the same
  pod) → the `pod` label matches the workload pods; reuse the kind's pod-name
  regex from `queries.md` (`pod=~"$WL-..."`) or the owner-join.
- **Standalone exporter** (a separate postgres_exporter / elasticsearch_exporter
  Deployment) → select by its own `service` / `instance` / cluster label, not
  the DB pod name. Probe `<metric>{namespace="$NS"}` first and read the label
  set off the result to find the right selector.

Abbreviate the chosen selector as `$ESEL` in the queries below.

## Shared Principle — Memory-Resident Engines

For every engine here except where noted, the container memory **limit** is a
hard ceiling the engine plans against, so:

```text
recommended mem limit   = max( engine_ceiling × overhead_factor ,
                               working_set_max × 1.25 )
recommended mem request = the resident footprint the engine keeps hot
                          (≈ p95 working set; ≈ the limit for heap/maxmemory-pinned engines)
```

- `engine_ceiling` is the engine's configured memory budget (WiredTiger cache,
  `shared_buffers`, `maxmemory`, JVM `-Xmx`, `max_server_memory_usage`).
- **Downsize guard:** never recommend a memory limit **below
  `engine_ceiling × overhead_factor`** on working-set evidence alone. The only
  way to safely reclaim memory is to _also_ lower the engine's own config — call
  that out as a paired change, never a silent trim.
- **CPU** still follows the generic `p95 × 1.15` rule, **but** databases are
  latency-sensitive: CPU starvation shows up as query-latency growth long before
  the usage percentile saturates. Lean on CPU PSI (`queries.md`) as the real
  bottleneck signal and never trim a DB's CPU request without near-zero CPU PSI.

Each section gives `engine_ceiling`, the `overhead_factor`, and the engine's
**pressure signal** that replaces OOM/PSI as the downsize guard.

---

## MongoDB

**Memory model.** The WiredTiger cache dominates and defaults to
`max(0.5 × (RAM − 1GiB), 256MiB)`, derived from the container memory limit (or
`storage.wiredTiger.engineConfig.cacheSizeGB` when set). Cut the limit and Mongo
recomputes a _smaller_ cache → more disk reads, worse latency — with no OOM.
Plus ~1MiB per connection and aggregation/sort scratch.

**Probe.**

```promql
count(mongodb_ss_wt_cache_maximum_bytes_configured{namespace="$NS"})
```

**Signal metrics.**

```promql
# configured WiredTiger cache ceiling (engine_ceiling)
max_over_time((max(mongodb_ss_wt_cache_maximum_bytes_configured{$ESEL}))[30d:10m])

# bytes actually held in cache — fill ratio vs the ceiling
max_over_time((max(mongodb_ss_wt_cache_bytes_currently_in_the_cache{$ESEL}))[30d:10m])

# read-into-cache rate (cache-miss pressure) and eviction pressure
max_over_time((max(rate(mongodb_ss_wt_cache_bytes_read_into_cache{$ESEL}[5m])))[30d:10m])

# current connections (≈1MiB each)
quantile_over_time(0.95, (max(mongodb_ss_connections{$ESEL,conn_type="current"}))[30d:10m])
```

> Metric names vary across exporter versions (Percona `mongodb_ss_*` vs older
> `mongodb_mongod_wiredtiger_cache_*`). Probe both prefixes if the first is
> empty.

**Sizing.** `engine_ceiling` = configured WiredTiger cache; `overhead_factor` ≈
`1 / 0.5` plus the +1GiB base, i.e. a limit that _keeps the current cache_ must
satisfy `limit ≥ cache / 0.5 + 1GiB`, then add connection headroom
(`current_conns × 1MiB`). Take the max of that and `working_set_max × 1.25`.

**Downsize guard.** Cache fill at ~100% of the configured maximum **with** a
non-trivial `read_into_cache` rate = the working set does not fit; raise, do not
trim. Only recommend a smaller limit when cache fill sits well below the
configured maximum **and** read-into-cache is near zero — and pair it with a
matching `cacheSizeGB` reduction.

**Structural inputs (the WT cache metrics are not enough on their own).** The WT
cache signals show _whether_ the working set fits; these show _why_ and _how
much_, and catch the case where the fix is an index, not RAM:

```promql
# total index size — the classic "indexes should fit in RAM" check (sum across DBs)
max(sum by(pod)(mongodb_dbstats_indexSize{$ESEL}))
# uncompressed data + compressed on-disk storage (cacheable universe + growth trend)
max(sum by(pod)(mongodb_dbstats_dataSize{$ESEL}))
max(sum by(pod)(mongodb_dbstats_storageSize{$ESEL}))
# per-collection index footprint — find the dominant collections
topk(8, sum by(database,collection)(mongodb_collstats_storageStats_totalIndexSize{$ESEL}))
```

Compare **total index size to the WT cache**: when indexes ≫ cache (verified
live: 53GiB indexes vs a 12.5GiB cache — 4×), index pages cannot stay resident
and the cache churns by construction. This is the **dominant memory input for an
index-heavy DB**, and it bounds how far more RAM helps — a small bump barely
dents a multiples-larger index set; only a much bigger box, or fewer/smaller
indexes, moves the needle. Never size Mongo memory off the WT cache metrics
alone.

**RAM problem vs missing-index problem.** Cache pressure caused by a missing
index (collection scans flooding the cache) looks identical to "needs more RAM"
in the WT metrics — but the fix is an index, not memory. Check first:

```promql
# full collection scans per second — ~0 for a properly indexed workload
max_over_time((max(rate(mongodb_ss_metrics_queryExecutor_collectionScans_total{$ESEL}[5m])))[30d:1h])
# documents examined (pair with docs returned for an examined:returned ratio ≫1 = inefficient)
sum(rate(mongodb_ss_metrics_queryExecutor_scannedObjects{$ESEL}[1h]))
```

Sustained collection scans / a high examined:returned ratio ⇒ fix the query or
add an index first; do not buy RAM to mask it.

**Index hygiene — cheaper than RAM, but replica-set-aware and delicate.**
Unused/redundant indexes waste cache and RAM; `$indexStats` exposes per-index
usage, but the metric has sharp edges:

- **Scope to the PRIMARY.** Application reads route to the primary, so usage
  counters on secondaries are ~0 (verified live: primary 103M index ops vs ~1M
  on each secondary — querying a secondary makes _every_ index look unused).
  Resolve it first, and apply this to **all** query-side Mongo metrics (usage,
  scans, ops, examined), not just indexstats:
  ```promql
  mongodb_mongod_replset_my_state{$ESEL} == 1   # the primary pod (or filter rs_state="PRIMARY")
  ```
- **Per-index dimension is `key_name`, not `index`** (the `index` label is
  empty):
  ```promql
  sum by(collection,key_name)(increase(mongodb_indexstats_accesses_ops{<primary-pod>}[7d]))
  ```
- **Never autodrop on a 0-ops reading.** `accesses.ops` counts only _query_ uses
  — a **TTL** index (e.g. `createdAt_1`), a **unique/constraint** index, or one
  used only by rare/batch jobs shows ~0 ops yet is essential (verified live: a
  0-op `createdAt_1` on the largest collection was a TTL index). Counters also
  **reset on restart**, the **primary rotates** (a node only sees usage since it
  last became primary — check `mongodb_ss_uptime`), and the exporter often
  tracks only a **subset** of indexes. Treat the result as _directional_ ("which
  indexes look cold"); confirm with `db.coll.aggregate([{$indexStats:{}}])` on
  the live primary plus the index definitions before dropping anything.

---

## PostgreSQL

**Memory model.** `shared_buffers` (commonly 25% of RAM) is pinned shared
memory; `work_mem` is allocated _per sort/hash node per connection_ (peak ≈
`work_mem × active_connections × nodes`); `maintenance_work_mem` for
vacuum/index builds; and Postgres leans heavily on the **OS page cache** (sized
via `effective_cache_size`) for everything not in shared_buffers — that page
cache lives in the container's working set and is incompressible-looking to a
naive trim.

**Probe.**

```promql
count(pg_settings_shared_buffers_bytes{namespace="$NS"})
```

**Signal metrics.**

```promql
# configured ceilings
max_over_time((max(pg_settings_shared_buffers_bytes{$ESEL}))[30d:10m])
max_over_time((max(pg_settings_work_mem_bytes{$ESEL}))[30d:10m])
max_over_time((max(pg_settings_maintenance_work_mem_bytes{$ESEL}))[30d:10m])
max_over_time((max(pg_settings_max_connections{$ESEL}))[30d:10m])

# buffer cache hit ratio — the undersize signal (decays when memory is short)
sum(rate(pg_stat_database_blks_hit{$ESEL}[5m]))
  / (sum(rate(pg_stat_database_blks_hit{$ESEL}[5m])) + sum(rate(pg_stat_database_blks_read{$ESEL}[5m])))

# peak concurrent connections (drives work_mem multiplication)
quantile_over_time(0.95, (sum(pg_stat_activity_count{$ESEL}))[30d:10m])
```

**Sizing.** `engine_ceiling` ≈
`shared_buffers + maintenance_work_mem + work_mem × peak_active_connections + ~150MiB base`;
`overhead_factor` ~1.2 plus a page-cache allowance (don't squeeze the limit down
to just `shared_buffers` — leave room for hot data in page cache). Take the max
of that and `working_set_max × 1.25`.

**Downsize guard.** A buffer cache-hit ratio durably **below ~0.99 (OLTP)** is
memory starvation — raise, don't trim. Only trim when the hit ratio is high
_and_ working set sits well under the limit.

**Replica-set note.** `pg_settings_*` are identical across members, but the
**cache-hit ratio, connections, and write activity differ per instance** — and
unlike Mongo, Postgres **read replicas actively serve reads**, so don't assume
one member represents all: analyze each and **size to the busiest**. Resolve the
role first — `pg_replication_is_replica == 1` (or `pg_settings` `…in_recovery`)
marks a replica; the primary is the member carrying `pg_stat_replication_*`
(connected standbys). Roles fail over, so key on the role metric, not a pod
ordinal. (Exporter naming varies — probe `pg_replication_*` /
`pg_stat_replication_*`.)

---

## Redis / Valkey

**Memory model.** The entire dataset must live in RAM. `maxmemory` is the data
ceiling; real RSS = `used_memory × mem_fragmentation_ratio` (allocator overhead,
typically 1.2–1.5×) plus replication/AOF buffers. If `maxmemory` is unset (`0`),
Redis grows unbounded until OOM.

**Probe.**

```promql
count(redis_memory_used_bytes{namespace="$NS"})
```

**Signal metrics.**

```promql
# data ceiling (0 = unbounded) and live usage
max_over_time((max(redis_memory_max_bytes{$ESEL}))[30d:10m])
quantile_over_time(0.95, (max(redis_memory_used_bytes{$ESEL}))[30d:10m])
max_over_time((max(redis_memory_used_bytes{$ESEL}))[30d:10m])

# fragmentation (RSS / used) and evictions — the undersize signal
max_over_time((max(redis_mem_fragmentation_ratio{$ESEL}))[30d:10m])
max_over_time((max(rate(redis_evicted_keys_total{$ESEL}[5m])))[30d:10m])
```

**Sizing.** If `maxmemory > 0`: `engine_ceiling` = `maxmemory`,
`overhead_factor` = `mem_fragmentation_ratio` (≥1.3) + replication-buffer
headroom. If `maxmemory == 0`: there is no engine ceiling — size off
`used_memory` peak × fragmentation × 1.25 **and recommend setting `maxmemory`**
to a value below the limit so Redis enforces its own bound instead of OOMing.

**Downsize guard.** A non-zero `evicted_keys` rate means the dataset doesn't fit
**unless** the `maxmemory-policy` is an intentional LRU/LFU cache (`allkeys-*`)
— check the policy before reading evictions as pressure. For a persistence/store
policy (`noeviction`/`volatile-*`), evictions ⇒ raise. Trim only with zero
evictions and used_memory well under maxmemory.

**Replica-set note.** In a master/replica (e.g. Sentinel) topology replicas
mirror the dataset, so `used_memory`/`maxmemory` are ~identical across members
(size memory off any). But **evictions, write load, expirations and client
connections are master-side** — read those on the master, or a quiet replica
makes the dataset look like it fits when the master is evicting. Resolve role
via `redis_instance_info{role="master"}` (or `redis_connected_slaves > 0`); role
fails over, so don't pin to a pod ordinal.

---

## Kafka

**Memory model.** Two distinct pools: a **modest JVM heap** (often 4–6GiB; Kafka
deliberately keeps the heap small) for the broker, **plus** heavy reliance on
the **OS page cache** for log segments — reads/writes are served from page
cache, and that cache counts toward the container's working set. Sizing the
limit to just the heap starves the page cache and collapses throughput. Also
uses off-heap direct memory for network buffers.

**Probe.**

```promql
count(kafka_server_replicamanager_underreplicatedpartitions{namespace="$NS"})
  or count(jvm_memory_bytes_max{namespace="$NS",area="heap"})
```

**Signal metrics.**

```promql
# JVM heap ceiling (Xmx) and live heap use
max_over_time((max(jvm_memory_bytes_max{$ESEL,area="heap"}))[30d:10m])
quantile_over_time(0.95, (max(jvm_memory_bytes_used{$ESEL,area="heap"}))[30d:10m])

# GC time fraction — heap-pressure signal (rises before working set hits limit)
max_over_time((max(rate(jvm_gc_collection_seconds_sum{$ESEL}[5m])))[30d:10m])

# health / load signals
max_over_time((max(kafka_server_replicamanager_underreplicatedpartitions{$ESEL}))[30d:10m])
max_over_time((max(rate(kafka_server_brokertopicmetrics_bytesin_total{$ESEL}[5m])))[30d:10m])
```

> Raw JMX mappings expose `java_lang_memory_heapmemoryusage_used/_max` instead
> of `jvm_memory_bytes_*`; probe both. Strimzi/Confluent JMX names also vary.

**Sizing.** `engine_ceiling` = JVM `-Xmx` (heap) **+ direct memory**;
`overhead_factor` must add a **generous page-cache allowance** — keep the limit
well above heap (commonly 2–3× heap) so hot segments stay cached. Take the max
of that and `working_set_max × 1.25`. **Never** set the limit near just the
heap.

**Downsize guard.** Sustained GC time fraction (e.g.
`rate(gc_seconds_sum) > ~0.05`) or heap-used persistently > ~75% of Xmx ⇒ heap
undersized → raise Xmx _and_ the limit. Under-replicated partitions > 0 is a
hard health signal. Trim only with low GC, heap headroom, **and** healthy
throughput. For the precise heap-need number, run the shared post-GC live-set
check (**JVM Heap Right-Sizing** below) — but remember a low Kafka live set is
expected (page-cache design), not a reason to shrink the already-small heap.

---

## ClickHouse

**Memory model.** ClickHouse tracks its own memory budget via
`max_server_memory_usage` (bytes) or, by default,
`max_server_memory_usage_to_ram_ratio` (default **0.9** of available RAM) —
meaning it **auto-sizes to ~90% of the container limit**. So the limit
_directly_ sets ClickHouse's query budget: trim it and queries start failing
with `MEMORY_LIMIT_EXCEEDED`. Mark cache and uncompressed cache add fixed pools.

**Probe.**

```promql
count(ClickHouseMetrics_MemoryTracking{namespace="$NS"})
```

**Signal metrics.**

```promql
# total tracked memory (ClickHouse's own accounting) — p95 and peak
quantile_over_time(0.95, (max(ClickHouseMetrics_MemoryTracking{$ESEL}))[30d:10m])
max_over_time((max(ClickHouseMetrics_MemoryTracking{$ESEL}))[30d:10m])

# RSS as ClickHouse sees it
max_over_time((max(ClickHouseAsyncMetrics_MemoryResident{$ESEL}))[30d:10m])

# query-memory failures — the hard undersize signal
max_over_time((max(rate(ClickHouseProfileEvents_QueryMemoryLimitExceeded{$ESEL}[5m])))[30d:10m])

# fixed caches
max_over_time((max(ClickHouseAsyncMetrics_MarkCacheBytes{$ESEL}))[30d:10m])
```

**Sizing.** If `max_server_memory_usage` is set explicitly: `engine_ceiling` =
that value; else the ceiling **is** `0.9 × limit`, so size the limit so that
`0.9 × limit ≥ MemoryTracking peak × 1.2` — i.e.
`limit ≥ MemoryTracking_peak × 1.35` — plus mark/uncompressed cache headroom.
Take the max of that and `working_set_max × 1.25`.

**Downsize guard.** Any `QueryMemoryLimitExceeded` events, or `MemoryTracking`
peak approaching the configured cap, ⇒ raise. Trim only with zero memory-limit
failures and tracked memory well under the cap.

---

## Elasticsearch / OpenSearch

**Memory model.** A bounded **JVM heap** (`-Xmx`, kept **≤ 50% of RAM** and **≤
~31GiB** to preserve compressed object pointers) **plus** the **OS page cache
for Lucene segments** — the other ~50% of RAM serves search from page cache.
Heap holds field data, query cache, indexing buffers. Both halves matter:
too-small heap → GC thrash / circuit breakers; too-small page cache → slow
searches.

**Probe.**

```promql
count(elasticsearch_jvm_memory_max_bytes{namespace="$NS",area="heap"})
  or count(opensearch_jvm_mem_heap_max_bytes{namespace="$NS"})
```

**Signal metrics.** (OpenSearch plugin names in parentheses.)

```promql
# heap ceiling and use
max_over_time((max(elasticsearch_jvm_memory_max_bytes{$ESEL,area="heap"}))[30d:10m])
quantile_over_time(0.95, (max(elasticsearch_jvm_memory_used_bytes{$ESEL,area="heap"}))[30d:10m])

# GC time fraction — heap-pressure signal
max_over_time((max(rate(elasticsearch_jvm_gc_collection_seconds_sum{$ESEL}[5m])))[30d:10m])

# field-data evictions — heap-cache pressure (raise heap, not just limit)
max_over_time((max(rate(elasticsearch_indices_fielddata_evictions{$ESEL}[5m])))[30d:10m])
# (OpenSearch: opensearch_jvm_mem_heap_max_bytes / _used_bytes,
#  opensearch_indices_fielddata_evictions_count)
```

**Sizing.** `engine_ceiling` = JVM `-Xmx`; the limit must satisfy
`limit ≥ 2 × Xmx` (heap ≤ 50% rule) **and** leave page cache for segments — take
the max of `2 × Xmx`, `(heap + segment-cache allowance)`, and
`working_set_max × 1.25`. **Never recommend a heap above ~31GiB** even if the
node is large; scale out instead.

**Downsize guard.** Sustained GC time, heap-used persistently > ~75%, or rising
field-data evictions ⇒ heap undersized → raise heap (respecting the 31GiB cap)
and the limit. Trim only with low GC, heap headroom, and no field-data eviction
churn. To decide raise-vs-shrink precisely (and to size a master node by
**dropping** Xmx instead of growing the box), run the shared post-GC live-set
check (**JVM Heap Right-Sizing** below).

---

## Generic JVM

For any other JVM workload (Spring Boot, Scala services, etc.) when the more
specific engines did not match.

**Memory model.** RSS = **heap** (`-Xmx`, committed up to the max) **+
non-heap** (metaspace, code cache, compressed class space) **+ native** (direct
byte buffers, thread stacks ≈ `threads × ~512KiB–1MiB`, JNI). The OS/cgroup
never reclaims committed heap, so working set ≈ committed heap + non-heap +
native; trimming the limit below that → OOMKill. Crucially, **GC keeps working
set _below_ the limit by collecting** — so a flat working-set max can hide a
heap that is actually under pressure, the same way a memory limit censors true
demand. GC frequency/time is the uncensored signal.

**Probe.**

```promql
count(jvm_memory_bytes_used{namespace="$NS",area="heap"})
  or count(jvm_memory_used_bytes{namespace="$NS",area="heap"})
```

**Signal metrics.** (`client_java` `jvm_memory_bytes_*` / Micrometer
`jvm_memory_used_bytes`; probe both.)

```promql
# heap ceiling (Xmx) and use
max_over_time((max(jvm_memory_bytes_max{$ESEL,area="heap"}))[30d:10m])
quantile_over_time(0.95, (max(jvm_memory_bytes_used{$ESEL,area="heap"}))[30d:10m])
max_over_time((max(jvm_memory_bytes_used{$ESEL,area="heap"}))[30d:10m])

# non-heap (metaspace + code cache) — add to the heap for the limit
max_over_time((max(jvm_memory_bytes_used{$ESEL,area="nonheap"}))[30d:10m])

# GC time fraction — the uncensored heap-pressure signal
max_over_time((max(rate(jvm_gc_collection_seconds_sum{$ESEL}[5m])))[30d:10m])
# Micrometer equivalent: rate(jvm_gc_pause_seconds_sum[5m])
```

**Sizing.** `engine_ceiling` = `Xmx + non-heap_peak + native_headroom`;
`overhead_factor` ~1.1–1.25. Concretely
`limit ≈ Xmx × 1.25 + non-heap_peak + (threads × ~1MiB)`. Take the max of that
and `working_set_max × 1.25`. The **request** should cover committed heap +
non-heap (heap rarely shrinks), so request ≈ p95 working set, often close to the
limit.

**Downsize guard.** High GC time fraction (`rate(gc_seconds_sum) > ~0.05`) or
frequent full GCs with heap-used near Xmx ⇒ heap undersized → raise Xmx _and_
the limit, **even if working-set max looks comfortably under the limit** (GC is
masking the demand). Trim heap/limit only with low GC, clear heap headroom, and
no OOM history. For the **two-directional** heap signal (and the number to size
Xmx to), run the shared post-GC live-set check below.

---

## JVM Heap Right-Sizing — Post-GC Live Set (shared: Generic JVM, Kafka, Elasticsearch/OpenSearch)

GC time fraction (used by every JVM section above) catches an **under**-sized
heap (high GC) but is silent on an **over**-sized one — a 10×-too-large heap
also has low GC. The signal that sizes the heap in **both** directions is the
**live set**: old-gen occupancy _immediately after a collection_. The sampled
heap `max` is a _pre-GC peak_ (mostly collectable young garbage) and badly
overstates true need — never size heap off it.

> **Verified live why this matters.** Same skill, two JVM workloads, opposite
> verdicts the pre-GC peak hid: an ES data node showed heap `max` 16GiB on a
> 21GiB Xmx (looks ~right) but a **2GiB live set with 0 old GCs in 30d** → heap
> ~10× oversized. A Jetty service showed heap `max` ≈ Xmx (looks pressured) and
> a **live set at 99% of Xmx with 30% old-GC wall-time** → genuinely starved.

**Live-set probe ladder** (name varies by exporter — probe top-down, use the
first that returns series):

1. **Post-collection occupancy (best — true live set):**
   `jvm_memory_pool_collection_used_bytes{pool=~".*Old.*"}` (`client_java` /
   simpleclient). Updated only after a GC of that pool, so it **is** the live
   set.
2. **Old-gen occupancy floor (fallback):** a low percentile of
   `jvm_memory_pool_used_bytes{pool=~".*Old.*"}` (client_java) /
   `jvm_memory_used_bytes{area="heap",id=~".*Old.*"}` (Micrometer) /
   `elasticsearch_jvm_memory_pool_used_bytes{pool="old"}` /
   `opensearch_jvm_mem_pools_old_used_bytes` — the sawtooth bottom ≈ live set.
3. **No per-pool series (last resort):** fall back to total-heap + GC% only (the
   per-section method above). Some exporters emit only `area`-level heap (e.g.
   `jvm_memory_used_bytes{area="heap"}` with no pool/`id` label) — then the live
   set is unavailable; say so and lower confidence.

```promql
# (1) live set: typical, high, worst-case (per pool, fleet-aggregated)
quantile_over_time(0.50, (avg(jvm_memory_pool_collection_used_bytes{$ESEL,pool=~".*Old.*"}))[30d:10m])
quantile_over_time(0.95, (avg(jvm_memory_pool_collection_used_bytes{$ESEL,pool=~".*Old.*"}))[30d:10m])
max_over_time((max(jvm_memory_pool_collection_used_bytes{$ESEL,pool=~".*Old.*"}))[30d:10m])

# (2) fallback floor when collection_used is absent
quantile_over_time(0.05, (max(jvm_memory_pool_used_bytes{$ESEL,pool=~".*Old.*"}))[30d:10m])

# young vs OLD GC split — old-GC% is the heap-pressure signal, young-GC% is allocation rate
max_over_time((max(rate(jvm_gc_collection_seconds_sum{$ESEL,gc=~".*Old.*"}[5m])))[30d:10m])
max_over_time((max(rate(jvm_gc_collection_seconds_sum{$ESEL,gc=~".*Young.*"}[5m])))[30d:10m])
max_over_time((max(rate(jvm_gc_collection_seconds_count{$ESEL,gc=~".*Old.*"}[5m])))[30d:10m])  # old-GC frequency
```

**Verdict — live-set peak as % of Xmx × old-GC time:**

| live-set peak vs Xmx          | old-GC time peak | meaning                                       | action                                                                 |
| ----------------------------- | ---------------- | --------------------------------------------- | ---------------------------------------------------------------------- |
| ≳90% **or** old-GC peak >~5%  | high             | **starved** — no reclaimable space, GC thrash | **raise** Xmx so live-set peak lands ≤~75% of Xmx; raise limit with it |
| ≲40% **and** ~0 old GCs (30d) | ≈0               | **over-sized** — heap dwarfs the live set     | **shrink** is safe (respect the coupling rules below)                  |
| otherwise                     | low              | appropriately sized                           | keep                                                                   |

Target a heap where the **live-set peak sits at ~70–75% of Xmx** (room for the
collector to work + burst headroom). Request/limit then follow the engine's
normal rule.

**Coupling + caveats (never size heap in isolation):**

- **Elasticsearch/OpenSearch:** keep heap **≤50% of RAM** (page cache) and
  **≤~31GiB** (compressed oops); ES sets `MaxDirectMemorySize ≈ ½ heap`, so
  cutting Xmx _also_ frees that much off-heap — often the cheapest fix for a
  master node hugging its limit is to **drop Xmx**, not raise the box.
- **Kafka:** the heap is **deliberately small** (brokers lean on page cache) — a
  low live set is _expected_, not an invitation to shrink further.
- **`MaxRAMPercentage`:** when heap is a % of the limit (no explicit `-Xmx`),
  change the **limit** to move the heap, and note the coupling.
- **Censoring:** when the live-set peak ≈ Xmx, true demand is _hidden_ (the JVM
  holds the line by thrashing) — treat the raised heap as a **floor** and
  re-measure.
- **Leak check:** a live set that climbs **monotonically** regardless of load is
  a leak — more heap only delays the OOM; flag it. A live set that tracks load
  (up at peak, down at trough) is real working data.

---

## Page-Cache-Sensitive Services (Non-Engine)

Some workloads are **not** a classified DB/JVM engine yet still degrade exactly
like one when memory is tight, because they **mmap large files** and rely on the
OS page cache to keep hot pages resident: VictoriaMetrics (`vmstorage` /
`vmselect`), HashiCorp Vault, etcd, Loki / Mimir / Thanos, NATS JetStream,
SQLite-backed services, and most BoltDB-backed Go services. They have **no
configurable cache ceiling** (so there is no `engine_ceiling` to size from) and
usually **no exporter** for cache state — but they share the engines' fatal
property: shrinking the limit evicts page cache and tanks latency **without**
firing an OOMKill or memory PSI.

**Classify on the structural signal, not the symptom.** Trigger this path when
no engine matched and the workload is stateful/mmap-heavy: it mounts a data
volume **and** `container_memory_cache` is a large, stable share of memory (rule
of thumb **≳25–30%** of `container_memory_working_set_bytes` — verified live:
`vmstorage` sits at ~48%). Use `container_memory_cache`, not
`container_memory_mapped_file` — the latter is often not scraped (verified
absent on this cluster). The product names above are **illustrative only**; the
cache-share signal is the real classifier. Do **not** classify on major page
faults — those are ~0 exactly when the service is correctly sized, which is the
case this category most needs to protect from a bad trim.

**Sizing — identical to the generic method.** There is no engine ceiling, so no
special formula is needed:

```text
recommended mem limit   = working_set_max × 1.25
recommended mem request ≈ p95 working set
```

`working_set_max × 1.25` already carries page-cache headroom for free: working
set **excludes** reclaimable (inactive-file) cache, so the ×1.25 is space the
kernel will repurpose as reclaimable page cache. (Optional belt-and-suspenders
floor: `container_memory_rss` max — the non-reclaimable anon memory the box can
never go below — but since `working_set ≥ RSS` always, this rarely binds.)

**The category's one real change is the downsize guard.** PSI and OOM are silent
while the page cache thrashes, so:

- **Never trim on PSI ≈ 0 / no-OOM alone** — also require the **major-page-fault
  rate at baseline** (see `queries.md` → "Major Page Faults"). A quiet PSI with
  a loud `pgmajfault` rate means **raise**, not trim.
- **Raise** the limit when the major-fault rate is sustained above a quiet
  sibling replica's baseline, even with PSI ≈ 0 and zero OOMKills.
- **Analytical / scan-heavy stores whose on-disk data ≫ RAM** (VictoriaMetrics,
  ClickHouse cold partitions, Thanos store) can carry an _irreducible_ cold-read
  fault floor that more memory will not remove — there, the undersize signal is
  faults that **respond to headroom** (fall when the limit rises), not the
  absolute rate; treat a flat baseline as a cost/latency tradeoff. (Verified
  live: `vmstorage` here runs at ~0 faults, so its working-set/PSI reading
  stands.)
- **CPU** follows the generic `p95 × 1.15` rule. For an HA / leader-elected
  member (Vault, etcd) size off the **hottest** replica — see the active/standby
  note in `SKILL.md` step 4.

State in the report that the workload was treated as page-cache-sensitive (no
engine exporter), give the `pgmajfault` p95/peak versus a quiet sibling, and
note the limit keeps the generic `working_set × 1.25` sizing that a bare PSI/OOM
downsize guard would have mis-read.

---

## Report Additions

When an engine was classified, add to the step-7 report:

- An **Engine** line under the header:
  `**Engine:** <engine> (exporter: present/absent) · ceiling: <cache/heap/maxmemory> = <value>`.
- In **Recommended Resources**, replace the generic `mem limit = max × 1.25`
  rationale with the engine rule actually used (e.g.
  `mem limit = WiredTiger cache 8GiB / 0.5 + 1GiB = 17GiB (engine model), floored by working-set peak`).
- A **risk flag** for the engine's pressure signal (cache-hit ratio, evictions,
  GC time fraction, query-memory failures).
- For a JVM engine, a **heap line**: `live set <p95>/<peak> vs Xmx <x>` plus the
  old-GC peak %, and a heap recommendation (raise / keep / shrink Xmx) with the
  target "live-set peak ≤~75% of Xmx" — or a note that per-pool metrics were
  absent so only GC%/working-set was used.
- For a **page-cache-sensitive (non-engine)** workload: state it was treated as
  such, the `pgmajfault` p95/peak vs a quiet sibling, and that the limit keeps
  generic `working_set × 1.25` sizing (PSI/OOM alone would mis-call a trim).
- If the probe was empty, the explicit caveat from "How This Plugs In" step 3.
