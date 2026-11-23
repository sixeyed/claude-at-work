# Chapter 8 — Building out your AI team

Nine sessions in this chapter. Most of them build or tune a team of custom agents (plan-writer, plan-reviewer, test-writer, test-reviewer, code-writer and code-reviewer), coordinated by a workflow script that runs `claude --agent` through each stage. The rest put that team to work on real features. The agents, the script and the issues are all in the project repo, **https://github.com/sixeyed/claude-at-work-project**. What's here is the transcripts, a couple of toy agents from section 8.1, and the inputs and outputs I used to build the reviewers.

## The sessions

They ran between 29 September and 2 October 2026. The timings and token counts come from the sessions' own logs, and each transcript has a timing breakdown at the end.

| Transcript | Section | Ran for | What happened |
| --- | --- | --- | --- |
| [`01-plan-writer-agent.md`](conversations/01-plan-writer-agent.md) | 8.4: *Try it now: build the first draft of the plan-writer prompt* | 30m | The workflow script as a state machine, tested against a fake `claude`, and the plan-writer agent. Then my correction: build an exemplar plan rather than letting the agent pick an old one |
| [`02-review-pair-done.md`](conversations/02-review-pair-done.md) | 8.6 – 8.8: *Use grilling to build out a complete feature request* and *Build the plan-reviewer agent prompt* | ~5h 40m over two days | Grilling issue 1 into shape, the first real `deliver.sh` runs, three plans for the same issue compared, and the plan-reviewer built over four iterations, ending with "expectations first" |
| [`02-test-pair.md`](conversations/02-test-pair.md) | 8.9: *The rest of the team* | 3h 17m | The test pair. Tests that are red at the gate but can never pass led to a reviewer that sketches a throwaway implementation |
| [`03-code-pair.md`](conversations/03-code-pair.md) | 8.9 – 8.10: *A custom issue-writer skill* | 3h 35m, then 8m | The code pair, the `send_back` route to an earlier pair, a bug no reviewer prompt could reliably catch, and the `issue-writer` skill that designed it out of the issue |
| [`04-team-review-1.md`](conversations/04-team-review-1.md) | 8.12: *Run a team performance review* | ~7h over two days | Fable reviews the whole team: four builds of issue 1 from scratch, none of which stopped for a human, then a blind comparison against plain Claude sessions |
| [`05-team-review-2.md`](conversations/05-team-review-2.md) | 8.12 | 6h 32m | Models and effort. Fourteen builds of issue 1 in four rounds, each judged blind, ending with Opus for planning and code review and Sonnet for the rest |
| [`06-issue-002-spec.md`](conversations/06-issue-002-spec.md) | 8.13: *Your turn* | 29m, then 3m | Issue 2, the search UI, written with the `issue-writer` skill |
| [`07-issue-003-spec.md`](conversations/07-issue-003-spec.md) | 8.13 | 31m | Issue 3, message threads, written while issue 2 was waiting to be built |
| [`08-issue-004-spec.md`](conversations/08-issue-004-spec.md) | 8.13 | 24m | Issue 4, file attachments, the first full-stack issue |
| [`09-feature-merge.md`](conversations/09-feature-merge.md) | 8.13 | 56m, ~12m of Claude working | Merging the three features the teams built in parallel. The conflicts resolved cleanly, but two tests showed the features really did clash |

Section 8.9 only summarizes the test pair and code pair sessions. If you want the detail it skips, the full sessions are here.

## Agents and outputs

| File | What it is |
| --- | --- |
| [`agents/recalcitrant-ro.md`](agents/recalcitrant-ro.md) | The unhelpful agent from listing 8.1. Run it with `claude --plugin-dir ./chapters/ch08 --agent recalcitrant-ro` |
| [`agents/on-strike.md`](agents/on-strike.md) | A stronger version that refuses everything. It's not in the book, but you can test how far it holds up |
| [`agent-output/01-implementation-plan-v1.md`](agent-output/01-implementation-plan-v1.md) – [`v3`](agent-output/01-implementation-plan-v3.md) | Three plans the plan-writer produced from the same issue. Section 8.8 uses the differences between them to build the plan-reviewer |
| [`issues/001-before-issue-writer.md`](issues/001-before-issue-writer.md) | Issue 1 as the grilling skill produced it in section 8.6 |
| [`issues/001-after-issue-writer.md`](issues/001-after-issue-writer.md) | The same issue rewritten as if the `issue-writer` skill had produced it. Compare the two to see what the skill adds |

## Reading them

A few that are worth your time if you don't want to read everything:

- **[`02-review-pair-done.md`](conversations/02-review-pair-done.md)** shows the plan-reviewer iterations. The order the reviewer reads in matters: reading the plan before the issue anchored its review on the plan's own wording.
- **[`03-code-pair.md`](conversations/03-code-pair.md)** shows where tuning prompts stopped helping. The code-reviewer caught the shared bug one time in four, then two in three, and the fix turned out to be the issue rather than the reviewer.
- **[`04-team-review-1.md`](conversations/04-team-review-1.md)** covers the *Bitter Lesson* sidebar in practice. I asked whether the team does any better than a plain session, Claude built a control to find out, and a blind review found the same bug in all seven builds and no difference between them.
- **[`05-team-review-2.md`](conversations/05-team-review-2.md)** is the nine-hour experiment run with almost no input from me, and it's where the 60 minute, $21 configuration came from.
- **[`09-feature-merge.md`](conversations/09-feature-merge.md)** shows Claude backing out a merge from `main` instead of fixing code there, which is the right call when two parallel features clash.

## Not in the repo

The agent prompts are in the project repo under [`.claude/agents`](https://github.com/sixeyed/claude-at-work-project/tree/main/.claude/agents), and the context they all share is in `.claude/delivery/agent-context.md`. The workflow script is `scripts/deliver.sh`. The exemplar plan is [`docs/plans/exemplar-implementation-plan.md`](https://github.com/sixeyed/claude-at-work-project/blob/main/docs/plans/exemplar-implementation-plan.md), and the `issue-writer` skill is under `.claude/skills/issue-writer`. Issues 1 to 4 and the exemplar issue are in [`docs/issues`](https://github.com/sixeyed/claude-at-work-project/tree/main/docs/issues). The handoff docs between sessions are in [`docs/plans/ch08`](https://github.com/sixeyed/claude-at-work-project/tree/main/docs/plans/ch08).

The project repo has tags at each stage of the chapter:

| Tag | Where it is |
| --- | --- |
| `ch08` | Where the chapter starts, which is the end of chapter 7 |
| `ch08-plan-writer` | The workflow script and the plan-writer |
| `ch08-plan-reviewer` | The plan pair complete, with the shared agent context |
| `ch08-issue-writer` | All six agents, and the `issue-writer` skill |
| `ch08-team-review` | Both review rounds merged, with the per-stage models and effort |
| `ch08-issue-2`, `ch08-issue-3`, `ch08-issue-4` | Each feature merged as the team delivered it: search, threads and attachments |
| `ch08-features` | All three features in (the same commit as `ch08-issue-4`) |
| `ch08-full` | The end of the chapter, after the semgrep waiver |

```
git clone https://github.com/sixeyed/claude-at-work-project.git
git checkout ch08
```
