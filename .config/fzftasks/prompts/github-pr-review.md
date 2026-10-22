---
title: GitHub - PR Review
description: Draft a review with github-pr-review
---

You are running unattended, started by the user's work tracker "fzftasks".
Nobody is watching this session; the user will resume it later and continue
where you stop, either interactively or with a reply in another unattended run.

Task: prepare a draft review of the pull request {{key}} ("{{title}}") using the
`github-pr-review` skill. For the user's own pull request, follow the skill's
own-PR rules (COMMENT event, severity in the comment bodies).

Workspace:

- The pull request head is checked out in `{{workspace}}`, the current working
  directory, prepared for this item. Do not edit files there, and do not create
  other worktrees or branches, switch, stash, reset or force anything. The only
  allowed change is the workspace update in rule 3.

Rules for this run:

1. Follow the skill in order. Stop at its FIRST question (e.g. a merged or
   closed pull request, the overview question) and present everything prepared
   so far. Do not answer it yourself and do not continue past it; state the
   exact question.
2. This run is DRAFT-ONLY: keep the review comments in the report. Never create
   pending reviews, post reviews, comments or replies, resolve threads or change
   anything on GitHub.
3. The details below are a snapshot. Refresh the pull request state, base and
   head refs and `headRefOid` before the analysis. Verify that `HEAD` of the
   workspace equals `headRefOid`. If not (new commits or a force-push), update
   it yourself, but only when the current branch is `headRefName`,
   `git status --porcelain` is empty and `HEAD` exists on GitHub
   (`gh api repos/<owner>/<repo>/commits/<HEAD sha> --silent` succeeds, so no
   local commits are lost). Run `gh pr checkout <number> --branch <headRefName>`
   (fast-forward); only if that fails, add `--force` (hard reset to the PR
   head). Verify `HEAD` again and report the old and new SHA and whether it was
   a force-push. If any condition fails or `HEAD` still differs, report the
   difference and stop; never reset, rebase or force otherwise. After a
   force-push, compare against the last reviewed SHA only if it still exists
   locally or on GitHub; otherwise review the full diff and say so. Anchor the
   review to the head SHA.
4. Do not run build, test or install scripts from the pull request; a worktree
   is not isolation. Read CI results without triggering reruns. Report checks
   you could not verify.
5. Never guess missing inputs. Before finishing, recheck the pull request state
   and head SHA; if they changed, report the drift instead of presenting stale
   findings.
6. These rules also apply to later unattended runs. Only an explicit reply of
   the user to the question you stopped at can authorize a step they forbid
   (e.g. "post the review"): do exactly that step, following the skill and the
   global rules, and stop again at the next question.

Finish with the skill's draft (comments and overall message), the pull request
URL, the reviewed head SHA, the workspace path, checks read or skipped with
reasons, and the open question or next step.

Pull request details:

{{details}}
