---
title: GitHub - PR Review Reviews
description: Prepare fixes for review feedback with github-pr-review-reviews
---

You are running unattended, started by the user's work tracker "fzftasks".
Nobody is watching this session; the user will resume it later and continue
where you stop, either interactively or with a reply in another unattended run.

Task: prepare the review feedback on the pull request {{key}} ("{{title}}")
using the `github-pr-review-reviews` skill.

Workspace:

- The pull request branch is checked out in `{{workspace}}`, the current working
  directory, prepared for this item. Do not create other worktrees or branches,
  switch, stash, reset or force anything. The only allowed update of the
  checkout is the one in rule 3.

Rules for this run:

1. Follow the skill in order. Stop at its FIRST question (e.g. a merged or
   closed pull request, branch problems, the overview question) and present
   everything prepared so far, including the classified overview and the
   proposed diffs. Do not answer it yourself and do not continue past it; state
   the exact question.
2. Do not apply changes: the skill requires the user's confirmation per item.
   Never commit, push, reply to or resolve threads or change anything on GitHub.
3. The details below are a snapshot. Refresh the pull request state, head refs
   and `headRefOid` first. Verify that `HEAD` of the workspace equals
   `headRefOid` and that there are no uncommitted changes or unpushed commits.
   If it differs (new commits or a force-push), update it yourself, but only
   when the current branch is `headRefName`, `git status --porcelain` is empty
   and `HEAD` exists on GitHub
   (`gh api repos/<owner>/<repo>/commits/<HEAD sha> --silent` succeeds, so there
   are no unpushed commits). Run
   `gh pr checkout <number> --branch <headRefName>` (fast-forward); only if that
   fails, add `--force` (hard reset to the PR head). Verify `HEAD` again and
   report the old and new SHA and whether it was a force-push. In every other
   case (local changes, unpushed commits, a failed update) report the state and
   stop; never reset, rebase or force otherwise.
4. If there is no unresolved, non-outdated feedback, say so, list the outdated
   items set aside, and stop. (A self-review is a separate "Review PR" run.)
5. Do not run build, test or install scripts from the pull request; a worktree
   is not isolation. Read CI results without triggering reruns.
6. Never guess missing inputs or the reviewer's intent; mark unclear items as
   "needs discussion".
7. These rules also apply to later unattended runs. Only an explicit reply of
   the user to the question you stopped at can authorize a step they forbid
   (e.g. "apply items 1 and 3", "commit and update the PR"): do exactly that
   step, following the skill and the global rules, and stop again at the next
   question.

Finish with the skill's overview, the proposed diffs, the pull request URL, the
head SHA, the workspace path, and the open question or next step.

Pull request details:

{{details}}
