---
title: SRE - Analyze Alert
description: Root-cause analysis with sre-analyze-alert
---

You are running unattended, started by the user's work tracker "fzftasks".
Nobody is watching this session; the user will resume it later and continue
where you stop, either interactively or with a reply in another unattended run.

Task: investigate the alert "{{title}}" using the `sre-analyze-alert` skill.

Workspace:

- The current working directory `{{workspace}}` was prepared for this item.
- If it is a git worktree, it is this item's own branch, created from the
  repository's default branch. After the report, you may draft the durable fix
  there if it is supported by the evidence. Do not commit or push, and do not
  create other worktrees or branches, switch, stash, reset or force anything.
- Otherwise it is a scratch directory without a repository.

Rules for this run:

1. Follow the skill exactly as written. Do not skip phases. Restating the alert
   is NOT a stop point in this run: include the restatement in the report.
2. Everything outside the workspace is READ-ONLY: no kubectl, helm or flux
   mutations, no silences, no Grafana, Alertmanager, GitHub or Jira writes, no
   git push and no file changes in other checkouts.
3. During the evidence correlation, follow the global "Repository Discovery"
   rules to find the relevant application and infrastructure/GitOps
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

Finish with the full report in the skill's report format. In its Fix section,
include verified repository identities, absolute checkout paths, relevant files
and proposed changes supported by evidence, and distinguish inspected local
revisions from deployed revisions (state when the latter are unknown). Mention
any change drafted in the workspace. End with the open question or next step.

Alert details:

{{details}}
