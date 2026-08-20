---
name: github-pr-review
description:
  Use when reviewing GitHub pull requests with gh CLI - creates pending reviews
  with code suggestions, batches comments, and chooses appropriate event types
  (COMMENT/APPROVE/REQUEST_CHANGES)
allowed-tools: AskUserQuestion
---

# GitHub PR Review

## Overview

Workflow for reviewing GitHub pull requests using `gh api` to create pending
reviews with code suggestions. **Always use pending reviews to batch comments,
even under time pressure.**

**CRITICAL: Always get explicit user approval before posting any review
comments.** Show exactly what will be posted and ask for yes/no confirmation
using AskUserQuestion.

## When to Use

- Reviewing pull requests
- Adding code suggestions to PRs
- Posting review comments with the gh CLI

## Core Workflow

**REQUIRED STEPS (do not skip):**

1. **Gather PR context** - Fetch the diff and metadata (see below)
2. **Draft the review** - Analyze PR and prepare all comments (see checklist)
3. **Show user exactly what will be posted** - Use AskUserQuestion with yes/no
4. **Get explicit approval** - Wait for user confirmation
5. **Post the review** - Only after approval

Before showing comments for approval, re-read them against **Writing Style &
Tone** below: short, direct, human. Rewrite anything that reads like an AI.

### Gather PR Context

Before drafting, pull down the diff and metadata — the diff is the primary
review artifact.

```bash
# PR metadata, including the head commit SHA and changed files
gh pr view <PR_NUMBER> --json number,title,url,baseRefName,headRefName,headRefOid,files,additions,deletions

# The diff (primary review artifact)
gh pr diff <PR_NUMBER> --color=never

# Optional: check CI signal while reviewing
gh pr checks <PR_NUMBER>
```

Use `-R owner/repo` on any of these if you are not in a checkout of the target
repo.

### What to Check

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

### Approval Pattern

Before posting ANY review, use AskUserQuestion to show:

- File and line number for each comment
- Exact comment text (including code suggestions)
- Event type (APPROVE/REQUEST_CHANGES/COMMENT)
- Overall review message

**Example:**

```
Question: "Ready to post this review?"
Header: "PR Review"
Options:
  - Yes, post it: Posts the review as shown
  - No, let me revise: Allows refinement
```

### Technical Workflow

**ALWAYS use the pending review pattern, even for a single comment.** It's two
API calls:

1. **Create a PENDING review** (omit the `event` field) with all inline comments
   in one `POST repos/:owner/:repo/pulls/<PR_NUMBER>/reviews` call. This returns
   a `REVIEW_ID`.
2. **Submit it** with
   `POST repos/:owner/:repo/pulls/<PR_NUMBER>/reviews/<REVIEW_ID>/events`,
   passing the chosen `event` (`COMMENT`/`APPROVE`/`REQUEST_CHANGES`) and an
   overall message.

See **Complete Example with Approval** below for the full commands and **Quick
Reference** for parameters.

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

## Quick Reference

### Required Parameters

- `commit_id`: Head commit SHA — the `headRefOid` fetched in Gather PR Context
- `comments[][path]`: File path relative to repo root
- `comments[][line]`: End line number (use `-F` for numbers)
- `comments[][side]`: Use `RIGHT` for added/modified lines (most common), `LEFT`
  for deleted lines
- `comments[][body]`: Comment text with optional ```suggestion block

### Optional Parameters

- `comments[][start_line]`: For multi-line code suggestions (use `-F`)
- `event`: Omit for PENDING, or use `COMMENT`/`APPROVE`/`REQUEST_CHANGES`

### Mapping a Diff Line to `line` and `side`

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

If you can't reliably anchor a comment (complex hunks, uncertainty), do not post
it inline — raise it in the overall review message instead.

### Syntax Rules

✅ **DO:**

- Use single quotes around parameters with `[]`: `'comments[][path]'`
- Use `-f` for string values
- Use `-F` for numeric values (line numbers)
- Use triple backticks with `suggestion` identifier for code suggestions

❌ **DON'T:**

- Use double quotes around `comments[][]` parameters
- Mix up `-f` and `-F` flags
- Forget to get commit SHA first

## Code Suggestions Format

````bash
-f 'comments[][body]=Your comment explaining the issue

```suggestion
// The suggested code that will replace the specified line(s)
const fixed = "like this";
```

Additional context or explanation after the suggestion.'
````

**Important**: Code suggestions replace the entire line or line range. Make sure
the suggested code is complete and correct.

### Edge Case: Suggestions with Nested Code Blocks

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

## Red Flags - You're About to Violate the Pattern

Stop if you're thinking:

- "User said ASAP so I'll skip pending review"
- "Only one comment so I'll post directly"
- "Time pressure means I should post immediately"
- "I'll post this one now and batch the rest later"
- **"User already approved the review idea, so I'll skip the approval step"**
- **"I'll post it and then tell them what I posted"**
- **"The approval step slows things down"**

**All of these mean: STOP. Get explicit approval, then use pending review. Keep
every comment short and human (see Writing Style & Tone).**

**Why pending reviews?** Take the same time (2 API calls vs 1) but provide
critical benefits:

- Can add more comments if you find additional issues while writing the first
- Can review your own comments before submitting
- Consistent workflow regardless of urgency
- Batches all comments into one notification for the PR author

**Why approval step?** Users need to see exactly what will be posted publicly:

- Review comments are public and permanent
- Code suggestions might be incorrect
- Tone might need adjustment
- User might want to refine the message

## Complete Example with Approval

**Step 1: Draft and show for approval**

First, analyze the PR and draft your comments. Then use AskUserQuestion:

```
I've reviewed PR #123 and found 3 issues. Here's what I'll post:

**Comment 1:** src/auth.ts line 20
Token expiry validation is missing...
[code suggestion shown]

**Comment 2:** src/auth.ts line 35
Missing error handling...
[code suggestion shown]

**Comment 3:** tests/auth.test.ts line 12
Missing error case test...
[code suggestion shown]

**Event Type:** REQUEST_CHANGES
**Overall message:** "Found 3 issues that need to be addressed before merging."

Ready to post this review?
```

**Step 2: After approval, post the review**

```bash
# Create pending review with multiple comments
gh api repos/:owner/:repo/pulls/123/reviews \
  -X POST \
  -f commit_id="abc123" \
  -f 'comments[][path]=src/auth.ts' \
  -F 'comments[][line]=20' \
  -f 'comments[][side]=RIGHT' \
  -f 'comments[][body]=First issue...' \
  -f 'comments[][path]=src/auth.ts' \
  -F 'comments[][line]=35' \
  -f 'comments[][side]=RIGHT' \
  -f 'comments[][body]=Second issue...' \
  -f 'comments[][path]=tests/auth.test.ts' \
  -F 'comments[][line]=12' \
  -f 'comments[][side]=RIGHT' \
  -f 'comments[][body]=Third issue...' \
  --jq '{id, state}'

# Submit with appropriate event type
gh api repos/:owner/:repo/pulls/123/reviews/<REVIEW_ID>/events \
  -X POST \
  -f event="REQUEST_CHANGES" \
  -f body="Found 3 issues that need to be addressed before merging."
```
