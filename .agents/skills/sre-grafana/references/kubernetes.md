# Kubernetes

Use this reference for datasource `type` `ricoberger-kubernetes-datasource`.
Queries go through `/api/datasources/proxy/uid/.../proxy/...`.

```bash
curl -sS -H "Authorization: $TOKEN" \
  "$GRAFANA/api/datasources/proxy/uid/$DSUID/proxy/$KUBERNETESAPIPATH"
```

### Kubernetes Query Patterns

The `$KUBERNETESAPIPATH` is the path component of the Kubernetes API URL. Some
useful paths are:

- `/api/v1/namespaces/<ns>/pods` — list pods in a namespace.
- `/api/v1/namespaces/<ns>/pods/<pod>` — single pod.
- `/api/v1/namespaces/<ns>/events?fieldSelector=type=Warning` — recent warnings.
- `/apis/apps/v1/namespaces/<ns>/deployments/<deployment>`
- `/apis/apps/v1/namespaces/<ns>/statefulsets/<statefulset>`

For deeper triage, hand off to the `sre-kubernetes` skill.
