# Chat Transcript

**Topic:** The first of a suite of delivery agents. The user wants plan-writer, plan-reviewer,
test-writer, test-reviewer, code-writer and code-reviewer, driven by a workflow script that runs
`claude --agent` through each stage. This session covers:
- drafting the workflow script as a state machine: reviewers can send work back, and any agent
  can stop with "needs human"
- testing the script against a fake `claude`, which found three bugs in the draft
- writing the plan-writer agent spec
- the user's correction: encode the lessons of past plans in an exemplar, rather than have the
  agent pick one of them. The exemplar is built from three parallel reviews comparing each plan
  with what its merge actually changed
- a BDD-or-TDD recommendation for the test pair
- CLAUDE.md's "stop at red" rule, now limited to interactive sessions
- a skill that the agent frontmatter claimed to preload, but didn't

**Date:** 29 September 2026
**Project:** `caw-project` — CollabHub, the *Claude at Work* sample project
**Model:** Claude Opus 5.5, Claude Code CLI, with three general-purpose subagents for the
plan-versus-implementation reviews
**Session:** `4591d03a-b413-4686-b282-03a3d1ebfb57` · 09:44–10:14 UTC (30m)

Messages are verbatim. Tool calls are summarised in italics — one note per run of
them — so the work is visible without pages of command output. 39 tool calls ran in
this session; 158,000 output tokens. The subagents' usage is reported separately: about 335,000
tokens between them.

Agent reports and background-task notifications arrive in the JSONL as user records, but nobody
typed them. They appear here as italic notes inside the assistant turn they interrupted.

---

## User

& /Users/elton/scm/manning/caw-project/.venv/bin/Activate.ps1

---

## Assistant

That line looks like it was meant for a terminal, not for me. It also wouldn't work as written:

- **`Activate.ps1` is the PowerShell activation script**, and the `& ` at the start is PowerShell's call operator. Your shell is zsh, so use the POSIX script instead:
  ```bash
  source .venv/bin/activate
  ```
- **Running it through me wouldn't help.** Each command I run starts a new shell, so an activated environment ends when that command does. It wouldn't carry over to my next command or to your terminal.
- **This repo uses uv, so you rarely need to activate.** `uv run <cmd>` runs the command in the workspace's `.venv`, for example `uv run pytest` or `uv run ruff check`. `scripts/test.sh` handles the environment for you.

What were you trying to do? I can run it for you.

---

## User

*(`/rename caw-ch08-plan-writer` — the session is named; `/remote-control` enabled)*

we want to build a suite of custom agents to be our software delivery team: plan-writer, plan-reviewer, test-writer, test-reviewer, code-writer, code-reviewer. we will have a workflow script that runs `claude --agent` to progress through each stage. the input will be an issue written in a text file, the output will be a tested feature ready to review. the workflow script models a state machine - each reviewer can send work back to its writing partner, and any agent can end the workflow with status "needs human" if they do not have enough detail, or hit a decision they cannot proceed with. start by drafting out the workflow script and the agent spec for the plan-writer. use the existing plans in the docs folder and their implementations as a guide for how the agent should work; it will use the plan writing skill from superpowers plugin and assume there is enough detail in the issue for it to plan out the whole work. the plan is delivered as a markdown file in the docs for the issue number (named in the input), and the workflow then progresses to plan-reviewer (which we will build later)

---

## Assistant

*(listed `docs/plans/` — ten ch06 plans and 22 ch07 plans, with no `.claude/agents/` yet — and the existing worktrees, all named `../caw-<name>`)*

Worktree convention is `../caw-<name>` on a `feature/` branch. Creating it now.

*(created worktree `../caw-delivery-agents` on `feature/delivery-agents`, and read `.claude/settings.json`; counted lines across the ch07 plans (15,043 in all, 147 to 2,589 each) and read the opening of the 2,589-line reactions plan; read the superpowers `writing-plans` skill in full; checked `claude --help` for `--agent`, `--json-schema`, `--permission-mode` and `--allowedTools`)*

*(ran two throwaway `claude -p --json-schema` calls on Haiku to see the result shape: the schema-validated answer comes back as `structured_output` in the JSON result, which a script can branch on)*

*(read the reactions plan's "How this plan runs" table, its closing docs and verification tasks and its self-review, the whole 151-line test-report plan, and `scripts/test.sh` and `scripts/lib/common.sh` for script conventions; checked for `jq`)*

Worktree `feature/delivery-agents` is at `../caw-delivery-agents`. I've studied the plans and confirmed `claude -p --json-schema` returns a `structured_output` the script can branch on. Next I'm checking what past plans got wrong in the build, then I'll write both files.

*(grepped the ch07 implementation plans for "Found while building", "Correction" and "Deviations" sections)*

Writing the plan-writer agent spec.

*(wrote `.claude/agents/plan-writer.md`: it invokes `superpowers:writing-plans`, learns from the closest existing plan and its merge, never commits, follows the ch07 RED/GREEN structure, and returns `done` or `needs_human` with questions)*

Writing the workflow script.

*(wrote `scripts/deliver.sh`, about 330 lines: it reads the issue number from the file, creates the worktree, keeps state in `build/delivery/`, has a per-stage tool allow-list in `dontAsk` mode, and has guards against commits and out-of-scope writes)*

Fixing two bugs I spotted on re-reading. First, `STEP` is incremented inside a `$(…)` subshell, so the increment is lost. Second, a stop at max rounds should resume at the writer, not replay the reviewer.

*(patched both, and syntax-checked under the macOS system bash, 3.2.57)*

The script parses under macOS's bash 3.2. Next I'll exercise the state machine against a fake `claude` in a throwaway repo in the scratchpad. That costs nothing and leaves nothing in `~/scm`.

*(built a scratch git repo with a fake `claude` that plays back a sequence of statuses and writes the plan and review files; ran needs-human, resume and rework up to the round limit)*

The harness caught a real bug. The write-scope check looks at every change in the worktree, so the reviewer gets blamed for the plan-writer's files. It has to compare against a snapshot taken before the stage runs. Fixing that.

*(replaced the check with before-and-after snapshots of changed paths and their content hashes)*

Rerunning the scenarios under bash, with a stray-write case and a missing-tools case added.

Scenarios 1–5 behave as designed. Scenario 6 exposed a bash 3.2 trap: command substitutions don't inherit `set -e`, so a failure inside `run_stage` (here, a stage with no tool list) didn't stop the run. Fixing that and re-testing it.

*(added `set -e` inside `run_stage`; all six scenarios now end with the expected exit codes and errors)*

The state machine passes every scenario. One last check: that `--agent plan-writer` loads the spec and preloads the superpowers skill. I'll run a cheap Haiku probe in the worktree.

*(ran `claude -p --agent plan-writer` on Haiku and asked it to report its role, tools and whether the skill was in context. It answered "plan-writer", and that the skill was listed but not loaded)*

I've drafted the workflow script and the plan-writer agent. The state machine works against a fake `claude`, but the plan-writer hasn't yet had a real run on an issue.

**Branch:** `feature/delivery-agents`, worktree `/Users/elton/scm/manning/caw-delivery-agents`. Nothing is committed.

## `scripts/deliver.sh <issue-file> [--restart]`

- **Worktree:** it reads the issue number from the top of the file (`Issue: 42`, `# Issue #42 — …`). It creates `../caw-issue-42` on `feature/issue-42` from `main`, then runs each stage there with `claude -p --agent <stage>`.
- **Status:** each agent returns its result through `--json-schema`: a status, a summary, the files it wrote and any questions. Writers may return `done` or `needs_human`. Reviewers may return `approved`, `changes_requested` or `needs_human`. Any other status stops the run.
- **Transitions:**
  - `changes_requested` sends the work back to the writer, which gets the reviewer's `reviews/<reviewer>-<round>.md`.
  - After `DELIVER_MAX_ROUNDS` reviews (default 3) without agreement, it stops for a human.
  - `needs_human` adds the questions to `docs/plans/issue-42/needs-human.md` with a blank **Answer:** under each. Rerunning resumes at the stage that stopped, and every agent reads the answers.
- **Output:** the issue is copied to `00-issue.md` and the plan goes to `01-implementation-plan.md`, both in `docs/plans/issue-42/`. State, a history log and each agent's full JSON result go to `build/delivery/`.
- **Guards:**
  - Each stage runs in `dontAsk` mode with an allow-list of tools defined in the script, so anything not listed is refused rather than prompted for.
  - The run fails if an agent commits.
  - It fails if a plan stage writes outside its directory.
  - It fails if a writer says `done` without leaving its output file.
- **Exit codes:** 0 done, 1 error, 2 needs a human, 3 paused at a stage whose agent isn't built yet. For now it will pause at plan-reviewer.

In a throwaway repo, with a fake `claude` I scripted to return chosen statuses, I checked:
- stopping for a human and resuming with the answers;
- rework rounds reaching the limit, then resuming at the writer;
- pausing at an unbuilt stage;
- a write outside scope being caught;
- a status the stage isn't allowed to return;
- a stage with no tool list.

This found and fixed three bugs:
- the step counter was lost inside a subshell;
- the scope check blamed a stage for earlier stages' files;
- macOS's bash 3.2 doesn't carry `set -e` into `$(…)`, so failures inside a stage didn't stop the run.

## `.claude/agents/plan-writer.md`

- **Skill:** it starts by invoking `superpowers:writing-plans`, then applies the project's overrides to it: the plan goes in the issue's own folder, it never commits, and the header carries Issue and Worktree lines.
- **Precedent:** it picks the closest ch06/ch07 plan and finds how that plan was actually built through `git log --merges` and `git show --stat`. It reads the "Found while building", "Deviations" and known-gaps sections, so it doesn't repeat what earlier planning missed.
- **House style:**
  - a decisions table;
  - `(RED)`/`(GREEN)` task labels, with red tasks first at the lowest test layer;
  - a phase table showing how the plan runs;
  - complete test code, plus the exact failure each test should give before it passes;
  - closing tasks for docs/ADR and verification, and a self-review section;
  - a "Review responses" section when it reworks a plan.
- **When it stops:** it returns `needs_human` when the issue is missing detail, depends on a 🔴 decision, or is really several pieces of work. It asks all its questions at once.

## Decisions for you

1. **The test-reviewer replaces your review of the failing tests.** CLAUDE.md says to stop at red for a human. In this pipeline, the test-reviewer's approval is that checkpoint. If you still want to see the failing tests yourself, the test-reviewer could return `needs_human` on approval.
2. **The agents must be on `main` before a real run.** New issue worktrees start from `main`, so they won't contain these uncommitted files. `DELIVER_BASE` can point at another branch.
3. **The skill isn't preloaded.** A Haiku check showed the `skills:` frontmatter doesn't load the skill under `--agent`. The spec's instruction to invoke it with the Skill tool covers that.

Once this is merged, I can try the plan-writer on a small sample issue.

---

## User

we should encode the learnings from previous plans into the agent - build an examplar plan and have it read that rather than picking a random existing plan; among the plan-writers decisions is BDD (for big, new, user-facing features) or TDD - these go as recommendations for the test pair. the workflow script supersedes the "stop on test" in CLAUDE.md - we can change that rule so its only for interactive sesssions; which skill isn't preloaded?

---

## Assistant

The skill in question is `superpowers:writing-plans`. My evidence that it wasn't preloaded was weak: I asked Haiku, which said the skill was listed but its content wasn't in context. I'll check the probe session's transcript to confirm that properly. In parallel I'll start the research for the exemplar plan.

*(opened the Haiku probe's own session transcript: the skill's heading, "Writing Plans", appears in it 0 times. Then listed the merge history on `main` to map each plan to its branch)*

Confirmed: the transcript of the `--agent plan-writer` probe contains no text from the skill's body (0 hits for its heading "Writing Plans"). So `skills:` in the frontmatter didn't load it, and the explicit Skill-tool step in the agent spec is what makes it happen.

For the exemplar, I'm sending three readers in parallel to compare past plans with what their merges actually built.

*(launched three background subagents, each comparing plans with the `git diff --stat` of their merges and reporting learnings, structures worth keeping and anti-patterns: one on the ch07 feature plans (reactions, read markers, search), one on the ch07 infrastructure and test-pyramid plans, and one on the ch06 slices and how BDD was used)*

While they run, I'll make the CLAUDE.md change.

*(found the stop-at-red sentence at CLAUDE.md:68, and read the testing memory that repeats it)*

*(rewrote the sentence so stop-at-red applies in an interactive session, with the test-reviewer's approval standing in under `scripts/deliver.sh`. Added a "Delivery workflow" section to CLAUDE.md that names the six stages and the exemplar)*

Also updating the testing memory so a future session doesn't reapply stop-at-red inside the workflow.

*(added a dated exception to the memory file)*

CLAUDE.md now limits stop-at-red to interactive sessions and adds a short "Delivery workflow" section that points at the exemplar. I'll write the exemplar once the three research reports are back.

*(the ch07-features report arrived. It found nine learnings, among them:*
- *reactions' file map missed a test that called a changed signature;*
- *search's new route never reached the Ingress allow-list, and a failed deploy found it;*
- *read markers matched its file map 21 files of 21, and pinned baseline counts)*

The first report is in, on the ch07 feature plans. Waiting on the other two.

*(the ch06 report arrived:*
- *Gherkin was written before code, and the scenario review saved the most time;*
- *D32 later cut the BDD suite from 41 tests to 15, because half of it was checking field rules;*
- *it proposed criteria for when a change earns a BDD journey)*

The ch06 and BDD report is in too, and it has good criteria for choosing BDD over TDD. One report left: the infrastructure and test-pyramid plans.

*(two task notifications confirmed that the first two subagents had finished)*

Still waiting on the infrastructure and test-pyramid report before I write the exemplar.

*(the infrastructure report arrived. Its findings:*
- *render-and-lint-only checks shipped a KEDA address bug that the next branch's first deploy found;*
- *a CH006 waiver needed its `nosemgrep` in a follow-up branch;*
- *the ~150-line plans matched their diffs better than the 1,100–2,600-line full-code ones)*

All three reports are in, and they agree on one sizing point. The shorter plans (about 150–350 lines) matched their builds better than the 1,000–2,600-line full-code ones. That's because the long plans wrote out the diff twice and still missed what only a real run found. Before writing, I'm checking the real paths the exemplar will reference.

*(listed Messaging's modules, routers, migrations and tests, the BDD features, pages and steps, and the SPA's `features/channels/`; checked the Ingress allow-list and the highest register ID, which is D42)*

Writing the exemplar. It's an annotated plan for a made-up issue ("pin a message"). Each section carries a `Why` note naming the build that taught it, so the plan-writer copies the shape and the reasons rather than the content.

*(wrote `docs/plans/exemplar-implementation-plan.md`. It opens with a pre-drafting "sweep" table and a length rule, followed by a full plan for pinned messages:*
- *decisions split into agreed and taken here;*
- *corrections to the issue;*
- *a BDD test-approach section with its layer table;*
- *the file map, including the files deliberately left unchanged;*
- *RED tasks with each test's expected failure, then GREEN tasks;*
- *the record, then verification, including a first real run;*
- *"Found while building", "Not in this plan", and a self-review)*

The baseline counts I put in the exemplar were placeholders. I'll check them against `docs/test-report.md` so the example doesn't carry numbers I made up.

*(read the test report: Messaging unit 94 and integration 211, Vitest 145, end-to-end 19, at `e4d3396`. Replaced the invented figures and added "take them from the test report" to the lesson; the exemplar is 404 lines)*

The exemplar is 404 lines, inside its own 250–600 guide. Now rewriting the agent spec around it:
- it reads the exemplar instead of picking a precedent plan;
- it makes the BDD/TDD call;
- it follows the new sizing rule, so tests are listed by name and expected failure rather than written in full.

I'm also dropping the `skills:` frontmatter, since it didn't load anything.

*(rewrote `.claude/agents/plan-writer.md`: it reads the exemplar, grounds the plan in code with the sweep, and makes the test-approach recommendation. The skill's "show every step's code" is overridden by a 250–600-line rule, and "complete test code" is gone)*

The sweep needs `git worktree list` and `git branch --no-merged`, which the plan-writer's allow-list doesn't include yet. Adding them.

*(widened the allow-list, then reran the six fake-`claude` scenarios: all still pass)*

I built the exemplar plan, pointed the plan-writer at it, added the BDD-or-TDD recommendation, and changed the stop-at-red rule. Everything is uncommitted in `feature/delivery-agents` (`../caw-delivery-agents`).

**The skill that isn't preloaded** is `superpowers:writing-plans`. I checked the transcript of the `--agent plan-writer` test session this time: none of the skill's text is in it, so putting `skills:` in the agent's frontmatter doesn't load it when the agent is started with `--agent`. I removed that frontmatter. The spec's first step is to invoke the skill with the Skill tool, and it says why.

**Exemplar: `docs/plans/exemplar-implementation-plan.md`** (404 lines)
- **Source:** three readers compared every ch06/ch07 plan with what its merge actually changed. The exemplar is a full plan for an invented issue, "pin a message to a channel". Each section has a `Why` note citing the plan line or commit that taught it. The agent copies the shape and leaves the notes out.
- **The sweep:** before drafting, the plan-writer runs a table of checks. Most of what past builds found missing, a grep would have caught first:
  - callers of a changed signature, tests included;
  - a new route missing from the Ingress allow-list;
  - comments still calling a settled decision "still open";
  - semgrep waivers alongside CH006 ones;
  - sibling branches in flight.
- **Size, 250–600 lines.** The plans of about 150–350 lines matched their builds best. The 1,100–2,600-line plans wrote the diff twice and still missed what only a real run found. So a plan now gives:
  - exact interfaces;
  - every test by name, layer and the exact reason it fails before the code exists;
  - Gherkin in full;
  - code only where the reason is the value.

  This replaces my earlier "complete test code" rule, since the test-writer writes the tests.
- **Closing tasks:** a first real run that expects to find something, and a "Found while building" section for the code-writer to fill in.
- **Baseline counts** are the real ones from `docs/test-report.md`.

**BDD or TDD.** The plan gets a "Test approach" section addressed to the test pair.
- **BDD** is for a big, new, user-facing capability, or a change to a journey the suite already has. It means one to three scenarios written first, in the ch06 scenario vocabulary.
- **TDD** is the default for rules, APIs, jobs, scripts and charts.
- Both come with a table mapping each behaviour to the lowest test layer that proves it, plus what no test covers. The test pair may depart from the recommendation but has to say why.
- The criteria come from D32 cutting the BDD suite from 41 tests to 15 because half of it was checking field rules, and from reactions justifying exactly one journey.

**CLAUDE.md**
- Stop-at-red now applies to interactive sessions only. Under `scripts/deliver.sh`, the test-reviewer's approval is that review.
- A new "Delivery workflow" section names the six stages and the exemplar, and says to update the exemplar when a build teaches something new.
- I updated the testing memory to match.

The plan-writer's tool allow-list now includes `git worktree list` and `git branch`, which the sweep needs. The fake-`claude` state-machine tests still pass. The plan-writer still hasn't run for real on an issue.

---

## Timing

| Stretch | Wall clock | What it was |
|---|---|---|
| The first request, to both files drafted and tested | 09:49–10:05 (16m) | Research, the two Haiku probes, writing, and the fake-`claude` test runs that found the three bugs |
| The follow-up, to the exemplar and the rewritten spec | 10:05–10:14 (9m) | About 2½ minutes of that was the three subagents running in parallel (the slowest took 2m 23s). CLAUDE.md was edited during that wait |
