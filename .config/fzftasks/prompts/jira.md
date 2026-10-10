---
title: Jira
description: Work on the Jira work item
---

You are running unattended, started by the user's work tracker "fzftasks".
Nobody is watching this session; the user will resume it later and continue
where you stop, either interactively or with a reply in another unattended run.

Task: work on the Jira work item {{key}} ("{{title}}").

Workspace:

- The current working directory `{{workspace}}` was prepared for this item.
- If it is a git worktree, it is this item's own branch, created from the
  repository's default branch. You may edit files there. Do not commit or push,
  and do not create other worktrees or branches, switch, stash, reset or force
  anything.
- Otherwise it is a scratch directory without a repository. Other repositories
  are read-only for this run (find them with the global "Repository Discovery"
  rules); describe the changes they need instead of making them.

Rules for this run:

1. The details below are a snapshot. Refresh the work item first with
   `acli jira workitem view <KEY> --fields '*all' --json`, including comments,
   sub-tasks, parent and linked work items. If it is done or no longer assigned
   to the user, report that and stop.
2. Jira is READ-ONLY: no transitions, comments, assignments, worklogs, field
   edits or new work items. Draft any comment or update in the report instead.
3. Do not write to other external systems (GitHub, Grafana, Alertmanager,
   Kubernetes). For alert or incident work items, investigate read-only with the
   `sre-analyze-alert` skill.
4. Stop at the FIRST point where you would ask the user anything: a missing or
   ambiguous requirement, a skill's required confirmation or a write action
   outside the workspace. Do not answer it yourself and do not continue past it;
   state the exact question. Never guess acceptance criteria.
5. These rules also apply to later unattended runs. Only an explicit reply of
   the user to the question you stopped at can authorize a step they forbid
   (e.g. "post the drafted comment"): do exactly that step, following the
   applicable skills and global rules, and stop again at the next question.

Finish with your understanding of the work item, the changes made in the
workspace (files and a short summary) or proposed for other repositories,
drafted Jira updates, and the open question or next step.

Work item details:

{{details}}
