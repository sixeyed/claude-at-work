# Chapter 9 — Scaling with a software factory

Nine sessions in this chapter, which turn the chapter 8 delivery team into a software factory. Features get written as GitHub issues, a GitHub Actions workflow runs the team on a hosted runner, and the run ends with a pull request full of proofs, a live preview environment and a Slack message. The code, workflows and agents are all in the project repo, **https://github.com/sixeyed/claude-at-work-project**. What's here is the transcripts.

## The sessions

They ran between 15 and 21 October 2026. The timings and token counts come from the sessions' own logs, and each transcript has a timing breakdown at the end.

| Transcript | Section | Ran for | What happened |
| --- | --- | --- | --- |
| [`01-preview-deployment.md`](conversations/01-preview-deployment.md) | 9.3: *Try it now: create the local preview* | 4h 42m, ~2h active | Issue 6 written with the `issue-writer` skill and delivered by the team: a k3d namespace per branch, made public with Cloudflare quick tunnels. Testing from the public URL found two older bugs |
| [`02-acceptance-review-agent.md`](conversations/02-acceptance-review-agent.md) | 9.5: *Try it now: build the acceptance reviewer agent* | ~4h over two days | A seventh agent that deploys the preview, runs the smoke pack and its own feature pack, and writes the proof. Rerunning its tests against unfixed `main` showed two of three "passes" proved nothing |
| [`03-issue-writer-gh.md`](conversations/03-issue-writer-gh.md) | 9.7: *Try it now: start the factory's migration to GitHub* | ~2h across three sittings | `tools/delivery`, a Python library with local and GitHub backends, and the `issue-writer` skill rewritten to post real issues. It was tightened twice from the issues written in sessions 04 and 05 |
| [`04-first-gh-issue.md`](conversations/04-first-gh-issue.md) | 9.8: *Try it now: test out the new issue-writer skill* | 72m, ~6m of Claude working | The first issue written straight to GitHub: letting users change their display name |
| [`05-first-gh-issue-v2.md`](conversations/05-first-gh-issue-v2.md) | 9.8 | 2h 25m, ~43m of exchange | The same idea again from scratch, with the improved skill. A different path through the grilling reached the same points |
| [`06-deliver-script-to-gh.md`](conversations/06-deliver-script-to-gh.md) | 9.10: *Try it now: rewrite the Bash delivery script in Python* | 62m | A golden fixture of 560 cases captured from the Bash, then the Python port built test-first. A background review found five real bugs |
| [`07-gh-actions-workflow.md`](conversations/07-gh-actions-workflow.md) | 9.11: *Try it now: write and run the GitHub workflow* | Four days, mostly watching runs | The workflow on a hosted runner, with a commit after every stage so a run can outlive its VM. Includes the first real delivery in GitHub and test-writer sketching, which was tried, measured and taken out again |
| [`08-delivery-pr.md`](conversations/08-delivery-pr.md) | 9.13: *Try it now: wrap up the factory process* | ~12h over two days | The PR opened from the proof, a second workflow holding the preview open, and Slack for notifications and preview passwords |
| [`09-github-actions-workflow.md`](conversations/09-github-actions-workflow.md) | 9.13 | 3h 45m, mostly waiting | Moving from the trial fork to the real repo, using the prerequisites doc and checker. It ends with a real issue delivered end to end and merged as [PR #7](https://github.com/sixeyed/claude-at-work-project/pull/7) |

Sessions 03, 04 and 05 overlap. I wrote the two GitHub issues in separate sessions while 03 was paused, then went back to 03 to review them and fix the skill. Sessions 07 and 09 are the same Claude Code session, picked up again after the PR work in 08.

Most of the GitHub work ran on a fork, [`caw-project/ch09`](https://github.com/caw-project/ch09), so I could experiment without filling the project repo with trial runs. That fork is still there, along with its issues, branches and unmerged PRs.

## Reading them

A few that are worth your time if you don't want to read everything:

- **[`02-acceptance-review-agent.md`](conversations/02-acceptance-review-agent.md)** for grading the grader. The acceptance reviewer said its tests passed, so Claude ran them against a preview of the unfixed code to check whether they would have failed.
- **[`06-deliver-script-to-gh.md`](conversations/06-deliver-script-to-gh.md)** for a rewrite done safely. Claude captured every branch of the Bash logic before writing any Python, then proved the port against it.
- **[`07-gh-actions-workflow.md`](conversations/07-gh-actions-workflow.md)** for the long view. It covers a factory running for days, the context compacting three times, and improvements based on data from eight deliveries' send-backs.
- **[`09-github-actions-workflow.md`](conversations/09-github-actions-workflow.md)** if you're setting up your own factory. It goes from an empty repo to a merged PR, following the prerequisites doc.

## Not in the repo

The agents are in the project repo under [`.claude/agents`](https://github.com/sixeyed/claude-at-work-project/tree/main/.claude/agents), now including `acceptance-reviewer.md`. The delivery engine is in `tools/delivery`, and `scripts/deliver.sh` is now a thin wrapper around it. The workflows are [`.github/workflows/deliver.yml`](https://github.com/sixeyed/claude-at-work-project/blob/main/.github/workflows/deliver.yml) and [`preview.yml`](https://github.com/sixeyed/claude-at-work-project/blob/main/.github/workflows/preview.yml). What you need to run the factory in your own repo is in [`docs/delivery/prerequisites.md`](https://github.com/sixeyed/claude-at-work-project/blob/main/docs/delivery/prerequisites.md). The designs, plans and handoff docs for each slice are in [`docs/plans/ch09`](https://github.com/sixeyed/claude-at-work-project/tree/main/docs/plans/ch09).

[PR #7](https://github.com/sixeyed/claude-at-work-project/pull/7) in the project repo is the factory's first delivery there. It shows the full review pack from the acceptance reviewer, including the screenshots.

The project repo has tags at each stage of the chapter:

| Tag | Where it is |
| --- | --- |
| `ch09` | Where the chapter starts, which is the end of chapter 8 |
| `ch09-preview` | Preview environments on Cloudflare quick tunnels (issue 6) |
| `ch09-acceptance-reviewer` | The acceptance reviewer, with issue 7 delivered |
| `ch09-github-issues` | Issues behind a pluggable backend, local or GitHub |
| `ch09-python-runner` | The delivery runner ported to Python |
| `ch09-github-workflow` | The delivery workflow in GitHub Actions |
| `ch09-pr-proofs` | PRs with proofs, held previews and Slack |
| `ch09-full` | The end of the chapter, with the display name feature merged |

```
git clone https://github.com/sixeyed/claude-at-work-project.git
git checkout ch09
```
