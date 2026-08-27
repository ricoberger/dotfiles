---
name: github-pr-create
description:
  Create or update the pull request for the current branch. Creates a draft PR
  titled from the first commit's subject and keeps the PR body in sync with the
  exact commit messages on the branch. Use after committing, or when asked to
  "create a PR", "open a pull request", or "update the PR body/description".
---

# GitHub Pull Request Creation

Check whether a pull request already exists for the current branch. Create one
if it does not, and always keep its body in sync with the commits on the branch.

## Body Format

The pull request body is built from **all** commits on the branch. Each commit
contributes its full message (subject line, blank line, body), and commits are
separated from one another by blank lines, in chronological order (oldest
first):

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

1. Determine the base branch and build the body from every commit on the branch.
   `%B` is a commit's raw message (subject + blank line + body), and the
   trailing `%n%n` separates consecutive commits with a blank line:

   ```sh
   base="$(gh pr view --json baseRefName --jq .baseRefName 2>/dev/null \
     || git remote show origin | sed -n 's/.*HEAD branch: //p')"
   git log --reverse --format='%B%n' "origin/$base..HEAD"
   ```

2. Check for an existing pull request:

   ```sh
   gh pr view --json url
   ```

3. If **no** pull request exists (the command above fails), ask the user whether
   one should be created. Only continue if the user confirms. Create it as a
   **draft**, using the first commit's subject as the title and the generated
   body:

   ```sh
   git log --reverse --format='%B%n' "origin/$base..HEAD" | gh pr create \
     --draft --title "$(git log --reverse --format='%s' "origin/$base..HEAD" \
     | head -n1)" --body-file -
   ```

4. If a pull request **already** exists, refresh its body so it includes every
   commit on the branch (this matters when the branch has more than one commit,
   or after adding commits to an existing pull request):

   ```sh
   git log --reverse --format='%B%n' "origin/$base..HEAD" | gh pr edit --body-file -
   ```

   Leave the title unchanged unless the first commit's subject changed. If a
   single commit has no body, its contribution is just the subject line.
