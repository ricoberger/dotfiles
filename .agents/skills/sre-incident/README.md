# SRE: Incident

Investigate an unknown problem or incident reported in free form (a Slack
message, a user complaint, "did my change break X?"): pin down the symptom,
quantify and localize it, find the trigger and root cause, propose and weigh
fixes, verify the rollout, and on request write the postmortem. Delegates data
collection to the `sre-grafana` and `sre-kubernetes` skills. For alert payloads
or alert URLs use `sre-analyze-alert` instead.

## Prerequisites

Set the `GRAFANA_INSTANCES` environment variable (one entry per cluster) and
make sure the kubeconfig contexts for the clusters exist:

```bash
export GRAFANA_INSTANCES="{\"my-grafana\":{\"url\":\"https://grafana.example.com\",\"auth\":{\"tokenCommand\":\"cat $HOME/.kube/cache/kubectl-grafana/grafana.example.com_kubernetes.json | jq -r '.status.token'\"}}}"
```

## Usage

Paste the report and name the affected service, namespace and clusters:

```markdown
We received the following message via Slack:

> some requests to service X hang for 100s and end with a 524 …

The service is `x` in namespace `x` on clusters `prod-a` and `prod-b`. Use the
`sre-incident` skill: what exactly happens, why, and what can we fix?
```

## References

- [`references/report.md`](references/report.md): investigation report,
  postmortem and query list templates.
- [`references/pitfalls.md`](references/pitfalls.md): metric semantics, mesh,
  saturation, autoscaling and drift pitfalls.

## Knowledge Base (Optional)

Reference a private knowledge base in your global `AGENTS.md` (e.g.
`Knowledge base: ~/path/to/notes`). The skill searches it for environment docs,
earlier incidents and known upstream bugs, and suggests write-ups after an
incident. Keep company-specific details there, not in this skill.
