# Chat Transcript

**Topic:** A seventh agent for the delivery team, the acceptance-reviewer: it deploys the build to
the branch's preview, proves it there with a standard smoke pack and a feature pack it writes,
and writes the proof a human accepts from. This session covers:
- designing it with the `superpowers` brainstorming and planning skills, and building it inline,
  test-first, with one whole-branch review at the end
- the review's critical finding: an agent can't reliably run a deploy that outlasts its tool
  call, so the workflow deploys the preview instead
- testing the agent on two real issues, and grading it by rerunning its feature pack against a
  preview of unfixed `main`, which showed two of its three "passed" tests proved nothing
- the prompt fix, re-graded the same way; the issue template fixed at the source; and the
  handoff for moving the workflow to GitHub

**Date:** 15–16 October 2026
**Project:** `caw-project` — CollabHub, the *Claude at Work* sample project
**Model:** Claude Opus 5.5, Claude Code CLI
**Session:** `57d91093-1542-40e5-aed8-0cab86caf34b` · 15 October 13:31–16:47 UTC, with
follow-ups at 19:08 and on 16 October 05:00–05:31. The first block includes two long delivery
runs in the background; the context was compacted at 16:47.

Messages are verbatim. Tool calls are summarised in italics — one note per run of them — so the
work is visible without pages of command output. 130 tool calls ran in this session before the
export; 383,000 output tokens. Sub-agent reports and background-task notifications are
summarised the same way.

This follows on from [`01-preview-deployment.md`](./01-preview-deployment.md), which built the
preview environments this agent deploys to, and wrote issue 7, which this session delivers.

---

## User

*(`/clear`)*

we are going to add a final ‘acceptance-reviewer’ agent to the team and deliver.sh. it’s role is to check the work and collect proofs to streamline human acceptance: review all the work, send back if necessary; deploy the preview environment and verifies its healthy and reachable;  run a basic smoke test pack (new - standard in the repo); writes and runs a custom smoke test pack for the new feature; captures screenshots where relevant; writes a proof.md doc with summaries and a link to where the screenshots are. later the same agent will create a PR, so the proofs it collects are targeted for that

---

## Assistant

*(the `superpowers:brainstorming` skill loaded)*

*(listed `.claude/agents` and `.claude/delivery`, read `scripts/deliver.sh` and `agent-context.md` in full, and read the preview commands in `scripts/deploy.sh` and `scripts/lib/preview.sh`, the BDD harness's config and page objects, the code-reviewer's structure and the ch08 team-review handoff)*

> **Elton selected:** *Everything throwaway* — for where the feature's smoke pack and screenshots live (the recommendation was both on the branch)
>
> **Elton selected:** *Leave it up (Recommended)* — for the preview when the agent finishes
>
> **Elton selected:** *Acceptance lens (Recommended)* — for how deep "review all the work" goes

*(checked how `testkit`'s plugin assigns test layers, and the root `pytest` config)*

That's enough to design against. One more finding: `smoke` is already a marker, used as a Gherkin tag in `tests/bdd`, so the new pack needs a different marker.

## Approaches for running the smoke packs

1. **A new `scripts/smoke.sh` running a pytest + Playwright pack in `tests/smoke/`, pointed at an origin.** *(Recommended)* It's the same toolchain as `tests/bdd`. Developers and CI can run it after any deploy, not only on a preview. Its output goes to a directory you choose, and it never touches `docs/test-report.md`.
2. **A new `scripts/test.sh smoke` layer.** This fits the existing entry point, but every `test.sh` run rewrites the committed test report, and only the code-writer may write that.
3. **The agent drives the browser itself through Chrome MCP.** This isn't repeatable or headless-safe, and it leaves no pack a developer can run again.

## The design

**1. The pipeline**
- `acceptance-reviewer` becomes the seventh entry in `STAGES`. It's a reviewer with no writer of its own, in a new pair called `acceptance`.
- Its possible results:
  - `approved` ends the run.
  - `send_back` goes to the code-writer, and the flow then comes forward through the code-reviewer and back to it. If the fault is in a test or the plan, the code stages pass it further back under the existing rule.
  - `needs_human` stops the run as usual.
  - `changes_requested` is refused, because there's no writer to receive it.
- `deliver.sh` gains `SB_acceptance_reviewer` and `SENDBACKS_code`, which `DELIVER_MAX_SENDBACKS` bounds. The send-back branch skips the `PENDING_` hand-off when the sender has no writer.
- An approval is checked by `build/acceptance/proof.md` existing, not by a review file.
- Pre-flight adds `cloudflared`, `k3d`, `kubectl` and `curl`.
- A second acceptance pass is a rework pass: it redeploys (the live tunnels are reused) and reruns both packs.

**2. The agent** (`.claude/agents/acceptance-reviewer.md`)
- It reads the shared context first, the same as the other six.
- Steps:
  1. Read the issue, the plan's decisions (**assumed** ones especially), the red and green reports, and every review's *Left for the human* section.
  2. Run `scripts/deploy.sh preview up` and confirm it printed `APP_ORIGIN`.
  3. Run the standard pack.
  4. Write a feature pack under `build/acceptance/smoke/`, one test for each acceptance criterion visible from outside, taking screenshots.
  5. Run the feature pack and write `proof.md`.
- Allowed Bash: the read-only set, plus `scripts/deploy.sh preview *` and `scripts/smoke.sh *`.
- Write scope: only `reviews/acceptance-reviewer-sendback-*` on the branch. Everything else goes under the ignored `build/acceptance/`.
- **Send-back rule:** only for a criterion that fails on the preview, or a broken standard pack, when the branch's code caused it.
- If the preview won't come up for reasons outside the branch, it retries once, then returns `needs_human`.
- Model: Sonnet, the same as the stages that mostly run and record. This choice is unmeasured, so it's one to revisit.
- First-pass turn cap: 200.

**3. The smoke harness**
- `tests/smoke/` is importable as `smoke.*` under the existing `pythonpath`.
- `smoke.fixtures` is loaded with `-p`, so a pack in `build/` gets the same fixtures. The fixtures provide:
  - the origin
  - a Playwright page signed in through Dex as Ada
  - `shot(name)`, which saves a screenshot to the output directory
  - a `smoke-<run-id>` prefix for anything the pack creates
- **Non-destructive by rule:** the pack reaches the app only through the origin. It never touches a database, never truncates, and creates only prefixed data.
- Marker: `preview`.
- `uv run pytest` skips the pack unless an origin is given.
- Standard pack:
  - the SPA loads
  - JWKS answers
  - each service's health check answers through the Ingress
  - `/api/v1/internal/` returns 404 (D40)
  - Ada signs in and sees the shared workspace
  - creating a channel and a message survives a reload
- `scripts/smoke.sh [--origin URL] [--out DIR] [extra paths…]` takes flags rather than environment variables, because agents can't use an environment prefix. The origin defaults to `preview url`.

**4. `proof.md`, shaped for the PR**
- verdict
- a 3–5 bullet summary, ready to paste into a PR
- **Try it:** the origin, the sign-in, the warning that tunnel URLs die when cloudflared stops, and `preview down` to tear it down
- a table with one row per acceptance criterion: how it was proven, and its result
- preview health
- standard pack results
- feature pack results, with screenshots
- a link to `screenshots/`
- **For the human:** assumed decisions, departures, and minor findings left by every stage
- the run's cost

**5. Proving it**
- **Red first:** cases added to `.claude/delivery/loop-test.sh` for:
  - approval ends the run
  - a send-back goes to the code-writer, then the code-reviewer, then acceptance again
  - `changes_requested` is refused
  - the send-back bound
  - a missing `proof.md`
- The standard pack is proven by running it against k3d.
- Docs updated in step: the `deliver.sh` header, the team table in `agent-context.md`, and `CLAUDE.md`'s delivery section.

**Not in scope:** creating the PR. `proof.md` is laid out so that step can lift whole sections from it.

The spec would go in `docs/plans/ch09/01-acceptance-reviewer-design.md`, in a new worktree at `../caw-acceptance-reviewer` on `feature/acceptance-reviewer`. Does the design look right, or should anything change before I write it?

---

## User

proof.md should live with the other docs, and stay in the repo - other proofs are disposable

---

## Assistant

I'll take that as approval of the rest. Changes: `proof.md` becomes `docs/plans/issue-<N>/04-proof.md`, tracked on the branch, numbered after the green report. Its write scope covers it, and the approval check looks for it. The screenshots and the feature's smoke pack stay disposable under `build/acceptance/`, and `04-proof.md` links to them locally. I'm setting up the worktree and writing the spec now.

*(created the worktree `../caw-acceptance-reviewer` on `feature/acceptance-reviewer`, checked the Ingress's public prefixes and the services' health routes, and wrote the spec, `docs/plans/ch09/01-acceptance-reviewer-design.md`)*

I've written the spec to `../caw-acceptance-reviewer/docs/plans/ch09/01-acceptance-reviewer-design.md`, in a new worktree at `../caw-acceptance-reviewer` on branch `feature/acceptance-reviewer`. Nothing is committed.

The proof now sits on the branch as `docs/plans/issue-<N>/04-proof.md`, after the green report. Everything else the stage produces is disposable, under the ignored `build/acceptance/`: screenshots, the feature's smoke pack and the JUnit results. The proof's screenshot links therefore only work inside the worktree; the later PR step will upload the images.

The decisions most worth checking:

- **Who it sends back to:** only the code-writer, and only when an acceptance criterion fails on the preview, or the standard smoke pack fails, because of the branch. Everything else goes in the proof's *For the human* section. Asking it for changes isn't allowed, because the stage has no writer to take them.
- **The smoke harness:**
  - The standard pack lives in `tests/smoke/` and runs through a new `scripts/smoke.sh` that takes the target origin as a flag.
  - The pack is non-destructive: it reaches the app only through the origin and only creates data with a run-specific prefix.
  - Its pytest marker is `preview`, because `smoke` is already a Gherkin tag in `tests/bdd`.
- **Health checks:** the standard pack proves the SPA, the signing keys, sign-in, a channel and message, an upload, and that `/api/v1/internal/` can't be reached. I didn't use per-service health checks, because the Ingress doesn't expose those routes.
- **Model:** Sonnet, but that's a guess until a real run gives numbers.
- **Proof of the whole stage:** one end-to-end `deliver.sh` run of issue 007.

Please review the spec. Once you approve it, I'll write the implementation plan. The first step will be the failing tests: new cases in `loop-test.sh` and unit tests for `smoke.sh`.

---

## User

approved

---

## Assistant

*(the `superpowers:writing-plans` skill loaded)*

I'm using the writing-plans skill to create the implementation plan. To write concrete tests I need the style of the existing harnesses, so I'm reading them first.

*(read `loop-test.sh` in full, the preview script's unit tests, `common.sh`, the BDD page objects for sign-in, chat and attachments, and the BDD fixtures)*

I'm writing the implementation plan; first, three quick facts it depends on: script helpers, the demo workspace name, and the channel-name rules.

*(checked `common.sh`'s helpers, the demo workspace's name and Messaging's channel-name rules; edited the spec twice — no `preview` marker, and the internal API answers HTML rather than 404 — and wrote the 48,000-character plan, `docs/plans/ch09/02-acceptance-reviewer-plan.md`)*

The implementation plan is written: `../caw-acceptance-reviewer/docs/plans/ch09/02-acceptance-reviewer-plan.md`, on `feature/acceptance-reviewer`. Nothing is committed.

While planning I found three things that changed the spec, and I've edited `01-acceptance-reviewer-design.md` to match:
- **The internal API isn't a 404.** The Ingress sends `/api/v1/internal/` to the app's `index.html`, so the smoke test checks that path answers with HTML rather than a service's JSON.
- **No `preview` marker.** Changing `testpaths` from `tests` to `tests/bdd` is simpler: a plain `uv run pytest` never collects the smoke packs, and only `scripts/smoke.sh` runs them.
- **`loop-test.sh` can't see an uncommitted agent.** It builds its worktree from `HEAD`, so a new `acceptance-reviewer.md` that isn't committed would make every run pause. Task 1 starts the loop worktree from your working copy instead.

The plan has seven tasks:
1. **Red:** new `loop-test.sh` scenarios for the stage — approve, approve with no proof, ask for changes, send back, the send-back limit, stop for a human, and writing outside its scope. Then a stop for you to review them.
2. **Green:** the stage added to `deliver.sh`.
3. **Red:** unit tests for `smoke.sh`'s arguments and where it finds the origin. Then a second stop.
4. **Green:** `smoke.sh`, the shared fixtures and the six-test standard pack. I'll check the pack fails against a dead origin, then passes on k3d and on a preview.
5. The `acceptance-reviewer.md` agent, written out in full in the plan.
6. Updates to `agent-context.md` and `CLAUDE.md`.
7. The first real `deliver.sh` run on issue 007. It takes about 80 minutes and costs money, so I'll ask you before starting it.

There are two ways to run it:
- **Subagent-driven:** a fresh agent builds each task and another reviews it before the next starts.
- **Native:** I build it in this session, with one review of the whole branch at the end.

I recommend **native**. The tasks share exact names: the context-block lines, the fake's new results, the fixture names. Most of the work is changes to one bash script, where having seen the whole of `deliver.sh` matters more than a fresh context for each task. The two stops for you to review the failing tests give independent checks at the points that matter.

Does the plan capture what you want, and which approach should I use?

---

## User

go native

---

## Assistant

*(the `superpowers:executing-plans` and `superpowers:test-driven-development` skills loaded)*

*(created the plan's workspace and progress ledger)*

Task 1: editing `loop-test.sh`.

*(seeded the loop worktree from the working copy's `.claude`, taught the fake `claude` the new verdicts, gave 13 existing scenarios a seventh verdict and added six acceptance scenarios)*

Running the red set.

*(ran the loop test red and recorded the result in the ledger)*

I've stopped at red for Task 1 so you can review the failing scenarios in `../caw-acceptance-reviewer/.claude/delivery/loop-test.sh`.

**What changed in the test harness:**
- The loop worktree now starts from your working copy's `.claude/agents` and `.claude/delivery`. Without that, an uncommitted agent file would never reach the test runs.
- The fake `claude` writes `04-proof.md` when the stage has no review path. It also has two new results: `approved_bare`, which approves without writing a proof, and `stray`, which writes `src/stray.txt` and then approves.
- 13 existing scenarios that used to finish at the code-reviewer now take a seventh verdict. `straight-through` also checks the new stage's prompt (`Proof:`, `Evidence:`, its send-back path, 200 turns), that it runs on Sonnet, and its `history.log` line.

**Six new scenarios:**

| Scenario | Expected |
|---|---|
| `acceptance-approves-without-proof` | exit 1 |
| `acceptance-may-not-ask-for-changes` | exit 1 |
| `acceptance-sendback` | goes code-writer, then code-reviewer, then acceptance again in round 2 as a rework pass; exit 0 |
| `acceptance-sendbacks-bounded` | the 4th send-back stops for a human; exit 2 |
| `acceptance-needs-human` | exit 2 |
| `acceptance-stray-write` | exit 1 |

**Result:** 55 checks fail, and all for the intended reason. `deliver.sh` doesn't know the stage yet, so every run ends after the code-reviewer and leaves the seventh verdict unused. The six scenarios with no seventh verdict still pass.

The plan predicted a different failure: a pause at the stage, with exit 3. It isn't paused, because the stage isn't in `STAGES` yet. The cause is the same, and I've recorded that as a ruling in the ledger.

Nothing is committed; the changes are `.claude/delivery/loop-test.sh` and `docs/plans/ch09/`. Say go and I'll do Task 2, the changes to `deliver.sh`, then run through to the next stop at Task 3's red.

---

## User

yes, keep on working it through /goal get the acceptance agent prompt and script workflow ready to test on a real issue

---

## Assistant

Carrying on through to the goal, with no stop at Task 3's red; I'll record that red run instead. Task 2: the stage in `deliver.sh`.

*(added the stage to `deliver.sh`: the `acceptance` pair, its context-block lines, write scope, tools, model and turn cap, the writerless send-back branch and the closing log)*

The script compiles. Instead of a placeholder agent, I'm writing the real agent file now (Task 5), then running the loop test.

*(wrote `.claude/agents/acceptance-reviewer.md` and ran the loop test — every scenario passed)*

The loop test is green. Next, Task 3: the unit tests for `smoke.sh`.

*(wrote the 12 unit tests from the plan and ran them)*

Red, as expected: all 12 tests fail because `scripts/smoke.sh` doesn't exist yet. Next, Task 4: `smoke.sh`, the fixtures and the standard pack, copied from the plan.

*(created `scripts/smoke.sh`, `tests/smoke/fixtures.py` and the six-test `test_platform.py` from the plan's code blocks, and ran the unit tests green)*

The unit tests are green. Now lint, and checking that the `testpaths` change doesn't break collection.

*(the lint hook blocked on an `S603` and an ambiguous character; waived `S603` the way the existing script test does, fixed the character, and ran the whole unit layer — the smoke pack was not collected)*

Lint is clean. Task 4 Step 5: checking the pack fails against a dead origin.

*(ran the standard pack against an origin with nothing behind it)*

It fails as it should: 3 failures and 3 setup errors, none passing. Step 6: is k3d up?

*(found the k3d cluster with no CollabHub deployed, and started `scripts/deploy.sh preview up` for this branch in the background)*

While the preview builds, Task 6: updating the shared context and `CLAUDE.md`.

*(updated `agent-context.md` for a seventh agent — one edit script failed on a stale match and was redone — and `CLAUDE.md` and the schema comment in `deliver.sh`)*

While the preview builds: everything is updated except the live pack run. I'll wait for the deploy to finish.

*(checked the deploy's progress)*

The images are still pushing. Meanwhile I'm starting the whole-branch review with a fresh reviewer on Opus.

*(dispatched an Opus sub-agent to review the whole branch)*

The reviewer is running alongside the preview deploy. I'll pick up when either finishes.

---

## User

*(background task: "Deploy this branch's preview environment" completed, exit 0)*

---

## Assistant

*(read the deploy's result)*

The preview is up. Running the standard pack against it, using the default origin from `preview url`:

*(ran `scripts/smoke.sh` against the preview)*

6 of 6 passed on the preview in 15 seconds. Checking that a screenshot actually shows the feature:

*(opened the screenshots: the image round-trip test had uploaded a 1×1 transparent PNG, so its screenshot showed nothing; tried to replace it with a generated solid-colour PNG in an edit script)*

That edit script failed and changed nothing. Redoing it with Edit:

*(added `solid_png()` and a visible 160×90 PNG to the fixtures; the second edit missed)*

The lint hook had already removed the unused `base64` import, which is why the second edit missed. Adding the two imports:

*(added `struct` and `zlib`, reran the whole standard pack on the preview — 6 passed — and worked out from the deploy log how long `preview up` had taken)*

Here, `preview up` took about 3 minutes with a warm build cache. A cold build on a feature branch will be slower but should usually fit the 10-minute cap. I'm adding both points to the agent prompt.

*(told the agent the deploy takes about three minutes warm and to use the Bash tool's longest timeout, to upload an image a person can see, and to look at every screenshot it cites; recorded the preview results and rulings in the ledger)*

Everything is built and proven on a live preview. I'm waiting on the whole-branch review before reporting.

---

## User

*(the review sub-agent reported. **Critical:** `preview up` — a cold build and three Helm waits of up to 10 minutes each — can't reliably finish inside the agent's 10-minute Bash ceiling, and a cut-off deploy leads to a second `preview up` colliding with the first. Its preferred fix: `deliver.sh` deploys before the stage and passes the outcome in the context block. **Important:** an approval would accept a proof left from an earlier pass; `git diff main` can't show a delivery's new files, since nothing is committed; two loop scenarios pass for the wrong reason; and every delivery from the same commit tags its images `<sha>-dirty`, so previews left up side by side can pull each other's images. Nine minors, and eleven areas checked and sound)*

---

## Assistant

The review found one critical and four important findings. Before deciding on I4, I'm checking how `deploy.sh` handles a `-dirty` tag on redeploy.

*(read the image-tag defaults and the app rollout logic, then added red loop scenarios: the workflow deploys the preview, a deploy retried once and one that fails twice, a stale proof, and exact failure messages for the two scenarios that passed for the wrong reason)*

Now the red test for I4, in the preview script's unit tests. First, how that file calls the shell functions:

*(read how the preview tests call the shell functions; the Edit was refused because the file hadn't been read; ran the loop test red)*

The loop test is red for the right reasons. The preview-tag test edit was refused because I hadn't read that file yet, so reading it now:

*(read the test file, added three tests for a namespaced dirty tag, and ran them)*

Red, as expected: `preview_image_tag` doesn't exist yet. GREEN: first the tag function, wired into `preview up`.

*(added `preview_image_tag` to `scripts/lib/preview.sh` and used it in `cmd_preview_up`)*

Now `deliver.sh`: the workflow deploys the preview itself, the stale-proof check, and the narrowed tool list.

*(made `deliver.sh` run `deploy.sh preview up` before each acceptance pass with one retry, logging to `build/acceptance/preview-up.log` and passing a `Preview:` line; hashed the proof before each pass and required it to change; cut the agent's tools to `preview url` and `smoke.sh`; ran the loop test — every scenario passed)*

Green: every scenario passes. Now updating the agent prompt to match. The workflow deploys, so §2 reads the `Preview:` line; I'm also fixing the git commands (I2) and the smoke-run guidance.

*(rewrote the agent's preview and record sections)*

Now the shared context gets the `Preview:` line, and the spec records the change.

*(updated `agent-context.md` and the spec; ran `bash -n`, lint, the unit layer and the convention checks)*

All checks pass: 465 unit tests, lint clean, and the convention checks have nothing to report. `deploy.sh` changed, so I'm redeploying the real preview under the new image tag and rerunning the pack.

*(started the redeploy and pack run in the background, and recorded the final review's outcome in the ledger)*

---

## User

issues 002-005 were delivered by the team (i think?) we can test the acceptance agent prompt on their output

*(sent mid-turn)*

---

## Assistant

Good idea. Running the acceptance stage on its own against an issue that's already delivered tests the prompt without the 80-minute full run. Checking what's left of those deliveries:

*(found issues 2–5 merged to `main` with no delivery worktrees left, and read issue 5's acceptance criteria)*

Issue 5 is a good test case: three users and clear, visible criteria. Checking the preview's identity provider knows all three users, and how the earlier run ended:

*(confirmed Dex has ada, grace and alan; created `../caw-issue-5-acc` on `feature/issue-5-acc` from `main`, reset `--mixed` to the commit before issue 5 so its delivery shows as uncommitted, copied the new tooling over it, and seeded the delivery state to resume at the acceptance stage)*

The worktree is ready. Waiting on the preview redeploy before starting the issue-5 run.

---

## User

*(background task: "Redeploy the preview with namespaced tag and rerun the pack" completed, exit 0)*

---

## Assistant

*(read the redeploy result — 142 seconds, 6 passed — started the acceptance stage on issue 5's delivery in the background, and recorded the setup in the ledger)*

The acceptance stage is running on issue 5's delivery in `../caw-issue-5-acc`. I'll review its proof when it finishes.

---

## User

*(background task: "Run the acceptance stage on issue 5's delivery" completed, exit 0)*

---

## Assistant

*(read the run's outcome and its evidence)*

The issue-5 run approved in 5.7 minutes for $0.86. Checking the proof and the screenshots before trusting that verdict:

*(read the issue-5 proof in full and opened four of the screenshots it cites; collected the ledger's rulings, removed the plan's workspace and showed the tree's status)*

The acceptance agent and its workflow are ready, and the first real test passed. I ran the acceptance stage alone against issue 5's delivery (direct messages, three users), and it approved in 5.7 minutes for $0.86. All 7 visible criteria passed on the live preview, and each of the 8 internal ones is mapped to a named test. Its proof is at `../caw-issue-5-acc/docs/plans/issue-5/04-proof.md`. That preview is still up at https://offers-video-radical-jeremy.trycloudflare.com; sign in as ada, grace or alan with password `collabhub`.

The work is in `../caw-acceptance-reviewer` on `feature/acceptance-reviewer`, uncommitted.

**What was built:**
- **`.claude/agents/acceptance-reviewer.md`**: the agent prompt, on Sonnet.
- **`scripts/deliver.sh`**: the seventh stage. `deliver.sh` deploys the preview itself before each acceptance pass and retries a failure once. The stage approves, sends back to the code-writer, or stops for a human.
- **`scripts/smoke.sh` and `tests/smoke/`**: the new smoke harness. The standard pack has six tests that only reach the app through its origin. A feature's own pack goes under `build/acceptance/` and is thrown away; the proof stays at `docs/plans/issue-<N>/04-proof.md`.
- **Spec and plan** in `docs/plans/ch09/`, plus updates to `agent-context.md` and `CLAUDE.md`.

**Tests:** the delivery loop test passes every scenario, including 8 new ones for this stage. 465 unit tests pass, including 15 new ones. On a live preview the standard pack passed 6 of 6.

**What the final review changed.** A separate reviewer found one critical and four important problems; all are fixed, each with a test written to fail first:
- **Deploy timeout (critical):** the agent was running the preview deploy itself, and a cold build can outlast its 10-minute command limit, leaving Helm stuck mid-deploy. The workflow now deploys before the stage runs. The agent can only read the preview's URL.
- **Stale proof:** a run could finish on a proof left from an earlier pass. An approval now requires the proof to have changed during that pass.
- **Wrong git command in the prompt:** `git diff main` misses every new file in a delivery, because nothing is committed. The prompt now uses `git status --untracked-files=all` and `git diff --stat`.
- **Two loop scenarios passed for the wrong reason:** they now check the actual error message.
- **Shared image tags:** every delivery branched from the same commit tagged its images `<sha>-dirty`, so previews left running side by side could pull each other's images. A dirty preview's tag now includes its namespace. This changes `scripts/deploy.sh` and `scripts/lib/preview.sh`.

**What the issue-5 run showed:**
- Its first attempt at the feature pack failed 5 of 5, because it guessed the users' display names. It read the screenshots, fixed its own test rather than blaming the feature, and recorded that in the proof.
- It flagged that the two header screenshots were taken while the message history still said "Loading messages…".
- The issue-6 changes in the same diff didn't confuse it.

To get that test, I made `../caw-issue-5-acc` on `feature/issue-5-acc` from `main` and reset it to just before issue 5, so issue 5's work (plus issue 6's, as noise) shows as uncommitted. I copied the new tooling over it and started the run directly at the acceptance stage.

**One improvement I'd make next:** the `smoke-…` channels each run creates pile up in every user's sidebar on a preview and clutter the feature screenshots. The standard pack should archive the channels it creates.

**Decisions I made along the way:**
- No commit steps, per `CLAUDE.md`.
- I didn't stop for review at the second red stage (the `smoke.sh` tests), since you said to keep working through. Those tests haven't had your review yet.
- I skipped proving the pack on plain k3d, because that cluster has no CollabHub deployed. The pack is proven on a preview only.
- The upload test used an invisible 1×1 PNG: the test passed but its screenshot showed nothing. It now uploads a visible 160×90 blue image, and the prompt tells the agent to look at every screenshot it cites.
- I wrote the real agent file straight away instead of a placeholder.

**Minor findings I left alone:**
- There's no option to skip the standard pack, so it reruns beside every feature pack.
- No loop scenario covers the pause when an agent file is missing.
- The page-load test catches uncaught exceptions but not console errors.
- One `smoke.sh` unit test creates a directory under `build/` in the repo.

**Still running:** two previews, this branch's and issue 5's. Take mine down with `scripts/deploy.sh preview down` from the feature worktree, and issue 5's with `BRANCH=feature/issue-5-acc scripts/deploy.sh preview down` when you're done with it.

The full run on a new issue (plan Task 7, issue 007) is the next step. It takes about 80 minutes and costs real money, so it's yours to start.

---

## User

Take down the previews. Issue 7 is?

---

## Assistant

*(took down both previews and read issue 7)*

Both previews are down, and the cluster has no preview namespaces left.

**Issue 7, "A name for a member who joined after the directory loaded":** a small bug fix in the web app only, with no backend changes.

- **The bug:** each browser tab loads the workspace's member list once and keeps it for 5 minutes. If someone joins after that, the tab shows them as an 8-character id everywhere a name should appear (their messages, the DM list, typing, search) until the list expires or the page reloads. It turned up on the first preview: Grace's first message appeared on Ada's screen as `01a13ec0`.
- **The fix:** when the app meets an id the member list doesn't know, it fetches the list again, once, and the name appears.
- **Scope:** one shared hook, `useWorkspaceMembers.ts`, which seven components use. That hook has no tests yet.

It's a good first full run for the acceptance stage. The bug is visible and easy to reproduce on a fresh preview:
1. Ada signs in and opens a channel.
2. Alan signs in for the first time, which adds him to the demo workspace, and posts.
3. Ada's open tab should show "alan", not an id, with no reload.

A freshly deployed preview should make step 2 a genuine first sign-in, but the agent will need to get the order right: Ada's member list must be loaded before Alan is created.

To run it, this branch's files first need to reach the new issue worktree, as before. Either commit the branch, or copy the files over a fresh worktree as in `docs/plans/ch08/04-team-review-handoff.md`. Then run `scripts/deliver.sh docs/issues/007.md`.

---

## User

Whichever approach you prefer - run the script and eval the acceptance agent

---

## Assistant

I can't commit the branch (`CLAUDE.md` forbids it), so I'll use the copy approach. Checking how handoff 04 hid copied files from the agents:

*(read how the ch08 runs hid copied tooling; created `../caw-issue-7` on `feature/issue-7` from `main`, copied the tooling in, and hid it from `git status` — tracked files with `git update-index --skip-worktree`, new ones with a per-worktree exclude file)*

The issue worktree shows a clean `git status`. Launching the full delivery of issue 7: seven stages, about 80 minutes.

*(started `scripts/deliver.sh docs/issues/007.md` in the background)*

Issue 7's delivery is running in the background. When it finishes I'll evaluate the acceptance stage on:
1. The proof itself: whether each criterion is mapped correctly and whether the screenshots show what they claim.
2. Whether the feature pack proves anything. I'll run it against a preview of unfixed `main`, where it should fail, because the newcomer still shows as an id there.

---

## User

how are we looking?

---

## Assistant

*(read the run's `history.log`)*

It's going well. Nine stages have finished with nothing stopped for a human, and the code-reviewer is running now. The acceptance-reviewer is next.

| Stage | Result | Time | Cost |
|---|---|---|---|
| plan-writer | done | 8.2m | $2.58 |
| plan-reviewer | changes requested (2 major) | 5.2m | $2.00 |
| plan-writer | fixed all five findings | 3.1m | $1.26 |
| plan-reviewer | approved | 1.5m | $0.79 |
| test-writer | 15 failing Vitest tests | 3.4m | $0.82 |
| test-reviewer | changes requested (1 major) | 4.0m | $0.86 |
| test-writer | fixed | 0.8m | $0.27 |
| test-reviewer | approved | 1.3m | $0.37 |
| code-writer | all green: Vitest 503/503, e2e 24/24 | 4.2m | $0.50 |
| code-reviewer | running | | |

So far that's about 32 minutes of stage time and $9.45.

The test-reviewer's major finding was a real one. One test, meant to show each workspace keeps its own list of departed members, also passed against a build that shared one list across all workspaces. The rewrite fixed that.

The fix stays inside the web app. When it meets an id it doesn't know, it refetches the member list once, joining any fetch already in flight. Ids of people who have left go quiet instead of triggering refetches. It also refetches the list on socket reconnect.

I'll evaluate the acceptance stage once it finishes.

---

## User

*(background task: "Run the full delivery workflow on issue 7" completed, exit 0)*

---

## Assistant

*(read the end of the run and its evidence)*

Approved in 3 minutes for $0.64. Now the evaluation. First, the feature pack the agent wrote:

*(read the proof, the agent's feature pack `test_issue_7.py` and the newcomer screenshot, and started a preview of unfixed `main`, `preview-eval-issue7-main`)*

That screenshot shows the fix working on the preview. Now the counter-test: the agent's own pack against unfixed `main`, where Grace has never signed in.

*(ran the agent's pack against the `main` preview: 1 failed, 2 passed)*

On `main`, the agent's first test fails with exactly the bug: Ada sees Grace's message from `01a14038`. On the fix it passes. Taking down the eval preview:

*(took down the `main` preview)*

Issue 7 went all the way through with nothing stopped for a human: 11 stages, about 40 minutes of stage time plus a 3-minute preview deploy, $12.50 in total. The acceptance stage took 3 minutes and $0.64 of that. Its proof is `../caw-issue-7/docs/plans/issue-7/04-proof.md`, and the issue-7 preview is still up for you to click through. Nothing is committed.

**What the acceptance-reviewer got right:**
- **The key test proves the fix.** I ran its feature pack against a fresh preview of unfixed `main`. The newcomer test failed with the bug itself: Ada saw Grace's message from `01a14038`. On the fix it passes. It got the tricky ordering right on its own: Ada's tab loads first, then Grace signs in for the first time, so she really is a newcomer.
- **It checked the request count.** It counted Ada's member-list requests (1–2), which is the closest a browser gets to the "refetch once" rule.
- **It disclosed the weak parts of its own evidence**, without being asked:
  - it never saw the short id on screen, only the name arriving without a reload;
  - tests 2 and 3 run after Grace is already known;
  - a rerun on the same preview no longer has Grace as a first-time joiner.
- **It picked up the code-reviewer's main open point.** The code-reviewer said the manual two-browser run was the only check left of the request count. The proof says which parts of that run its pack covers and which it doesn't (the messaging restart and a per-id count), under *For the human*.
- **The record is complete.** It collected all seven assumed decisions, the departures, and the code-reviewer's minor findings, and the screenshot I checked shows Grace's name on the message.

**Where it fell short:** tests 2 and 3 (the DM list and the reconnect) also passed on unfixed `main`. The proof's table still marks those two criteria "passed" alongside the first, and only the *For the human* section says they don't discriminate. A reader skimming the table would take three proofs where there is one.

I'd fix that in the prompt rather than make the agent deploy the old code too. For each visible criterion, it would name the build its test would fail on, which is the rule `agent-context.md` already sets for every other stage. A test that would also pass without the change gets labelled "regression check" in the table, not "proven". It's a few lines in `acceptance-reviewer.md`; do you want me to make it?

---

## User

yes, let’s also make sure the acceptance agent is using the shared context and we’re not duplicating content in there. also: we don’t specify any of the superpowers skills for the other agents (e.g. writing a plan); is that worth adding? we could run some eval loops on issue 7

---

## Assistant

Before deciding on adding skills, I want evidence of what the agents do now. The superpowers plugin's session-start hook may already fire in headless runs. Checking the issue-7 transcripts for skill calls:

*(searched the issue-7 agents' transcripts for skill calls and the superpowers hook)*

The hook does fire in headless runs, so every agent already gets the superpowers introduction, and three of them invoked skills unprompted. Finding out which stages those were:

*(mapped the transcripts to stages: the plan-writer invoked `writing-plans`, the test-writer and code-writer `test-driven-development`. Then rewrote the agent prompt to defer to the shared context — removing its copies of the server-proof rule, the send-back file's contents, the stop-for-a-human list, the rework mechanics and the status list — and added the rule that each test names the build it must fail on, the regression-check label, and a note that a preview's state outlives a run. Reset issue 7 to rerun only the acceptance stage on a fresh preview, and started it in the background)*

While that runs, on whether to name superpowers skills in the agents. To give you options, I need to know how a run can switch the plugin on or off:

*(read how the plugin is enabled in the user settings and which CLI flags can override it)*

The rerun is still going. Here's my view on the skills while it finishes.

**Don't name superpowers skills in the agent prompts.** If anything, `deliver.sh` should switch the plugin off. Three reasons:

1. **It's already in every run, just not by design.** The plugin's session-start hook runs in headless sessions too, and it tells every agent it MUST invoke skills. In this issue-7 run, 3 of 11 stages did so on their own:
   - the plan-writer used `writing-plans`;
   - the test-writer and code-writer used `test-driven-development`.

   The ch08 runs probably had the same uncontrolled variable.
2. **The skills conflict with the team's own rules.**
   - `brainstorming` has a hard gate that waits for a human to approve, which is fatal in a headless run.
   - `writing-plans` saves to `docs/superpowers/plans/`, writes commit steps, and ends by asking the human to choose an execution method.
   - `test-driven-development` says to delete code written before its test, while this repo splits red and green across separate agents.

   The agent prompts, the exemplar plan and `agent-context.md` already hold the repo's own version of each of these, refined over the ch08 runs.
3. **It isn't portable.** The plugin is in your user settings, so a teammate or CI would get different agents. That cuts against "CI runs the same scripts".

**An eval worth running on issue 7:** plugin on (as today) against plugin off. `deliver.sh` would pass `--settings '{"enabledPlugins":{"superpowers@claude-plugins-official":false}}'` to each agent, behind a temporary switch.
- **Runs:** two per arm. One plugin-on run is already done, so three new ones, at about $12 and 45 minutes each. They have to run one after another, because two preview deploys can't run at once. That's about 2.5 hours and $36.
- **Measures:**
  - stops for a human, rounds and send-backs;
  - time, turns and cost per stage;
  - each acceptance verdict, plus its feature pack run against `main`, as I did today;
  - a blind comparison of the plans and code, as in ch08/05.

Should I set that up and run it? I'll report on the acceptance rerun when it lands.

---

## User

*(background task: "Rerun the acceptance stage on issue 7 with the revised prompt" completed, exit 0)*

---

## Assistant

*(read the rerun's outcome and its criteria table — approved in 1.9 minutes, 25 turns, $0.54 — then deployed a fresh preview of `main`, ran the new pack against it, and took that preview down)*

The new labels are accurate. On unfixed `main`, both tests the agent marked **proven** fail: the first with the bug itself (`01a14042` where "grace" should be). The **regression check** passes, just as the proof says. The `main` preview is down again.

| | First run (old prompt) | Rerun (new prompt) |
|---|---|---|
| Tests that fail on `main` | 1 of 3 | 2 of 3 |
| How the proof labels them | all 3 "passed" | 2 **proven**, 1 **regression check** with the discriminating Vitest tests named |
| Stage cost | 3m, $0.64 | 1.9m, $0.54 |

**What changed in the prompt:**
- **The new rule:** for each feature test, the agent names the build it must fail (this branch without its change) and asks whether it would. It then arranges the test so only the change decides the outcome, or labels it a regression check. The rule refers to the shared *Tests that prove something* instead of restating it.
- **Less duplication:** I removed what repeated the shared context: the server-proof rule, what goes in a send-back file, when to stop for a human, rework mechanics, and the status list. One line went into the shared *Decide, record, carry on* for where the acceptance-reviewer records its assumptions.
- **A preview's state lasts beyond a run:** a test that needs a first-time user works once per preview, and the agent now has to say so.

Both files are in `../caw-acceptance-reviewer`, uncommitted. The issue-7 preview is still up from the rerun; take it down with `BRANCH=feature/issue-7 scripts/deploy.sh preview down`.

The plugin on/off eval from my last message is waiting on your go-ahead: three new issue-7 runs, about 2.5 hours and $36.

*(the context was compacted here, at 16:47, and the session resumed from a summary)*

---

## User

plugin eval doesn't really seem worth it?

---

## Assistant

Agreed, it isn't worth it. Two runs per arm would differ by about as much as any two runs of the same setup do: rounds, send-backs and cost already vary that much between runs. So $36 and 2.5 hours would most likely end in "no clear difference". It also wouldn't change the main decision, which is not to name the skills in the agent prompts:

- **They aren't portable.** The plugin is installed at user level, so a teammate's machine or CI wouldn't have it.
- **They conflict with the team's rules.** Each skill brings its own: brainstorming waits for a human, writing-plans has its own plan location and commit steps, and TDD's "delete the code" doesn't fit separate red and green agents.
- **The agents use them anyway.** In the issue-7 run, three agents picked them up unprompted. That run finished with no stops and good plans, so the plugin isn't hurting anything we can see.

That leaves one small question: whether `deliver.sh` should turn the plugin off so a run behaves the same on every machine. My suggestion is to leave it alone for now. If a run ever goes wrong in a way that traces back to a skill, the off switch is one `--settings` line in `invoke_agent`.

Still open on the acceptance work:
- **Handoff doc:** `docs/plans/ch09/03-acceptance-reviewer-handoff.md` (Task 7 of the plan).
- **Smoke channels:** archive the channels the smoke packs create, so preview sidebars don't fill up with them.
- **Issue-7 preview:** still up; take it down with `BRANCH=feature/issue-7 scripts/deploy.sh preview down`.

Should I do the handoff doc next?

---

## User

what would you write in the handoff?

---

## Assistant

It would follow the shape of `ch08/05-model-effort-handoff.md`: a record of what was built, what the trials showed, and what's left, so the next session (or the PR step) can start without this conversation.

**1. What was built**
- **The seventh stage:** how it plugs into `deliver.sh`. It runs as a pair with no writer, so it can only approve, send back or stop. Approval requires a fresh `04-proof.md`. Send-backs go to the code-writer, bounded by the acceptance pair's own round count. The workflow deploys the preview before each pass, with one retry, and passes the outcome in the `Preview:` line.
- **`smoke.sh` and the standard pack:** what the six tests cover, how a feature pack gets added, and that runs write to `build/` and never to `docs/test-report.md`.
- **The image-tag fix:** dirty builds now get a per-namespace tag, so two previews of uncommitted work no longer overwrite each other's images.
- **What stays in the repo and what doesn't:** `04-proof.md` stays. Everything in `build/acceptance/` is disposable, and the PR step will upload the screenshots.

**2. What the trials showed**

| Trial | Time | Cost | Result |
|---|---|---|---|
| Issue 5, acceptance stage only | 5.7m | $0.86 | approved |
| Issue 7, full run (11 stages) | ~40m | $12.50 | no stops for a human |
| Issue 7, acceptance v1 | 3m | $0.64 | approved, but its labels were wrong |
| Issue 7, acceptance v2 | 1.9m | $0.54 | approved, labels confirmed |

- **The counter-test against `main`:** this was the real evaluation method. In v1, only 1 of 3 feature tests failed on `main`, yet all 3 were marked "passed". After the prompt fix, 2 were marked **proven** and both failed on `main`. The third was labelled a **regression check** and passes on `main`, as the proof says.
- **The prompt change and its reason:** each test must name the build it would fail on. I'd also note that the duplication with the shared context was removed.
- **A preview's state lasts beyond a run:** a test of a first-time user is valid once per preview.

**3. Decisions and why**
- Proofs live with the plan; everything else is throwaway.
- The preview is left up after a run.
- The review is done through an acceptance lens, not a second code review.
- The workflow deploys the preview, not the agent. This keeps deploy permissions out of the agent's tools and makes retrying deterministic.
- The stage runs on Sonnet.
- **No superpowers skills named in prompts:** the reasons from my last message, plus the observation that the agents pick them up anyway.
- The rulings from the plan's execution: no commit steps, the red step was different from what the plan expected, and the pack was proven on a preview but not on plain k3d.

**4. Known gaps (the deferred minors)**
- `--out` and the pack paths resolve against different directories.
- There's no `--no-standard` option.
- `DELIVER_MAX_ROUNDS=1` makes the first acceptance pass a final round.
- No loop-test scenario covers the exit-3 pause.
- The page-load test catches page errors only, not console errors.
- A unit test writes into `build/` in the repo.
- Smoke channels pile up in preview sidebars.
- Code-reviewer findings stay with the human. The acceptance stage reports them but can't fix them.

**5. Next**
- **The PR step:** the proof is already written as a PR body, and the screenshots need uploading with `tea`.
- **Archiving smoke channels.**
- **Updating the issue exemplar:** add a nudge for issues to name a visible check that would fail without the change, since A2 and A3 in issue 7 couldn't discriminate as written.

It would be one file of about 120 lines. I'd skip a blow-by-blow of the trials; the proofs and the run logs already cover that. Should I write it?

---

## User

let's update the issue exemplar and issue-writer skill here; send back from acceptance agent - only to code-writer or to any earlier stage?

---

## Assistant

*(located the exemplar issue and the `issue-writer` skill in the feature worktree, read both in full along with issue 7's *Acceptance* section, and read how `deliver.sh` routes a send-back)*

I'm checking how the acceptance agent's send-backs are routed, then I'll edit the exemplar and the skill.

*(rewrote the exemplar's *Acceptance* section and added a *Why* note on checks that can't fail; added the question to the skill's grilling step and its final check, and changed "six agents" to "seven")*

I've updated the exemplar issue and the issue-writer skill in `../caw-acceptance-reviewer`, uncommitted. On send-backs: I'd keep the acceptance agent sending to the code-writer only.

## Send-back: code-writer only

Work can already go further back than that. Every stage can send work back one pair. So if the code-writer finds the real fault is in a test, it sends back to the test-writer, and the test-writer can send back to the plan-writer. Each hop is judged by the agent who owns that work, which matters for three reasons:

- **The acceptance agent sees symptoms, not causes.** It sees a check failing in a browser. Whether that's a bug in the code, a test that pinned the wrong thing, or a plan that misread the issue can only be told with the code open, and that's the code-writer's job.
- **Jumping straight to the plan gains nothing.** A send-back to the plan-writer reruns plan, tests, code and review anyway. The extra steps through the code-writer and test-writer are cheap next to that, and they catch a cause that turns out to be in the code after all.
- **Every hop stays bounded.** One rule — a send-back goes to the pair before you — and every send-back counts against `DELIVER_MAX_SENDBACKS`.

The one case it handles badly is a run that went wrong from the start, such as a plan that misread the issue in a way every later stage built on. That's better handled as a `needs_human` stop than by an automatic rerun of the whole delivery, which is what the acceptance agent already does.

## Exemplar issue

- **Renamed section:** the *Acceptance* heading now says "on the branch's preview" instead of "first real run on Compose". A new intro line says what makes each pinned-message check fail on `main` and why none of them needs a fresh preview.
- **New *Why* note, from issue 7:** two of its three checks also passed on `main`. "Grace is listed by name" and the reconnect check ran after the first check had already made Grace known to Ada's page, so there was no stale directory left to show the bug.
- **What the note asks for:** each check names a starting state that only the change can decide. If running a check uses up that state, the issue says so and gives each such check its own user, because a preview keeps its data between runs.

## Issue-writer skill

- "Six agents" is now "seven".
- **During the grilling:** for each acceptance check, the skill asks whether it would fail on `main` today and from what starting state. A check that would pass there either gets a starting state only the change can decide, or is cut.
- **In the final read-through:** every check states what makes it fail on `main`, and none relies on state an earlier check has already used.

The new *Why* note cites `docs/plans/ch09/03-acceptance-reviewer-handoff.md`, which doesn't exist yet. Either I write the handoff, or I change the citation to point at the issue-7 proof.

> The note added to the exemplar's *Acceptance* section:
>
> > **Why each check says what makes it fail without the change:** the acceptance-reviewer turns
> > every check into a browser test on the branch's preview, and a test that passes on `main`
> > proves nothing about the branch. Issue 7's three checks all passed on its preview, but two
> > passed on `main` as well: "Grace is listed by name" and "after a reconnect nothing shows a
> > short id" ran after the first check had already made Grace known to Ada's page, so the bug
> > never had a stale directory to show. Only a rerun against `main` found it
> > (`docs/plans/ch09/03-acceptance-reviewer-handoff.md`). For each check, name the starting
> > state that leaves only the change to decide it. If that state is spent by running the check
> > — a first sign-in, an empty workspace — say so, and name a different user for each check
> > that needs one: a preview keeps its data between runs.

---

## User

write the handoff - the next step will be moving the workflow to github, so the agent will be extended to create the PR there

---

## Assistant

*(read the ch08/05 handoff's structure, the spec's and agent file's headings, the standard pack's test names, and the repo's remotes — `origin` is GitHub, `forge` is Forgejo — then wrote `docs/plans/ch09/03-acceptance-reviewer-handoff.md`)*

I've written the handoff at `docs/plans/ch09/03-acceptance-reviewer-handoff.md` in `../caw-acceptance-reviewer`, uncommitted. It's about 190 lines, and the exemplar's new citation to it now resolves.

It covers:
- **Where it stands:** how the agent works, what it can return, what it writes and runs, and what a pass costs.
- **What changed:** the files, plus the loop-test and unit-test results.
- **The trials:** issue 5, the full issue-7 run, and acceptance v1 and v2. Rerunning each pack against `main` is the grading method, with what the prompt fix changed.
- **The decisions table:** this includes the send-back routing and the superpowers ruling.
- **Known gaps:** the deferred minors, plus the smoke channels piling up in preview sidebars.

The last section is written for the GitHub move, as decisions that step needs first:

1. **Who commits and pushes.** A PR needs a pushed branch, and the repo says no session commits. I suggest the workflow does it after `approved`, the same way it already owns the deploy, and the agent only gets `gh pr create --body-file`. Either way, *Never commit* in `CLAUDE.md` needs a stated exception.
2. **Where the preview lives.** A GitHub-hosted runner takes its k3d cluster and tunnel with it when the job ends, so "leave it up" means nothing there. The options are a self-hosted runner, a long-lived cluster, or tearing the preview down and relying on screenshots.
3. **Screenshots in the PR.** GitHub has no API for the inline image attachments its web editor makes. The options are a branch with raw links, an Actions artifact (a link only, no inline images), or committing them.
4. **The PR body:** lift the proof as it is, with the screenshot links rewritten.
5. **One delivery at a time:** two previews deploying at once clash over KEDA, so the GitHub workflow needs a `concurrency:` group.
6. **What CI changes about a run:** there's no superpowers plugin on a runner, so the first CI runs set a new baseline. The run also needs an Anthropic key as a secret.
7. **`gh` instead of `tea`.**

The first two shape everything else, so they're the ones to settle before the PR step is designed.

---

## User

summarize the decisions and process we followed here to create the agent prompt

---

## Assistant

## How the acceptance-reviewer prompt was made

### 1. Design before code
- **You gave the role:** review the work, deploy the preview, run a standard smoke pack and a feature pack, take screenshots, write `proof.md`, and later open the PR.
- **Three questions settled the open points:**
  - *Where proofs live.* The proof is tracked beside the plan; everything else is disposable.
  - *The preview.* It stays up after a run.
  - *Review depth.* The agent reviews through an acceptance lens, not as a second code review.
- **Spec, then plan:** the spec (`ch09/01`) was approved, then the plan (`ch09/02`), and I executed it inline.

### 2. Decisions that shaped the prompt
- **The workflow deploys the preview, not the agent.**
  - A build plus a deploy can take longer than any tool call, and a retry is the script's job.
  - It also keeps deploy permissions out of the agent's tools.
  - The agent gets the outcome as a `Preview:` line in its context.
- **Narrow permissions.**
  - It may run `smoke.sh`, `deploy.sh preview url` and read-only git.
  - It may write only the proof and its send-back file.
- **Its verdicts are limited by its role.**
  - It has no writer, so it can't request changes, only send back. Send-backs go to the code-writer only, which can send them on to earlier stages.
  - `approved` counts only if the proof was rewritten during that pass.
- **The proof is laid out as a PR body from the start**, for the PR step that comes later.
- **Sonnet:** the job is following steps and writing Playwright.
- **The prompt holds the role only.** Anything shared stays in `agent-context.md`.

### 3. Tests before the real agent
- **The state machine:** proven with a fake `claude` in `loop-test.sh`, including nine new acceptance scenarios.
- **The smoke harness:** `smoke.sh` has unit tests, and the standard pack was proven on a live preview.
- **Final review:** a fresh Opus reviewer read the whole branch; its critical and important findings were fixed.

### 4. Evaluation on real deliveries
- **Issue 5:** the acceptance stage only, run on a finished delivery. It approved, with sensible criterion mapping.
- **Issue 7:** a full run of all seven stages, with no stop for a human.
- **The grading method:** rerun the agent's feature pack against a preview of `main`. A test that passes there proves nothing about the branch, whatever the proof says.
- **What v1 got wrong:** it marked all three checks "passed", but only one failed on `main`. The verdict looked right and the evidence was weak.

### 5. Fix, then re-grade
- **One new rule in the prompt.** Each test names the build it must fail on, and is set up so only the change decides the outcome. Any test that can't be set up that way is labelled a **regression check**, naming the test that does discriminate.
- **A warning:** a preview keeps its data between runs, so state like "first sign-in" can be used only once.
- **Duplication removed:** the material the prompt had copied from the shared context.
- **v2 result:** 2 proven, 1 regression check. All three labels were confirmed by rerunning against `main`.

### 6. Fixed at the source
Issue 7's own acceptance checks couldn't tell the fixed build from `main`. So the exemplar issue and the issue-writer skill now require each check to state what makes it fail on `main`.

### 7. Decisions not to act
- **Superpowers skills:** I didn't name them in any prompt. The agents use them unprompted, the plugin isn't portable, and its rules conflict with the team's.
- **The plugin on/off eval:** skipped. Two runs per arm couldn't separate the result from run-to-run noise.

### What carried the work
- **Grading the evidence, not the verdict:** the rerun against `main` was the eval.
- **Each failure traced to where it started:** the prompt for the labels, the issue template for checks that couldn't fail.
- **One source for shared rules:** keeping them in one file stops prompts drifting apart.

The full record is in `docs/plans/ch09/01`–`03`.

---

## User

so the verified failing - spins up another preview environment from main?

---

## Assistant

Yes, but only in my evaluation, not in the agent's run.

**How I checked it.** I brought up a second preview by hand, `preview-eval-issue7-main`, from a worktree of `main`. I ran the agent's feature pack against it with `scripts/smoke.sh --origin <main origin>`, read which tests failed, and took the preview down again. It took about 3 minutes to deploy and seconds to run.

**What the agent does.** It never runs anything against `main`. The new prompt rule makes it *reason* about the counterfactual: name the build each test must fail on, set the test up so only the change decides the outcome, and otherwise label it a regression check. In v2 that reasoning turned out right, but nothing in the workflow checks it.

**Should the workflow check it?** It could, as a mechanical step after `approved`: deploy `main`, run the feature pack, and confirm every test marked **proven** fails there. A proven test that passes on `main` becomes a send-back to the agent. Against that:
- **Time and cluster resources:** about 3 minutes more per run, and a second namespace while it runs. Two deploys can't run at once, so the `main` deploy waits for the branch deploy.
- **Used-up state:** a test that needs a first-time user works once per preview, on `main` too. So the `main` preview would need a fresh deploy each run, or a fresh namespace, rather than one reused per `main` commit.
- **On GitHub:** on an ephemeral runner this gets simpler, because every job's cluster is fresh anyway.

I think it's worth adding when the workflow moves to GitHub. It turns the only eval we trusted into a gate, and the check is mechanical, which suits the script rather than the agent. Should I add it to the handoff's *Next* list?
