---
title: AI Team
description: Implement the task with the ai-team skill
---

You are running unattended, started by the user's work tracker "fzftasks".
Nobody is watching this session; the user will resume it later and continue
where you stop, either interactively or with a reply in another unattended run.

Task: implement {{key}} ("{{title}}") with the `ai-team` skill. Follow the
skill; the rules below only adjust it for unattended runs.

Workspace:

- The current working directory `{{workspace}}` was prepared for this item. It
  must be a git worktree on this item's own branch, created from the
  repository's default branch. If it is not a git worktree (a scratch directory
  without a repository), stop: report that the `ai-team` skill needs a
  repository and that the item must be created with one.
- Phase 0: the current branch was pre-created for this task. Adopt it as the
  feature branch (the skill's option (a)), derive the task slug from the branch
  name and use the repository's default branch as base. Do not ask about the
  branch.
- The developer agent may commit on this branch and run builds and tests in the
  worktree. Do not install dependencies globally, and do not create other
  worktrees or branches, switch, stash, reset, rebase or force anything.

Rules for this run:

1. Do not write to external systems: no git push, no GitHub, Jira, Grafana,
   Alertmanager or Kubernetes changes. The only exception is the delivery gate
   (rule 4).
2. If {{key}} starts with `jira:`, refresh the work item first with
   `acli jira workitem view <KEY> --fields '*all' --json` (read-only), including
   comments, sub-tasks, parent and linked work items, and pass it to the product
   owner. If it is done or no longer assigned to the user, report that and stop.
3. Stop at every point where the skill needs the user, present everything
   prepared so far and state the exact question. Do not answer it yourself and
   do not continue past it. These are:
   - open questions of the product owner: collect ALL of them and ask them
     together in one stop (each with the recommended answer), instead of one at
     a time,
   - the spec gate (Phase 1), with the summary of `SPEC.md` and its path,
   - `BLOCKED:` questions of the developer,
   - unresolved findings after the maximum number of review rounds,
   - the delivery gate (Phase 4),
   - anything else the skill or the global rules require a confirmation for.
4. Delivery gate: push the branch and create the draft pull request only after
   the user explicitly chose "Create a PR" in a reply to the gate presented for
   the current head SHA. Never push, post or delete anything otherwise.
5. If the `subagent` tool or one of the team's agents is not available, stop and
   report it; never take over a role yourself.

Finish with the current phase, the path of `STATE.md`, the artifacts written
(spec, implementation notes, review files), the commits on the branch, and the
open question or next step.

Task details:

{{details}}
