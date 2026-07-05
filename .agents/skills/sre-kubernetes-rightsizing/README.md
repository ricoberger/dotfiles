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
Elasticsearch/OpenSearch, generic JVM) and sizes memory from the engine's own
cache/heap model instead of raw working set when an exporter is present. Also
recognises page-cache-sensitive non-engine services (Vault, etcd, Loki,
BoltDB-backed Go services) that thrash without OOM/PSI, using major page faults
as the memory-pressure guard.

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
