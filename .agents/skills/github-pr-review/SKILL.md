---
name: github-pr-review
description:
  Use when reviewing GitHub pull requests with gh CLI - creates pending reviews
  with code suggestions, batches comments, and chooses appropriate event types
  (COMMENT/APPROVE/REQUEST_CHANGES). Triggers on "review this PR", "review PR
  <number/url>", "add review comments", or "re-review the PR". This skill
  AUTHORS review comments - it does NOT implement the feedback from reviewers
  (that is the github-pr-review-reviews skill).
---

# GitHub PR Review

## Overview

Workflow for reviewing GitHub pull requests using `gh api` to create pending
reviews with code suggestions. **Always use pending reviews to batch comments,
even under time pressure.**

**This skill is the counterpart to `github-pr-review-reviews`:**

- `github-pr-review` (this skill) **authors** review comments on someone else's
  PR.
- `github-pr-review-reviews` **consumes and implements** the feedback reviewers
  left on a PR.

**CRITICAL: Always get explicit user approval before posting any review
comments.** Show the full draft via a structured question, confirm each inline
comment individually via a structured question, and get a final confirmation
before posting. Review comments are public and permanent — the user must see
exactly what will be posted: suggestions can be wrong and tone may need
adjustment.

## When to Use

- Reviewing pull requests
- Adding code suggestions to PRs
- Posting review comments with the gh CLI

## When NOT to Use

- Addressing/implementing the review feedback left on a PR → use
  `github-pr-review-reviews`

## Core Workflow

**REQUIRED STEPS (do not skip or reorder):**

1. **Gather PR context** - Fetch the diff and metadata; warn + confirm if the PR
   is already MERGED/CLOSED.
2. **Draft the review** - Analyze the diff against the checklist and prepare all
   comments.
3. **Overview question, then per-item confirmation** - Show the full draft as a
   structured question (a Yes there only starts the walk); confirm each comment
   (include/skip/edit), then one final post confirmation.
4. **Post the review** - A pending review with only the approved comments, then
   submit it.

Before showing comments for approval, re-read them against **Writing Style &
Tone** below: short, direct, human. Rewrite anything that reads like an AI.

### Step 1 - Gather PR Context

If no PR was specified, use the current branch's PR if it has one (`gh pr view`
with no arguments resolves it). Otherwise run `gh pr list --state open` —
exactly one open PR: proceed with it and say so; several: ask the user which
one.

Before drafting, pull down the diff and metadata — the diff is the primary
review artifact.

```bash
# PR metadata, including state, author, head commit SHA, and changed files
gh pr view <number> --json \
  number,title,url,state,author,baseRefName,headRefName,headRefOid,files,additions,deletions

# Own PRs only allow COMMENT at submit time (see Event Types)
gh api user --jq .login

# The diff (primary review artifact)
gh pr diff <number> --color=never

# Optional: check CI signal while reviewing
gh pr checks <number>
```

- **`state` is `MERGED` or `CLOSED` → warn and confirm** via a structured
  question before drafting — review comments on a dead PR rarely help anyone.
- **Not in a checkout of the target repo?** Add `-R owner/repo` to the `gh pr`
  commands, and replace `:owner/:repo` in every `gh api` call in this skill with
  the explicit `owner/repo`. `gh api` has no `-R`; the `:owner/:repo`
  placeholders resolve from the current directory's git remote and would
  silently target the wrong repo.

If the PR is checked out locally, run the project's existing build and test
commands (per the repo's docs) before finalizing the review. Only claim
verification you actually ran.

### Step 2 - Draft the Review

Review the diff for:

- correctness and logic errors
- security risks
- API breaks
- data loss / irreversible behavior
- missing or failing tests
- edge cases
- performance and algorithmic complexity
- naming, clarity, ergonomics
- documentation and user-facing behavior
- consistency with project conventions

Prepare every inline comment (path, line, side, body) and the overall message.
End the overall message with the reviewed head SHA (e.g. "Reviewed at abc1234"):
a later re-review round diffs from it without recovering the SHA via the API,
and the message the user confirms in Step 3 is exactly what gets posted.

#### Anchoring: Mapping a Diff Line to `line` and `side`

Inline comments need an exact `path`, a `line`, and a `side`. Derive them
deterministically from the unified diff:

- Each hunk header looks like `@@ -old_start,old_count +new_start,new_count @@`.
- Initialize counters: `old_line = old_start`, `new_line = new_start`.
- Walk each line in the hunk:
  - Context line (starts with `' '`): increment both `old_line` and `new_line`.
  - Addition (starts with `'+'`): increment `new_line` only.
  - Deletion (starts with `'-'`): increment `old_line` only.
- To comment on new/modified code: `side=RIGHT`, `line=new_line`.
- To comment on a deleted line: `side=LEFT`, `line=old_line`.
- For a multi-line suggestion, also set `start_line` (+ `start_side`, matching
  `side`) to the first line of the range.

If you can't reliably anchor a comment (complex hunks, uncertainty), do not post
it inline — raise it in the overall review message instead.

#### Code Suggestions

A comment body that carries a code suggestion:

````markdown
Your comment explaining the issue

```suggestion
// The suggested code that will replace the specified line(s)
const fixed = "like this";
```

Additional context or explanation after the suggestion.
````

**Important**: Code suggestions replace the entire line (`line`) or line range
(`start_line`..`line`). Make sure the suggested code is complete and correct.

When suggesting changes to markdown files or documentation that contain triple
backticks, use 4 backticks to prevent conflicts:

`````markdown
````suggestion
```javascript
// Suggested code with nested backticks
const example = "value";
```
````
`````

### Step 3 - Overview Question, Then Per-Item Confirmation

First show the **full draft** so the user sees everything before deciding on
individual comments. Deliver it as a structured question — the draft block is
the question's message, never a separate plain-text reply (plain text between
tool calls tends to get skipped):

```
Question:
  PR #<number> — <title>
  <owner>/<repo>

  DRAFT REVIEW (N comments, EVENT)
    1. <path>:<line> — <one-line gist>
    2. ...

  — EVENT: <COMMENT/APPROVE/REQUEST_CHANGES>
  — OVERALL MESSAGE: <full message>

  "Go through the N comments one at a time?"
Options:
  - Yes: start the per-item walk
  - Stop: end here — nothing is posted
```

A **Yes** here approves **nothing** — it only starts the walk; every comment
still gets its own question below. A freeform reply (e.g. "drop 2, rest is
fine") is applied directly: confirm only the items the user didn't clearly
decide.

Then walk through each comment **one at a time** — never collapse this into a
single yes/no for the whole review; one unwanted comment would force the user to
reject everything. For each:

1. Show the full comment body in chat, including any suggestion block.
2. Ask with a structured question (repeat the gist so the question stands on its
   own):

   ```
   Question: "Comment <i>: <one-line gist>. Include this comment?"
   Header: "<path>:<line>"
   Options:
     - Yes, include: Keep it in the review
     - Skip: Drop this comment
     - Edit: Refine the wording before deciding
   ```

3. **Yes** → keep it in the review. **Skip** → drop it. **Edit** → take the
   refinement, re-show the updated body, and re-confirm.

Finally, confirm the post itself with one last structured question — nothing is
posted until it is answered with **Yes**. Embed the full overall message
verbatim in the question text; never write "the message shown above", since
earlier or same-turn text may never have rendered:

```
Question: "Post review (N comments, EVENT) with this overall message:
  '<full overall message>'?"
Options:
  - Yes: Post the review
  - Edit: Refine the overall message, re-show, re-confirm
  - No: Do not post
```

### Step 4 - Post the Review

**ALWAYS use the pending review pattern, even for a single comment.** It costs
one extra API call and buys: adding comments you find while writing, reviewing
your own comments before submitting, one consistent workflow regardless of
urgency, and a single notification for the PR author. It's two API calls:

1. **Create a PENDING review** (omit the `event` field) with all inline comments
   in one `POST repos/:owner/:repo/pulls/<number>/reviews` call. This returns a
   `REVIEW_ID`.
2. **Submit it** with
   `POST repos/:owner/:repo/pulls/<number>/reviews/<REVIEW_ID>/events`, passing
   the chosen `event` (`COMMENT`/`APPROVE`/`REQUEST_CHANGES`) and the overall
   message exactly as confirmed in Step 3 (it already ends with the reviewed
   head SHA, per Step 2).

For anything beyond one short comment, don't build the review with `-f` flags —
bodies with apostrophes, backticks, newlines, or `suggestion` fences turn into
shell-quoting bugs. Write the payload to a temp JSON file and pass it with
`--input`:

```json
{
  "commit_id": "<headRefOid>",
  "comments": [
    { "path": "src/auth.ts", "line": 20, "side": "RIGHT", "body": "..." }
  ]
}
```

```bash
# 1. Create the PENDING review
gh api repos/:owner/:repo/pulls/<number>/reviews -X POST \
  --input /tmp/review.json --jq '{id, state}'
rm /tmp/review.json

# 2. Submit it with the chosen event type and overall message
gh api repos/:owner/:repo/pulls/<number>/reviews/<REVIEW_ID>/events -X POST \
  -f event='REQUEST_CHANGES' \
  -f body='<overall message>'
```

`commit_id` is the `headRefOid` from Step 1; each comment carries the `path`,
`line`, and `side` (plus `start_line`/`start_side` for ranges) anchored in
Step 2. Omitting `event` on the create call is what keeps the review PENDING.

Building the create call with `-f`/`-F` flags instead is fine for a single short
comment without tricky quoting: single quotes around parameters containing `[]`
(`'comments[][path]=...'`), `-f` for strings, `-F` for numbers (`line`,
`start_line`); `commit_id` is still required.

For a standalone PR-level comment that is not a review (e.g. posting a summary
or a list of suggestions), use `gh pr comment <number> --body-file <file>`. The
approval rule still applies: show the exact body first.

### Re-Reviews

When the user asks for another round after fixes ("the comments are resolved,
review again"):

- Fetch the branch first (`git fetch origin <headRefName>`) — it may have been
  amended or force-pushed since the last round.
- Diff only what changed since the last reviewed head:
  `git diff <last-reviewed-sha>..<new-head>`.
- If the last-reviewed SHA isn't in the conversation, recover it from your prior
  review:
  `gh api repos/:owner/:repo/pulls/<number>/reviews --paginate --jq '[.[] | select(.user.login=="<your-login>")] | last | .commit_id'`
- Verify each earlier finding is actually fixed — confirm it or flag the
  regression — before hunting for new issues. Fixes can introduce new bugs.
- Say in the overall message which fixes were verified.
- A clean round is still a review: skip the per-comment walk in Step 3 (there is
  nothing to confirm) but keep the final post confirmation, then create the
  pending review with no comments and submit it, stating which fixes were
  verified.

## Writing Style & Tone

**CRITICAL: Write comments like a normal, busy human reviewer would — not like
an AI.** Terse, direct, and specific. A colleague reading your comment should
not be able to tell a machine wrote it. Overly polished, exhaustive, or
relentlessly upbeat comments feel robotic ("creepy") and waste the author's
time.

### Rules

- **Get to the point.** Lead with the actual issue. Cut preambles and framing.
- **One point, once.** Don't restate the same concern in the summary and the
  inline comment. Put the detail inline; keep the summary to a sentence.
- **Skip the praise sandwich.** Don't open every comment with "Nice, focused
  fix…". Occasional, genuine, specific praise is fine; reflexive praise is not.
- **Don't over-explain.** Trust the author to know their code. State the problem
  and, if useful, the fix. Skip the multi-paragraph proof and the exhaustive
  enumeration of every code path.
- **Short over complete.** A one-line comment that lands beats a correct essay.
  If it needs three paragraphs, it probably needs a conversation instead.
- **Plain words.** Write "this breaks retries" not "this removes the idempotency
  the deterministic name provided". Avoid stiff, formal, or buzzword-y phrasing.
- **Contractions and normal punctuation.** "doesn't", "won't", "here's". Avoid
  em-dash pile-ups, semicolons, and bulleted breakdowns of the obvious.
- **Drop the AI tics.** No "Great work!", no "Let me know if…", no closing "LGTM
  🎉", no summarizing what you just said. Say it once and stop.
- **Match the weight to the issue.** A nit gets one line. Don't dress a nit up
  with "Non-blocking nit:" ceremony and a justification for why it's fine as-is.

### Before / After

**❌ Too much (robotic):**

> Nice, focused fix for the cross-restore disk-name collision — the pvc-<uuid>
> shape and dependency are all fine. One blocking concern: generating a fresh
> UUID on every Reconcile removes the idempotency the deterministic name
> provided, and can orphan Azure disks and PVs on retries. Previously
> generateNewPVName returned the same name across reconciles, so
> CreateDiskFromSnapshot and r.Create were effectively no-ops on a second pass.
> With a random UUID per call, re-reconciliation re-processes already-restored
> PVCs and creates brand-new resources each time: [three bullet points]…

**✅ Human:**

> Blocking: the random UUID per Reconcile breaks idempotency. On a requeue (e.g.
> staggered snapshot readiness) we re-run the whole loop and mint a new disk +
> PV each pass, orphaning the old ones. Can we skip PVCs that already exist, or
> persist the name in the Restore status and reuse it?

**❌ Too much (nit):**

> Non-blocking nit: the first reconcile of an N-PVC restore issues up to N
> separate Status().Update calls inside getOrCreatePVName; could be batched into
> one, but it's correct as-is. LGTM.

**✅ Human:**

> Nit: could batch these Status().Update calls into one, but fine either way.

Apply this style to **every** comment body and the overall review message before
showing them for approval.

## Event Types

Choose the appropriate event type when submitting:

| Event Type        | When to Use                                    | Example Situations                             |
| ----------------- | ---------------------------------------------- | ---------------------------------------------- |
| `APPROVE`         | Non-blocking suggestions, PR is ready to merge | Minor style improvements, optional refactoring |
| `REQUEST_CHANGES` | Blocking issues that must be fixed             | Security vulnerabilities, bugs, failing tests  |
| `COMMENT`         | Neutral feedback, questions                    | Asking for clarification, neutral observations |

**Own PR:** GitHub rejects `APPROVE` and `REQUEST_CHANGES` on a PR the current
gh user authored (HTTP 422 at submit time, after the pending review exists). In
that case submit with `COMMENT` and carry severity in the comment bodies
("blocking:", "nit:").

## Red Flags - You're About to Violate the Pattern

Stop if you're thinking:

- User said ASAP so I'll skip the pending review.
- Only one comment so I'll post directly.
- Time pressure means I should post immediately.
- I'll post this one now and batch the rest later.
- The user already approved the review idea, so I'll skip the approval step.
- I'll post it and then tell them what I posted.
- The approval step slows things down.
- I'll ask one big yes/no for the whole review — a single unwanted comment then
  forces the user to reject everything; confirm per item.
- The per-comment walk covers everything, so I'll skip the draft overview
  question — the overview is the only place the user sees the whole review at
  once, and it must be a structured question, not plain text.
- The user answered Yes on the overview question, so the comments are approved —
  a Yes there only starts the walk; every comment still needs its own
  confirmation.
- I already showed that above, no need to repeat it — every confirmation
  question must be self-contained; earlier or same-turn text may never have
  rendered.

**All of these mean: STOP. Get explicit approval, then use pending review. Keep
every comment short and human (see Writing Style & Tone).**
