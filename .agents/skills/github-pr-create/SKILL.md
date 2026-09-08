---
name: github-pr-create
description:
  Create or update the pull request for the current branch. Creates a draft PR
  titled from the first commit's subject. If a
  `.github/PULL_REQUEST_TEMPLATE.md` exists it fills that template, otherwise it
  keeps the PR body in sync with the exact commit messages on the branch. Use
  after committing, or when asked to "create a PR", "open a pull request", or
  "update the PR body/description".
---

# GitHub Pull Request Creation

Check whether a pull request already exists for the current branch. Create one
if it does not, and keep its body up to date with the commits on the branch.

The body is built one of two ways, depending on whether the repository defines a
pull request template:

- **Template mode** — a `.github/PULL_REQUEST_TEMPLATE.md` file exists. The PR
  body is built from that template (see [Template Mode](#template-mode)).
- **Commit mode** — no template file exists. The PR body is built from the
  branch's commit messages (see [Commit Mode](#commit-mode)).

## Template Mode

When `.github/PULL_REQUEST_TEMPLATE.md` exists, use it as the source of the PR
body:

- Start from the **exact contents** of the template file. Keep its headings,
  section order, comments, and checklist items intact.
- Fill in the template's sections using information derived from the branch's
  commits — e.g. write the summary/description from the commit subjects and
  bodies, and tick any checklist items that the commits clearly satisfy. Do not
  paste the raw commit log in place of the template; preserve the template's
  structure.
- For sections you cannot confidently fill from the commits, ask the user for
  the missing information and use their answer to complete the section. If the
  user does not provide it, leave the section as it is in the template (keep the
  placeholder text or empty checkboxes) so the author can complete it later.
- When **updating** an existing PR, refresh only the parts derived from commits
  (e.g. the description) so they reflect every commit on the branch. Preserve
  any content a human already filled into other sections; do not overwrite the
  whole body back to the blank template.

## Commit Mode

When no template file exists, the pull request body is built from **all**
commits on the branch. Each commit contributes its full message (subject line,
blank line, body), and commits are separated from one another by blank lines, in
chronological order (oldest first):

```
subject of commit 1

body of commit 1


subject of commit 2

body of commit 2
```

The body must be built from the **exact bytes** of each commit message,
including the 72-character wrapping. Do not re-flow, unwrap, or re-format the
text. Always pipe it into `--body-file -` (inline `--body "..."` risks stripping
or normalizing the hard line breaks).

## Steps

1. Determine the base branch:

   ```sh
   base="$(gh pr view --json baseRefName --jq .baseRefName 2>/dev/null \
     || git remote show origin | sed -n 's/.*HEAD branch: //p')"
   ```

2. Build the body into a temporary file, choosing the mode by whether a template
   exists:
   - **Template mode** (`.github/PULL_REQUEST_TEMPLATE.md` exists): start from
     the template and fill its sections from the branch commits, as described in
     [Template Mode](#template-mode). Use the commits for reference:

     ```sh
     git log --reverse --format='%B%n' "origin/$base..HEAD"
     ```

   - **Commit mode** (no template): build the body from the raw commit messages.
     `%B` is a commit's raw message (subject + blank line + body), and the
     trailing `%n%n` separates consecutive commits with a blank line:

     ```sh
     git log --reverse --format='%B%n' "origin/$base..HEAD"
     ```

3. Check for an existing pull request:

   ```sh
   gh pr view --json url
   ```

4. If **no** pull request exists (the command above fails), ask the user whether
   one should be created. Only continue if the user confirms. Create it as a
   **draft**, using the first commit's subject as the title and the body built
   in step 2 (pipe the body in via `--body-file -`):

   ```sh
   title="$(git log --reverse --format='%s' "origin/$base..HEAD" | head -n1)"
   # <body-source> is the template-filled body or the commit log, per step 2.
   <body-source> | gh pr create --draft --title "$title" --body-file -
   ```

5. If a pull request **already** exists, refresh its body:
   - In **commit mode**, regenerate the body so it includes every commit on the
     branch (this matters when the branch has more than one commit, or after
     adding commits to an existing pull request):

     ```sh
     git log --reverse --format='%B%n' "origin/$base..HEAD" | gh pr edit --body-file -
     ```

   - In **template mode**, refresh only the commit-derived sections of the
     existing body and preserve everything the author already filled in, then
     update it:

     ```sh
     # <updated-body> keeps the template structure and human-authored content,
     # refreshing only the commit-derived sections.
     <updated-body> | gh pr edit --body-file -
     ```

   Leave the title unchanged unless the first commit's subject changed. If a
   single commit has no body, its contribution is just the subject line.
