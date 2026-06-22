---
name: github-pr-review-reviews
description:
  Use when addressing the review feedback left on a GitHub pull request - reads
  all review comments, suggestions, and conversation, validates each one, and
  implements the valid ones as local edits after per-item confirmation. Triggers
  on "address PR review comments", "implement review feedback", "apply PR
  suggestions", "go through / resolve the comments on my PR", or "fix review
  comments". This skill CONSUMES and IMPLEMENTS reviewer feedback - it does NOT
  author review comments (that is the github-pr-review skill).
allowed-tools: AskUserQuestion, Bash, Read, Edit, Write, Grep, Glob
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
Show the exact proposed diff for each comment and ask yes/skip/edit using
AskUserQuestion. Never apply a change the user has not approved.

**This skill is read-only toward GitHub.** It only reads comments and edits
local files. It does not post replies, resolve threads, commit, or push.

## When to Use

- Addressing the review comments on a pull request
- Applying reviewer code suggestions
- Working through reviewer feedback and implementing the valid parts

## When NOT to Use

- Writing/authoring review comments on a PR → use `github-pr-review`
- Committing the resulting changes → use `git-commit` after this skill finishes

## Prerequisites

**CRITICAL: Check the gh CLI before doing anything else.**

### Check for gh CLI

```bash
gh --version
```

**If gh is not installed:**

1. **Stop immediately** - Do not attempt to run gh api commands.
2. **Inform the user** with this message:

```
The GitHub CLI (gh) is required for this skill but is not installed.

Please install it from: https://cli.github.com/

Installation options:
- macOS: brew install gh
- Windows: winget install GitHub.cli
- Linux: See https://cli.github.com/ for your distro

After installing, authenticate with:
  gh auth login

Then try your request again.
```

3. **Do not proceed** until gh is installed.

### Check Authentication

```bash
gh auth status
```

If this fails, stop and tell the user to run `gh auth login` before retrying.

## Core Workflow

**REQUIRED STEPS (do not skip or reorder):**

1. **Check prerequisites** - `gh --version` and `gh auth status`.
2. **Resolve the PR** - From the current branch, an explicit number, or a URL;
   warn + confirm if it is already MERGED/CLOSED.
3. **Verify branch state** - Ensure the PR's head branch is checked out.
4. **Collect comments** - All three sources, filtered to unresolved/active.
5. **Validate & classify** - Each comment as Valid / Not applicable / Needs
   discussion, with reasoning.
6. **Show the overview** - Present the full classified list.
7. **Confirm & implement per item** - For each Valid item: show the proposed
   diff, ask yes/skip/edit, apply only on approval.
8. **Final summary** - Grouped report plus reminders.

### Step 1 - Prerequisites

See the [Prerequisites](#prerequisites) section above. Halt on any failure.

### Step 2 - Resolve the PR

Accept any of these inputs:

- **No argument** → auto-detect the PR for the current branch:

  ```bash
  gh pr view --json number,state,headRefName,headRepositoryOwner,headRepository \
    --jq '{number, state, headRefName, owner: .headRepositoryOwner.login, repo: .headRepository.name}'
  ```

  If no PR is found for the branch, ask the user for a PR number or URL.

- **A PR number** (e.g. `16722`) → use the current repo context.

- **A full URL** (e.g. `https://github.com/Staffbase/mops/pull/16722`) → parse
  `<owner>`, `<repo>`, and `<number>` from the path and target that repo
  explicitly with `gh api repos/<owner>/<repo>/...`.

Record `owner`, `repo`, and `number` for all subsequent calls.

**Check the PR state** (always fetch `state` alongside the number):

```bash
gh pr view <number> --repo <owner>/<repo> --json state --jq '.state'
# → OPEN | MERGED | CLOSED
```

- **`OPEN`** → proceed normally.
- **`MERGED` or `CLOSED` → WARN and confirm.** The feedback is on code that is
  already merged or abandoned, so "implementing" it means a **new** change on
  top of the base branch, not addressing an in-flight PR. Tell the user the PR
  is merged/closed and ask, via AskUserQuestion, whether to continue anyway or
  stop. Do not collect/edit further until the user confirms.

### Step 3 - Verify Branch State

Because changes are applied to the **local working tree**, confirm you are on
the correct branch before editing. (If Step 2 found the PR MERGED/CLOSED, you
must already have the user's confirmation to continue before reaching here.)

```bash
# PR head branch
gh pr view <number> --json headRefName --jq '.headRefName'

# Currently checked-out branch
git rev-parse --abbrev-ref HEAD
```

- **Branch mismatch → HARD HALT.** Do not edit files. Tell the user which branch
  the PR targets and offer to run `gh pr checkout <number>` **only after
  explicit confirmation**.
- **Dirty working tree → WARN.** Show `git status --short` and ask the user to
  confirm they want to proceed (their changes will be intermixed with the
  applied edits). This is a warning, not a halt.

### Step 4 - Collect Comments

Gather from **all three** sources.

````bash
# 4a. Inline review comments (includes ```suggestion blocks).
#     `position: null` means the comment is OUTDATED.
gh api repos/<owner>/<repo>/pulls/<number>/comments --paginate \
  --jq '.[] | {id, user: .user.login, path, line, original_line, position,
               in_reply_to_id, body, html_url}'

# 4b. Review summary bodies (the top-level review messages).
gh api repos/<owner>/<repo>/pulls/<number>/reviews --paginate \
  --jq '.[] | select(.body != "") | {id, user: .user.login, state, body, html_url}'

# 4c. General PR conversation comments.
gh api repos/<owner>/<repo>/issues/<number>/comments --paginate \
  --jq '.[] | {id, user: .user.login, body, html_url}'
````

**Resolved-thread status is not in the REST API.** Use GraphQL to find which
review threads are resolved, then exclude their comments:

```bash
gh api graphql -f query='
  query($owner:String!, $repo:String!, $number:Int!) {
    repository(owner:$owner, name:$repo) {
      pullRequest(number:$number) {
        reviewThreads(first:100) {
          nodes {
            isResolved
            isOutdated
            comments(first:1) { nodes { databaseId } }
          }
        }
      }
    }
  }' -f owner=<owner> -f repo=<repo> -F number=<number> \
  --jq '.data.repository.pullRequest.reviewThreads.nodes[]
        | {resolved: .isResolved, outdated: .isOutdated,
           id: .comments.nodes[0].databaseId}'
```

### Step 5 - Filter

- **Include**: unresolved, active comments from any author (humans **and** bots
  such as CodeRabbit or Copilot are treated equally).
- **Exclude (skip)**: comments whose thread `isResolved == true`.
- **Set aside**: outdated comments (`position: null` or `isOutdated == true`).
  Do not process them by default — list them separately and let the user opt in.

### Step 6 - Validate & Classify

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

### Step 7 – Overview, Then Per-Item Confirmation

First present the **full classified list** so the user sees everything:

```
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
```

Then walk through each **Valid & actionable** item **one at a time**. For each:

1. Show the comment, the file:line, and the **proposed diff**.
2. Ask with AskUserQuestion:

   ```
   Question: "Apply this change?"
   Header: "<path>:<line>"
   Options:
     - Yes, apply: Apply the change to the working tree
     - Skip: Leave this comment unaddressed
     - Edit: Refine the change before applying
   ```

3. **Yes** → apply with Edit/Write. **Skip** → record as skipped. **Edit** →
   take the user's refinement, re-show the updated diff, and re-confirm.

Implement **all** changes as local edits — both literal ```suggestion blocks and
prose feedback. Do not commit, push, reply, or resolve threads.

### Step 8 – Handle Non-Actionable Items

- **Not applicable** → reported with the reason. No action.
- **Needs discussion** → surface to the user: the comment, the open question,
  and the skill's own take/recommendation. Do **not** auto-implement; let the
  user decide. (If the user then asks for a change, run it through Step 7.)

### Step 9 - Final Summary

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

Reminders:
  - Changes are UNSTAGED in your working tree — review, test, and commit them
    yourself (e.g. via the git-commit skill).
  - No GitHub threads were replied to or resolved.
```

## Validation Heuristics

| Signal                                              | Likely class              |
| --------------------------------------------------- | ------------------------- |
| Clear bug/typo/security fix with obvious correction | Valid & actionable        |
| ```suggestion block that still applies cleanly      | Valid & actionable        |
| Referenced code already matches the request         | Not applicable            |
| Comment line no longer exists / `position: null`    | Not applicable (outdated) |
| "Why did you...?" / "Should we...?" / opinion       | Needs discussion          |
| Request spanning files/behaviour beyond this PR     | Needs discussion          |

## Red Flags - You're About to Violate the Pattern

Stop if you're thinking:

- "I'll apply these without showing each diff first."
- "The user clearly wants all comments fixed, so I'll skip per-item
  confirmation."
- "I'll commit/push the changes to be helpful."
- "I'll reply to or resolve the threads on GitHub."
- "This branch is probably right, I'll just start editing."
- "The PR is merged but I'll implement the feedback anyway without asking."
- "I'll implement this 'Needs discussion' item with my best guess."
- "gh is probably installed, no need to check."

**All of these mean: STOP.** Check prerequisites, verify the branch, classify,
show the overview, and confirm each change before applying. Never write to
GitHub. Never commit.

## Quick Reference

```bash
# Resolve PR from current branch
gh pr view --json number,headRefName --jq '{number, headRefName}'

# Parse a URL: https://github.com/<owner>/<repo>/pull/<number>

# Inline review comments (suggestions live here; position:null = outdated)
gh api repos/<owner>/<repo>/pulls/<number>/comments --paginate

# Review summary bodies
gh api repos/<owner>/<repo>/pulls/<number>/reviews --paginate

# Conversation comments
gh api repos/<owner>/<repo>/issues/<number>/comments --paginate

# Resolved/outdated thread status (GraphQL)
gh api graphql -f query='...reviewThreads { nodes { isResolved isOutdated } }...'

# Verify branch
git rev-parse --abbrev-ref HEAD
gh pr view <number> --json headRefName --jq '.headRefName'
```
