# Chat Transcript

**Topic:** Moving the delivery workflow out of bash and into Python, so `scripts/deliver.sh` takes an issue by its key and can deliver a GitHub issue as well as a local one. This session covers:
- grilling the design in two rounds — a full port rather than a shim, a key-only entry point, one shape of issue copy for every backend, a committed `source.json` guard — then a plan and a worktree
- a golden fixture captured from the bash rule functions (560 passes) and `loop-test.sh` run green against the bash, before any Python; then the failing tests, and the build to green, with the lint hook blocking on complexity three times on the way
- a stubbed end-to-end run of GitHub issue #3 through the real `gh`, and — asked for mid-turn — the same issue copied locally and delivered with the local backend, whose issue copy came out byte for byte the same
- a background review that found five real bugs, fixed test-first while answering the user's question about what the GitHub Actions slice would hit
- a third round of decisions for that slice, the code-writer barred from `.github/workflows/`, a handoff, the commit and the Forgejo PR

**Date:** 16 October 2026
**Project:** `caw-project` — CollabHub, the *Claude at Work* sample project
**Model:** Claude Opus 5.5, Claude Code CLI
**Session:** `4d37e8e0-ea47-4bce-a6b2-3eee228f06e2` · 13:42–14:45 UTC (62m)

Messages are verbatim. Tool calls are summarised in italics — one note per run of them — so the work is visible without pages of command output. 111 tool calls ran in this session before the export, plus those in its one review sub-agent; 410,000 output tokens. The sub-agent's report is summarised the same way.

This follows on from [`03-issue-writer-gh.md`](./03-issue-writer-gh.md), whose handoff set the three jobs this session takes on: port `deliver.sh` to Python, deliver from a key, and keep the agents unaware of the backend.

---

## User

check docs/plans/ch09 - docs 04 and 05. we are moving the ai delivery team to be backend agnostic, so the workflow can be hosted locally or in github. the next slice is to move the backend logic out of deliver.sh and into python to re-use the backend adaptor library. agents will need to be updated, but they stay agnostic to the backend. /mattpocock-skills:grilling

---

## Assistant

*(the `grilling` skill loaded)*

*(read plans 04 and 05 in full; the `delivery` library's model, CLI and resolver; `deliver.sh`'s 140-line header, its function list, pre-flight, state and context block; the head of `loop-test.sh`; and handoff 03's *Next: the workflow on GitHub*)*

Read docs 04 and 05, the library, and the core of `deliver.sh`. Now checking for any delivery runs still in progress, since that affects how resume should work.

*(checked the `build/delivery/state` of every `caw-issue-*` worktree on disk: all 26 at `STAGE=done`)*

I've read docs 04 and 05, the `delivery` library, and the core of `deliver.sh`: its header, preflight, state, the context block and `loop-test.sh`.

One fact settles a question in the handoff. Every delivery worktree on disk (`caw-issue-1` through `caw-issue-7` and all the `-run` variants) has `STAGE=done`. No run is in flight, so a bash-started run never has to resume under Python. I've built that into Q4.

Round 1 covers the decisions that don't depend on each other:

---

❓ **Q1** - **What this slice includes**: The handoff lists three jobs (port, keys, agnostic agents), and GitHub-specific work keeps growing around them: stage labels, comments, commit and push, and the GHA workflow. Where does this slice stop?

- (a) Port only, with behaviour unchanged, still taking a local file. Keys and agents come next.
- (b) Port, plus keys, plus agents that don't know the backend. `deliver.sh` takes a key and fetches the issue through the backend, so `gh-3` could be delivered on a laptop. No labels, comments, commits, pushes or GHA.
- (c) Everything in (b), plus stage labels and comments on the issue.

➡️ **(b).** It's what you described, and it's the smallest slice that proves the backend works end to end: you could deliver `gh-3` locally. Labels, comments and the commit exception all belong with the GHA workflow, because that's where a person watches the issue instead of the terminal. Inside the slice, the work goes in order behind `loop-test.sh`: port with behaviour unchanged, then keys, then agents.

---

❓ **Q2** - **How much of `deliver.sh` moves to Python**: You said "the backend logic". Two readings:

- (a) **Thin.** Bash keeps the state machine. It gets the key and paths from `delivery` and calls a new `delivery issue fetch KEY --to <path>`. That's about 30 lines of change.
- (b) **Full port.** The state machine, the rounds, the tool and write rules, the context block, the preview wrapper and `claude` invocation all go to Python. `scripts/deliver.sh` becomes a thin wrapper.

➡️ **(b), the full port.** The next slice adds label changes and comment posts *inside* the loop, at each stage's transition. Doing that in bash 3.2 with `eval`-based state is where the script gets fragile. The rules in a full port can also be unit-tested as tables, which matters most for the tool and write scopes, because those are the safety boundary. If you want to limit risk, (a) is a legitimate stopgap, but it means the port still has to happen later.

---

❓ **Q3** - **What the entry point takes**: Today it's `scripts/deliver.sh docs/issues/008.md [--restart]`.

- (a) A key only: `scripts/deliver.sh issue-8` or `scripts/deliver.sh --backend github --url … gh-3`. The backend resolves exactly as in `resolve.py`, so `DELIVERY_BACKEND`/`DELIVERY_URL` also work. If the key's prefix doesn't match the backend (`gh-3` on local), it's an error, exit 2.
- (b) A key, or a path to a local file as before.

➡️ **(a), a key only.** One way in. Every existing worktree and plan uses `issue-N`, which is already the local key, so nothing old breaks. Refusing a mismatched prefix also stops `gh-3` being looked up in `docs/issues/`.

---

❓ **Q4** - **Resuming a bash run under Python**: Nothing is in flight, as above. Should Python read the old shell-assignment `state` file anyway?

➡️ **No.** Python writes `build/delivery/state.json`. If it finds an old `state` without `STAGE=done`, it stops with "started under the bash deliver.sh; finish or `--restart` it". `history.log` keeps its format so the measurement runs stay comparable.

---

❓ **Q5** - **What `00-issue.md` looks like**: Today it's a byte copy of the local file (`Issue: N`, then `# Issue N — title`). Agents need one shape whatever the backend.

- (a) One rendering for every backend: `# <title>`, a blank line, then the body. The key goes in the context block only.
- (b) Keep each backend's own shape: a local copy as now, and GitHub as title plus body.

➡️ **(a).** The fetched `Issue` already holds title and body apart (decision 7). Rendering them once means no agent ever sees a backend-specific header, which is the point of making the agents agnostic. It's re-fetched on every run, start or resume, so edits to an issue still reach the agents, as the bash `cp` does now.

---

❓ **Q6** - **The context block's issue lines**: Today it has `Issue: #8`, and prompts build `docs/plans/issue-<N>/…` themselves for reviews, send-backs and `needs-human.md`.

➡️ Change it to `Issue: <key>` (no `#`), and add `Plan dir: docs/plans/<key>/` and `Human answers file: <path>` as lines that are always there, even before the file exists. That covers every path an agent currently builds. The rule becomes **"take every path from the block; never build one"**. `agent-context.md` and the five agent descriptions use `<key>`.

---

❓ **Q7** - **The collision guard**: `issue-` and `gh-` prefixes can't collide with each other. What can collide is two GitHub repos, each with a `gh-3`, both landing in `docs/plans/gh-3/` on `main`. What should guard against that?

- (a) A small `docs/plans/<key>/source.json` (`{"backend","url","number"}`), written on the first fetch. The run refuses if it later differs. It's committed with the plan, so the guard still works after a merge.
- (b) Record the source only in `build/delivery/` in the worktree. That's lost on merge.
- (c) No guard. Document that one repo is one GitHub backend.

➡️ **(a).** It's the only option that survives a merge to `main`. Agents never read it (the block doesn't name it), so they stay agnostic.

---

❓ **Q8** - **Where the runner lives**:

- (a) In the same `tools/delivery` package: `delivery deliver KEY [--restart]`, with modules under `delivery/run/` (state, rules, context, invoke), stdlib only.
- (b) A separate workspace member, e.g. `tools/deliver`, that depends on `delivery`.

➡️ **(a).** It shares resolve and the backends with no new package, and stdlib-only also drops the `jq` dependency from preflight. If it grows, it can be split later.

---

❓ **Q9** - **Testing the port**:

- (a) `loop-test.sh` stays the black-box oracle. It moves to keys (`issue-999`, with a local `docs/issues/999.md` in a temp root, or an injected backend), passes against bash before the port, then against Python. Pure rules are unit tests in `tools/delivery/tests/unit/`.
- (b) Also rewrite `loop-test.sh` as pytest integration tests now, with the fake `claude` on `PATH`, and retire the bash script.

➡️ **(a) in this slice.** An oracle you rewrite at the same time as the code isn't an oracle any more. Moving it to pytest makes a good follow-up once the port is green. Until then, CLAUDE.md's "run `loop-test.sh` after any change" still holds.

---

Answer as many as you like, and say "go with yours" for any you agree with. Once Q1 and Q2 are settled, the next round covers the stage-by-stage port details: the tool and write rule tables, how `claude` is invoked, and preflight.

---

## User

all good

---

## Assistant

All nine accepted. That settles the slice: a full Python port, taking a key, with agnostic agents and no GitHub-side writes. Round 2 is the port's details.

---

❓ **Q10** - **How the runner calls `claude`**: Bash builds the argument list and pipes the result JSON through `jq`.

➡️ Use `subprocess`, with `claude` taken from `PATH`, through an injected `Agent` runner seam: `(args, cwd) -> result JSON`. It works the same way `github.py`'s `Runner` does. Unit tests check the argument list each stage gets (`--agent`, `--model`, `--effort`, `--max-turns`, `--allowedTools`, `--json-schema`, `--resume`, `--permission-mode`). `loop-test.sh` keeps working unchanged because its fake `claude` is still first on `PATH`. The flags are identical, just without the `jq` step.

---

❓ **Q11** - **Porting the tool and write rules exactly**: `allowed_tools`, `write_scope` and `write_denied` are the safety boundary, and the handoff says to "port exactly, test as a table". How do we prove "exactly"?

- (a) Before porting, capture a golden fixture from bash: source the functions and print each stage × {first pass, rework, final} × {with or without a send-back} combination to a JSON file under `tools/delivery/tests/unit/`. The Python tables must match it.
- (b) Write the expected tables by hand from reading the bash.

➡️ **(a).** The bash is the spec, and reading by eye is how one `Bash(…)` pattern goes missing. The fixture is captured once, kept in the repo, and the capture script is thrown away. After that, the fixture is the reference.

---

❓ **Q12** - **Preflight per backend**: Today it checks `claude git jq uv node npm python3 helm docker cloudflared k3d kubectl curl`, plus the Docker daemon and `.env.example`.

➡️ Drop `jq`, and add `gh` only when the backend is GitHub. Then fetch the issue (`backend.get(key)`) as the backend check. `check()` asks "can take a new issue" and needs write access, which delivery doesn't need. A failed fetch exits 1 with the backend's message, before any worktree is created.

---

❓ **Q13** - **Which checkout local issues come from**: The bash takes whatever path you give it, usually the primary checkout's `docs/issues/`. For `issue-8`, the local backend needs a root.

➡️ Use the root of the checkout that runs `scripts/deliver.sh` (`REPO_ROOT`), never the worktree. A new worktree is cut from `main` and may not have an issue you've just written and not merged. That's how it works today in practice.

---

❓ **Q14** - **The wrapper and the reference docs**: CLAUDE.md says "the script's header is the reference".

➡️ `scripts/deliver.sh` becomes `exec uv run --project "$REPO_ROOT" delivery deliver "$@"`, plus a header of about 10 lines pointing at the module. The full behaviour description moves into the docstring of `delivery/run/__init__.py`, and CLAUDE.md's Delivery workflow paragraph points there. Every `DELIVER_*` name, exit code (0/1/2/3) and `--restart` stays as it is.

---

❓ **Q15** - **The issue-writer's GitHub ending**: Decision 14 makes it say "delivery from GitHub arrives with the GHA slice". After this slice, `scripts/deliver.sh --backend github --url … gh-N` works from a laptop.

➡️ Update the ending to give that exact command. The GHA trigger is still to come, so it says so in one line.

---

❓ **Q16** - **Records**:

➡️ Three records:

- A new ADR through `adr-writer`, "delivery runner in Python, issues by key". It's a separate decision from the backends ADR.
- The register: there's no D-number for delivery tooling, so nothing to change unless you know of one.
- Handoff 05's "Open" list gets the items this slice closes ticked off in the new plan, not edited in place.

---

❓ **Q17** - **How this gets built**: Per your memory note, plans go in `docs/plans/ch09/`, numbered after 05.

- (a) Write `06-delivery-runner-plan.md` from this session. I then build it here in a worktree, `feature/delivery-runner` at `../caw-delivery-runner`, test first, stopping at red for your review.
- (b) Write the plan only, and leave the build to another session.

➡️ **(a).** It's the same shape as slice 1: plan, red, stop, green, records, and `loop-test.sh` green on both bash and Python.

---

## User

yes all goof

---

## Assistant

All of round 2 accepted. Every branch of the design has now been covered, so here is the whole design to confirm before I write the plan.

**Scope.** This slice ports `deliver.sh` to Python, switches it to keys, and makes the agents backend-agnostic. It leaves out labels, comments, commits, pushes and the GHA workflow.

**The runner**
- It's a new command, `delivery deliver KEY [--restart]`, in the `tools/delivery` package under `delivery/run/`, stdlib only.
- `scripts/deliver.sh` becomes a wrapper that hands everything to it. Every `DELIVER_*` variable, exit code (0/1/2/3) and `--restart` stays as it is.
- The reference for its behaviour moves from the script's header to the module docstring, and CLAUDE.md points there.
- The backend resolves exactly as `resolve.py` does today. A key whose prefix doesn't match the backend (`gh-3` on local) exits 2.
- Local issues are read from the checkout that runs the command, never from the worktree.
- Preflight drops `jq`, adds `gh` for GitHub, and checks the backend by fetching the issue before any worktree is created.
- Branch, worktree and plan folder are named from the key: `feature/<key>[-<run>]`, `../caw-<key>[-<run>]`, `docs/plans/<key>/`.
- `claude` runs from `PATH` through an injected seam. The flags are the same as today's.
- Run state is `build/delivery/state.json`. An old bash `state` that isn't `done` stops the run with a clear message. `history.log` keeps its format.
- The preview still calls `scripts/deploy.sh preview up`.

**The issue and the guard**
- On every run, start or resume, the issue is fetched again and written to `00-issue.md` as `# <title>`, a blank line, then the body, whatever the backend.
- `docs/plans/<key>/source.json` records where the issue came from, and a run whose source differs is refused. Agents never read it.

**The agents**
- The context block says `Issue: <key>` and always includes `Plan dir:` and `Human answers file:`.
- Prompts take every path from the block and never build one. That applies to `agent-context.md`, the five agent descriptions, `plan-writer.md:70`, the exemplar plan and CLAUDE.md.
- No agent calls `delivery` or `gh`, or reads a URL.

**Tests**
- A golden fixture of the tool and write rules is captured from the bash before the port, and the Python tables must match it.
- The pure rules get unit tests.
- `loop-test.sh` moves to keys and stays the black-box check: it has to pass against the bash first, then against Python.

**Records**
- A new ADR: the runner in Python, issues by key.
- The issue-writer's GitHub ending gives the `scripts/deliver.sh --backend github …` command.
- The new plan lists which of handoff 05's open items this slice closes.

**Build.** I write `docs/plans/ch09/06-delivery-runner-plan.md` first, then build it in `../caw-delivery-runner` on branch `feature/delivery-runner`. I'll stop at red for your review, and nothing gets committed.

Is that the design you want? Once you confirm, I'll create the worktree and write the plan.

---

## User

yes looks good

---

## Assistant

*(created the worktree `../caw-delivery-runner` on `feature/delivery-runner` from `main`, and grepped `loop-test.sh` and the agent docs for issue-number paths: 14 hits)*

The worktree is ready. Writing the plan now.

*(wrote `docs/plans/ch09/06-delivery-runner-plan.md`: a 16-row *Decided* table, the shapes, and 19 tasks)*

The plan is written, and the worktree is ready for the build.

- **Branch:** `feature/delivery-runner`
- **Worktree:** `/Users/elton/scm/manning/caw-delivery-runner`
- **Plan:** `docs/plans/ch09/06-delivery-runner-plan.md`

It records the 17 decisions as 16 rows, then 19 tasks: 10 that write the failing tests (stopping at red for your review), 4 that build the code, 3 records, and 2 checks.

I made four calls while writing it that we didn't discuss:

- **How `loop-test.sh` gets its issue:** it writes `docs/issues/999.md` into the checkout that runs it, and the cleanup that already removes its worktree removes the file too. The runner reads local issues from that checkout, and key `issue-999` keeps every path the test checks the same, so no assertion has to change.
- **A finished bash run:** if an old bash `state` file says `STAGE=done`, the Python runner reports the delivery as done, as the bash would. Only an unfinished one is refused.
- **A different issue source:** if `source.json` doesn't match where the issue now comes from, the run exits 2 (bad config), not 1.
- **The by-hand check:** task 19 runs `issue-8` and `gh-3` (on `caw-project/ch09`) with `DELIVER_MODEL=haiku` and stops after the plan-writer's first pass. Before `gh-3` runs any further, issue #3's tenancy note needs fixing, as handoff 05 says.

Nothing is staged or committed. Should I start writing the failing tests now? The first step runs `loop-test.sh` unchanged against the bash to get a green baseline.

---

## User

yes go for it - form tests to build and review. /goal a fully working implementation. we can use https://github.com/caw-project/ch09/issues/3 as the test input and stub claude for now

---

## Assistant

Using TDD for this. I'll go from failing tests through the build to a review, and use `gh-3` with a stubbed `claude` as the end-to-end input. First I'll read the whole of `deliver.sh`, since it's the spec for the port.

*(read the rest of `deliver.sh` — argument parsing, the tool and write rules, `run_stage` and the state machine — plus `scripts/lib/common.sh` and the rest of `loop-test.sh`'s 402 lines)*

I've read the whole spec. Next, the library's existing code and test idioms so the port matches them.

*(read `local.py`, `github.py`, `errors.py`, `pyproject.toml`, the tests' `conftest.py` and the head of `test_cli.py`)*

Running `loop-test.sh` unchanged against the bash first, to get the green baseline. That runs in the background while I write the golden-fixture capture.

*(started `loop-test.sh` against the bash in the background; wrote two throwaway capture scripts, one that evals `deliver.sh`'s rule functions and prints them for 7 stages × 8 situations × 10 overrides, one that prints each stage's tools and write rules)*

Captured 560 rule rows plus the per-stage tool and write tables. Converting them into the committed JSON fixture:

*(converted both into `tools/delivery/tests/unit/fixtures/deliver-rules.json`; checked the pytest config and `agent-context.md`'s context-block section; the baseline finished — every scenario passed)*

The baseline is green: `loop-test.sh` passes all 29 scenarios against the bash. Now the unit tests, starting with the rules against the golden fixture.

*(wrote `test_run_rules.py`, every fixture row against the Python rules, and `test_run_machine.py`, one test per verdict; the lint hook blocked on three findings, fixed)*

Now the context-block tests. They pin the new `Issue: <key>` and `Plan dir:` lines and leave every other line exactly as the bash prints it.

*(wrote `test_run_context.py` and `test_run_keys.py`; replaced a no-op string replace with `re.escape`)*

Now state, history stats and the `claude` invocation:

*(wrote `test_run_state.py` and `test_run_invoke.py`; the lint hook flagged an unescaped `match=`, fixed)*

Now the history, preflight, settings and CLI tests:

*(wrote `test_run_record.py`, `test_run_preflight.py`, `test_run_settings.py` and `test_run_cli.py`; checked how testkit assigns a layer to a `tools/` test; wrote `tests/integration/test_deliver.py` — a GitHub delivery against a real git repo, a fake `gh` and a fake agent — and fixed an `S607` the formatter had moved away from its `noqa`)*

Last red task: `loop-test.sh` changes only how it calls the runner. It now passes a key, with the issue in `docs/issues/999.md` for the local backend to read.

*(edited `loop-test.sh`: it writes `docs/issues/999.md` into the checkout, removes it on exit, and calls `scripts/deliver.sh --backend local issue-999`)*

Running everything red:

*(ran the suite — all 10 new test modules failed to import, with no `delivery.run` to import — and `loop-test.sh`, which the bash failed with `unknown option '--backend'`; then went straight on to green: `RunError`, `settings.py`, `state.py`, `keys.py`)*

Now the state machine, a direct port of the bash `case` block:

*(wrote `machine.py`; the lint hook blocked: `advance` too complex, 17 against a limit of 10)*

The lint hook flagged `advance` as too complex. I'll split each verdict into its own function, which also reads more like the bash `case`:

*(split `advance` into one function per verdict)*

Now the rules. First I'll print the fixture's exact strings so the port reproduces them character for character:

*(printed the fixture's write-rule strings; wrote `rules.py`; the lint hook blocked on en dashes in a docstring, replaced)*

Now the context block, record-keeping and the `claude` invocation:

*(wrote `context.py`, `record.py` and `invoke.py`; the lint hook blocked on `context_block`'s complexity and an implicit string concatenation; split the block into helpers)*

Now preflight, the preview wrapper, and the loop itself:

*(wrote `preflight.py`, `preview.py` and `run/__init__.py` — the loop, with the bash header moved into its docstring; the lint hook blocked on complexity again, and a scripted patch to split the loop failed because the formatter had reflowed the file)*

The formatter had already reflowed the file, so the patch missed. I'll rewrite the module whole with the split in place:

*(saved the docstring, wrote the module's body whole in the scratchpad, and joined the two; lint clean)*

Now the `deliver` subcommand in the CLI:

*(added the `deliver` subcommand to `cli.py` and ran the suite: 751 passed)*

All 751 tests pass. Checking that the integration file actually ran under its layer:

*(ran the integration file under `-m integration`: 5 passed)*

Now the wrapper. `scripts/deliver.sh` becomes a few lines that hand off to the Python runner:

*(rewrote `scripts/deliver.sh` as a wrapper)*

The global options (`--backend`, `--url`) have to come before the `deliver` subcommand, so the wrapper sorts the arguments:

*(added the argument sorting; checked `--help`, a `gh-3` refused on the local backend with exit 2, and a missing key)*

Now the oracle: `loop-test.sh` against the Python runner.

*(ran `loop-test.sh` against the Python runner: every scenario passed)*

All 28 scenarios pass against the Python runner, with no assertion changed. Next are the agent docs: finding every place a prompt builds an `issue-<N>` path or reads `Issue: #N`.

*(grepped the agents, `agent-context.md`, CLAUDE.md, the skill and the exemplar for `issue-<N>`, `Issue: #` and `caw-issue`; read each hit in context; replaced them with `<key>` across seven agent files and `agent-context.md`, rewrote the `Issue:` bullet to explain the key and `Plan dir:`, and checked for references to the bash internals)*

Agent docs are moved to keys. Now the exemplar line, the issue-writer's ending, and CLAUDE.md:

*(updated the exemplar's worktree line, the issue-writer's ending — now the `scripts/deliver.sh --backend github … gh-<N>` command — `.env.example`'s comment, and CLAUDE.md's two delivery paragraphs)*

Docs are done. Now the end-to-end run you asked for: `gh-3` from `caw-project/ch09` through the real `gh`, with `claude` stubbed and a fake deploy. It goes straight through all seven stages.

*(wrote a stub `claude`, which has every writer return done and every reviewer approve, leaving the file each verdict needs, and a fake deploy; ran `DELIVER_RUN=stub scripts/deliver.sh --backend github --url https://github.com/caw-project/ch09 gh-3`: seven stages, exit 0)*

The run went straight through, exit 0. Checking what the agents saw:

*(compared `00-issue.md` with `gh issue view 3` — 138 lines against GitHub's 137-line body plus the heading — read `source.json` and the acceptance-reviewer's prompt, and grepped every prompt for the issue's URL: none; a rerun reported done, and the same key from `sixeyed/claude-at-work-project` was refused with exit 2; removed the stub's worktree and branch; loaded the `adr-writer` skill)*

*(read the backends ADR's header, wrote `docs/adr/261016-delivery-runner-in-python-by-key.md`, added *Found while building*, *Verified* and *Closed* to the plan, and started `scripts/test.sh lint unit`)*

---

## User

*(sent mid-turn)*

verify with the local run too - copy gh-3 to issues/ and check the script works with local backend

---

## Assistant

`lint unit` passes. Now the local check you asked for: copy `gh-3` into `docs/issues/` through the library's own `issue create`, then deliver it with the local backend and the same stubbed `claude`.

*(fetched `gh-3` as JSON, created `docs/issues/009.md` from its title and body with `delivery --backend local issue create`, and ran `scripts/deliver.sh issue-9` with the same stubs: seven stages, exit 0, and the copy's body matched)*

The local run passes too. One more check: both backends should give the agents a byte-identical issue copy.

*(rendered the fetched `gh-3` and `cmp`'d it with `issue-9`'s `00-issue.md`: identical; `issue-9` with `--backend github` was refused, exit 2; removed the stub's worktree and branch; recorded the run in the plan; started a background agent to review the port against the bash on `main`)*

The local check passes, and the build is green. An independent review of the port against the bash on `main` is running in the background; I'll go through its findings when it reports.

**What the local check showed:**
- **The copy:** `gh-3` went into `docs/issues/009.md` through `delivery issue create --backend local`, in the local file format.
- **The run:** `scripts/deliver.sh issue-9` with the stubbed `claude` ran all seven stages and exited 0. Its `source.json` records `{"backend": "local", "url": null, "number": 9}`.
- **Same shape for both backends:** the `00-issue.md` the agents get from `issue-9` is byte-for-byte the one `gh-3` gives them from GitHub.
- **Wrong backend refused:** `issue-9` with `--backend github` exits 2.
- **Cleanup:** I removed the stub worktrees and branches for both runs. `docs/issues/009.md` stays in the worktree; delete it if you don't want it.

**State of the build** (in `/Users/elton/scm/manning/caw-delivery-runner`):
- **Tests:** all 751 `tools/delivery` tests pass. That includes 560 rule checks against the fixture captured from the bash and 5 integration tests for the GitHub path. `scripts/test.sh lint unit` passes.
- **`loop-test.sh`:** passed all 28 scenarios against the bash before the port, and against the Python after it. Only the way it names the issue changed.
- **The `gh-3` run:** fetched issue #3 through the real `gh`, ran straight through, and the issue's URL appears in no agent's prompt. The same key from another repo is refused.
- **Records:** a new ADR, `docs/adr/261016-delivery-runner-in-python-by-key.md`, plus updates to CLAUDE.md, `agent-context.md`, the seven agent files, the issue-writer's ending and `.env.example`. The plan has *Found while building*, *Verified* and *Closed* sections.

**Where I departed from what we agreed** (all recorded in the plan):
- **`Human answers:` kept as it was.** I didn't add an always-present `Human answers file:` line. The existing line only appears once someone has answered, which is how an agent knows there are answers to read, and agents never write that file themselves.
- **Bad `DELIVER_*` settings exit 2, not 1,** to match every other `delivery` command.
- **The wrapper moves `--backend` and `--url` in front of `deliver`**, so `scripts/deliver.sh` accepts them anywhere on the line.

I haven't run a real-model delivery of `gh-3`; issue #3 still needs its D46 tenancy note before it's worth one. Nothing is staged or committed.

---

## User

ok. next step will be a github actions workflow which invokes the deliver script, running claude in the hosted runner. anything we’ve missed in here that could affect that? so the end state of that slice is we can either run the whole deliver.sh locally as before, or manually trigger an action run and it all happens in github. both would need to commit and push their branches once the acceptance reviewer is happy.

---

## Assistant

Good question. Most of the answer is about state and environment, not the runner's logic. Let me check a few facts before answering: how long real runs took, what the hooks need, and where the code and remotes live.

*(totalled every `history.log` on disk — the longest run 101 minutes, `caw-issue-1-m3` — listed the remotes, read `caw-project/ch09`'s top level over the API, and read the two hooks' tool needs and `.claude/settings.json`)*

*(the background review reported: no blocking bugs, and a ranked list — agents inheriting the primary checkout's virtualenv, keys with a leading zero, a missing deploy script crashing the run, a rerun of a finished delivery rewriting its issue copy, tracebacks on unexpected errors, and three nits)*

*(located the code each fix touches)*

Tests first: one for each fix.

*(wrote a test for each: leading-zero keys refused, a new `test_run_environment.py`, a new `integration/test_preview.py`, and a finished delivery left alone in `test_deliver.py`; 4 failed and the environment test couldn't import)*

All four are red for the reasons intended. Now the fixes:

*(applied the fixes in `invoke.py`, `keys.py`, `preview.py` and `run/__init__.py`; a newline inside an f-string broke `preview.py`, fixed; one test then failed — stripping `sys.prefix`'s `bin` from PATH would strip `/usr/bin` outside a virtualenv — so `agent_env` now strips only an active `VIRTUAL_ENV`'s; 758 passed, and `loop-test.sh` passed)*

All 758 tests and every `loop-test.sh` scenario pass. Two last touches: the wrapper gets `--frozen`, so a run never relocks the primary checkout, and the plan records the review's fixes.

*(added `--frozen` to the wrapper and recorded the review's fixes in the plan)*

The review is done, and I fixed what it found before answering your question.

**Fixed from the review** (each fix has a test; all 758 tests and every `loop-test.sh` scenario pass):
- **The wrong venv:** agents and the deploy script were running inside the primary checkout's venv, which `uv run` had activated. It's now dropped before `claude` starts.
- **Leading zeros:** `issue-08` would have been a second delivery of `issue-8`. Keys with a leading zero are now refused.
- **A missing deploy script** crashed the run. It now counts as a failed deploy, as it did in the bash.
- **Rerunning a finished delivery** rewrote its committed `00-issue.md`. The "already done" check now comes first.
- **Unexpected errors**, such as a corrupt state file, now print one `error:` line instead of a traceback.
- **Lockfile:** the wrapper runs `uv run --frozen`, so a run never relocks the lockfile.

**What we've missed that the GitHub Actions slice will hit**, most important first:

1. **Run state is lost when the runner ends.** `build/delivery/` holds the state file, transcripts, `history.log` and send-back snapshots, and it's git-ignored in a worktree the runner throws away. So does `needs-human.md`, until something pushes it.
   - Locally, "commit only after acceptance approves" works. On GitHub, a `needs_human` stop, a crash or a cancelled job loses everything, and the person has no questions to answer.
   - This is the main decision: either push a work-in-progress branch on every stop, or upload `build/delivery/` as an Actions artifact and restore it on the next run.
   - I'd push the branch on a stop too. It's simpler, and the questions are then visible in the repo.

2. **Resuming from a pushed branch doesn't work yet.**
   - The runner only looks for a *local* `feature/<key>`. A fresh checkout on a runner has `origin/feature/gh-3` but no local branch, so the runner would cut a new one from `main` and the push would be rejected.
   - It needs to fetch the remote branch and track it.

3. **Commit and push belong in the runner, for both modes.** Put them after the acceptance-reviewer approves, so the bash-era "the workflow never commits" check on each stage still holds for the agents. That needs deciding:
   - **Remote:** locally, `origin` is GitHub and `forge` is Forgejo, so it should be a setting (e.g. `DELIVER_REMOTE`).
   - **Identity:** the actions bot on the runner, the developer's own locally.
   - **The CLAUDE.md exception:** the workflow commits; agents never do.

4. **`GITHUB_TOKEN` limits.**
   - It can't push changes under `.github/workflows/`, and the code-writer's write scope includes `.github/`.
   - Pushes made with it don't trigger other workflows, so CI wouldn't run on the delivered branch.
   - Either use a GitHub App or fine-grained token, or take `.github/workflows/` out of the code-writer's scope.

5. **Runner setup.**
   - **Preflight's list becomes the setup steps.** `k3d` and `cloudflared` aren't on hosted images.
   - **The hooks fire in headless runs too.** The lint hook needs `uv` and the frontend's `node_modules` (for eslint). The security hook uses `uvx semgrep` and `gitleaks`, and skips `gitleaks` if it's missing.
   - **Auth:** `claude` needs installing and an `ANTHROPIC_API_KEY` (or OAuth token) secret.
   - **Plugins:** there are no user-level plugins or memory on a runner, so the first runs are a new baseline (handoff 03, item 6).

6. **Capacity.**
   - **Time:** the longest finished run on disk took about 101 minutes (`caw-issue-1-m3`), well inside the 6-hour job limit.
   - **Memory:** a run holds the e2e Compose stack (Elasticsearch included), then a k3d cluster with all images.
   - **Runner size:** GitHub's standard runners are larger for public repos than for private ones, and I haven't checked which `caw-project/ch09` is. I did confirm it holds the full code tree as well as the issues, which the workflow needs.

7. **The preview dies with the job**, so the proof's *Try it* link is dead by the time anyone reads it. Screenshot links need a home too. Both are handoff 03, items 2–4.

8. **Concurrency changes shape.** Each hosted runner has its own cluster, so the "both upgrade KEDA" clash goes away. You still want a `concurrency:` group per key, so two runs of the same issue can't race.

Two things are already ready for that slice. The backend config comes straight from the workflow context (`DELIVERY_URL` from the server URL and repo name, `GH_TOKEN` from the job's token with issue read access). The stub `claude` from today's runs gives a free first proof that the workflow works end to end, before any model spend.

Items 1–3 change the runner itself and are where this slice's choices matter most. Want to grill those first?

---

## User

1 - yes, push on a stop; 2 - yes, fetch and re-use; 3 - default to forge locally, github in the runner, agree on the claude.md exception; 4 - the code writer does not edit workflows; 7 - creating the pr is the next slice, thinking that will trigger another action which deploys a new preview and that action keeps running until human approves the pr or it times out; rest as you suggest. grill if we need to

---

## Assistant

Your decisions settle most of it. A few sub-decisions hang off them, mostly because of what a commit does to the runner's bookkeeping, so here's one short round:

---

❓ **Q1** - **Where resume state lives once it's pushed**: Resume needs `state.json`, and the send-back snapshots for any open send-back. All of it is under the git-ignored `build/delivery/`, so pushing on a stop carries none of it.

- (a) Move resume state into the plan dir: `docs/plans/<key>/run/state.json`, plus `history.log` and the snapshots. It's committed with each stop. Transcripts (the large per-stage JSON) stay in `build/delivery/`; in GitHub Actions they're uploaded as an Actions artifact for the record.
- (b) Keep everything in `build/` and force-add it on each commit.

➡️ **(a).** It's an ordinary tracked file, the plan dir is already the delivery's record, and `history.log` belongs next to the proof. The write-scope check has to ignore `run/`, the same way it ignores `build/` today.

---

❓ **Q2** - **Snapshots once there are commits**: Today a snapshot is "every uncommitted path". After a stop's commit and a resume, files the send-back snapshot saw as uncommitted are committed and drop out of `git status`. They'd then show up as changed, and the "Changed since the send-back" list would be wrong.

➡️ **Snapshot the branch against its base**, with `merge-base main`: every path changed or added since the base, plus untracked files, with a content hash. Commits on the branch then don't disturb it, and the per-stage write check works exactly as before, since it compares two snapshots taken around one stage. This lands in the runner, with a test.

---

❓ **Q3** - **What a commit is**:

➡️ One commit per stop and one at approval, each covering everything outside `build/`. Messages are `delivery(<key>): needs a human at <stage>, round <R>` and `delivery(<key>): accepted`, with the stage summary in the body. The workflow makes these commits, and the check after each stage that the agent made none stays as it is.

---

❓ **Q4** - **Local runs on a stop**: You said push on a stop, which I read as aimed at GitHub Actions.

- (a) Same in both modes: a local stop also commits and pushes to `forge`.
- (b) Locally, a stop commits but doesn't push; only approval pushes.

➡️ **(a).** One code path, and a stop can then be answered from either place. `DELIVER_PUSH=0` would turn pushing off for dry runs and `loop-test.sh`, which must never push.

---

❓ **Q5** - **Syncing with the remote branch on a resume**: In GitHub Actions a person answers by editing `needs-human.md` on the branch, then re-runs the workflow. A local resume can find the remote branch ahead of the worktree for the same reason.

➡️ Always fetch first. If the remote branch is ahead and the local one can be fast-forwarded, fast-forward. If the two have diverged, stop with exit 1 and say so; never merge or force anything. A worktree with uncommitted changes and a remote that's ahead also stops, because that's someone's work in progress.

---

❓ **Q6** - **When "the code-writer doesn't edit workflows" lands**: It's a one-pattern change to its write rules, which means a deliberate change to the fixture.

➡️ In this slice, now. It's the runner's safety boundary, and the GitHub Actions slice depends on it. `write_denied` for the code-writer gains `^\.github/workflows/`, and the fixture row changes with it.

---

❓ **Q7** - **Recording it**:

➡️ Q6 goes into this branch now. Everything else (your decisions plus these) goes into `docs/plans/ch09/07-delivery-actions-handoff.md`, as the brief for the GitHub Actions slice. That handoff also covers the CLAUDE.md commit exception and the PR-preview slice after it, with its long-running preview action.

---

## User

yes to all - but 6 we should also edit the agent’s prompt to say workflow changes are out of scope (or better in the shared context file so no agents try to change workflows)

---

## Assistant

Doing Q6 now, test first. The fixture row and a new rule test change before the rule does.

*(changed the fixture's code-writer `write_denied` row to include `\.github/workflows/`, and added a test that `ci.yml` is refused and `dependabot.yml` isn't; 2 failed)*

Red as expected. Now the rule, then the shared rule in `agent-context.md`:

*(added the pattern to `rules.py`: 759 passed; read `agent-context.md`'s *Where you work, and what you may touch*, added a bullet making CI workflows out of scope for every stage, and grepped the agent files for `.github`: none)*

The shared rule is in, and no agent file mentions `.github` to contradict it. Now the brief for the next slice:

*(wrote `docs/plans/ch09/07-delivery-actions-handoff.md`, recorded the rule in plan 06, and ran `loop-test.sh` and `scripts/test.sh lint unit`: both passed)*

The workflow rule is in this slice, and the GitHub Actions slice has its brief.

**The code-writer can't edit workflows.** It's enforced in two places:
- **The write check:** the code-writer's denied paths now include `.github/workflows/`. The fixture row changed on purpose, and a new test checks that `ci.yml` is refused while `.github/dependabot.yml` is still allowed.
- **The shared rules:** `agent-context.md` now says CI workflows are out of scope for every stage, so no agent plans, tests or reviews one. If an issue seems to need a workflow change, the agent builds everything else and names that change in its output file as work for a person; it isn't a reason to stop.

**The brief is `docs/plans/ch09/07-delivery-actions-handoff.md`.** It records your answers and the round you just agreed:
- **Push on every stop** and at approval, locally and in the runner, with one commit each and fixed messages.
- **Resume state moves into `docs/plans/<key>/run/`**, committed. Transcripts go up as an Actions artifact.
- **Snapshots are taken against the branch's base**, so a stop's commit doesn't spoil "Changed since the send-back".
- **Fetch, track and fast-forward** the remote branch; stop if it has diverged.
- **`DELIVER_REMOTE`** defaults to `forge` locally and is set to `origin` in the runner. `DELIVER_PUSH=0` turns pushing off, for `loop-test.sh`.
- **The CLAUDE.md exception:** the runner commits and pushes its own branch; an agent never does.
- **The workflow:** the manual trigger and its inputs, including a stub `claude` for a free first run, one concurrency group per key, the setup list (including what the hooks need), and what CI changes about a run.

All 759 tests pass, along with every `loop-test.sh` scenario and `scripts/test.sh lint unit`. Everything is uncommitted in `/Users/elton/scm/manning/caw-delivery-runner` on `feature/delivery-runner`. That includes `docs/issues/009.md`, the local copy of `gh-3`; delete it if you don't want to keep it.

---

## User

good. commit and push to forge

---

## Assistant

*(staged all 46 files, committed `8e699c2`, and pushed `feature/delivery-runner` to `forge`)*

I've committed the slice as `8e699c2` on `feature/delivery-runner` and pushed it to `forge`. The branch now tracks `forge/feature/delivery-runner`.

It's one commit of 46 files: the Python runner, its tests and fixture, the wrapper, the agent and doc updates, the ADR, and plans 06 and 07. It also includes `docs/issues/009.md`, the local copy of `gh-3` from the check, and the commit message says what that file is.

I haven't opened a PR. If you want one, I'd use `tea` against `manning/claude-at-work-project`.

---

## User

yes, pr

---

## Assistant

*(the `pr` skill loaded)*

*(wrote the PR body to the skill's template — Summary, Evidence, Merge Danger — and opened it with `tea pr create`)*

I opened PR #8 on Forgejo: https://forge.sixeyed/manning/claude-at-work-project/pulls/8. It takes `feature/delivery-runner` into `main`, and Forgejo reports no conflicts.

The description covers:
- **Summary:** how `scripts/deliver.sh` changes, the module layout, the flow of one run, and how the context block changes.
- **Evidence:** the fixture-matched rules, `loop-test.sh` passing before and after the port, the 759 tests, the stubbed GitHub and local runs, and the review's fixes.
- **Merge danger:** a two-way door, limited to the delivery tooling. One thing doesn't reverse cleanly: a delivery started under the Python runner can't be resumed by the bash.

---

*(`/manning-book-workflow:extract-transcript` — this export)*
