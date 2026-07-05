# SRE: Analyze Alert

Analyze an SRE alert (typically from Grafana Alertmanager) end-to-end: explain
why it is firing, correlate evidence from metrics, logs, traces, profiles and
the Kubernetes cluster, identify the most likely root cause, and propose a
concrete fix. Triggers when the user pastes an alert payload, an alert URL, or
asks to "investigate", "analyze", "debug", or "find the root cause" of an alert.
Delegates data collection to the `sre-grafana` and `sre-kubernetes` skills.

## Prerequisites

### Option 1: Alert Payload

Paste the entire alert payload as markdown from the
[Alertmanager](https://github.com/ricoberger/Alertmanager) macOS App to the
skill.

### Option 2: Alert URL

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
