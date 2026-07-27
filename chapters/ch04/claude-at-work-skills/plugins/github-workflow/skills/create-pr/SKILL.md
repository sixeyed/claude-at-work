---
name: create-pr
description: Use when the user asks to open a pull request for the current branch — "create a PR", "open a pull request", "raise a PR for this branch".
---

# Create PR

Push the current branch and open a pull request linked to its issue. Create and read only — this skill never merges, never enables auto-merge, never force-pushes, never pushes to the default branch.

This skill runs in Claude Code against a real local clone, so it uses **`git` and the `gh` CLI** — that's the path for pushing, running tests, and opening the PR. The bundled `github-workflow` connector is not needed here; don't reach for it.

## Preflight

1. **Find your tools:** confirm `gh` is installed and authenticated (`gh auth status`). If it isn't, stop and tell the user to run `gh auth login` — this skill needs it to open the PR.
2. **Find the repo:** derive `owner/repo` from `git remote get-url origin`. No remote? Stop and tell the user to push the repo to GitHub first.
3. **Check the branch:** if the current branch is the default branch (`main`/`master`), stop — there's nothing to raise a PR from, and this skill never pushes to the default branch.

## Steps

1. Find the linked issue: from the branch name (`issue-NN-...`), the commit messages, or an issue reference the user gave. No issue is fine — not every PR needs one.
2. **Run the tests. If any test fails, stop.** Report the failure and go no further: no push, no PR, and no draft PR either — a draft with a known-red test is still publishing broken work, and fixing the test first is always the better path. The tests must pass before anything leaves the machine.
3. Push the branch (`git push -u origin <branch>`).
4. Draft the PR:
   - **Title:** from the issue title or the change itself, imperative
   - **Body:** a summary of what changed and why; `Closes #NN` when an issue is linked (so the merge closes it); and how the change was tested
   - Write the body for a reviewer who hasn't seen the conversation — automated review reads exactly what you put here.
5. Create the PR against the default branch with `gh pr create`.

## Never

Merge the PR, enable auto-merge, or force-push. Opening the PR is where this skill ends — review and merge belong to humans (and to whatever automated review the repo runs on new PRs).

## Report

End by reporting the PR number and URL, the linked issue if there is one, and the test results that cleared the push.
