# SRE: Kubernetes Right-Sizing

Analyze the resource usage of a Kubernetes Deployment, StatefulSet, or DaemonSet
over the last 30 days and recommend right-sized CPU/memory requests and limits
plus autoscaling (KEDA/HPA) improvements. Triggers when the user asks to
"right-size", "analyze resource usage", "tune requests/limits", "is this
workload over/under-provisioned", or "improve autoscaling" for a named workload.
Reads live cluster spec and 30-day metrics through a single Grafana instance
(delegating to the sre-grafana and sre-kubernetes skills), treats the live
cluster as authoritative and an optional manifest as the verification + apply
target, and never edits cluster resources directly. Detects common database and
JVM engines (MongoDB, PostgreSQL, Redis, Kafka, ClickHouse,
Elasticsearch/OpenSearch, generic JVM) and sizes memory from the engine
cache/heap model instead of raw working set. Also recognises
page-cache-sensitive services (Vault, etcd, Loki) that thrash without OOM/PSI,
using major page faults as the memory guard.

## Shared Git and PR History

The skill uses path-scoped Git history and PR descriptions, discussions and
reviews to find previous changes and decisions, including overlapping open PRs,
rollbacks and changes to shared configuration. It does not depend on a particular
developer's local files. Missing labels, incomplete checkout history or GitHub
access failures are reported as limitations, not proof that nothing changed.
Without a known repository, fresh live analysis can still proceed.

There is **no mandatory local run/state file, database or tracking issue**.
Unpublished discussions, rejections and no-change outcomes remain personal
conversation context and may be suggested again later. Published rejections
are surfaced with their reasons, not treated as permanent prohibitions. Recent
changes are advisory; there is no hard cooldown.

When you approve publication, commits explain the change and the PR description
or an approved comment carries a concise shared summary: exact workload/cluster
identities, before/after configuration, rationale, relevant decisions, named
baseline metrics, reproducible queries with fixed UTC bounds, and verification
criteria. Repository PR templates are preserved. Full raw metrics dumps and
session-relative scripts are not required shared artifacts.

Ask to "verify the rightsizing from <PR URL or commit>" after at least seven
comparable post-rollout days. The skill reads shared evidence, establishes actual
rollout/configuration and compares against the baseline. Missing or expired
historical evidence can make the result inconclusive; no personal file is
required. Verification results stay in chat unless you approve posting a dated
PR comment. Commit/merge dates and labels are not deployment evidence.

The [history reference](references/history.md) describes discovery, shared
evidence and publication. Restart comparisons still use equal windows or
normalized rates/exposure; OOM timestamps are matched to their reasons. CPU
requests are not caps, and missed memory headroom targets alone do not prove
pressure.

## Local Changes and Publication

Configuration edits always require your approval of the complete patch shown
**before any target file is changed**, not a diff generated after writing.
Approvals stay in the conversation, not a file-based ledger. Evidence, controller,
source-isolation and validation requirements still apply. **Pushes, PR
creation/updates and comments require publication approval** of the relevant
diff/scope and shared content. The skill never mutates live cluster resources.

Use independent sessions for separate efforts; there is no batch scheduler or
automatic parallel orchestration.

## Updating an Earlier Installation

Run `install.sh` and start a fresh session to pick up these instructions. The
installer retires the former batch/worker/interactive-agent entry points and
SQLite helper files, but does not delete external history or worktrees. Existing
Markdown/SQLite records are left untouched and are not automatically read,
migrated or published. An explicitly provided old report may supplement the
shared evidence; it is never required.

## Prerequisites

Set the `GRAFANA_INSTANCES` environment variable:

```bash
export GRAFANA_INSTANCES="{\"my-grafana\":{\"url\":\"https://grafana.example.com\",\"auth\":{\"tokenCommand\":\"cat $HOME/.kube/cache/kubectl-grafana/grafana.example.com_kubernetes.json | jq -r '.status.token'\"}}}"
```

```json
{
  "my-grafana": {
    "url": "https://grafana.example.com",
    "auth": {
      "tokenCommand": "cat $HOME/.kube/cache/kubectl-grafana/grafana.example.com_kubernetes.json | jq -r '.status.token'"
    }
  }
}
```
