---
name: github-pr-review-reviews
description:
  Use when addressing the review feedback left on a GitHub pull request - reads
  all review comments, suggestions, and conversation, validates each one, and
  implements the valid ones as local edits after per-item confirmation, and
  optionally — each behind its own explicit confirmation — commits and updates
  the PR, then replies to / resolves the addressed threads. Triggers on "address
  PR review comments", "implement review feedback", "apply PR suggestions", "go
  through / resolve the comments on my PR", or "fix review comments". This skill
  CONSUMES and IMPLEMENTS reviewer feedback - it does NOT author review comments
  (that is the github-pr-review skill).
---

# GitHub PR Review Reviews

## Overview

Workflow for collecting all review feedback on a GitHub pull request using
`gh api`, validating each comment/suggestion, and implementing the valid ones as
local edits to the working tree.

**This skill is the counterpart to `github-pr-review`:**

- `github-pr-review` **authors** review comments on someone else's PR.
- `github-pr-review-reviews` (this skill) **consumes and implements** the
  feedback reviewers left on a PR.

**CRITICAL: Always get explicit user confirmation before applying any change.**
Show the exact proposed diff for each comment and ask yes/skip/edit via a
structured question. Never apply a change the user has not approved.

**This skill is read-only toward GitHub while processing feedback.** Steps 1-8
only read comments and edit local files. Committing, pushing, updating the PR,
and replying to / resolving threads happen only in the Step 9/10 follow-ups —
and only after the user explicitly confirmed them there.

**Re-run friendly.** Running this again on the same PR after a new review round
is expected — threads resolved since the last run are automatically excluded by
the Step 3/4 filter, so only fresh feedback is processed.

## When to Use

- Addressing the review comments on a pull request
- Applying reviewer code suggestions
- Working through reviewer feedback and implementing the valid parts

## When NOT to Use

- Writing/authoring review comments on a PR → use `github-pr-review`

## Core Workflow

**REQUIRED STEPS (do not skip or reorder):**

1. **Resolve the PR** - From the current branch, an explicit number, or a URL;
   warn + confirm if it is already MERGED/CLOSED.
2. **Verify branch state** - Ensure the PR's head branch is checked out.
3. **Collect comments** - All three sources.
4. **Filter** - Keep unresolved, active comments; set outdated ones aside.
5. **Validate & classify** - Each comment as Valid / Not applicable / Needs
   discussion, with reasoning.
6. **Overview question, then per-item confirmation** - Show the full classified
   list as a structured question (a Yes there only starts the walk); for each
   Valid item show the proposed diff, ask yes/skip/edit, and apply only on
   approval.
7. **Handle non-actionable items** - Report Not-applicable reasons; surface
   Needs-discussion questions.
8. **Final summary** - Grouped report, delivered inside the Step 9 question when
   one is offered.
9. **Offer commit & PR update (opt-in)** - Ask whether to commit, push, and
   update the PR; do it only on confirmation.
10. **Offer replies & resolution (opt-in)** - Draft a reply per implemented
    thread; confirm each before posting and resolving.

### Step 1 - Resolve the PR

Accept any of these inputs:

- **No argument** → auto-detect the PR for the current branch:

  ```bash
  gh pr view --json number,state,headRefName,url
  ```

  Parse `<owner>` and `<repo>` from `url`. Do **not** use
  `headRepositoryOwner`/`headRepository`: for fork PRs those point at the fork,
  while PR numbers and all API calls below belong to the **base** repo — which
  is what `url` contains. If no PR is found for the branch, ask the user for a
  PR number or URL.

- **A PR number** (e.g. `16722`) → use the current repo context.

- **A full URL** (e.g. `https://github.com/Staffbase/mops/pull/16722`) → parse
  `<owner>`, `<repo>`, and `<number>` from the path and target that repo
  explicitly with `gh api repos/<owner>/<repo>/...`.

Record `owner`, `repo` (the base repo), and `number` for all subsequent calls.

**Check the PR state** (`OPEN | MERGED | CLOSED`). The auto-detect call above
already returns it; when given a number or URL, fetch it together with the head
branch needed in Step 2:

```bash
gh pr view <number> --repo <owner>/<repo> --json state,headRefName
```

- **`OPEN`** → proceed normally.
- **`MERGED` or `CLOSED` → WARN and confirm.** The feedback is on code that is
  already merged or abandoned, so "implementing" it means a **new** change on
  top of the base branch, not addressing an in-flight PR. Tell the user the PR
  is merged/closed and ask, via a structured question, whether to continue
  anyway or stop. Do not collect/edit further until the user confirms.

### Step 2 - Verify Branch State

Because changes are applied to the **local working tree**, confirm you are on
the correct branch before editing. (If Step 1 found the PR MERGED/CLOSED, you
must already have the user's confirmation to continue before reaching here.)

```bash
# Currently checked-out branch — compare with headRefName from Step 1
git rev-parse --abbrev-ref HEAD
```

- **Branch mismatch → HARD HALT.** Do not edit files. Tell the user which branch
  the PR targets and offer to run `gh pr checkout <number>` **only after
  explicit confirmation**.
- **Dirty working tree → WARN.** Show `git status --short` and ask the user to
  confirm they want to proceed (their changes will be intermixed with the
  applied edits). This is a warning, not a halt.

### Step 3 - Collect Comments

**First, get the resolved/outdated set, then fetch full bodies only for the
comment IDs that remain in scope.** On PRs with many resolved threads this
avoids pulling large volumes of stale comment text into context.
**Resolved-thread status is not in the REST API** — use GraphQL:

```bash
gh api graphql -f query='
  query($owner:String!, $repo:String!, $number:Int!) {
    repository(owner:$owner, name:$repo) {
      pullRequest(number:$number) {
        reviewThreads(first:100) {
          nodes {
            id
            isResolved
            isOutdated
            comments(first:1) { nodes { databaseId } }
          }
        }
      }
    }
  }' -f owner=<owner> -f repo=<repo> -F number=<number> \
  --jq '.data.repository.pullRequest.reviewThreads.nodes[]
        | {threadId: .id, resolved: .isResolved, outdated: .isOutdated,
           id: .comments.nodes[0].databaseId}'
```

(For PRs with more than 100 review threads, paginate with
`reviewThreads(first:100, after:$cursor)`.)

The `databaseId` of a thread's first comment is the same integer as the REST
inline comment `id` (3a) and the `pulls/comments/<id>` path. Build the set of
root-comment ids whose thread is unresolved and not outdated, then keep only the
REST inline comments in that set (a reply's `in_reply_to_id` points at the
thread root). This is what lets you skip already-resolved threads on re-runs.
Keep each thread's `threadId` — Step 10 needs it to resolve threads.

Then gather comments from **all three** sources:

````bash
# 3a. Inline review comments (includes ```suggestion blocks).
#     `position: null` means the comment is OUTDATED.
#     On PRs with many comments, drop `body` here and fetch bodies by ID for
#     the in-scope threads only, via (note: no PR number in the path):
#     gh api repos/<owner>/<repo>/pulls/comments/<comment_id> --jq '{path, line, body}'
gh api repos/<owner>/<repo>/pulls/<number>/comments --paginate \
  --jq '.[] | {id, user: .user.login, path, line, start_line, original_line,
               position, in_reply_to_id, body, html_url}'

# 3b. Review summary bodies (the top-level review messages).
gh api repos/<owner>/<repo>/pulls/<number>/reviews --paginate \
  --jq '.[] | select(.body != "") | {id, user: .user.login, state, body, html_url}'

# 3c. General PR conversation comments.
gh api repos/<owner>/<repo>/issues/<number>/comments --paginate \
  --jq '.[] | {id, user: .user.login, body, html_url}'
````

### Step 4 - Filter

- **Include**: unresolved, active comments from any author (humans **and** bots
  such as CodeRabbit or Copilot are treated equally).
- **Exclude (skip)**: comments whose thread `isResolved == true`.
- **Set aside**: outdated comments (`position: null` or `isOutdated == true`).
  Do not process them by default — list them separately and let the user opt in.
- **Informational only**: review summary bodies (3b) and conversation comments
  (3c) that contain no actionable request — e.g. "Built both platforms, all
  green" approvals or status notes. Don't force these into the Valid /
  Not-applicable / Needs-discussion buckets; note them once as informational and
  move on.

### Step 5 - Validate & Classify

For each in-scope comment, read the referenced file/lines, understand the
request, and assign exactly one class:

| Class                  | Meaning                                                            |
| ---------------------- | ------------------------------------------------------------------ |
| **Valid & actionable** | A concrete, correct change you can make. Has a proposed edit.      |
| **Not applicable**     | Already fixed, outdated, wrong, or based on a misread of the code. |
| **Needs discussion**   | Ambiguous, a question, opinion-based, or out of the PR's scope.    |

Always include a short **reason** for the classification. For Valid items,
prepare the concrete edit (file, line(s), and the replacement). Treat a review
thread (a comment plus its replies) as a single unit.

### Step 6 - Overview Question, Then Per-Item Confirmation

First show the **full classified list** so the user sees everything before
deciding on individual items. Deliver it as a structured question — the list is
the question's message, never a separate plain-text reply (plain text between
tool calls tends to get skipped):

```
Question:
  PR #<number> — <title>
  <owner>/<repo>

  VALID & ACTIONABLE (N)
    1. <path>:<line> (@author) — <one-line summary>
    2. ...

  NOT APPLICABLE (N)
    - <path>:<line> (@author) — <reason>

  NEEDS DISCUSSION (N)
    - <path>:<line> (@author) — <the open question>

  OUTDATED, SET ASIDE (N)
    - <path>:<line> (@author) — process anyway?

  "Go through the N valid items one at a time?"
Options:
  - Yes: start the per-item walk
  - Stop: end here — nothing is applied
```

Sections with a count of 0 may be collapsed to one line or omitted. A **Yes**
here approves **nothing** — it only starts the walk; every item still gets its
own question below. A freeform reply (e.g. "skip 2, rest is fine") is applied
directly: confirm only the items the user didn't clearly decide.

Then walk through each **Valid & actionable** item **one at a time**. For each:

1. Show the comment, the file:line, and the **proposed diff**.
2. Ask with a structured question:

   ```
   Question: "Apply this change?"
   Header: "<path>:<line>"
   Options:
     - Yes, apply: Apply the change to the working tree
     - Skip: Leave this comment unaddressed
     - Edit: Refine the change before applying
   ```

3. **Yes** → apply the edit to the working tree. **Skip** → record as skipped.
   **Edit** → take the user's refinement, re-show the updated diff, and
   re-confirm.

Implement **all** changes as local edits — both literal ```suggestion blocks and
prose feedback. After applying the approved edits, you may build or run the
project's existing tests to confirm they hold.

### Step 7 - Handle Non-Actionable Items

- **Not applicable** → reported with the reason. No action.
- **Needs discussion** → surface to the user: the comment, the open question,
  and the skill's own take/recommendation. Do **not** auto-implement; let the
  user decide. (If the user then asks for a change, run it through Step 6.)

### Step 8 - Final Summary

End with a grouped report:

```
SUMMARY — PR #<number>

Implemented (N)
  - <path>:<line> — <what changed>

Skipped by user (N)
  - <path>:<line> — <comment summary>

Not applicable (N)
  - <path>:<line> — <reason>

Needs discussion (N)
  - <path>:<line> — <open question>
```

At this point the changes are unstaged in the working tree and nothing was
written to GitHub. When Step 9 is offered, deliver this summary **inside the
Step 9 question** (as the question's message) so it cannot be skipped; when Step
9 is not offered (nothing implemented), the summary is the final reply.

### Step 9 - Follow-Up: Commit, Push & Update PR (opt-in)

If at least one change was implemented, offer to finish the local side. Ask with
a structured question whose message is the Step 8 summary — **nothing below runs
without a Yes**:

```
Question:
  <the full Step 8 SUMMARY block>

  "Commit the changes, push, and update the PR?"
Options:
  - Yes: commit, push, update the PR body
  - No: stop here — everything stays local
```

On **No** (or when nothing was implemented): stop — this also skips Step 10,
since the replies reference commits that would not exist on GitHub.

On **Yes**, in this order:

1. **Commit** the changes with the `git-commit` skill.
2. **Push** the branch (`git push`).
3. **Update the PR body** with the `github-pr-create` skill (rebuilds the body
   from all commits on the branch).

### Step 10 - Follow-Up: Reply & Resolve Threads (opt-in)

Only offered after Step 9 ran. Ask first whether to handle the threads at all —
the user may prefer to answer the reviewers themselves:

```
Question: "Reply to and resolve the addressed threads?"
Options:
  - Yes: walk through each implemented thread with a drafted reply
  - No: leave all threads untouched
```

On **Yes**, go through the **implemented** threads **one at a time**. For each,
show the reviewer's comment and a drafted reply (one plain sentence of what
changed, referencing the commit — see Writing Style), then ask:

```
Question: "Post this reply and resolve the thread?"
Header: "<path>:<line>"
Draft: "Done in <short-sha>: <what changed>."
Options:
  - Yes: post the reply and resolve the thread
  - Reply only: post the reply, leave the thread unresolved
  - Edit: refine the reply text, re-show, re-confirm
  - Skip: leave this thread untouched
```

On **Yes** or **Reply only**, post the reply; resolve the thread only on
**Yes**:

```bash
# Reply to the thread's root comment
gh api repos/<owner>/<repo>/pulls/<number>/comments/<comment_id>/replies \
  -f body='Done in <short-sha>: <what changed>.'

# Resolve the thread (threadId from the Step 3 GraphQL query)
gh api graphql -f query='
  mutation($id:ID!) {
    resolveReviewThread(input:{threadId:$id}) { thread { isResolved } }
  }' -f id=<threadId>
```

Skipped, not-applicable, and needs-discussion threads are left untouched — the
user or the reviewer settles those on GitHub.

## Writing Style

All user-facing text this skill produces — classification reasons, the overview,
the "needs discussion" take, the final summary, and the Step 10 thread replies —
should read like a human wrote it: short, plain, and direct. No praise
sandwiches, no restating the same point twice, no exhaustive multi-paragraph
justifications, no AI tics ("Great work!", "Let me know if…", "LGTM 🎉"). Say it
once in plain words and move on. (This mirrors the tone guidance in the
`github-pr-review` skill.)

## Validation Heuristics

| Signal                                              | Likely class                  |
| --------------------------------------------------- | ----------------------------- |
| Clear bug/typo/security fix with obvious correction | Valid & actionable            |
| ```suggestion block that still applies cleanly      | Valid & actionable            |
| Referenced code already matches the request         | Not applicable                |
| Comment line no longer exists / `position: null`    | Outdated → set aside (Step 4) |
| "Why did you...?" / "Should we...?" / opinion       | Needs discussion              |
| Request spanning files/behaviour beyond this PR     | Needs discussion              |

## Red Flags - You're About to Violate the Pattern

Stop if you're thinking:

- I'll apply these without showing each diff first.
- The user clearly wants all comments fixed, so I'll skip per-item confirmation.
- The walk covers every item anyway, so I'll skip the Step 6 overview question —
  the overview is the only place the user sees all buckets at once, and it must
  be a structured question, not plain text.
- The user answered Yes on the overview question, so the items are approved — a
  Yes there only starts the walk; every item still needs its own confirmation.
- I'll commit/push, update the PR, or reply/resolve threads without the Step
  9/10 confirmations.
- This branch is probably right, I'll just start editing.
- The PR is merged but I'll implement the feedback anyway without asking.
- I'll implement this Needs-discussion item with my best guess.

**All of these mean: STOP.** Verify the branch, classify, show the overview, and
confirm each change before applying. Never write to GitHub or commit without the
user's explicit Step 9/10 confirmations.
