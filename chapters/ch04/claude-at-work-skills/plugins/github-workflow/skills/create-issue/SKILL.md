---
name: create-issue
description: >-
  Use when the user wants to record a decision, task, bug, or open question as
  a GitHub issue — "create an issue", "raise an issue", "track this on GitHub",
  "turn this decision into an issue" — or wants to practice issue creation
  while learning to work with Claude: "try creating an issue", "raise a test
  issue". Works everywhere: uses the gh CLI when available (Claude Code),
  otherwise hands the user a prefilled link to submit in their browser.
---

# Create Issue

Turn a decision, task, bug, or open question into a well-formed GitHub issue.
Create and read only — this skill never merges, never pushes, never deletes
anything.

## Two paths, no connectors

1. **`gh` CLI** — check `gh auth status`. If it's installed and authenticated
   (typical in Claude Code), create the issue directly:

   ```
   gh issue create --repo {owner}/{repo} --title "..." --body "..."
   ```

2. **Prefilled browser link** — everywhere else (Claude Desktop, Cowork, or
   Claude Code without `gh`). Draft the issue, then build a link the user
   opens in their own browser, where they're already signed in to GitHub:

   ```
   https://github.com/{owner}/{repo}/issues/new?title={encoded}&body={encoded}
   ```

   URL-encode the title and body (a one-liner with Python's
   `urllib.parse.urlencode` gets the encoding right — newlines, `#`, `&` and
   all). Keep the body compact; very long URLs get truncated. Present the link
   and tell the user the drafted issue is waiting — they just review and click
   **Submit new issue**.

**Do not create the issue through a GitHub MCP connector, even if one is
connected.** This is deliberate, not an oversight. GitHub connectors
authenticate as GitHub Apps, and app tokens can only write to repos covered by
the user's app installation — a repo being public isn't enough. That makes the
connector path fail unpredictably: it works on the user's own repos and 403s
("Resource not accessible by integration") on everyone else's, including
public practice repos. The two paths above behave the same for every user, so
use them and nothing else.

## Find the repo

Establish `owner/repo` for the target:

- With `gh` and a local clone, derive it from `git remote get-url origin`.
- Otherwise, take it from what the user told you.
- If the user has no repo in mind — they're learning and just want to see the
  workflow succeed — use the public practice repo
  **`sixeyed/claude-at-work-scratchpad`**. It exists for exactly this, so
  there's nothing to break and duplicates don't matter.
- If it's genuinely unclear and it's not a practice run, ask — don't guess a
  repo name.

## Drafting the issue

1. Read the source material — the doc, register entry, or conversation the
   user pointed at. Base the issue on what it actually says, not on your
   summary of the topic. For a practice run there may be no source material —
   a short note saying what the user was trying out is a perfectly good issue.
2. On a real repo with `gh`, check for an existing issue covering the same
   item (`gh issue list --search ...`) and report a match instead of creating
   a duplicate. Skip this on the practice repo — it's a scratchpad.
3. Draft the title in the **imperative** — the issue is a unit of work, so
   name the work:
   - ✅ `Decide multi-workspace tenancy model`
   - ✅ `Fix login lockout reset`
   - ❌ `Decision needed: multi-workspace tenancy` (a status, not an action)
4. Draft the body with this shape:
   - **Context** — where this came from, with a link to the source doc if
     there is one
   - **Options** — for decisions: each option with its trade-offs
   - **What needs deciding / doing** — a checklist of the open questions or
     acceptance criteria

   Keep it free of secrets and personal details — issues on public repos are
   readable by anyone.
5. **Labels — `gh` path only, and only on repos the user can push to.** Apply
   one label: `decision` for decisions, `bug` or `enhancement` otherwise;
   create it first if it doesn't exist. On someone else's repo (including the
   practice repo), skip labels — GitHub drops them from non-collaborators.

## Out of scope

Assignees, milestones, and projects — leave them for the user. If they ask for
those in the same breath, create the issue first, then let them know those
steps are theirs.

## Report

- **`gh` path:** report the issue number and the full URL, and one line on
  what the body covers.
- **Link path:** present the prefilled URL, one line on what the drafted body
  covers, and remind the user the last step is theirs — review and click
  **Submit new issue**.
