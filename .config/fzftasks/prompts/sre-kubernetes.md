---
title: SRE - Kubernetes
description: Investigate a Kubernetes resource with sre-kubernetes
---

You are running unattended, started by the user's work tracker "fzftasks".
Nobody is watching this session; the user will resume it later and continue
where you stop, either interactively or with a reply in another unattended run.

Task: investigate the Kubernetes resource "{{title}}" using the `sre-kubernetes`
skill.

- If the details below contain "Listed by: `fzfk --issues`", the resource was
  reported as unhealthy: find the root cause and propose a fix.
- Otherwise assess the resource's health and configuration, report notable
  findings (failing or degraded state, warning events, risky or missing
  settings) and ask what to look into next.

Cluster access:

- Use the skill's kubeconfig context mode with the context from the details. It
  is already provided, do not ask for it.
- Pass exactly the "kubectl flags" from the details to every kubectl command.
  Never rely on or change the current context (`kubectl config use-context`,
  `set-context`, ...); the user may have switched it since this item was
  created.
- The details are a snapshot taken when the item was created. Re-check the
  current state before drawing conclusions; the resource may have changed or
  been replaced (e.g. a pod after a rollout).

Workspace:

- The current working directory `{{workspace}}` was prepared for this item.
- If it is a git worktree, it is this item's own branch, created from the
  repository's default branch. After the report, you may draft the durable fix
  there if it is supported by the evidence. Do not commit or push, and do not
  create other worktrees or branches, switch, stash, reset or force anything.
- Otherwise it is a scratch directory without a repository.

Rules for this run:

1. Follow the skill exactly as written. Do not skip phases.
2. Everything outside the workspace is READ-ONLY: no kubectl, helm or flux
   mutations (apply, edit, patch, scale, rollout restart, delete, cordon, drain,
   exec into containers, ...), no silences, no Grafana, Alertmanager, GitHub or
   Jira writes, no git push and no file changes in other checkouts.
3. To find where the resource is defined, follow the global "Repository
   Discovery" rules to find the relevant application and infrastructure/GitOps
   repositories, and inspect matching code, manifests and local Git history for
   the affected environment. Discovery is read-only: no edits, fetches, clones,
   branches or worktrees. If a mapping stays unresolved, report the candidates,
   evidence and the exact missing information; do not invent repository-specific
   fixes.
4. Stop at the FIRST point where you would ask the user anything (e.g. before a
   destructive or write action, or about missing input). Do not answer it
   yourself and do not continue past it; state the exact question. Never guess
   missing inputs.
5. These rules also apply to later unattended runs. Only an explicit reply of
   the user to the question you stopped at can authorize a step they forbid
   (e.g. "open a PR with the fix"): do exactly that step, following the skill
   and the global rules, and stop again at the next question.

Finish with a report: a summary, the evidence (commands and relevant output),
the root cause or findings, and the proposed fix. In the fix, include verified
repository identities, absolute checkout paths, relevant files and proposed
changes supported by evidence, and distinguish inspected local revisions from
deployed revisions (state when the latter are unknown). Mention any change
drafted in the workspace. End with the open question or next step.

Resource details:

{{details}}
