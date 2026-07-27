---
name: work-on-issue
description: Use when the user asks to implement a GitHub issue — "work on issue N", "pick up #N", "implement issue N", "fix #N".
---

# Work on Issue

Pick up a GitHub issue, implement it on a branch, and leave the work committed locally. Create and read only — this skill never merges, never commits to the default branch, never deletes anything.

This skill runs in Claude Code against a real local clone, so it uses **`git` and the `gh` CLI** — that's the path for reading the issue, branching, and committing. The bundled `github-workflow` connector is not needed here; don't reach for it.

## Preflight — refuse to start if the tree isn't clean

1. **Find your tools:** confirm `gh` is installed and authenticated (`gh auth status`). If it isn't, stop and tell the user to run `gh auth login` — this skill needs it to read the issue.
2. **Find the repo:** derive `owner/repo` from `git remote get-url origin`. No remote? Stop and tell the user to push the repo to GitHub first.
3. **Check the working tree:** if `git status` shows uncommitted changes, **stop before doing anything else**. Show the user what's modified and let them decide — stash, commit, or discard is their call, especially when the changes touch files the issue needs. Do not stash or discard on their behalf.

## Steps

1. Fetch the issue and all its comments (`gh issue view N --comments`) — the comments often carry the real acceptance criteria. If the user gave words instead of a number, search for the issue and confirm you found the right one.
2. Confirm you understand the scope. If the issue is ambiguous, ask before writing code — a wrong branch is more expensive than a question.
3. Update the default branch (`git pull`), then create a branch named `issue-NN-short-slug`, e.g. `issue-14-auth-rate-limiting`. Always this pattern — the number links the branch to the issue for everyone who reads `git branch`.
4. Implement the change following the repo's `CLAUDE.md` conventions — code style, test framework, commit format all come from there, not from habit.
5. Run the tests. Don't move on until they pass.
6. Commit with messages that reference `#NN` so GitHub links the commits to the issue.

## Where this skill stops

**The last action is the final local commit.** Do not push. Do not open a pull request — not even as a favor, not even if it feels like the obvious next step. Pushing and raising the PR is the `create-pr` skill, and keeping it separate means the user takes that step deliberately. Finish by telling the user the branch name, what's committed, and that `create-pr` is ready when they are.

## Report

End by reporting: issue number and title, branch name, test results, and the commits made.
