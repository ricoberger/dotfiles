---
name: sre-kubernetes
description: |
  Inspect a Kubernetes cluster — reachable via an API server URL and bearer
  token, a context name from `~/.kube/config`, or a Grafana datasource proxy —
  for failing pods, warning events, recent rollouts, resource pressure, and
  other state relevant to an SRE alert or question. Triggers when the user
  asks about pod / deployment / node health, references a cluster URL +
  token, names a kubeconfig context, points at a Grafana instance with a
  Kubernetes datasource, or when `sre-analyze-alert` needs cluster-side
  evidence. Read-only by default; destructive actions require explicit
  confirmation.
---

# SRE: Kubernetes

Investigate the state of a Kubernetes cluster via the API server. The goal is to
surface what is broken, what changed, and what looks unhealthy — never to mutate
cluster state without explicit user approval.

## Inputs

The skill accepts **one of three** input modes. Ask the user which they want to
use if it is not clear, and require the corresponding fields before issuing API
calls:

### Mode A — API Server URL + Bearer Token

| Input          | Example                                        |
| -------------- | ---------------------------------------------- |
| API server URL | `https://kubernetes.example.com`               |
| Bearer token   | `eyJhbGciOi…` (raw token, no `Bearer ` prefix) |

### Mode B — Kubeconfig Context

| Input        | Example                                     |
| ------------ | ------------------------------------------- |
| Context name | `kube-de1` (must exist in `~/.kube/config`) |

Verify the context exists before issuing API calls:

```bash
kubectl config get-contexts -o name | grep -Fx "$CONTEXT"
```

If the lookup returns nothing, ask the user to correct the context name or
switch to Mode A — do not silently fall back to the current context.

### Mode C — Grafana Datasource Proxy

Use this mode when the user has provided a Grafana instance (URL + bearer token)
that exposes a Kubernetes datasource, and you have no direct `kube-apiserver`
reachability or kubeconfig context. The Grafana plugin proxies arbitrary
API-server requests through Grafana's auth:

| Input            | Example                                                        |
| ---------------- | -------------------------------------------------------------- |
| Grafana base URL | `https://grafana.example.com`                                  |
| Grafana token    | Bearer token for Grafana (not the cluster's serviceaccount)    |
| Datasource UID   | UID of a `ricoberger-kubernetes-datasource`, e.g. `kubernetes` |

The proxy endpoint is
`<GRAFANA>/api/datasources/proxy/uid/<DSUID>/proxy/<KUBE-API-PATH>`, and the
caller is whichever serviceaccount the datasource is configured with — so the
available verbs are whatever that SA was granted (typically read-only).

Resolve the datasource UID via the `sre-grafana` skill (Step 0) if not supplied;
the Kubernetes datasource has `type: ricoberger-kubernetes-datasource`.
`sre-analyze-alert` invocations always pass the alert's `Grafana URL` /
`Grafana Credentials` plus the well-known UID `kubernetes` — use those verbatim.

## Choosing the Access Method

Pick the path that matches the input mode the user provided:

1. **`kubectl` with an inline server + token** (Mode A). No kubeconfig changes
   needed:

   ```bash
   kubectl --server="$API" --token="$TOKEN" \
     -n "$NS" get pods
   ```

2. **`kubectl` with a kubeconfig context** (Mode B). Always pass `--context`
   explicitly — never rely on the current context:

   ```bash
   kubectl --context="$CONTEXT" \
     -n "$NS" get pods
   ```

3. **Raw `curl` against the API server** (fallback for Mode A when `kubectl` is
   not installed):

   ```bash
   curl -sS -H "Authorization: Bearer $TOKEN" \
     "$API/api/v1/namespaces/$NS/pods" | jq '.items[] | {name: .metadata.name, phase: .status.phase}'
   ```

4. **Raw `curl` through the Grafana proxy** (Mode C). The path component after
   `proxy/` is the **literal Kubernetes API path** — same paths you would hit
   directly, just prefixed with the proxy URL:

   ```bash
   curl -sS -H "Authorization: Bearer $GRAFANA_TOKEN" \
     "$GRAFANA/api/datasources/proxy/uid/$DSUID/proxy/api/v1/namespaces/$NS/pods" \
     | jq '.items[] | {name: .metadata.name, phase: .status.phase}'
   ```

   `kubectl` is **not usable in Mode C** — the proxy expects raw API paths, not
   kubectl URL shapes. Translate the kubectl commands in the triage checklist
   below to their equivalent REST paths:

   | kubectl shorthand        | REST path                                                         |
   | ------------------------ | ----------------------------------------------------------------- |
   | `get pods -n $NS`        | `/api/v1/namespaces/$NS/pods`                                     |
   | `get pod $POD -n $NS`    | `/api/v1/namespaces/$NS/pods/$POD`                                |
   | `get events -n $NS`      | `/api/v1/namespaces/$NS/events?fieldSelector=type=Warning`        |
   | `get deploy $D -n $NS`   | `/apis/apps/v1/namespaces/$NS/deployments/$D`                     |
   | `get sts $S -n $NS`      | `/apis/apps/v1/namespaces/$NS/statefulsets/$S`                    |
   | `logs $POD -c $C -n $NS` | `/api/v1/namespaces/$NS/pods/$POD/log?container=$C&tailLines=200` |
   | `get <crd> -n $NS`       | `/apis/<group>/<version>/namespaces/$NS/<plural>`                 |

   `kubectl top` and `kubectl describe` have no proxy equivalent — for resource
   pressure in Mode C, prefer the `sre-grafana` skill
   (`container_memory_working_set_bytes`, `container_cpu_usage_seconds_total`);
   for "describe" output, fetch the resource JSON and inspect
   `.status.conditions`, `.status.containerStatuses[]`, and an `events` query
   filtered by `involvedObject.name=$POD`.

All paths require **read-only** verbs (`get`, `list`, `describe`, `logs`, `top`)
unless the user explicitly approves a write.

> The command examples in the rest of this skill use the Mode A form
> (`--server` + `--token`). When operating in Mode B, replace those flags with
> `--context="$CONTEXT"`. When operating in Mode C, translate to the REST path
> through the Grafana proxy as shown above.

## Standard Triage Checklist

Run these in order. Stop when you have enough to answer the question — there is
no need to gather everything every time.

### 1. Pods That Are Not Happy

```bash
kubectl --server="$API" --token="$TOKEN" -n "$NS" get pods \
  --field-selector=status.phase!=Running \
  -o wide
```

Then for the most suspicious pod:

```bash
kubectl --server="$API" --token="$TOKEN" -n "$NS" describe pod "$POD"
```

What to extract: `Status`, `Reason`, container `State` / `Last State` / `Reason`
/ `ExitCode`, `Events` block at the bottom.

### 2. Pods That _are_ Running but Unhealthy

```bash
kubectl --server="$API" --token="$TOKEN" -n "$NS" get pods \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.containerStatuses[*].restartCount}{"\n"}{end}' \
  | sort -k2 -n -r | head
```

High restart counts within the alert window almost always mean a
CrashLoopBackOff or a failing liveness probe.

### 3. Recent Events

```bash
kubectl --server="$API" --token="$TOKEN" -n "$NS" get events \
  --sort-by=.lastTimestamp \
  --field-selector type=Warning | tail -50
```

Look for `FailedScheduling`, `BackOff`, `OOMKilled`, `Unhealthy`, `FailedMount`,
`NodeNotReady`, image pull errors.

### 4. Recent Rollouts / Config Changes

A surprising number of alerts trace back to a deploy that landed minutes
earlier:

```bash
kubectl --server="$API" --token="$TOKEN" -n "$NS" get deploy,statefulset,daemonset \
  -o jsonpath='{range .items[*]}{.kind}{"/"}{.metadata.name}{"\t"}{.metadata.generation}{"\t"}{.status.observedGeneration}{"\n"}{end}'

kubectl --server="$API" --token="$TOKEN" -n "$NS" rollout history deploy/$DEPLOY
```

Cross-reference the rollout time with the alert `Started` timestamp.

### 5. Logs From the Offending Container

```bash
kubectl --server="$API" --token="$TOKEN" -n "$NS" logs "$POD" \
  -c "$CONTAINER" --tail=200
```

If the container has restarted, fetch the previous log too:

```bash
kubectl --server="$API" --token="$TOKEN" -n "$NS" logs "$POD" \
  -c "$CONTAINER" --previous --tail=200
```

For larger log volumes, prefer the `sre-grafana` skill — direct `kubectl logs`
is bounded to a single container instance.

### 6. Resource Pressure

```bash
kubectl --server="$API" --token="$TOKEN" -n "$NS" top pod
kubectl --server="$API" --token="$TOKEN" top node
```

If `metrics-server` is unavailable these will fail — note that and fall back to
`cAdvisor`-derived metrics via Grafana (`container_memory_working_set_bytes`,
`container_cpu_usage_seconds_total`).

### 7. Workload-Specific Checks

Pick the ones relevant to the alert:

- **CrashLoopBackOff**: previous-container logs (step 5) + describe for the exit
  reason.
- **Pending pods**: `kubectl describe pod` to see scheduler messages
  (insufficient cpu/memory, taints, PVC pending).
- **Image pull errors**: check `imagePullSecrets` and registry reachability.
- **StatefulSet / PVC issues**: `kubectl get pvc,pv -n $NS` and check the
  `Bound`/`Pending` state.
- **Networking**: `kubectl get endpoints` for the service — a "no endpoints"
  state usually means readiness probes are failing.

## Reporting

Hand back a compact summary, not raw command output. Include:

1. **Unhealthy objects** (pod name → phase / reason / restart count).
2. **Top warning events** in the namespace (deduplicated, with first/last
   timestamps).
3. **Recent rollouts** that overlap the alert window, with the new image tag or
   revision.
4. **Resource pressure** observations.
5. The exact commands used, so the user can re-run them.

Always include timestamps in the report — "5 pods restarted" without a window is
useless.

## Hard Rules

- **No write verbs without explicit confirmation.** That includes `apply`,
  `delete`, `patch`, `edit`, `scale`, `rollout undo`, `cordon`, `drain`, `exec`,
  and `port-forward`. Always ask before running them, and show the user the
  exact command first.
- **Never** leak the bearer token (no echoing, no writing to disk, no including
  it in URLs you pass back).
- **Do not** `kubectl exec` into a pod just to poke around — prefer logs and
  events. If exec is genuinely required, name the exact command and ask.
- **Do not** assume the cluster identity from a hostname. If two labels point at
  different clusters (`cluster=de1` vs the user's URL says `de2`), surface the
  mismatch.
- If a command returns no rows, say so explicitly. Empty results are evidence,
  not failure.

## Hand-Off

When invoked by `sre-analyze-alert`, return only the distilled cluster findings
(unhealthy pods, warning events, recent rollouts, resource pressure) plus the
exact commands used. Leave root-cause synthesis to the caller.
