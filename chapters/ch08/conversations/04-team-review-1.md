# Chat Transcript

**Topic:** A review of the whole delivery team — the six agent prompts, `scripts/deliver.sh` and
the shared context — so that it delivers an issue without stopping for a human, four builds of
issue 1 from scratch to see whether it does, and then the question of whether the team is worth
having at all. This session covers:
- reading everything the earlier sessions left, and the last full run's transcripts
- the script: a reviewer's send-back that keeps its own review, send-backs that never land in a
  final round, turn caps by stage, a stage resumed when it runs out of turns, and a fake
  `claude` that proves the state machine
- the prompts: "decide, record, carry on" in place of most stops, rework passes, and Python
  sketches for the reviewers
- four runs of issue 1, none of which stopped — and the user's question about tuning for this
  issue, which found wording in the prompts drawn from issue 1's own faults
- the user's next question — is the team better than a plain session? — and a control built to
  answer it: three plain sessions in repos with no trace of the team, and a blind review of all
  seven builds, which found the same bug in every one and no difference between them
- what follows from that: how much the agents repeat each other's reading, whether the team
  could be generated for another repo, and a single session driven phase by phase from outside

**Date:** 1 October 2026, with a follow-up on 2 October
**Project:** `caw-project` — CollabHub, the *Claude at Work* sample project
**Model:** Claude Fable 5.1, Claude Code CLI, and, outside the session, headless `claude -p`
runs on Opus 5.5 — the delivery agents, the plain sessions and the judges
**Session:** `c2b77952-3e47-449c-a8ab-41deb47086de` · 05:18–10:31 UTC (5h 13m), then
14:50–15:51 UTC, with a follow-up at 03:07–03:46 UTC the next morning

Messages are verbatim. Tool calls are summarised in italics — one note per run of them — so the
work is visible without pages of command output. About 75 tool calls ran in this session;
275,000 output tokens. The headless runs are separate processes: four builds by the team (44
stages, about $130), three by a plain session (about $21) and seven blind reviews (about $23).

Background-task notifications arrive in the JSONL as user records, but nobody typed them. They
appear here as italic notes inside the assistant turn they started. Most of the first day's
wall-clock time is agents running in the background.

This follows on from [`03-code-pair.md`](./03-code-pair.md), which left
`docs/plans/ch08/03-code-pair-handoff.md`.

*(`/clear`, then `/model` set to Fable 5.1 — the session starts with an empty context)*

---

## User

docs/plans/ch08/03-code-pair-handoff.md - we have implemented the ai delivery team. review all the agent prompts, script and shared docs. these need to be generic, performant, and optimized so we can run the team to deliver any issue without escalating via needs-human.  make any fixes you think are warranted and do a full run of issue 001. iterate with new worktrees building the issue from scratch until the team reliably delivers.

---

## Assistant

*(read the handoff, `03-code-pair-handoff.md`, and listed the delivery team's files; then read `scripts/deliver.sh` (634 lines), the shared `agent-context.md` (299 lines), `sketch.sh`, all six agent prompts, issue 001 and the two earlier handoffs, in full)*

Read the handoffs, `deliver.sh`, the shared context and all six agent prompts. Next I'm checking the last full run's transcripts for wasted turns and stops before changing anything.

*(looked at what the last full run left in `../caw-issue-1` — 16 stage results, its `history.log` and state — and counted tool calls, refusals and repeated reads in seven of its stage transcripts: refusals were rare, one or two a stage; found Docker running the k3d cluster)*

*(created the worktree `../caw-delivery-tune` on `feature/delivery-tune`; read `scripts/test.sh` and testkit's plugin and report to see how a layer with no results is reported — "not run"; copied the `messaging` service under `build/sketch/` with the copy first on `PYTHONPATH` and ran its 94 unit tests there, which imported the copy; skimmed the exemplar plan's headings and checked the CLI has `--resume` and `--effort`)*

*(patched `scripts/deliver.sh` in three passes with Python scripts that assert each replaced string: the header and settings — `DELIVER_RUN`, `DELIVER_MAX_SENDBACKS`, `DELIVER_REWORK_MAX_TURNS`; per-pair `FINAL_`, `SENDBACKS_`, `PENDING_` and per-sender `SB_` state; turn caps by stage; tool lists and write scopes; `Rework pass` and `Changed since the send-back` in the context block; `run_stage` rewritten to rerun a stage that returns nothing and to resume one that runs out of turns; the send-back case; time, turns and cost in `history.log`)*

*(wrote `.claude/delivery/loop-test.sh` — a fake `claude` that takes scripted verdicts, and 13 scenarios — and ran it: two failures, both in the test. `nested-sendbacks` was given two verdicts too many; and a resumed fake had no context block to find its plan path in. Fixed the count, had the resumed fake read the block its first run was given, and reran: the out-of-turns scenario still failed)*

Debugging the last loop-test scenario (the out-of-turns resume in the fake `claude`); the other twelve pass.

*(read the fake's lines: its `grep -v resumed` threw away every log file, because the scenario's own directory is named `out-of-turns-resumed`; anchored the filter to `-resumed.txt` and reran — "Every scenario passed.")*

*(checked the resume against the real CLI, with Haiku: a run capped at 2 turns ended `error_max_turns` with no structured output; `--resume` on its session id, with `--agent` and `--json-schema` again, returned `success` and the structured result)*

*(extended `sketch.sh` with `service <name>` and `pytest <paths>`, and tried it: copied `messaging`, changed `validate_name` in the copy to return the name upper-cased, and ran `test_channel_rules.py` in the copy — 7 failed, 17 passed; `diff` showed the one change; `clean` removed it)*

*(read the exemplar plan's decisions, corrections and verification sections; wrote the patch for `agent-context.md` — it failed on one string whose line break was not where the patch expected; looked at the exact lines, tried `cat -A`, which macOS doesn't have, fixed the patch and applied it)*

Shared context is patched. Now the six agent prompts, then the exemplar plan and CLAUDE.md.

*(patched the six agent prompts in one script, then a line in the code-writer that still said "stop for a human", the exemplar plan — an **assumed** decision row, e2e run once in the verification task — and `CLAUDE.md`'s delivery paragraph; reran the loop test: every scenario passed)*

*(wrote a run harness in the scratchpad: it creates `../caw-issue-1-<name>` on `feature/issue-1-<name>` from `main`, copies the eleven changed files over it, hides them from `git status` with `git update-index --skip-worktree`, and runs `scripts/deliver.sh` with `DELIVER_RUN`; started run r1 in the background and saw the plan-writer begin)*

Run r1 is under way: issue 1 from scratch in `../caw-issue-1-r1` (branch `feature/issue-1-r1`), with the revised delivery files laid over a fresh worktree from `main`. The existing `../caw-issue-1` is untouched.

Changes so far, all uncommitted in `../caw-delivery-tune` on `feature/delivery-tune`:

- **`scripts/deliver.sh`**
  - A reviewer's send-back now advances its own round, so its review is no longer overwritten, and its writer is handed that review when the flow comes forward.
  - A send-back never lands in a final round; a pair takes at most three send-backs (`DELIVER_MAX_SENDBACKS`) before a human sees the next.
  - Stages after a send-back are told which files changed since.
  - Turn caps are per stage (150–250), with 100 for rework passes and 60 for the final round.
  - A stage that runs out of turns is resumed once in the same session; a stage that dies without a result is rerun once.
  - `history.log` records time, turns and cost per step.
  - `DELIVER_RUN=<name>` builds the same issue again in a sibling worktree.
  - Writers can now `rm`, the code-writer can add dependencies, and the code pair can run ruff, helm and `bash -n` checks.
- **`.claude/delivery/loop-test.sh`** (new): a fake `claude` that proves the state machine; 13 scenarios pass.
- **`.claude/delivery/sketch.sh`**: now copies Python services too, so reviewers can sketch and mutate backend code. I checked it by hand on `messaging`; issue 1 won't exercise it.
- **Shared context and the six prompts**
  - A new "Decide, record, carry on" rule: agents settle gaps by the best-fitting reading and record them as **assumed** decisions.
  - `needs_human` is narrowed to four cases: a 🔴 dependency, a hard-to-undo choice with nothing written to favour a side, a broken environment, or a critical finding deadlocked in the final round.
  - Plan faults found late are sent back rather than stopped on.
  - New guidance on rework passes, batching tool calls, flaky tests, and not rereading `CLAUDE.md`.
  - The code-writer runs each `scripts/test.sh` layer once, with e2e unfiltered.
- **Exemplar plan and `CLAUDE.md`**: brought in line with the above.

A full run took about 95 minutes last time. I'll read the transcripts and reviews when r1 finishes, fix what it shows, and start the next run from scratch.

*(`/rename caw-ch08-team-review`, while r1 ran)*

*(69 minutes later, the background task finished: run r1, exit code 0)*

*(read r1's `history.log` and state: 12 steps, `STATUS=done`, no `needs-human.md`, one send-back by the code-reviewer; checked its tree — only source, tests, docs and the plan folder changed — and its test report: lint, unit 560 and e2e 20 passed, integration not run; counted API messages against tool calls in each stage's transcript, 23 messages for 75 calls in the plan-writer, so calls were batched; found the refused calls — reviewers trying `cp` and a `python3` heredoc to edit the sketch; reran r1's Vitest suite and read the code reviews' *Unpinned* and *Left for the human*)*

*(added `sketch.sh reset <path>` and, to both reviewers, "one turn a build": the Edit and the run in the same turn; started runs r2 and r3 in the background, 20 seconds apart)*

Run r1 delivered issue 1 from scratch with no stop for a human: 12 stages, about 85 minutes of stage time, $33.92 (the last full run before these changes took 16 stages, 95 minutes, $36.61).

- **Result:** Vitest 238/238 when the code-reviewer ran it; lint, 560 unit tests and 20/20 e2e journeys pass in the test report. Integration shows "not run", because the plan named only the layers an SPA-only change reaches.
- **Send-back worked as redesigned:** the code-reviewer found that a workspace switch sent a pending read on the old socket instead of dropping it. It sent that to the test pair for a red test, the code-writer fixed it, and the four rework passes took 8.8 minutes in total.
- **Assumed decisions:** the plan recorded ten, and the code-reviewer listed them under *Left for the human* in its final review.
- **Most expensive stage:** the test-reviewer, at 157 turns and $7.13, sketching 30 wrong builds one edit and one run at a time.

From that I made two small changes: reviewers are told to edit and run each sketch or mutant in one turn, and `sketch.sh reset <path>` restores a single file (both reviewers had tried `cp` and shell edits, which are refused).

Runs r2 and r3 are now building the issue from scratch in parallel, in `../caw-issue-1-r2` and `../caw-issue-1-r3`, to see whether the result holds across runs. I'll report when they finish.

---

## User

Ok how is performance looking? Average time to implement the feature successfully?

---

## Assistant

*(read both runs' logs and histories: each had its plan approved in round 2 and was in the test-writer)*

There is only one completed run with the revised team so far, so I can't give a real average yet: r1 took about 85 minutes of stage time and $33.92. Runs r2 and r3 are both about 25 minutes in, at the test-writer, with nothing going wrong.

| Run | Team | Outcome | Stages | Stage time | Cost |
|---|---|---|---|---|---|
| Rerun from the handoff | before these changes | delivered, no human stop | 16 | 95 min | $36.61 |
| r1 | revised | delivered, no human stop | 12 | 85 min | $33.92 |
| r2 | revised, plus the reviewer tweak | in progress, plan approved in round 2 | 4 so far | 22.9 min so far | $9.29 so far |
| r3 | revised, plus the reviewer tweak | in progress, plan approved in round 2 | 4 so far | 26.0 min so far | $10.48 so far |

Where r1's time went:

- **Plan pair:** 22.6 minutes over two rounds. All three revised runs needed two rounds, taking 22–26 minutes.
- **Test pair:** 31.6 minutes, approved in one round. The test-reviewer alone was 15.7 minutes and $7.13, the most expensive stage.
- **Code pair:** 21.5 minutes for the first build and review.
- **Send-back loop:** 8.8 minutes for all four rework passes after the code-reviewer's finding.

Two caveats on these numbers:

- **Parallel load:** r2 and r3 are running at the same time on one machine, so their times may run a little longer than a solo run, and they will queue for the e2e stack.
- **Wall-clock time:** the figures are stage time from each agent's own result; real elapsed time is slightly higher.

The one-turn-per-sketch change went in after r1, so r2 and r3 are the first test of whether it brings the test-reviewer's cost down. I'll give you the three-run average, and the spread, when they finish.

---

## User

how are we looking?

---

## Assistant

*(read both runs' logs and histories: r3 finished after 8 steps with exit 0; r2 was at step 14, the code-reviewer's second round, after a test-review round and a send-back)*

Good: r3 has finished and r2 is on its last stage, with no stop for a human in any of the three runs.

| Run | Outcome | Stages | Stage time | Cost |
|---|---|---|---|---|
| r1 | delivered | 12 | 85 min | $33.92 |
| r2 | final code review running | 13 so far | 73 min so far | $30.75 so far |
| r3 | delivered | 8 | 72 min | $30.32 |

Assuming r2's last review passes, the average is about 77 minutes and $32 per delivery, against 95 minutes and $36.61 for the run before these changes.

- **r3 went straight through.** The only rework was one plan round; the test and code pairs were each approved first time. Vitest 223/223 and e2e 20/20 per the code-reviewer.
- **r2 used two loops, both resolved by the team.** The test-reviewer found a poll test no correct build could pass. Later the code-reviewer found a real bug: returning to a channel via an empty one opened it at the top of its history, unread. That went back for a red test and a fix, and the three rework passes so far took 6 minutes.
- **The test-reviewer is cheaper but not leaner in turns.** It cost $4.12 and $5.74 in r2 and r3 against $7.13 in r1, though r3 still used 175 turns.
- **All three plans needed two rounds.** The plan-reviewer found a different major or critical fault in each first draft, so that round is doing real work rather than being overhead.

I haven't independently verified the r2 and r3 builds yet, and they ran in parallel on one machine, so solo times may be a little shorter. Once r2 finishes I'll check both trees and write up the handoff.

*(20 minutes later, the background task finished: runs r2 and r3, exit code 0)*

*(read r2's last lines — step 14, approved, exit 0 — then reran Vitest and the typecheck in r2 and r3: 210 and 223 tests passed, both typechecks clean; both test reports show lint, unit and e2e 20/20; no sketch left behind in either)*

---

## User

*(sent mid-turn)*

ok good. nothing in the agent specs or shared context which is specific tuning for this issue?

---

## Assistant

*(searched the six prompts and the shared context for issue 1's vocabulary — unread, divider, badge, throttle, poll, refetch, cached, return visit, reconnect: hits in the plan-reviewer's checklist items 2, 3, 6, 7 and 8, two phrases in the code-reviewer, and one line added to the plan-writer this session; read those passages, rewrote each to name the class of fault rather than issue 1's instance, reran the loop test and started run r4 in the background)*

There was some, yes — all of it wording that predates this session, and I've just generalised it. Nothing I added this session was tuned to issue 1, apart from one checklist line in the plan-writer that echoed the same wording.

What I found and changed:

- **plan-reviewer, "Words that need interpreting":** its examples were issue 1's own ambiguities ("trailing edge", "on focus", "on reconnect", "fixed at open"). Now generic classes: words of timing, quantity and lifetime.
- **plan-reviewer, "Library defaults":** "a refetch on focus, an emit buffered while disconnected" came straight from issue 1's plans. Now retries, timeouts, events and ordering.
- **plan-reviewer, races / state captured once / what the change makes worse:** these were phrased in SPA cache terms (refetch, poll, render). Now phrased for any state with two writers, including rows, streams, retries and redelivered jobs.
- **code-reviewer:** "fresh and cached, first visit and return" and "a return visit" pointed at the cached channel-switch bug every early build had. Now "state fresh and state left over, the first time and again".
- **plan-writer:** my new pre-return checklist line said "refetch, poll and event"; now "every other writer of the same state".

What I left, because it is repo knowledge rather than issue knowledge: the shared context's *Tests that prove something* cites existing test files and jsdom's lack of layout. Those are frontend-heavy, but they describe how tests in this codebase have gone wrong, not this feature.

Two caveats:

- **r1–r3 ran with the old wording**, so part of their catch rate may be priming. The earlier handoff said the same about the code-reviewer. Run r4 is now building issue 1 from scratch with the generalised prompts, to see whether delivery holds.
- **Issue 1 is the only issue the team has ever run.** It is SPA-only, so the backend paths (Python sketches, integration tests from a headless stage, migrations) are still unproven by a real delivery. A second, backend issue is the real test of "generic".

Status of the completed runs: r2 finished and was approved, so all three delivered with no human stop. I reran Vitest and the typecheck myself on r2 and r3 (210/210 and 223/223, both clean), and both committed reports show lint, unit and e2e 20/20 passing.

| Run | Stages | Stage time | Cost |
|---|---|---|---|
| r1 | 12 | 85 min | $33.92 |
| r2 | 14 | 74 min | $31.55 |
| r3 | 8 | 72 min | $30.32 |

That averages 77 minutes and $31.93. I'll report on r4 when it finishes.

---

## User

are we done or is there anything else you would add?

---

## Assistant

*(read r4's log: the plan-writer done in 11.7 minutes, the plan-reviewer running; listed `docs/plans/ch08/` — three handoffs, no fourth)*

Not quite done: r4, the first run with the generalised prompts, is only at its plan review (about 12 minutes in). Until it finishes, "reliably delivers" rests on three runs that used the older, issue-1-flavoured wording.

Still on my list for this session:

- **Read r4's result.** If it delivers without a stop, the generalised wording holds for this issue. If it doesn't, I'll look at whether the lost priming is why.
- **Write the handoff**, `docs/plans/ch08/04-…`, as the earlier sessions did: what changed, the run table, and what's still open.

Things I would add, but haven't, because they are your call:

- **A backend issue as the next delivery.** Issue 1 is SPA-only. The Python sketch copies, integration tests from a headless stage, migrations and dependency installs are in the script and prompts but no real run has used them. That is the real test of "any issue".
- **The Integration row in the committed test report.** A fresh worktree has no integration results, so all three reports say "not run" where `main` says 381 passed. I had the plan name only the layers the change reaches, and the code-reviewer flags it for the human to rerun. The alternatives are always running `all`, which meets the Elasticsearch container timeouts on this machine, or changing `testkit.report` to keep the committed row.
- **The R4 question from the last handoff** (an error ack followed by a reconnect). Under the new rule each run decides this itself and records it as an assumption, so the three builds may differ. If you settle it, it belongs in the issue and the exemplar issue.
- **Model and effort per stage.** Every stage runs Opus at default effort. The test-reviewer is the most expensive stage ($4–7, up to 175 turns); a lower effort or a cheaper model there, or on rework passes, is the biggest untested cost lever.
- **Consolidating what the three reviewers share** into the shared context. I left it alone: it is a wording refactor of prompts that were tuned by variance runs, and I couldn't re-measure it cheaply.
- **Clean-up.** This session left `../caw-issue-1-r1` to `-r4` and their `feature/issue-1-r*` branches, on top of the older leftover worktrees. I haven't removed any. Pick one build to keep for review, if any, and I can remove the rest.

Nothing is committed. The delivery changes sit uncommitted in `../caw-delivery-tune` on `feature/delivery-tune`.

*(an hour later, the background task finished: run r4, exit code 0)*

*(read r4's history: 10 steps, exit 0, 76.9 minutes and $33.88, no `needs-human.md`; reran its Vitest suite, 230 passed, and its typecheck, clean; then wrote the handoff, `docs/plans/ch08/04-team-review-handoff.md`, in the tuning worktree)*

Run r4 delivered too, so the team has now built issue 1 from scratch four times with no stop for a human, including once with the generalised prompts.

| Run | Prompts | Stages | Stage time | Cost | Loops the team resolved itself |
|---|---|---|---|---|---|
| r1 | revised | 12 | 85 min | $33.92 | 2 plan rounds; code-reviewer send-back |
| r2 | + one turn per sketch | 14 | 74 min | $31.55 | 2 plan rounds; 2 test rounds; code-reviewer send-back |
| r3 | as r2 | 8 | 72 min | $30.32 | 2 plan rounds only |
| r4 | + examples generalised | 10 | 77 min | $33.88 | 2 plan rounds; 2 test rounds |

The average is 77 minutes and $32.42 per delivery, against 95 minutes and $36.61 for the run before this session.

Every build's test report shows lint, unit and e2e 20/20 passing. I reran Vitest and the typecheck myself on r2, r3 and r4 (210, 223 and 230 tests, all clean); on r1 I'm relying on the code-reviewer's 238/238.

Things to know before you rely on this:

- **Issue 1 is still the only issue the team has run**, and it is SPA-only. The Python sketch copies, integration tests from a headless stage, migrations and dependency installs are unproven by a real delivery.
- **The four builds are different implementations.** Each plan recorded 8–13 assumed decisions, so they may differ on the edges the issue leaves open — including the error-ack-then-reconnect question from the last handoff.
- **Integration shows "not run"** in every build's committed test report, where `main` shows 381 passed. The code-reviewer flags it for you to rerun.
- **The out-of-turns resume and crash retry never fired** in a real run; they are covered by the loop test and one manual check against the CLI.

Your calls:

- **Which build to keep.** `../caw-issue-1-r1` to `-r4` (branches `feature/issue-1-r1` to `-r4`) each hold a complete uncommitted build. Tell me which to keep for review, if any, and I'll remove the rest.
- **Committing the team changes.** Everything is uncommitted in `../caw-delivery-tune` on `feature/delivery-tune`.

I wrote the handoff as `docs/plans/ch08/04-team-review-handoff.md` in that worktree; it has the full change list, the run table and the open items.

*(`/manning-book-workflow:extract-transcript ch08 {n} team-review-fable.md` — the session to this point was exported to this file: 52 tool calls, 201,000 output tokens. The user came back four hours later.)*

---

## User

was this worth doing? is the ai team likely to be better at delivering from a good feature spec than just a plain claude code session?

---

## Assistant

Probably yes for quality, but I can't say so from evidence: nobody has run the comparison. Every number from this session is the team against an earlier version of itself, never against a plain session given the same issue.

What the runs do show is that the review stages earned their place:

- **Every first-draft plan had a real fault.** The plan-reviewer found a different major or critical one in each of the four runs, for example a journey step no correct build could pass (r3), and a pending read sent on the old socket after a workspace switch (r2, r4).
- **Two of four builds had a real bug with every test green.** The code-reviewer found them by mutating the code and probing, and each was fixed test-first.
- **The red gate caught tests that prove nothing.** In r2 it found a poll test that no correct build could pass.

A plain session is one writer with no independent check, so it would plausibly ship faults of exactly these kinds. The earlier handoff points the same way: four code-writer builds from one plan all had the same channel-switch bug, and it only went away when the issue and plan were improved.

What it costs is 77 minutes and about $32 per delivery. My guess is a plain session would build this feature in a fraction of that, but I haven't measured it.

So the trade is roughly:

- **Team:** slower and dearer, but runs unattended and leaves a plan, a reviewed failing-test set, a list of assumed decisions and a list of what no test pins. That suits features where a subtle bug is expensive, or where you want to review a finished branch rather than supervise.
- **Plain session:** faster and cheaper, and better when you are at the keyboard anyway, the change is small, or the spec is still moving.

Was this session worth it? It didn't make the team more capable of delivering: the run before it also finished without a human. What it bought is fewer stages, about 18 minutes and $4 less per run, send-backs that can't dead-end in a final round, and a loop test for the script.

The experiment that would answer your question is cheap: give a plain session issue 1 with the repo's normal rules, then run the team's code-reviewer over the result and count what it finds. One or two of those runs would tell you more than my estimate. Want me to run it?

---

## User

i do but it needs to be a proper control - if the plain agent sees the agent prompts, context doc etc then it is liable to infer some of the process from them. so we would need a new worktree, delete the ai team machinery and just leave the issue there. even then - would the plain agent dig around in git history?

---

## Assistant

Yes, it would likely look: a plain session routinely runs `git log` and `git show` to see how similar work was done, and this issue itself cites commits. A worktree with the files deleted isn't a clean control, for three reasons:

- **Git history.** A worktree shares the repo's history, so the agent prompts, `deliver.sh`, the exemplar plan and the three handoffs are one `git show` away. The handoffs describe issue 1's bugs by name, including the channel-switch one.
- **Sibling directories.** `../caw-issue-1` and `../caw-issue-1-r1` to `-r4` hold five complete builds of this exact feature, readable by path.
- **`CLAUDE.md`.** It describes the delivery workflow and names the agents.

So the control needs to be a separate repo, not a worktree:

1. **Export `main`'s tree** with `git archive` into a directory outside `~/scm/manning`, so there are no siblings.
2. **Remove the machinery:**
   - `.claude/agents/`, `.claude/delivery/`, `scripts/deliver.sh`
   - the `issue-writer` skill and `docs/issues/exemplar-issue.md`
   - `docs/plans/exemplar-implementation-plan.md` and `docs/plans/ch08/`
   - the *Delivery workflow* section and the `deliver.sh` clause in `CLAUDE.md`
3. **Keep everything a normal session has:** the rest of `CLAUDE.md` including the test-first rule, the lint and security hooks, the design docs, and `docs/issues/001.md`.
4. **`git init` with one commit**, so there is no history to dig in. `scripts/test.sh` and the hooks need a repo to run.
5. **Run it headless** on the same model as the team's agents, with the issue as the prompt and the union of the team's tool permissions.

Three things I can't remove, so you should know them:

- **The issue is itself a product of the team's lessons.** Its *Paths* table names the channel-switch case. That matches your premise of "a good feature spec", but it means the control starts with that bug already flagged.
- **Your user-level setup still loads**, including the superpowers plugin, which pushes a session towards planning and test-first. I'd leave it, since it is what a plain session is for you.
- **Earlier runs' transcripts** sit under `~/.claude/projects/`. An agent could read them by path; I'd check the control's transcript afterwards to confirm it didn't.

Judging needs to be the same for all builds. The team's code-reviewer expects a plan and a red report, so it can't review the control as it stands. Instead I'd use:

- **A fixed set of probes** from the bugs found so far (pending read on a workspace switch, return through an empty channel, switch to a cached channel mid-history), run against the control and against r1–r4.
- **A blind review** of each build by a fresh agent given only the issue and the code.

One run is an anecdote, so I'd do three control runs.

Before I start, two decisions:

- **The commit.** Step 4 is a commit, in a throwaway repo that is not this project. Are you happy with that, given the never-commit rule here?
- **Stop at red.** `CLAUDE.md` tells an interactive session to stop at red for review, and a headless run can't. I'd tell the control to carry straight on from red to green. Is that right, or do you want the rule removed from its `CLAUDE.md` instead?

---

## User

fine to commit; the red rule - will the headless session know it is headless? can we soften claude.md so that req is only for interactive sessions?

---

## Assistant

*(searched the tuning worktree for every reference to the delivery machinery — the agents, `.claude/delivery/`, the `issue-writer` skill, the two exemplars, `docs/plans/ch08/`, a section of `CLAUDE.md` and one comment in `scripts/test.sh`; read the test-first rule: it already scoped the stop to "an interactive session", and added a sentence saying what a headless one does)*

*(wrote a control script in the scratchpad: `git archive main` into `~/scm/caw-control/<name>`, the machinery removed — and `docs/project/` with its "ignore this" rule, which had not been in the plan — `.env` copied, `git init`, one commit, a `feature/issue-1` branch, then one headless `claude -p` on Opus with the issue as its prompt; built the first repo as a dry run and searched it for the agent names, `deliver.sh`, `agent-context`, `issue-writer` and "exemplar": nothing)*

The control repo is built and checked clean; launching three plain-session runs now.

*(started three control runs in the background, 15 seconds apart)*

A headless session isn't reliably aware that it is headless, so I've made it explicit in both places: the rule and the prompt. Three control runs are now building issue 1 in parallel.

**The rule.** `CLAUDE.md` now says the stop at red is for interactive sessions only; a headless session (`claude -p`) runs the failing tests, records what each failed with, and carries on to green. That edit is in `../caw-delivery-tune` (uncommitted, with the rest) and in the control's copy.

**The control repos**, `~/scm/caw-control/c1`, `c2` and `c3`:

- **Isolation:** each is an export of `main` into a new repo with a single commit, outside `~/scm/manning`, so there is no history and there are no sibling builds.
- **Removed:**
  - `.claude/agents/`, `.claude/delivery/`, the `issue-writer` skill and `scripts/deliver.sh`
  - the exemplar issue and the exemplar plan
  - `docs/plans/ch08/` and `docs/project/`
  - the *Delivery workflow* section of `CLAUDE.md`
  - a comment in `scripts/test.sh` that named `deliver.sh`
- **Checked:** a search of the first repo for the agent names, `deliver.sh`, `agent-context`, `issue-writer` and "exemplar" finds nothing.
- **Kept:** the rest of `CLAUDE.md` including the test-first rule, the lint and security hooks, the design docs, the earlier chapter plans the issue cites, and `docs/issues/001.md`.

**The run.** Each is one headless session on Opus, the same model the team's agents use, capped at 400 turns. The prompt tells it:

- to implement the issue following the repo's rules;
- that it is headless, with nobody to answer or review;
- that it is already on `feature/issue-1` and shouldn't create a worktree;
- not to commit;
- to finish with a summary of what it built, ran and left for a human.

Two things differ from the plan I gave you:

- **Tool permissions are broader than the team's.** I gave the control general `git`, `npm`, `uv`, `python3` and `docker` access rather than the team's narrow per-stage lists, because a plain session hobbled by refusals wouldn't be a fair control. It could commit; the script checks afterwards whether it did.
- **I removed `docs/project/` and its "ignore this" rule**, which I hadn't listed. It is book material that might describe the team.

When the three finish I'll check their transcripts for anything they read outside the repo, then run the same probes and a blind review over these three and r1–r4.

---

## User

while that's running - some quick stats. pre-your work ~90 minutes per build and $36, post- 75m and $32? how much code/test is built on average by the team?

---

## Assistant

*(counted added and removed lines in each of the five team builds, split into production code, tests, docs and the team's own plan files — marking untracked files in each worktree's index to count them, then resetting it)*

Close: before was 95 minutes and $36.61 (one run), after averages 77 minutes and $32.42 over four runs.

On average the team writes about 800 lines of production code and 2,400 lines of tests per build, roughly three lines of test for every line of code:

| Build | Production code | Tests | Docs | Plan, reports and reviews |
|---|---|---|---|---|
| Before (`caw-issue-1`) | +944 in 17 files | +2,333 in 18 files | +151 | 2,091 lines |
| r1 | +816 in 9 files | +2,428 in 15 files | +166 | 2,351 lines |
| r2 | +715 in 9 files | +2,168 in 10 files | +144 | 2,382 lines |
| r3 | +899 in 14 files | +2,478 in 17 files | +163 | 1,868 lines |
| r4 | +789 in 11 files | +2,486 in 16 files | +147 | 1,986 lines |
| **r1–r4 average** | **+805** | **+2,390** | **+155** | **2,147 lines** |

- **Production code** is everything changed under `src/frontend/src` that isn't a test or test helper. Each build also removes 50–80 existing lines.
- **Tests** are the Vitest files, the shared test helpers and the BDD feature, steps and page object.
- **Docs** are the design doc rewrite and the two ADR changes, not counting the test report.
- **Plan, reports and reviews** is the team's own paperwork under `docs/plans/issue-1/`: about as many lines as the tests.

So a delivery is about 3,350 lines of code, tests and docs for $32, a little under a cent a line, plus the 2,100 lines of plan and review that a human reads instead of supervising.

To count new files I briefly marked untracked files in each worktree's git index and then reset it, including in `../caw-issue-1`. No file contents changed.

---

## User

the plan sessions still running?

---

## Assistant

*(checked the three control runs: c2 finished — success, 123 turns, 20 minutes, $6.50; c1 and c3 still running, about 21 minutes in, c1 in `scripts/test.sh e2e` and c3 in `lint unit`; all three trees held code, tests, a journey, the doc rewrite and an ADR)*

Two of the three plain sessions are still running, both in their final verification; one has finished.

| Control | Status | Time | Turns | Cost |
|---|---|---|---|---|
| c1 | running `scripts/test.sh e2e` | 21 min so far | — | — |
| c2 | finished, success | 20 min | 123 | $6.50 |
| c3 | running `scripts/test.sh lint unit` | 20 min so far | — | — |

So the plain session is roughly four times faster and five times cheaper than the team's 77 minutes and $32, as I guessed. Whether its build is as good is the open question, and I haven't looked at c2's result yet.

All three have written the same kinds of things the team does: production code, Vitest tests, a BDD journey, the design doc rewrite and an ADR. None has finished long enough for me to check its transcript for reads outside the repo.

I'll run the probes and the blind review across all seven builds once c1 and c3 finish.

---

## User

they done?

---

## Assistant

*(read the results: c1 finished — 137 turns, 22.2 minutes, $7.04; c3 still running; each repo still at its one commit; searched each control transcript for reads under `~/scm/manning` or `~/.claude/projects` — none — and counted one `git log`/`git show` command in each)*

*(wrote a judge script: copy a build's `src/frontend` and the issue, nothing else, to `~/scm/caw-judge/<label>`, and run a headless Opus session that must give a verdict on 15 rows of the issue, each proved by a probe test it writes and runs; shuffled the seven builds into labels b1–b7 and started the reviews in the background, four first, then three)*

Two of the three are done; c3 is still in its verification runs at about 27 minutes.

| Control | Result | Time | Turns | Cost | Test report |
|---|---|---|---|---|---|
| c1 | success | 22 min | 137 | $7.04 | lint, unit 537, e2e 20/20 pass |
| c2 | success | 20 min | 123 | $6.50 | lint, unit 530, e2e 20/20 pass |
| c3 | running | 27 min so far | — | — | passing so far |

- **No leakage found.** None of the three read anything under `~/scm/manning` or the earlier runs' transcripts. Each ran one `git log`/`git show` command, against a history that holds a single commit.
- **No commits.** Each repo still has just the one setup commit.
- **On the face of it, they deliver the same thing as the team:** code, Vitest tests, the BDD journey, the doc rewrite and an ADR, with every layer green, in about a quarter of the time and a fifth of the cost.

Green tests don't settle it, though: two of the team's four builds also had every test green before the code-reviewer found a real bug. So I've started the blind review.

- **What each judge sees:** only the issue and the SPA's source and tests, copied to a neutral directory with a shuffled label. No plan, reviews, reports or git, so it can't tell a team build from a plain one.
- **What it does:** checks the same 15 rows for every build (the six "where the rules meet" bullets and the nine "paths" rows from the issue). It has to prove each verdict with a probe test it writes and runs, then list any other bugs and assess the test suite.
- **Order:** four builds are being judged now; the other three, including c3, start when those finish.

One thing I'll verify before trusting c3's verdict: that its build had finished before its judge copied the tree.

*(four minutes later, the background task finished: the three control runs, exit code 0)*

*(read c3's result — $7.39, finished at 16:28:40, one commit, its report showing integration run and 18 failed — and saw the first four judges had started three minutes before, so c3's own judge would start after it)*

c3 has finished: about 30 minutes and $7.39, with no commit. So the three plain sessions took 20, 22 and about 30 minutes, and cost $6.50, $7.04 and $7.39.

c3 ran the integration layer as well, and its report shows 18 integration failures. That matches the Elasticsearch container timeouts the last handoff recorded on this machine, and it is an SPA-only change, but I haven't confirmed the cause.

c3 finished before its judge starts, so the ordering concern I raised is settled. The first four blind reviews are running; I'll report when all seven are in.

---

## User

still in judgement?

---

## Assistant

*(checked the judges: six finished, 55–91 turns and $2.66–3.72 each, b7 still running; read the six results: every one holds on 14 rows and breaks on M3, with one major bug of the same root cause and one to three minor ones)*

Six of seven are judged; the last (r2) is still running. The result so far is not what I predicted: the blind review found no quality difference between the team's builds and the plain sessions' builds on the 15 rows.

| Build | Type | Rows holding (of 15) | Row broken | Other bugs found | Judge on the tests |
|---|---|---|---|---|---|
| r1 | team | 14 | M3 | 1 major (same root cause), 2 minor | "unusually strong" |
| r3 | team | 14 | M3 | 1 major (same root cause), 2 minor | strong |
| r4 | team | 14 | M3 | 1 major (same root cause), 1 minor | strong |
| c1 | plain | 14 | M3 | 1 major (same root cause), 3 minor | thorough at unit level; component wiring never exercised together |
| c2 | plain | 14 | M3 | 1 major (same root cause), 3 minor | strong |
| c3 | plain | 14 | M3 | 1 major (same root cause), 2 minor | strong on units; no test mounts the whole shell with the read rule |
| r2 | team | pending | | | |

- **Every build has the same bug.** A message that arrives live while the channel's opening fetches are still in flight gets a "New messages" divider, even in a channel read to the end. All six wait for the fetches to settle before capturing "what existed at open", so anything arriving in that window counts as old.
- **The issue invites it.** One row says the divider "waits for both refetches" and another says a live message "never grows a divider". Neither the plan-reviewer, the test-reviewer nor the code-reviewer caught the gap in any team run. That is the earlier finding again: the spec is the stronger lever.
- **The only visible difference is in the tests.** The judges called all three team suites strong at the integrated level. For two of the three plain builds they noted that the pieces are well tested alone but never together. The team also writes more test code, though I haven't counted the plain builds' lines.
- **The channel-switch bug from the earlier handoff did not reappear** in any plain build; the issue now names that path, and all six hold on it.

So on this issue, with this spec, the plain session delivered the same measured quality in about a quarter of the time and a fifth of the cost: 20–30 minutes and about $7, against 77 minutes and $32.

What this doesn't settle:

- **One judge per build, 15 rows.** The judges prove what they probe; a bug outside those rows and outside what a judge happened to look for goes unseen. The team's code-reviewers did find and fix two real bugs (in r1 and r2) that a plain build may or may not have had. Those bugs are on rows the plain builds also passed, so I have no evidence the plain builds had them.
- **The spec was already hardened by the team's earlier failures.** A weaker issue might separate the two more.
- **One SPA-only feature.** A backend change with a migration might go differently.
- **Unattended versus supervised.** The plain session was given broad permissions and told nobody was watching; the team's value may be more in the audit trail than in the code.

I'll add r2's verdict when it lands. The follow-up I'd suggest is to fix the issue's M3 contradiction and see whether both approaches then get it right.

*(two minutes later, the background task finished: the seven blind reviews, exit code 0)*

*(read b7's result — 98 turns, $3.98, the same 14 of 15 with M3 broken; summed the judges' cost, $22.72; counted the three plain builds' lines: 702–879 of production code, 1,438–1,633 of tests)*

The last verdict is in, and it matches the other six: all seven builds hold on 14 of the 15 rows and break on the same one.

| | Team (r1–r4) | Plain session (c1–c3) |
|---|---|---|
| Rows holding, of 15 | 14 in every build | 14 in every build |
| Row broken | M3 in every build | M3 in every build |
| Major bugs beyond that row | none | none |
| Minor bugs the judge listed | 1–2 per build | 2–3 per build |
| Time | 72–85 min (average 77) | 20–30 min |
| Cost | $30–34 (average $32.42) | $6.50–7.39 |
| Production code | about 805 lines | about 795 lines |
| Test code | about 2,390 lines | about 1,510 lines |

- **Same bug everywhere.** In every build, a message that arrives while the channel's opening fetches are in flight gets a "New messages" divider. The issue asks for the divider both to wait for those fetches and never to appear for a live message, and no build reconciled the two.
- **Same size of feature.** The plain sessions wrote about as much production code as the team.
- **The team writes about 60% more test code.** That shows in the judges' comments: all four team suites were called strong, with the gap being the one race. Two of the three plain suites were marked as testing the pieces alone but never wired together.
- **The judging cost $22.72** for all seven.

So, to your original question: on this evidence the team is not better at delivering this feature from this spec. It costs about five times as much and takes about three and a half times as long for the same measured correctness. What the extra buys is a larger test suite and the paper trail of plan, reviews and assumed decisions.

The limits are the ones I gave before: one judge per build, 15 rows, one SPA-only feature, and a spec already hardened by the team's own earlier failures. I'd treat this as "no difference detected", not "no difference exists".

Two things would sharpen it:

1. **A weaker spec.** Run both from the issue's original wording, before `issue-writer` added the paths and meeting-points. If the team's reviewers earn their cost anywhere, it should be there.
2. **A backend issue**, with a migration and an API change, where a wrong build is harder to see from green tests.

Housekeeping: the seven builds, three control repos under `~/scm/caw-control/` and seven judge copies under `~/scm/caw-judge/` are all still on disk. The delivery changes are still uncommitted in `../caw-delivery-tune`. I haven't updated the handoff with the control result; say if you want it added.

*(the session was left overnight; the next message is from 03:07 UTC on 2 October)*

---

## User

Ok so can you see from transcripts how much work the agents are duplicating - e.g researching the same thing. Is there value in them keeping a shared findings doc, or would dilute the benefit of a fresh start each time

---

## Assistant

*(wrote a script over the 44 stage transcripts of r1–r4: every file each stage read, by kind, and whether an earlier stage in the same run had read it — source 190 of 286, tests 182 of 285, docs 27 of 55, library 7 of 26, the team's own handoff files 117 of 154)*

Yes, the transcripts show it, and the answer is that the agents re-read a lot but re-research very little, so a shared findings doc would save less than it looks and would cost the reviewers some independence.

Across the four runs (44 stages), counting each distinct file a stage read and whether an earlier stage in the same run had already read it:

| What was read | Distinct reads | Already read by an earlier stage |
|---|---|---|
| Source files | 286 | 190 (66%) |
| Test files and helpers | 285 | 182 (64%) |
| Design docs and ADRs | 55 | 27 (49%) |
| Library source in `node_modules` | 26 | 7 (27%) |
| The team's own handoff files (plan, reports, reviews) | 154 | 117 (76%), by design |

- **The same dozen files get read by five or six stages in every run:** `MessageList.tsx`, `useChannelSocket.ts`, `useChannels.ts`, `ChannelView.tsx`, `ChannelList.tsx`, `chat.ts`, `socket.ts` and the test helpers.
- **Most of that re-reading is unavoidable.** A writer has to read a file before it can edit it, and a reviewer has to read the code it is reviewing. A findings doc doesn't replace having the source in context.
- **Real research is rarely repeated.** Library behaviour is looked up almost entirely by the plan pair (the plan records it with file and line), and later stages mostly trust that: only 7 library reads were repeats.
- **The one clear duplication is deliberate.** The plan-reviewer runs about as many searches as the plan-writer (18–31 each) and re-reads nearly all the same source. That is the "form your own view before reading the plan" step, and it is what found a different major fault in every first-draft plan.

I can't put an exact cost on the re-reading from these numbers. My rough estimate is that it is a minority of each stage's cost, since reads are batched into a few turns and most turns go on writing, running tests and sketching.

On the shared findings doc, I'd split it by kind of content:

- **Verified facts: worth sharing, and mostly already shared.** Things like "TanStack 5.101.4 only listens to `visibilitychange`, `focusManager.ts` line N" or "MSW records a request a tick later". The plan and the red report's *For the code-writer* section carry these now. Making it an explicit, short "facts with evidence" section that every stage appends to would be cheap and low-risk.
- **Interpretations and conclusions: don't share.** "The divider capture is safe because…" is exactly what a reviewer needs to work out for itself. The first handoff recorded reviewers marking a requirement "covered" in the plan's own words until they were made to write expectations first. A findings doc of conclusions would bring that anchoring back.

The blind review supports being cautious here: all seven builds shared one bug, which every stage inherited from the same reading of the issue. More shared conclusions would make that kind of shared blind spot more likely, not less.

If the goal is cost, the bigger lever is the one the control run exposed: the plain session reached the same measured result in about a fifth of the cost. Trimming re-reads would shave a few percent off the team; dropping or merging stages would change the multiple.

---

## User

How generic are the agents? Could we template the bulk of it and create a generic skill “add an agent team to this project” which inspected the repo and generated the agent prompts tailored to the stack/conventions

---

## Assistant

*(counted lines carrying repo-specific terms in the shared context and the six prompts — 100 of about 1,650 — and by section of the shared context: 10 in *Running tests*, 7 in *Tests that prove something*, almost none in the workflow sections)*

Mostly generic, yes: by a rough count about 100 of the 1,650 lines across the six prompts and the shared context mention anything specific to this repo, and those lines cluster in a few places. A generator skill is feasible, but the parts it would have to generate are the parts that were hardest to get right here.

**What is already generic and could be a fixed template**

- **The workflow:** six stages, rounds, the final round, send-backs, rework passes, "decide, record, carry on", when to stop, the structured result. That is ten of the shared context's fourteen sections, and my count found almost no repo-specific lines in them.
- **The reviewers' method:** expectations written before the work is opened, verify rather than trust, severity grading, the review file's skeleton, sketching and mutating.
- **`deliver.sh`'s state machine and `loop-test.sh`.** These don't depend on the stack at all.

**What is repo-specific and would have to be generated**

| Where | What it holds | How a skill could derive it |
|---|---|---|
| *Running tests* in the shared context | the test commands per layer, install steps, what can't run headless | inspect `package.json`, `pyproject.toml`, the test scripts and CI config |
| `deliver.sh` tool lists and write scopes (about 30 lines) | which commands each stage may run, where tests and code live | same inspection, plus the repo layout |
| `sketch.sh` | how to copy the code and run tests against the copy | per-language recipe; needs trying, not just writing |
| *What governs the work* | this repo's conventions doc, design docs, decisions register | look for equivalents; many repos have none |
| The code-writer's verification section | `scripts/test.sh`, the committed test report, convention and security checks | the repo's own check scripts, if any |
| The exemplar plan and exemplar issue | the shape of a good plan and issue here | hardest: these were distilled from this project's past plans |

**What a generator can't produce on day one**

- ***Tests that prove something.*** Those 61 lines are a list of ways tests in this codebase have passed without proving anything, each from a real failure. The plan-reviewer's checklist is the same kind of thing. The first handoff recorded that generic review advice found none of the defects these lists caught.
- **Permission lists that work.** The exact tool patterns here were settled by runs where stages lost turns to refusals.

So I'd build it as two layers rather than one generated blob:

1. **A fixed core** shipped with the skill: the script, the loop test, the workflow sections of the shared context, and the six role prompts with the repo-specific lines pulled out into named slots.
2. **A generated project profile:** one file the skill writes by inspecting the repo (test commands, layout, conventions sources, write scopes), which the core reads. The failure-pattern lists start nearly empty, seeded with a few language-level ones, and the skill includes a "harvest" step that adds to them after each delivery.

Two cautions before investing in it:

- **It has been proven on one feature in one repo.** The Python paths here have never been through a real delivery, so "generic" is a claim about the wording, not a tested result. I'd want a backend issue here, and one trial on a second repo, before packaging it.
- **Yesterday's control run.** The plain session matched the team's measured quality at a fifth of the cost. Generalising the team to other projects multiplies whatever value it has, and that value hasn't been shown yet. I'd settle that question first, with the weaker-spec and backend comparisons.

If you want, I can do the mechanical first step cheaply: split the current files into core and profile in the tuning worktree, so you can see exactly how much ends up on each side.

---

## User

The advantage of the team is visibility into the throughput. Think a GitHub project board which shows multiple issues in progress at their agent stages, deliver.sh automated by labels on the issues. A single session would be structured in the same way,  would not have the visibility and would not generate artifacts that could  be mined to improve the factory. Or could it?

---

## Assistant

It could do most of it. The visibility and the artifacts come from the harness around the agent, not from having six agents, so a single session can be given both. What it can't give you is findings from an independent reviewer, and those are the richest thing to mine.

| What you want | Six-stage team | Single session |
|---|---|---|
| Board column per issue | free: `deliver.sh` knows the stage and can set a label at each transition | possible: the session is told to work in named phases and a hook or a `gh` call moves the label at each boundary |
| Triggered by an issue label | same wrapper either way | same wrapper either way |
| Phase status you can trust | enforced from outside: the script checks files exist, write scopes, no commits | self-reported, unless the wrapper checks an artifact at each boundary |
| Time, turns and cost per phase | exact, one result file per stage | derivable from the transcript's timestamps, but only as good as the phase markers |
| Plan, red report, green report | required outputs | can be required the same way; a plain session won't write them unprompted (I haven't checked whether yesterday's three controls left any) |
| Stop, fix and resume at a phase | built in | coarser: resume the session or start again |
| Review findings to mine | yes: each review lists what the writer got wrong, graded | none, because nothing independent looked |

The last row is the real difference. The improvements to the "factory" so far all came from review findings: the checklist of how plans go wrong, the list of tests that prove nothing, the exemplar plan's notes. A lone session's transcript shows what it did and how long it took, but not what it got wrong, because it doesn't know.

That points to a middle design rather than either extreme:

- **One builder session**, structured in phases (plan, red, green, record), writing the same three artifacts and moving the board label at each boundary. Yesterday's controls suggest that costs about $7 and 20–30 minutes.
- **One independent reviewer session** afterwards, with a fresh context, given the issue and the code. The blind judges did this for about $3 and 9 minutes each, and found the bug that all four team builds and all three plain builds shared.
- **One fix pass** if the reviewer finds something.

That keeps the board, the trigger, the artifacts and a mineable findings file, for perhaps a third of the team's cost. It gives up the plan and test gates, which on yesterday's evidence didn't change the measured outcome for this issue, though that is one feature with a well-hardened spec.

Two honest gaps in my position:

- **I haven't built or run the middle design.** The cost figures are borrowed from the control and judge runs, not measured for this shape.
- **The six-stage team may still earn its cost on weaker specs or riskier changes.** That comparison hasn't been run.

If the board is the goal, the label automation is the same work whichever shape sits behind it, so it could be built first and the builder swapped later.

---

## User

Interesting. The main thing with one session is the frenetic prompt - we can mandate output at stages but the agent may choose to skip, and then the issue is stranded

---

## Assistant

That risk is real, and the answer is the same one `deliver.sh` already uses: don't rely on the prompt for anything that matters; have the wrapper check it. A single session can be held to its stages from outside in three ways, in increasing strength.

- **Check and resume.** After the session ends, the wrapper looks for each required artifact. If one is missing, it resumes the same session with "you skipped the red report; write it now". I built and checked that mechanism yesterday for stages that run out of turns: resuming by session id keeps the whole context, so it is cheap.
- **A Stop hook.** Claude Code runs a hook when the agent tries to finish, and the hook can refuse and hand back a reason. A hook that checks the artifacts means the session cannot end without them. This is enforcement inside the session, not after it.
- **The wrapper drives the phases.** Instead of one long prompt, the script sends one prompt per phase to the same session: "write the plan", check the file, move the label, then "write the failing tests", and so on. The agent keeps one continuous context, but it never sees the next phase until the wrapper has accepted the current one, so it can't skip ahead or skip out.

The third is the one I'd pick. It turns the "frenetic prompt" into four or five short ones, each with a single deliverable, and it makes the board label a fact the script established rather than something the agent reported. It is `deliver.sh` with one session id carried through, so most of the existing script applies: the artifact checks, the write-scope check, the no-commit check, the retry on a crash.

What it doesn't fix:

- **Presence isn't quality.** The wrapper can prove a red report exists, and even that the tests in it fail. It can't prove the plan is any good. That is still the independent reviewer's job.
- **A session can still get stuck.** Bounded resumes, then a "needs human" label on the issue, is the honest end state; the issue is flagged, not stranded.
- **Long contexts degrade.** One session carrying plan, tests and code for a large feature will be summarised along the way. Yesterday's controls finished in 123–137 turns, so this feature fits comfortably, but a bigger one might not.

For what it's worth, none of yesterday's three plain sessions skipped anything they were asked for: each wrote tests, the doc rewrite, the ADR and the closing summary. But they were asked for an outcome, not staged artifacts, so that isn't evidence about stage discipline.

---

## User

But if this runs in gh actions how does we preserves state to restart a session? We would need to make sure we use the same runner throughout

---

## Assistant

You don't need the same runner, but you do need to decide where the state lives, and there are really two pieces of state: the session and the working tree.

**The session.** A Claude Code session is a transcript file on disk under `~/.claude/projects/`, keyed by the working directory's path. Resuming needs that file present and the same working directory path. That gives three options:

- **Keep all phases in one job.** A job runs on one runner from start to finish, so the session file and the checkout are simply there. The whole build is 20–80 minutes on yesterday's numbers, well inside a hosted runner's job limit. This is the simplest and what I'd start with. The wrapper still moves the issue label between phases, so the board updates live.
- **Carry the session file between jobs.** Save the transcript as a workflow artifact or cache entry at the end of one job and restore it to the same path in the next. Hosted runners use the same workspace path each time, so this should work, but I haven't tested resuming a session on a different machine and wouldn't rely on it until someone has.
- **Don't depend on the session at all.** Each phase starts fresh and reads the previous phase's files. This is exactly how the six-stage team works: nothing passes between stages except the plan, reports and reviews. It restarts anywhere, on any runner, after any gap.

**The working tree.** This is the harder half, and it applies to every design. The half-built code, the tests and `deliver.sh`'s state file all live in an uncommitted worktree today. Between jobs, or after a "needs human" pause that lasts a day, that has to go somewhere durable:

- **Push work-in-progress commits to the issue's branch** at each phase boundary. This is the natural fit for Actions and gives you a branch you can inspect from the board. It changes the current "never commit" rule, which was written for local runs where you do the committing; in CI the commits would be the pipeline's, on a branch nobody merges without review.
- **Or upload the tree as an artifact.** It works, but it is clumsier and expires.

The human-stop case is what forces the issue. A run that pauses for an answer can't hold a runner for hours, so it must be able to come back on a different runner later. That means the durable state has to be in the branch and the issue, not on a machine.

So my recommendation follows from that:

1. **One job per attempt**, all phases in it, session resumed in place between phases.
2. **Commit to the issue branch at each phase boundary**, with the state file and artifacts included.
3. **If a job dies or pauses, the next job starts from the branch** with a fresh session that reads the artifacts. You lose the in-context memory, but nothing else.

That makes the session an optimisation and the files the source of truth. It is also a point in favour of the file-based handoffs: they are what make a restart on any runner possible at all.

Pinning to one self-hosted runner would also work, but it makes that machine a single point of failure and caps you at one issue at a time, which defeats the board.
