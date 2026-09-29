# Chapter 7 — Developing in parallel with high quality

Fifteen sessions in this chapter, and most of them overlap. The chapter is about scaling up safely: quality gates enforced with hooks, agents working side by side in Git worktrees, test-driven development, a test pyramid built by three agents at once under remote control, and then a stretch of work to check whether any of it holds up. The code, hooks, plans and test report are all in the project repo, **https://github.com/sixeyed/claude-at-work-project**. What's here is the transcripts.

## The sessions

They ran between 12 and 17 September 2026. The timings and token counts come from the sessions' own logs — each transcript has a timing breakdown at the end.

| Transcript | Section | Ran for | What happened |
| --- | --- | --- | --- |
| [`01-quality-gates.md`](conversations/01-quality-gates.md) | 7.3 — *Try it now: add linting and static analysis hooks* | ~40m active | Lint on every edit, advisory security checks at the end of each turn, then a deliberately bad function to see what Claude does when a hook blocks |
| [`02-search.md`](conversations/02-search.md) | 7.5 — *Try it now: run three Claude Code sessions* | 1h 43m | Message search, out of band through the Worker into Elasticsearch. The live end-to-end run found a bug the unit and integration suites couldn't |
| [`03-helm.md`](conversations/03-helm.md) | 7.5 | 1h 41m, then 11m | KEDA, session affinity and NetworkPolicy in the Helm chart. Two design problems and a new decision, and the next morning a merge conflict with the search PR |
| [`04-scripts.md`](conversations/04-scripts.md) | 7.5 | 1h 56m, then 20m | Build, test and deploy scripts. The first real install of the Helm chart turned up five bugs, and the final merge found one in another agent's PR |
| [`05-tdd.md`](conversations/05-tdd.md) | 7.7 — *Try it now: start work on a new feature with TDD* | 37m, then 48m | Read markers and unread counts, red-green-refactor, with a stop at red for review |
| [`06-test-framework.md`](conversations/06-test-framework.md) | 7.9 — *Try it now: build the test framework* | 2h 19m | The test pyramid's foundation, built by subagents, ending with three handoff docs — one per layer |
| [`07-unit-tests.md`](conversations/07-unit-tests.md) | 7.11 — *Try it now: manage Claude Code centrally with remote control* | ~30m of work | The unit layer, from its handoff doc, with no stops for review |
| [`08-integration-tests.md`](conversations/08-integration-tests.md) | 7.11 | ~50m of work | The integration layer on Testcontainers. Merging the unit agent's work turned up a real bug in the Worker |
| [`09-e2e-tests.md`](conversations/09-e2e-tests.md) | 7.11 | ~70m of work | The end-to-end layer: 43 BDD tests triaged down to 15 key journeys, and a flaky test traced to two real message-loss races in the SPA |
| [`10-test-review.md`](conversations/10-test-review.md) | 7.11 | 2h 24m | Parallel audits of the finished pyramid, seven confirmed bugs pinned by failing tests and then fixed |
| [`11-debugging-prep.md`](conversations/11-debugging-prep.md) | Cut from the book | 57m | Finding somewhere a bug could hide from every test, and planting one |
| [`12-debugging.md`](conversations/12-debugging.md) | Cut from the book | 13m | A fresh agent in a separate checkout, given only the bug report, using the `systematic-debugging` skill |
| [`13-reactions.md`](conversations/13-reactions.md) | 7.12 — *Your turn* | ~2h 25m of work | Message reactions end to end — the first normal feature with the whole pyramid in place |
| [`14-portable-deployment.md`](conversations/14-portable-deployment.md) | 7.12 | ~6h 25m of work | Making the app deployable anywhere but the laptop, with an acceptance test of two instances on one cluster |
| [`15-test-report.md`](conversations/15-test-report.md) | 7.12 | ~20m of Claude working | A Markdown test report written by every test run, committed to git until there's CI to host one |

Sessions 11 and 12 are a debugging exercise that didn't make the final chapter: one agent plants a bug where no test can see it, and a second agent with none of that context has to find it. They're left here because they're worth reading, but you won't find them in the book.

Sessions 02, 03 and 04 ran at the same time, one terminal each. So did 07, 08 and 09, all driven from Claude Desktop through remote control — the transcripts cross-reference each other where one agent's notes reach another.

## Reading them

A few worth your time if you don't want to read everything:

- **[`01-quality-gates.md`](conversations/01-quality-gates.md)** for the hook test from section 7.3. I added a lint-failing function and asked for a comments-only review, expecting Claude to fix my code. It deleted the function instead, because nothing called it.
- **[`04-scripts.md`](conversations/04-scripts.md)** for what happens when the last of three parallel PRs has to merge on top of the other two. The merge resolved cleanly and the chart still wouldn't deploy.
- **[`05-tdd.md`](conversations/05-tdd.md)** for the red-test summary in listing 7.2, and the refactor summary in listing 7.3 — the part of TDD that's easy to skip, and where Claude actually thought about maintainability.
- **[`09-e2e-tests.md`](conversations/09-e2e-tests.md)** for the flaky test. The easy answer was a retry, and the real answer was two bugs in the app.
- **[`11-debugging-prep.md`](conversations/11-debugging-prep.md)** and **[`12-debugging.md`](conversations/12-debugging.md)** as a pair — cut from the book, but kept here. The first session spent an hour finding a bug no test would catch; the second found and fixed it in 13 minutes, test-first.

## Not in the repo

The hooks are in the project repo under `.claude/hooks`, wired up in `.claude/settings.json`. The designs, implementation plans and the three handoff docs from section 7.9 are under [`docs/plans/ch07/`](https://github.com/sixeyed/claude-at-work-project/tree/main/docs/plans/ch07), and the latest test report is [`docs/test-report.md`](https://github.com/sixeyed/claude-at-work-project/blob/main/docs/test-report.md).

The project repo has tags at each stage of the chapter:

| Tag | Where it is |
| --- | --- |
| `ch07` | Where the chapter starts — the end of chapter 6 |
| `ch07-hooks` | The lint and security hooks in place |
| `ch07-parallel` | All three worktree PRs merged — search, Helm and scripts |
| `ch07-tdd` | Read markers merged |
| `ch07-framework` | The test pyramid's foundation, with the handoff docs |
| `ch07-remote` | All three test layers built, and the gaps from the review fixed |
| `ch07-full` | Reactions, portable deployment and the test report — the end of the chapter |

At `ch07-remote` the suite is 375 unit tests, 356 integration and 18 end-to-end. By `ch07-full` it's 467, 381 and 19.

```
git clone https://github.com/sixeyed/claude-at-work-project.git
git checkout ch07
```
