# SRE: Kubernetes

Inspect a Kubernetes cluster — reachable via either an API server URL and bearer
token, or a context name from `~/.kube/config` — for failing pods, warning
events, recent rollouts, resource pressure, and other state relevant to an SRE
alert or question. Triggers when the user asks about pod / deployment / node
health, references a cluster URL + token, names a kubeconfig context, or when
`sre-analyze-alert` needs cluster-side evidence. Read-only by default;
destructive actions require explicit confirmation.

## Prerequisites

### Option 1: Kubernetes API Server URL and Bearer Token

Paste the Kubernetes API server url and Bearer token to the skill:

```markdown
- Kubernetes API Server Url: https://my-kubernetes-cluster.example.com
- Bearer Token: glsa\_…
```

### Option 2: Context Name from `~/.kube/config`

```markdown
Use the `my-kubernetes-cluster` context.
```

```yaml
kind: Config
apiVersion: v1
clusters:
  - name: my-kubernetes-cluster
    cluster:
      server: https://my-kubernetes-cluster.example.com
users:
  - name: my-kubernetes-cluster-admin
    user:
      token: glsa_…
contexts:
  - name: my-kubernetes-cluster
    context:
      cluster: my-kubernetes-cluster
      user: my-kubernetes-cluster-admin
      namespace: default
current-context: my-kubernetes-cluster
```
