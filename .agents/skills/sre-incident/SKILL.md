---
name: sre-incident
description: |
  Investigate an unknown problem or incident reported in free form (a Slack
  message, a user complaint, "X is slow / hangs / returns errors", "did my
  change break Y?"): pin down the symptom, quantify and localize it, find the
  trigger and root cause, propose and weigh fixes, verify the rollout, and on
  request write the postmortem. Triggers on "something is broken", "take a
  look at this report", "investigate this incident", "why does X happen", or a
  pasted user report. Delegates data collection to the `sre-grafana` and
  `sre-kubernetes` skills. For alert payloads or alert URLs use
  `sre-analyze-alert` instead.
---

# SRE: Incident

You are acting as an SRE investigating a problem that nobody has diagnosed yet.
The input is a vague report, not an alert: the reporter describes what they see,
often with a guess about the cause, and sometimes with queries or dashboards.
Find out **what exactly is broken, why, and what we can do about it** — backed
by data, not by the reporter's guess.

An incident investigation usually spans several rounds: a first report,
follow-up questions, a fix, a rollout check and maybe a postmortem. Keep the
context of earlier rounds (time windows, IDs, helpers, findings) and build on
it.

## Hand-Off

- **Alert payload or alert URL** → use `sre-analyze-alert`.
- **Data collection** → `sre-grafana` (metrics, logs, traces, profiles, all via
  the Grafana HTTP API) and `sre-kubernetes` (cluster state, read-only).
- **Resource tuning** → `sre-kubernetes-rightsizing`.
- **Commit / PR** → `git-commit`, `github-pr-create`.

Read the skills you delegate to before the first query.

## Phases

Work through the phases in order. Later rounds can jump back to any phase (e.g.
"does service Z have the same problem?" restarts at phase 2 for Z).

### 1. Intake — Restate the Symptom

- Restate the report as a **testable symptom**: who sees what, on which
  service/endpoint, in which environment(s)/cluster(s), since when, how often.
  Example: "Some requests to service X hang ~100 s and end with a 524 at the
  CDN, in clusters A and B."
- Separate **observation** from **interpretation**: "the app answers right away
  but the response gets lost in the mesh" is a hypothesis to test, not a fact.
- Resolve the targets: service, namespace, clusters, Grafana instances,
  kubeconfig contexts. Analyze **each cluster as a separate, labelled target**
  with the same pinned UTC window.
- Treat queries, dashboards and log searches shared by the reporter as
  **leads**. Run them, then check their semantics (wrong `offset`, filters that
  miss most cases, counts vs. ratios). Say so if they are misleading.
- Resolve the relevant repositories (application and GitOps/infrastructure)
  following the global Repository Discovery rules. Discovery is read-only.
- **Check the knowledge base** if the user's instructions reference one (e.g.
  "knowledge base: <path>"): search it read-only for the service, its components
  and the symptom (e.g. `grep -ril`) before forming hypotheses. Look for
  environment docs (request path, clusters, datasource UIDs, log fields),
  earlier incidents and known open upstream bugs, and state which entries you
  used. Treat them as leads: they may be outdated, so confirm against live data.
  Without a knowledge base, continue without it.
- Ask only when a missing input materially changes the investigation (e.g. which
  environment). Otherwise state the assumption and proceed.

### 2. Map the Path and Quantify the Impact

- **Map the request path** from the client to the failing component: CDN →
  ingress gateway → mesh proxies / waypoints → service → dependencies
  (databases, caches, queues, storage). Use live cluster state and the manifests
  in the GitOps repo (Services, routes, mesh policies, autoscalers, versions).
- **Quantify per cluster**: affected requests, total requests, rate, affected
  endpoints/methods, affected users/sessions. Prefer the component closest to
  the user for impact (e.g. the edge gateway), and say which component you
  measured at.
- **Establish a baseline**: the same metric for a quiet period (e.g. the week
  before, excluding the incident) and for comparable services. Compare rates
  over the **same window, measured the same way**.
- Pin every number to an explicit UTC window and the query that produced it.

### 3. Localize

Narrow the problem down before explaining it. Localization is the strongest
evidence you will get.

- **Hop by hop**: find where a request was last seen intact. Match individual
  failing requests across hops by a correlation ID (CDN ray ID, request ID,
  trace ID) and compare status, flags, duration and bytes at each hop. "The
  service answered in 23 ms with 200, the gateway saw nothing for 100 s" puts
  the fault between those two hops.
- **By dimension**: group failures by pod, node, source/destination pod pair,
  worker, tenant, endpoint, client, version, time bucket. Look for episodes
  (start/end times), pairs, or single components that carry the failures.
- **Use control groups**: other services on the same pod/pair/node, other
  clusters, the same service before the onset. "Only X fails on this pair while
  Y on the same pair is fine" isolates what is different about X (protocol, port
  name, payload size, timeouts).
- **Arrivals vs. completions**: decide whether the problem is _more work coming
  in_ or _less work getting done_. Request-rate metrics often only count
  completed requests (see [`references/pitfalls.md`](references/pitfalls.md)).

### 4. Find the Trigger and the Root Cause

- **Onset**: for each localized episode, find the first failing request and look
  at what happened on the same component in the seconds/minutes before (large or
  aborted transfers, bursts of new work, deploys, scale events, node events,
  config pushes). Check several episodes — one match is a coincidence, four of
  five is a pattern. Report the ones that don't match.
- **What changed**: Git history of the GitOps and application repos in the
  window, rollouts and their revisions, chart/image versions, autoscaler events,
  manual drift (`kubectl edit`, `kubectl scale`), suspended GitOps
  reconciliation, and who made a live change (audit/proxy logs) when relevant.
- **"Did my change cause it?"**: compare timing, what the change actually
  touches (e.g. a memory _request_ doesn't cap memory, the _limit_ does),
  whether pods were restarted, and whether unchanged clusters show the same
  symptom. State clearly whether it is causal, not causal, or not ruled out.
- **Bottleneck**: use saturation signals over utilization — PSI (CPU, memory,
  I/O stall), disk throughput vs. the volume's provisioned limit, iowait,
  connection pools, queues, goroutines/threads, GC. Check the pod **and** its
  node, and the impact on neighbours on the same node.
- **Traces and profiles** when metrics show the mechanism but not the trigger:
  slow spans, which step blocks, which inputs (e.g. the same images requested in
  many sizes).
- **Known upstream issues**: when the evidence points at a dependency (proxy,
  runtime, library, operator), search its issues/PRs with `gh` per the global
  rules. Check whether the fix is released and whether the **running version**
  contains it (read the deployed versions from the cluster, not just the repo).
- If evidence is inconclusive, loop back to phase 3 with a sharper query instead
  of speculating.

### 5. Live Checks (Approval Required)

Some failures only show while they happen: in-flight requests, proxy
connection/cluster stats, admin endpoints, thread dumps.

- **Ask before** any `kubectl exec`, `port-forward`, debug container or admin
  endpoint call on production, and before enabling extra logging or stats.
- Once approved, prefer read-only `GET`s (e.g. Envoy `/clusters`, `/stats`,
  `/config_dump` via `pilot-agent request GET …`). Build a small detector from
  logs/metrics to find a component that is in an episode **right now**, then
  capture snapshots at onset, mid-episode and after recovery.
- Keep large dumps out of the conversation: extract what you need into
  `/tmp/<slug>/` and delete the rest. Don't wait in a tight loop; use `sleep` to
  the expected time and say when you'll check again.

### 6. Report

Produce the investigation report (structure in
[`references/report.md`](references/report.md)): Summary, What happens, Why it
happens, What we couldn't confirm, What we can do, Confidence, Next step.

- Conclusions first, then enough evidence (numbers, windows, queries, IDs) to
  trust them. Don't narrate the investigation.
- Label inference as inference. Correct earlier claims explicitly when new data
  contradicts them ("this corrects my earlier guess that …").
- End with a concrete question about the next step (e.g. prepare fix A, run live
  check B, analyze service C).

### 7. Fix Options

For each option state what it fixes (root cause, blast radius, symptom only),
its risk, its cost and how to verify it worked.

- **Order**: immediate mitigation → reduce the blast radius → durable fix →
  upstream fix. Say which options only hide the symptom (client retries,
  restarts) and which are emergency-only.
- **Downtime analysis**: for every config change, work out how it rolls out
  (Service vs. pod template changes, named `targetPort`s, endpoint gaps, rolling
  update settings, proxy config pushes, connection draining). Prefer the variant
  that doesn't restart pods or drop endpoints, and verify the claim in the
  dependency's source for the deployed version.
- **Isolate the trigger vs. the victim**: moving the component that triggers the
  problem often protects everyone else; moving the victim protects only it.
- **Replay before you ship**: simulate new autoscaler triggers, alert rules or
  thresholds against the incident window **and** 30 days of normal operation,
  and report how often they would fire or scale.
- **Detection**: propose a metric that measures the symptom itself (e.g. long
  hangs / all requests) rather than a proxy for it, and note its pitfalls.
  Prefer SLO burn-rate alerting if the organization uses it.

### 8. Implement (On Request)

When the user asks for a change, implement it — this skill does not restrict
edits, it just doesn't repeat how to make them:

- Work in the repository the user named or that discovery identified, following
  its `AGENTS.md`, the global worktree/git rules and its validation tooling
  (lint, render templates and diff the rendered output, schema/policy checks).
- Commit and open PRs only when asked, via `git-commit` and `github-pr-create`.
- Report what the change does to running workloads (pod restarts, endpoint
  changes) and what to verify after rollout.

### 9. Verify the Rollout

- Check every affected cluster: GitOps reconciliation status and revision,
  rendered/live objects contain the change, workloads healthy (ready replicas,
  restarts, warning events), autoscalers healthy.
- Detect suspended reconciliation and live drift, and explain what resuming will
  reset. Never resume/suspend or edit live objects yourself: print the plain
  commands for the user to run (one block per action, no loops or variables,
  unless asked otherwise).
- Compare the symptom metric before and after (same weekday/hours) to confirm
  the fix worked.

### 10. Postmortem (Only When Asked)

Write the postmortem **only when the user explicitly asks for it after the
incident is resolved**. Use the template in
[`references/report.md`](references/report.md). On request also provide the list
of queries that showed the problem — all signal types plus the evidence IDs — in
the format described there.

### 11. Knowledge Base Update (Suggest, Then Ask)

When the incident is resolved or the user wraps up, and a knowledge base is
referenced, suggest what to record there and **ask before writing**:

- An incident write-up (symptom, root cause, trigger, fix, evidence IDs, open
  follow-ups).
- Durable lessons for the evergreen docs: topology facts, metric pitfalls,
  upstream bugs with fixed versions, detection queries.

Follow the knowledge base's own `AGENTS.md` conventions (structure, tags,
formatting, linting). Company-specific details belong there, never in this
skill.

## Working Practices

- **Pinned windows**: use explicit UTC timestamps, not `now-…`, for anything you
  report, so numbers are reproducible. Use day buckets aligned to UTC midnight
  or state the alignment.
- **Helpers**: put helper scripts and intermediate results under
  `/tmp/<incident-slug>/`. They must fetch the token at runtime and never write
  it to disk or output. `/tmp` may be cleaned between rounds — check and
  recreate.
- **Evidence log**: append every query or lookup that showed or ruled out
  something to `/tmp/<incident-slug>/evidence.md` as you go: type (PromQL,
  LogsQL, trace, profile, CDN, kubectl, admin endpoint, Git), cluster,
  datasource, window, the exact query and a one-line finding. Record the IDs
  behind key claims (trace IDs, request/ray IDs, pod pairs, commits, upstream
  issues). Answer "which trace / query showed X?" and build the query list from
  this log, not from memory.
- **macOS tooling**: assume BSD `awk`/`sed`/`date`; use `jq` or Python for
  non-trivial parsing.
- **Big results**: aggregate in the query (`stats by`, `sum by`, `topk`) instead
  of pulling raw lines; sample raw lines only to read field names or examples.
- **Delegation**: long, self-contained analyses (e.g. "check service Z for the
  same pattern over last week") can go to a `worker` subagent per the global
  delegation rules.
- Consult [`references/pitfalls.md`](references/pitfalls.md) whenever a metric
  looks surprising.

## Hard Rules

- **Never** invent metric values, log lines, pod names, IDs or timestamps. An
  empty result is a finding — say so.
- **Never** run mutating or intrusive actions (exec, port-forward, restarts,
  scaling, edits, resume/suspend, config changes) without explicit approval.
  Analysis requests are read-only.
- **Never** log, echo or write bearer tokens or secret values.
- **Always** give the cluster, time window and exact query/command for each
  piece of evidence.
- **Always** surface contradictions between signals instead of picking one.
- **Always** separate verified facts from inference in reports.
