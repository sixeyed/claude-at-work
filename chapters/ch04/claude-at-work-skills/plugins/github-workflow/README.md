# github-workflow

GitHub development workflow skills for Claude:

- **create-issue** — turn a decision, task, bug, or open question into a well-formed GitHub issue.
- **work-on-issue** — pick up an issue, create a branch, and implement it following repo conventions.
- **create-pr** — push the branch and open a pull request linked to its issue.

None of these skills merge, force-push, or push to the default branch.

## How the skills reach GitHub

- **create-issue → `gh` CLI if present, otherwise a prefilled browser link.** In Claude Code it creates the issue directly with `gh`. Everywhere else (Claude Desktop, Cowork) it drafts the issue and hands you a `github.com/.../issues/new` link with the title and body already filled in — you review and click **Submit new issue** in a browser where you're signed in to GitHub.
- **work-on-issue and create-pr → `git` and the `gh` CLI.** They run in Claude Code against a real local clone.

**No GitHub connector is used — deliberately.** GitHub MCP connectors authenticate as GitHub Apps, and app tokens can only write to repos covered by your app installation; a repo being public isn't enough. That means connector-based issue creation works on your own repos and fails with *403 "Resource not accessible by integration"* on anyone else's — including public practice repos. The `gh` CLI has no such limit (its token acts with your full user rights), and the browser link needs no token at all, so those are the only two paths the skills use.

## Setup

Nothing to set up for the browser-link path — just be signed in to GitHub in your browser.

For Claude Code, install and authenticate the `gh` CLI:

```bash
gh auth status   # already logged in?
gh auth login    # if not
```

work-on-issue and create-pr derive `owner/repo` from `git remote get-url origin`, so run them from inside the clone.

## Practice repo

If you're learning and just want to see the workflow succeed, create-issue defaults to the public practice repo **[sixeyed/claude-at-work-scratchpad](https://github.com/sixeyed/claude-at-work-scratchpad)** when you haven't named a repo. Anyone with a GitHub account can open issues there — it exists so there's nothing to break.

## Troubleshooting

- **Claude tried to use a GitHub connector and got a 403** — the skills say not to; point Claude back at the skill. The fix is never to authorize more connectors: use `gh` or the prefilled link.
- **The prefilled link opens an empty issue form** — the URL was probably truncated (very long bodies). Ask Claude for a shorter body, or paste the drafted text in manually.
- **Labels missing on an issue** — labels are only applied via `gh` on repos you can push to; GitHub drops them from non-collaborators, so the skill skips them elsewhere. That's expected on the practice repo.
- **work-on-issue / create-pr can't reach GitHub** — check `gh auth status`; run `gh auth login` if needed.
- **A skill says there's no git remote** — work-on-issue and create-pr derive `owner/repo` from `git remote get-url origin`; add the remote if it's missing. create-issue takes `owner/repo` from what you tell it when there's no remote to read.
