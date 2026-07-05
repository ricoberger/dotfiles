# SRE: Grafana

Query a Grafana instance for metrics, logs, traces, and profiles to investigate
an alert or answer related questions. Triggers when the user asks to "check
Grafana" or "query metrics/logs/traces/profiles", references a Prometheus,
VictoriaMetrics, VictoriaLogs, VictoriaTraces, Tempo, or Pyroscope datasource
exposed through Grafana, or when the `sre-analyze-alert` skill needs supporting
evidence. Selects the appropriate datasource, runs the query against Grafana's
HTTP API, and summarizes the result.

## Prerequisites

### Option 1: Grafana URL and API Token

Paste the Grafana url and API token to the skill:

```markdown
- Grafana URL: https://grafana.example.com
- Grafana Credentials: Bearer glsa\_…
```

### Option 2: `GRAFANA_INSTANCES` Environment Variable

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

Paste the source url of the alert in the format
`<grafana-url>/alerting/grafana/<alert-id>/view` to the skill.
