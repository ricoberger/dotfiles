---
name: github-pr-create
description:
  Create or update the pull request for the current branch. Creates a draft PR
  titled from the first commit's subject, or, for multi-commit branches in
  repositories with a pull request template, a Conventional Commits title
  summarizing all commits. If the repository has a pull request template it
  fills that template, otherwise it keeps the PR body in sync with the exact
  commit messages on the branch. Use after committing, or when asked to "create
  a PR", "open a pull request", or "update the PR body/description".
---

# GitHub Pull Request Creation

Check whether a pull request already exists for the current branch. Create one
if it does not, and keep its body up to date with the commits on the branch.

The body is built one of two ways, depending on whether the repository defines a
pull request template:

- **Template mode** — a pull request template exists (see
  [Template Detection](#template-detection)). The PR body is built from that
  template (see [Template Mode](#template-mode)).
- **Commit mode** — no template file exists. The PR body is built from the
  branch's commit messages (see [Commit Mode](#commit-mode)).

The title also depends on the mode and the number of commits (see
[Title](#title)).

## Template Detection

GitHub accepts the template file name in any letter case
(`PULL_REQUEST_TEMPLATE.md` or `pull_request_template.md`) in the `.github/`
directory, the repository root, or `docs/`. Look for it from the repository
root, in that order, and use the first match:

```sh
root="$(git rev-parse --show-toplevel)"
template="$(find "$root/.github" "$root" "$root/docs" -maxdepth 1 -type f \
  -iname 'pull_request_template.md' 2>/dev/null | head -n1)"
```

If no single file is found, check for multiple templates in a
`PULL_REQUEST_TEMPLATE/` directory in the same locations:

```sh
find "$root/.github" "$root" "$root/docs" -maxdepth 2 -type f \
  -ipath '*/pull_request_template/*.md' 2>/dev/null
```

If exactly one template is found there, use it. If there are several, ask the
user which one to use. If none is found anywhere, use commit mode.

## Template Mode

When a template exists, use it as the source of the PR body:

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

## Title

- **Commit mode**, or **template mode with a single commit**: use the first
  commit's subject unchanged:

  ```sh
  title="$(git log --reverse --format='%s' "origin/$base..HEAD" | head -n1)"
  ```

- **Template mode with multiple commits**: write a new title that describes the
  combined change of all commits on the branch, following the `git-commit`
  skill's subject rules.

  Use the commit subjects and bodies as input:

  ```sh
  git log --reverse --format='%B%n' "origin/$base..HEAD"
  ```

## Steps

1. Determine the base branch and fetch it, so `origin/$base` is up to date and
   the commit range contains exactly the branch's commits:

   ```sh
   base="$(gh pr view --json baseRefName --jq .baseRefName 2>/dev/null \
     || git remote show origin | sed -n 's/.*HEAD branch: //p')"
   git fetch origin "$base"
   ```

2. Build the body into a temporary file, choosing the mode by whether a template
   exists (see [Template Detection](#template-detection)):
   - **Template mode** (template found): start from the template and fill its
     sections from the branch commits, as described in
     [Template Mode](#template-mode). The commit log is only a reference for
     writing the sections, not the body itself:

     ```sh
     git log --reverse --format='%B%n' "origin/$base..HEAD"
     ```

   - **Commit mode** (no template): the raw commit messages are the body. `%B`
     is a commit's raw message (subject + blank line + body, ending in a
     newline); the trailing `%n` plus the newline `git log` adds after each
     entry separate consecutive commits with blank lines, as in the example in
     [Commit Mode](#commit-mode):

     ```sh
     git log --reverse --format='%B%n' "origin/$base..HEAD"
     ```

3. Check for an existing pull request:

   ```sh
   gh pr view --json url
   ```

4. If **no** pull request exists (the command above fails), ask the user whether
   one should be created. Only continue if the user confirms. Create it as a
   **draft**, using the title from [Title](#title) and the body built in step 2
   (pipe the body in via `--body-file -`):

   ```sh
   # $title is set as described in the Title section.
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

   Then check the title:
   - In **commit mode**, or in **template mode with a single commit**, leave the
     title unchanged unless the first commit's subject changed.
   - In **template mode with multiple commits** (e.g. after commits were added
     to a PR that had a single commit), generate the title as described in
     [Title](#title). If it differs from the current title, show both and ask
     the user before updating, since the current title may have been edited by
     hand:

     ```sh
     gh pr edit --title "$title"
     ```

   If a single commit has no body, its contribution is just the subject line.
