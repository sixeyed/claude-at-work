# Chat Transcript

**Topic:** Making the delivery team's issue tracker swappable — local files today, GitHub now, Forgejo or Azure DevOps later — starting with the `issue-writer` skill. This session covers:
- grilling the design in three rounds, in which the user chose namespaced keys (`gh-5`, not a shared number sequence) and asked for the backend and URL to be passed to the skill
- building `tools/delivery/`, a Python library and CLI with local and GitHub adaptors, test-first to a stop at red; then green, the skill rewrite, an ADR and the records
- the first live run against a throwaway repo, which found issues turned off; then a round trip that proved create, verify and edit against real GitHub
- reviewing the two issues the user wrote with the skill in other sessions ([`04`](./04-first-gh-issue.md) and [`05`](./05-first-gh-issue-v2.md)), and tightening the skill from each: one line per paragraph on GitHub, a fifth *Conventions* branch per requirement, decisions recorded everywhere they are stated, and `Req N` for requirements because `R1` is a Redis instance
- a background fact-check of CLAUDE.md that found its "settled decisions" list ten entries behind the register, then the commit, the Forgejo PR and a handoff for the next agent

**Date:** 16 October 2026
**Project:** `caw-project` — CollabHub, the *Claude at Work* sample project
**Model:** Claude Opus 5.5, Claude Code CLI
**Session:** `1b1a1ec1-039c-41ab-be55-fa2f5ad4a617` · 07:27–08:26, 10:17–10:55 and 13:09–13:40 UTC. The two gaps are the user writing issues #2 and #3 with the new skill in other sessions; the context was compacted during the second.

Messages are verbatim. Tool calls are summarised in italics — one note per run of them — so the work is visible without pages of command output. 112 tool calls ran in this session before the export, plus those in its two sub-agents; 285,000 output tokens. Sub-agent reports and background-task notifications are summarised the same way.

This follows on from [`02-acceptance-review-agent.md`](./02-acceptance-review-agent.md), whose handoff named running the workflow on GitHub as the next step.

---

## User

we are adapting the ai agent delivery team to support different infra. currently it's all local - issues are docs in the repo, the deliver.sh runs on a local machine. we want to support github so issues will be real issues, the deliver.sh will run in a gha workflow triggered by a label on the issue - and it will update the label to reflect the stages. the backend (local, gh - potentially forgejo or azdo later) needs to be swappable and the agents should be agnostic, so we want a shared library of adaptors (Python?). we'll start with the issue-writer skill, so it can post a GH issue instead of creating a doc and read it back to confirm. /mattpocock-skills:grill-me

---

## Assistant

*(the `grill-me` skill loaded, which hands straight on to `grilling`)*

*(listed the issue-writer skill, `.claude/delivery/` and `docs/issues/`; read the skill, the first 200 lines of `deliver.sh` and the agent context; checked `gh auth status`, the GitHub repo's issues and PRs, and the uv workspace members)*

I've read the issue-writer skill, the `deliver.sh` header and the agent context, and checked both remotes. Facts the questions below rely on:

- **The agents already read the issue from a local file.** `deliver.sh` copies the issue into the worktree on every run, and each agent's context block gives it an `Issue file:` path. So the agents can stay backend-agnostic without ever calling an adaptor.
- **`deliver.sh` gets the issue number from a line in the file:** it reads `Issue: N` from the first 20 lines and uses N for `feature/issue-N`, `../caw-issue-N` and `docs/plans/issue-N/`.
- **The two backends use clashing numbers.** `sixeyed/claude-at-work-project` on GitHub has no issues yet, but PRs #1–4 share its number sequence, so the first real GitHub issue will be **#5**. Local issues already go up to `008`, and `docs/plans/issue-5`…`8` are taken.
- **The uv workspace only covers `src/services/*`,** and there's no `.github/` directory yet.
- **There are two remotes:** `origin` is GitHub and `forge` is Forgejo (where PRs actually merge today).

Here's round 1.

---

❓ **Q1** - **Agent agnosticism boundary**: Where does the backend stop?
- (a) Only the *edges* use the library: the issue-writer (create and read back) and `deliver.sh`/the GitHub Actions wrapper (fetch the issue, write it into the worktree as today's file copy, update stage labels). The six agents still read `Issue file:` and never know which backend is in use.
- (b) The agents call the library themselves, for example to post review comments to the issue.

➡️ **(a).** The agents are already agnostic through the file copy. Keeping them there means none of the six agent prompts change, and `loop-test.sh` keeps working with a fake backend.

---

❓ **Q2** - **Library shape and home**: Python works for this (the user leaned that way, and uv is already here). Where does it live?
- (a) A new uv workspace member under `src/` (e.g. `src/delivery/`). That puts it next to the product code, though it isn't product code.
- (b) A separate tooling package, e.g. `tools/delivery/` with its own `pyproject.toml`, added to the workspace's `members`.
- (c) Inside `.claude/delivery/`.

Whichever you choose, it exposes a **CLI** (`uv run delivery issue create|get|set-stage …`), because `deliver.sh` is bash 3.2 and the skill drives it through Bash.

➡️ **(b) `tools/delivery/`**, a workspace member with a CLI entry point. It's dev tooling that no image installs, like `testkit`, but it isn't a service. `.claude/` is for prompts, not packages.

---

❓ **Q3** - **Selecting the backend**: How does a run know which backend it's using?
- (a) An env var, `DELIVERY_BACKEND=local|github`, defaulting to `local`, plus backend settings (`DELIVERY_GITHUB_REPO=sixeyed/claude-at-work-project`).
- (b) A committed config file (`.claude/delivery/backend.toml`).
- (c) Autodetect from the git remote. That's ambiguous here, with both a GitHub and a Forgejo remote.

➡️ **(a) env var.** It matches how `scripts/` already take their settings (CLAUDE.md), and it's trivial to set in GitHub Actions. A committed default can come later if switching gets tedious.

---

❓ **Q4** - **How the GitHub adaptor talks to GitHub**:
- (a) It shells out to `gh` (`gh issue create/view/edit --json`). This works locally with your existing login and in GitHub Actions with `GH_TOKEN`. Forgejo would then shell out to `tea`, which your memory notes say is already in use.
- (b) It calls the REST API directly with `httpx` and a token.
- (c) It uses PyGithub.

➡️ **(a) `gh`.** There's no token handling to write, it's the same tool you use by hand, and the adaptor is a thin, testable mapping from `--json` output to our model. Azure DevOps would most likely need (b) when it comes, which is fine behind the protocol.

---

❓ **Q5** - **Issue numbering and the collision**: GitHub's next number is #5, and `docs/plans/issue-5`…`8` (plus branches `feature/issue-5`…) already exist from local issues.
- (a) Namespace paths by backend once GitHub is in play: `docs/plans/gh-5/`, `feature/gh-5`.
- (b) Keep `issue-N` and make `deliver.sh` refuse when `docs/plans/issue-N/` already exists for a different issue.
- (c) Burn GitHub numbers up to 8 (create and close placeholder issues) so the sequences line up, and then treat GitHub as the single sequence from here on.

➡️ **(c), plus the guard from (b).** If GitHub becomes *the* issue tracker, one number sequence and unchanged paths keep everything simple, and the guard catches any future overlap. Choose (a) if you expect local and GitHub issues to keep being created side by side.

---

❓ **Q6** - **Is the local backend an adaptor too?** Should today's behaviour (`docs/issues/NNN.md` with `Issue: N`) be reimplemented as the `local` adaptor, so the skill always calls `delivery issue create` and never writes the file itself?

➡️ **Yes.** The skill then has one path for every backend, and the local adaptor is the reference implementation and the easiest to test.

---

❓ **Q7** - **What "read it back to confirm" means**: After creating the issue, the skill fetches it by number and…
- (a) checks that the fetched body is identical to the drafted markdown, after normalising line endings and trailing whitespace, and that the title matches;
- (b) also runs step 5 (the plan-writer read) on the *fetched* text rather than the local draft;
- (c) both.

➡️ **(c).** (a) proves the round trip didn't mangle anything (GitHub has a 65,536-character body limit and rewrites line endings). (b) means the review reads exactly what the agents will get. If (a) fails, the skill edits the issue rather than creating a second one.

---

❓ **Q8** - **What the issue-writer does on GitHub beyond creating the issue**: The skill currently ends with "starting the delivery is yours". Should it:
- (a) create the issue with no labels, leaving the trigger label for you to add;
- (b) add a non-triggering marker label (e.g. `delivery`) so these issues can be found;
- (c) add the trigger label itself?

➡️ **(b).** Applying the trigger stays a human action, as today. The marker label is cheap and lets the GitHub Actions workflow and humans filter for issues written for delivery. This needs the adaptor to create the label if it's missing.

---

## User

5a; others as recommended

---

## Assistant

*(checked the GitHub repo's visibility and how testkit's plugin discovers test layers)*

Noted: **5a**, with every path namespaced by backend. That makes an issue's identity a **key** rather than a bare number, and much of round 2 follows from that. Two more facts: the GitHub repo is **public**, and pytest discovers `testpaths = ["src/services", "tests"]`, with each test's layer set by its `tests/unit/` or `tests/integration/` directory.

---

❓ **Q9** - **The issue key**: Each adaptor returns a key that `deliver.sh` and the paths are built from: `feature/<key>`, `../caw-<key>`, `docs/plans/<key>/`.
- local: `issue-8`, which keeps every existing plan, branch and worktree valid;
- github: `gh-5`;
- later: `fj-N` for Forgejo and `ado-N` for Azure DevOps.

Or rename local to `local-8` for symmetry, which means migrating `docs/plans/issue-*`.

➡️ **local stays `issue-N`; the others get a short prefix.** Nothing moves, and the asymmetry is a one-line note in the library.

---

❓ **Q10** - **Scope of this slice**: Should this slice cover only (1) the library (the protocol, the issue model, the local and GitHub adaptors, the CLI) and (2) the issue-writer skill rewritten to use it? Then `deliver.sh` taking a key, the GitHub Actions workflow and the stage labels come in the next slice. The key (Q9) is only *defined* now. `deliver.sh docs/issues/NNN.md` keeps working unchanged, but it can't run a `gh-5` issue yet.

➡️ **Yes, that split.** It keeps this slice reviewable. The label state machine needs its own design round, and nothing in the issue-writer depends on it.

---

❓ **Q11** - **The issue model and who renders it**: The skill drafts a **title** and a **body** (the exemplar's sections, starting at `## Summary`) and calls `delivery issue create --title … --body-file <scratch>`. Each adaptor renders those its own way:
- local writes `Issue: N`, then `# Issue N — <title>`, then the body, to `docs/issues/NNN.md`, exactly as today;
- GitHub uses the native title and the body as-is, with no `Issue:` line, because the number is metadata.

`get <key>` returns `{key, number, title, body, url, labels}` as JSON. The first operations would be `create`, `get`, `edit` (for a failed read-back) and `ensure-label`, and nothing else until the next slice.

➡️ **As described.** The model holds title and body separately, and adaptors own the rendering.

---

❓ **Q12** - **Confirming before posting**: Creating an issue on a public repo is outward-facing, while writing a local file isn't. Should the skill name the backend and repo and wait for an explicit "post it" before `create` when the backend isn't `local`?

➡️ **Yes.** It's one confirmation after the coverage-table sign-off it already asks for. Local stays as it is.

---

❓ **Q13** - **Where the library's tests live and what they prove**:
- **Unit** (`tools/delivery/tests/unit/`, with `tools` added to `testpaths`): the local adaptor against `tmp_path`; the GitHub adaptor's argument building and JSON mapping through an injected command-runner seam, so no real `gh` runs; the CLI wiring; the read-back normalisation.
- **Integration**: a real `gh` against GitHub. Testcontainers can't start GitHub, so this would mean a live scratch repo, opt-in through an env var and skipped otherwise. Or none for now, with a manual first-run check written into the plan instead.

➡️ **The unit tests as listed, and no automated live test yet.** The first real run of the skill against `sixeyed/claude-at-work-project` is the check. A live test that is usually skipped proves little and needs a token in CI. Revisit when the GitHub Actions slice brings `GH_TOKEN` into CI anyway.

---

❓ **Q14** - **Where the skill gets the backend from**: `DELIVERY_BACKEND` from your shell environment (Q3). Should the skill also take a per-invocation override, e.g. `/issue-writer --backend github`, and should a shared default live in `.env.example`?

➡️ **Env var only, documented in `.env.example`** with `DELIVERY_BACKEND=local` and `DELIVERY_GITHUB_REPO`. The skill reports the backend it resolved before grilling starts, so a wrong setting shows up early.

---

## User

as described except 14 - we should be able to tell the skill the backend to use and - if remote - the url

---

## Assistant

Understood. The backend and, for a remote one, its URL can be passed to the skill. That opens a few small branches, and I expect this to be the last round.

---

❓ **Q15** - **Arguments, precedence and the URL's shape**: The skill would take `/issue-writer --backend github --url https://github.com/sixeyed/claude-at-work-project`, which maps directly onto the CLI's `--backend` and `--url`.
- **Precedence:** argument, then env var (`DELIVERY_BACKEND`, `DELIVERY_URL`, generic across backends and replacing my `DELIVERY_GITHUB_REPO`), then the default `local`.
- **The URL is the repo's web URL**, and the adaptor turns it into what its tool needs (`gh -R owner/repo --hostname …`).
- **Is `--backend` required when a URL is given?** For `github.com` it could be inferred, but a self-hosted Forgejo or GitHub Enterprise host can't be. So: infer from `github.com` and `dev.azure.com`, and require `--backend` for any other host.
- `--url` with `local` is an error.

➡️ **As described.**

---

❓ **Q16** - **Fail before grilling, not after**: Once the backend and URL are resolved, the skill runs `delivery check` *before* the interview. For GitHub, that checks the repo exists and the token can create issues and labels. A bad URL or missing auth then costs seconds rather than a whole grilling session with nowhere to post the result.

➡️ **Yes.** `check` is a fifth CLI operation, and every adaptor implements it (local: `docs/issues/` exists).

---

❓ **Q17** - **Recording the decision**: The pluggable backend, the key scheme and the agents staying file-only are the kind of thing CLAUDE.md says gets recorded in the slice that makes it. Should this slice:
- write an ADR in `docs/adr/` with the `adr-writer` skill;
- update CLAUDE.md's *Delivery workflow* section with the library, the backends and the keys;
- update the skill's frontmatter description (it currently says `docs/issues/NNN.md`) and `.env.example`?

➡️ **All three.** The open-decisions register is for product decisions, so it isn't touched.

---

❓ **Q18** - **How a GitHub run of the skill ends**: Locally, the skill still ends with `scripts/deliver.sh docs/issues/NNN.md`. For GitHub, until the next slice it can only give the issue URL and key (`gh-5`), and say that label-triggered delivery isn't built yet. Should it say just that, or also offer a stopgap such as `delivery issue get gh-5 > file` to run it locally?

➡️ **The URL and key, plus one line saying delivery from GitHub comes with the GitHub Actions slice.** No stopgap: its path collisions are exactly what 5a set out to avoid.

---

## User

all good

---

## Assistant

That covers every branch of the design. Here's what we've agreed for this slice:

**Architecture**
- **The agents stay backend-agnostic.** Only the edges use the library: the issue-writer, and later `deliver.sh` and the GitHub Actions workflow. The six agents keep reading the `Issue file:` copy, and their prompts don't change.
- **The library is a Python uv workspace member at `tools/delivery/`.** It has a CLI with five operations (`check`, `issue create`, `issue get`, `issue edit`, `ensure-label`), and the GitHub adaptor shells out to `gh`.
- **The local backend is an adaptor too.** It writes `docs/issues/NNN.md` exactly as today, with `Issue: N` and the `# Issue N — title` heading. The GitHub adaptor uses the native title and posts the body as-is.
- **Issue keys:** local issues stay `issue-N`; GitHub is `gh-N`, with `fj-N` and `ado-N` reserved for Forgejo and Azure DevOps. Each key gives its paths: `feature/<key>`, `../caw-<key>` and `docs/plans/<key>/`.
- **Choosing a backend:** a `--backend`/`--url` argument wins over the `DELIVERY_BACKEND`/`DELIVERY_URL` env vars, which win over the `local` default. The backend is inferred for `github.com` and `dev.azure.com` URLs, and required for any other host. Passing `--url` with `local` is an error.

**Issue-writer skill**
1. Resolve the backend and run `delivery check` before grilling starts.
2. Grill as it does today.
3. For a remote backend, name the backend and repo and wait for an explicit "post it".
4. Create the issue with a `delivery` marker label, which is not the trigger label.
5. Read it back: compare the normalised title and body, use `edit` rather than creating a second issue if they differ, then do step 5's plan-writer read on the fetched text.
6. End with the URL and key, plus one line saying delivery from GitHub comes in the next slice.

**Tests and records**
- **Unit tests** go in `tools/delivery/tests/unit/`, with `tools` added to `testpaths`. They cover the local adaptor on `tmp_path`, the GitHub adaptor through an injected command runner, the CLI and the read-back normalisation. There's no live GitHub test; the first real run against the repo is the check.
- **Records:** an ADR, a CLAUDE.md *Delivery workflow* update, the skill's description, and `.env.example`.

**Out of scope until the next slice:** `deliver.sh` taking a key, the GitHub Actions workflow, the stage-label state machine, and a guard against path collisions.

Is this our shared understanding? If so, I can write it up as a plan in `docs/plans/` and start the test-first build in a worktree on a new feature branch, stopping at red for your review.

---

## User

yes go for it

---

## Assistant

*(checked the repo was clean, read the plans-location memory, and listed `docs/plans/ch09/` and the existing worktrees)*

I'll put the plan in `docs/plans/ch09/` as `04-`, after the acceptance-reviewer handoff; tell me if it belongs in a new chapter folder instead. First, the worktree:

*(created the worktree `../caw-delivery-backends` on `feature/delivery-backends` from `main`; read the root `pyproject.toml`, testkit's `layer_of` and its unit tests, `ruff.toml`, `.env.example` and the lint step of `scripts/test.sh`; wrote the plan, `docs/plans/ch09/04-delivery-backends-plan.md`)*

Now the failing tests. testkit first:

*(added three tests to testkit's `test_plugin.py` for tests under `tools/<pkg>/tests/` — the first edit was refused because the file hadn't been read; scaffolded `tools/delivery/` with its `pyproject.toml` and wired it into the workspace; wrote `tests/conftest.py` with a fake `gh`, and `test_resolve.py`, `test_local.py` and `test_github.py`)*

`from conftest import` won't work under importlib mode, so the shared helpers go through fixtures instead:

*(moved the shared helpers behind `gh_issue` and `gh` fixtures; wrote `test_readback.py` and `test_cli.py`; fixed the fake runner's wiring in one CLI test and ran the new tests)*

The conftest's import hides every individual failure behind one collection error. The fake only needs to know an answer is an exception, so I'll drop that import:

*(dropped the import, ran `ruff check` and `ruff format`, and captured each file's red result)*

I've stopped at red for your review. The plan and the failing tests are written in `../caw-delivery-backends` on branch `feature/delivery-backends`. Nothing is staged or committed.

**Plan:** `docs/plans/ch09/04-delivery-backends-plan.md`. I put it in ch09 after the acceptance-reviewer handoff; tell me if it belongs in a new chapter folder. It records what we agreed, plus four small calls I made while planning. Please check these:
- **The backend and URL come from one place.** If either `--backend` or `--url` is given, the env vars are ignored entirely. Otherwise `--backend local` with `DELIVERY_URL` set in your shell would error.
- **`issue verify` is its own command,** so the read-back comparison is mechanical rather than the skill eyeballing whitespace.
- **GitHub's 65,536-character body limit is refused before `gh` runs.**
- **`check` needs WRITE, MAINTAIN or ADMIN permission,** because creating the `delivery` label needs write access.

**One thing I found that wasn't in our design:** testkit's plugin only gives a test its layer under `src/services/<pkg>/tests/`. Tests under `tools/delivery/tests/unit/` would get no `unit` marker and no socket guard, and `-m unit` would skip them. Extending that is now part of the slice.

**Red tests:**

| File | What it covers | How it fails now |
|---|---|---|
| `src/services/testkit/tests/unit/test_plugin.py` (+3) | Tests under `tools/<pkg>/tests/` are marked `unit` or `integration`, and a stray file stops the run | Both layer tests select 0 tests instead of 1; the stray file runs with exit `OK` instead of `USAGE_ERROR`. The 14 existing tests still pass. |
| `tools/delivery/tests/unit/test_resolve.py` | Precedence, the one-source rule, URL inference, every refusal, URL tidying | `ModuleNotFoundError: delivery.errors` |
| `…/test_local.py` | Numbering (exemplar ignored), the exact file `deliver.sh` reads (its own grep), reading today's `008.md`, edit, bad keys, `check` | same |
| `…/test_github.py` | The exact argv sent to `gh` for each operation, the body sent on stdin, read-back by the number in the printed URL, the body limit, permission and issues-disabled refusals, GitHub Enterprise hosts | same |
| `…/test_readback.py` | Normalisation, and differences named by field and body line number | same |
| `…/test_cli.py` | Every command against local on `tmp_path`, JSON output, exit codes 0/1/2 with no traceback, the env var picking GitHub, a GitHub create through the fake | same |

The delivery tests can only fail on import at this stage, because the package is empty. To get them to collect at all I added config before green: `tools/delivery/pyproject.toml`, an empty `delivery/__init__.py`, and the root `pyproject.toml` changes (`tools/*` added to the members, `tools` to `testpaths`, and the dev dependency and coverage entry). The GitHub tests run against a fake `gh` defined in `tools/delivery/tests/conftest.py`, so no unit test calls the real one.

Once you've reviewed these, say the word and I'll build the green tasks: the testkit change, the `delivery` modules, the skill rewrite, then the ADR, CLAUDE.md and `.env.example`.

---

## User

go for it. we have some throwaway github repos in a test org we can use when the writer skill is ready

---

## Assistant

Building green. testkit first:

*(extended `layer_of` in testkit's `plugin.py` to `tools/<name>/tests/`, with its docstrings — again after a refused edit on an unread file)*

Now the library modules:

*(wrote `errors.py`, `model.py`, `resolve.py` — with a refusal for a GitHub URL that isn't `owner/repo` — `local.py`, `github.py`, `readback.py` and `cli.py`; tidied `ensure_label`'s argument list; ran ruff and the delivery and testkit tests)*

All 204 pass. Checking the delivery tests are now in the unit layer, behind the socket guard:

*(confirmed `-m unit` selects all 79 delivery tests and `-m "not unit"` none; ran the real CLI: `delivery check` printed `local: ok`, and a Forgejo URL with no `--backend` exited 2)*

The library works end to end locally. Now the skill:

*(read the issue-writer skill, the exemplar's heading and the first lines of issues 001–008; rewrote the skill onto the delivery CLI in 13 edits, and confirmed each one applied)*

All edits applied. Now the record: the ADR, through `adr-writer`.

*(the `adr-writer` skill loaded; matched the latest ADR's header and wrote `docs/adr/261016-pluggable-delivery-backends.md`)*

Now CLAUDE.md and `.env.example`:

*(added `tools/delivery/` to CLAUDE.md's layout and a paragraph on backends and keys to its delivery section; added a delivery-backend section to `.env.example`, and checked nothing parses that file in a way the new section would break)*

Now the verification: `scripts/test.sh lint unit` and the delivery loop test.

*(ran `scripts/test.sh lint unit`, which exited 0, and `.claude/delivery/loop-test.sh`; read the pytest summary, the coverage lines and `git status`)*

The library and the rewritten issue-writer are built and the unit tests pass. The one thing not yet done is the first real run against GitHub, which needs one of your throwaway repos. Everything is in `../caw-delivery-backends` on `feature/delivery-backends`, uncommitted.

**Checks:** `scripts/test.sh lint unit` passes: lint, all pytest unit tests including the 79 new delivery tests, and the frontend's 503 tests. `.claude/delivery/loop-test.sh` passes every scenario, as expected since `deliver.sh` wasn't touched. The only untested code is the function in `github.py` that actually calls `gh`, so 86% coverage there. I also ran the real CLI: `delivery check` prints `local: ok`, and a Forgejo URL with no `--backend` exits 2 with "say which with --backend".

**What changed:**
- **testkit:** `layer_of` now treats `tools/<pkg>/tests/unit|integration/` the same way as the service test folders, so the delivery tests run in the unit layer behind the socket guard.
- **`tools/delivery/`:** the backend chooser, the local and GitHub adaptors, the read-back comparison, and the CLI (`check`, `issue create|get|edit|verify`, `ensure-label`). It uses only the standard library.
- **Issue-writer skill:**
  - A new step 0 picks the backend and runs `check` before any grilling.
  - It now drafts a title and a body file.
  - For a remote backend it asks you to confirm before posting.
  - It creates the `delivery` label and posts the issue with it.
  - It reads the issue back with `verify`, and fixes a mismatch with `edit` rather than posting a second issue.
  - The plan-writer read in step 5 runs on the fetched issue rather than the draft.
  - It ends with a URL and key for remote, or the `deliver.sh` command for local.
- **Records:**
  - the ADR, `docs/adr/261016-pluggable-delivery-backends.md`;
  - `tools/delivery/` added to CLAUDE.md's repo layout, plus a paragraph on backends and keys in its delivery section;
  - `DELIVERY_BACKEND` and `DELIVERY_URL` in `.env.example`;
  - root `pyproject.toml` and `uv.lock`;
  - `docs/test-report.md`, rewritten by the test run.

**For the first real run:** start Claude Code in `../caw-delivery-backends`, because that's where the new skill and the `delivery` package are. Then run `/issue-writer --url https://github.com/<test-org>/<repo>` with a small idea. The things to watch:
- `check` passes;
- you're asked to confirm before it posts;
- the issue appears with the `delivery` label;
- `verify` prints `match`;
- the ending shows `gh-<N>`.

If you give me the org and repo, I can first run `check`, `ensure-label` and a create/verify round trip through the CLI directly, to prove the GitHub adaptor before you spend a grilling session on it.

---

## User

https://github.com/caw-project/ch09

---

## Assistant

*(ran `check`, `ensure-label delivery` and an `issue create` of a throwaway round-trip issue against `caw-project/ch09`)*

The first real run caught a problem with the repo rather than the code. `check` refused because `caw-project/ch09` has issues turned off, and `gh issue create` confirmed it ("the repository has disabled issues"). That's the case `check` exists for. The `create` line above shows exit 0 only because I piped it through `tee`. `ensure-label` did succeed, so the `delivery` label now exists on the repo.

Should I turn issues on for `caw-project/ch09` with `gh repo edit caw-project/ch09 --enable-issues` and then finish the round trip (create, verify, edit, verify again)? Or would you rather enable them yourself, or point me at a different repo?

---

## User

yes

---

## Assistant

*(turned issues on with `gh repo edit`, then ran `check`, `issue create`, `verify` against the draft and against a changed draft, `edit`, `verify` again, and `issue get gh-999`)*

The round trip against real GitHub works end to end. I turned issues on for `caw-project/ch09`, then:

| Step | Result |
|---|---|
| `check` | `github https://github.com/caw-project/ch09: ok` |
| `issue create … --label delivery` | Created **`gh-1`** (https://github.com/caw-project/ch09/issues/1) with the `delivery` label; the body came back exactly as sent |
| `issue verify` against the draft | `match`, exit 0 |
| `issue verify` against a changed draft | exit 1, with `body line 7: drafted '1. At most two pins…', the issue has '1. At most one pin…'` |
| `issue edit`, then `verify` | `match`, exit 0 |
| `issue get gh-999` | exit 1 with `gh`'s own message, no traceback |

I've left issue #1 open in the throwaway repo; say if you want it closed.

The GitHub adaptor is proven, so the last check is the skill itself: start Claude Code in `../caw-delivery-backends` and run `/issue-writer --url https://github.com/caw-project/ch09` with a small idea. Nothing is committed on `feature/delivery-backends`.

---

## User

check the docs for a good sample issue

---

## Assistant

*(started an `Explore` sub-agent in the background to find three or four small, specified-but-unbuilt features, checked against the code, issues 001–008 and the 🔴 register entries)*

I've sent a search agent through the design docs (01–06) for small features that are specified but not built yet. It's checking each against the code and issues 001–008, and against the 🔴 entries in the open-decisions register. I'll come back with three or four candidates once it reports.

---

## Assistant

*(the search sub-agent reported four candidates — editing your own display name, changing a member's role or removing them, adding an existing user by email, and `GET /assets/{id}` metadata — and ruled out self-leave, presence, retention sweeps and the canvas; it recommended the first)*

**Editing your own display name** makes the best trial issue. The backend route already exists, so it's an SPA-only feature with about four or five clear rules: small enough for a quick grilling, but with real interactions to probe. These candidates come from a search agent's report; I haven't checked its file references myself.

1. **Edit your own display name (recommended).**
   - Auth already has `PATCH /users/me` (`src/services/auth/auth/routers/users.py:40`), which accepts a name of 1–100 characters. The SPA only ever reads the profile.
   - What's missing is a profile form, the update call, showing the server's validation error, and refreshing the cached profile and the member directory.
   - It gives the grilling something to chew on: the new name should show up in every place that already displays it, it overlaps with issue 007's member directory (which left renames out of scope), and one user can be signed in on two tabs.
   - Avatars stay out, because they depend on a 🔴 register entry (D13).
2. **Admins change a member's role or remove them.**
   - The routes exist (`routers/workspaces.py:166` and `:196`).
   - It needs a members screen only admins can open, plus handling for two errors: a 409 when the last owner would be demoted or removed, and a 503 when the token-revocation store is down.
   - About five or six rules, so a bigger trial.
3. **Add an existing user to the workspace by email.**
   - The route exists (`:135`). An unknown email is a 404, not an invitation.
   - About three or four rules; it could fold into #2.
4. **`GET /assets/{id}` metadata.** This is the weakest: nothing calls it yet, and it would mean deciding who is allowed to view an asset.

The search agent ruled out presence, retention sweeps and anything on the canvas, all of which hit 🔴 decisions or are too big.

To start the trial, open Claude Code in `../caw-delivery-backends` and run `/issue-writer --url https://github.com/caw-project/ch09`, giving it the idea "a signed-in user can change their own display name".

*(the user ran the skill in another session — [`04-first-gh-issue.md`](./04-first-gh-issue.md) — and came back nearly two hours later)*

---

## User

ok here is the issue - review and see if the skill needs tweaking https://github.com/caw-project/ch09/issues/2

---

## Assistant

*(fetched `gh-2` through the delivery CLI)*

I've read the issue as the backend holds it. Next I'll check how it got there (edits, duplicates), how GitHub renders it, and how its sections line up with the exemplar's:

*(listed the repo's issues, read `gh-2`'s edit history through the GraphQL API, compared its headings with the exemplar's, and rendered a wrapped paragraph through `gh api markdown` in GFM mode)*

The posting side of the skill worked, but the issue shows three gaps in the skill: one specific to GitHub, two that would affect any backend.

**What worked**
- The issue was posted once, with the `delivery` label, and the repo has no duplicates.
- It was edited once, 12 minutes after it was created. That's the step-5 fix going through `issue edit` rather than a second `create`, as intended.
- Every section of the exemplar is there, in order, and at 213 lines it's within the 120–250 range.

**Proposed changes to the skill**

1. **For a remote backend, don't hard-wrap the prose (GitHub only).** GitHub turns every single newline in an issue body into a line break. I checked this with GitHub's markdown renderer: `one line\nwrapped line` comes back as `one line<br>wrapped line`. So the body's 95-column wrapping reads raggedly on the issue page. The agents won't care, but people reading the issue on GitHub will.
   - Change step 4 so that for a remote backend each paragraph or list item is one line; local files stay wrapped as today.
   - I'd rather the skill write it that way than have the adaptor reflow the text: reflowing markdown risks breaking lists, tables and code blocks, and `verify` would then report a difference on every line.
2. **Check every requirement against CLAUDE.md's conventions (any backend).** Requirement 3 makes display names unique across all of CollabHub. So "That name is already taken" tells a user that someone in *another workspace* has that name, which is a small cross-tenant leak. That's the kind of thing CLAUDE.md's "a 404, not a 403" rule exists to prevent.
   - The skill already says an issue "answers to" CLAUDE.md, but nothing makes the grilling ask about the conventions.
   - Add a fifth question to step 3's four per-requirement questions (Meet, Paths, Assumptions, Timeline): "which convention in *Conventions that are easy to get wrong* does this rule touch?"
3. **Record a decision everywhere it's stated (any backend).** The issue settles D28 and lists updating the docs, the register and the ADRs. It misses CLAUDE.md, which says outright "There is no user-preferences feature anywhere (D28, 🔴)" and gives D28 as the reason the SPA is light-only. Add to step 5's checklist: every place that states a decision this issue changes, CLAUDE.md included, is in *Record in this slice*.

**Something to note, not change:** a trial idea of four or five rules grew into nine requirements, a D28 decision, global uniqueness and a data migration. Every one of those was your call during the grilling, so the skill did its job. The issue is now a big one for the agents to deliver, though, so it may not be the cheapest first run.

Should I make those three changes to the skill? If so, I'd also fix issue #2 through `issue edit` and `verify`: unwrap the prose, add CLAUDE.md to *Record in this slice*, and leave the cross-tenant leak for you to decide (for example, unique within each workspace instead of globally).

---

## User

yes make those changes - also review claude.md for anything which is out of date or would be detrimental to the issue writer skill or the delivery team

---

## Assistant

I'll make the skill changes and fix issue #2 myself. Checking CLAUDE.md's claims against the repo means reading across many files, so a background agent will do that in parallel.

*(started a read-only background sub-agent to fact-check CLAUDE.md against the repo, looking for what is out of date or would mislead the issue-writer or the delivery agents)*

Now the skill. Change 1 (unwrapped prose for remote backends) goes in step 4:

*(edited the skill: "Four branches" became five, with a new **Conventions** branch; the coverage table gained a Conventions column; step 4 gained the one-line-per-paragraph rule for remote backends; step 5 gained the check that every decision is recorded wherever it is stated; and the intro's "four branches" became five)*

The skill now has all three changes. Next is issue #2: unwrap the prose, add CLAUDE.md to *Record in this slice*, then `edit` and `verify` it through the CLI.

*(wrote `unwrap.py` to join wrapped prose while leaving code fences, tables and headings alone; unwrapped `gh-2`'s body to 132 lines and added the CLAUDE.md record line)*

The fences and the timeline came through intact. Before posting, I'll prove nothing changed but the line breaks and the one added line, then edit and verify:

*(compared the old and new bodies word by word — three words added, none removed — then ran `issue edit` and `issue verify` on `gh-2`, and counted `<br>` tags in GitHub's rendering)*

Issue #2 is fixed. No word of the issue changed except the added line, `verify` printed `match`, and GitHub now renders the issue with no forced line breaks (it had 1 per wrapped line). The CLAUDE.md review is still running, and I'll report it with any edits when it finishes.

So far:
- **Skill:**
  - **Conventions:** a fifth question for every requirement, *Conventions*, plus a matching column in the coverage table. Its example is the cross-workspace name leak.
  - **Line breaks:** one line per paragraph for remote backends. Code blocks, tables and the timeline keep their lines.
  - **Recording decisions:** a step-5 check that every decision is recorded wherever it's stated today, CLAUDE.md included.
- **Issue #2:** I added this line to *Record in this slice*: "`CLAUDE.md`: D28 joins *Settled so far*; rewrite the no-preferences paragraph". Global name uniqueness, and the cross-tenant leak it causes, is still as written; that's your call.

---

## Assistant

*(the CLAUDE.md sub-agent reported eleven findings: the "Settled so far" list missing ten 🟢 decisions; no mention of D13; "No Garage fixture" out of date; the test stack publishing seven ports, not five, and nothing scaling Elasticsearch or the Worker down; D23 overstated, since Auth's types are hand-written and D23 is 🟡; the acceptance-reviewer described as deploying the preview; the testing commands contradicting `agent-context.md`; two interactive-only rules not marked as such; Dex missing from the Compose line; and `tests/smoke` missing from the root-tests sentence. It could not verify the hook timings, the `KEEP_STACK` rerun or `loop-test.sh`)*

The review is back. Before I relay it, I'll spot-check its strongest claims myself:

*(grepped the register for the ten decisions, testkit for `garage_server` and the test Compose file for the ports — two of the patterns found nothing)*

Two of my checks found nothing, which may just be my patterns, so I'll look at those files directly:

*(re-checked the register statuses and read the port section of `docker-compose.test.yml`)*

I checked the review's findings against the repo, and every one I looked at holds up: ten 🟢 decisions missing from CLAUDE.md's settled list, the Garage fixture, seven test-stack ports rather than five, nothing in `scripts/test.sh` scaling anything down, and `agent-context.md` contradicting CLAUDE.md on running tests. I haven't edited CLAUDE.md yet. Here's what I'd change, starting with what matters most to the delivery team and the issue-writer.

**Actively harmful to the delivery agents**
1. **The settled-decisions list (~L115) is ten entries behind the register.** D8a, D8b, D15, D17, D30, D32, D34, D39, D43 and D45 are all 🟢 but missing. An agent could treat D43 (who authorizes an attachment download) or D45 (preview tunnels) as open, and stop or re-decide something already settled. The new step-5 rule in the skill would also have the issue-writer trusting this list.
   - **Fix:** replace the list with "the 🟢 rows of the register are settled — read the register". Keep only the prose CLAUDE.md adds: D16, D28, and D13 (which is 🔴 and not mentioned at all).
   - A copied list drifts every time a slice settles something, which is what happened here.
2. **The testing commands contradict `agent-context.md`.**
   - CLAUDE.md calls `scripts/test.sh` "the everyday run" and suggests `KEEP_STACK=1` reruns.
   - `agent-context.md` forbids `scripts/test.sh` to every stage except the code-writer's final check, and refuses env-var prefixes.
   - `agent-context.md` also says "CLAUDE.md wins over both".
   - **Fix:** add one line: delivery agents run tests as `agent-context.md` *Running tests* says.
3. **Interactive-only rules aren't marked as interactive.**
   - "Create the branch and worktree… and tell the user" (L68) doesn't apply under `deliver.sh`, which creates the worktree itself, and there's no user to tell.
   - "🔴 means stop and ask" (L113) means `needs_human` for an agent.
   - **Fix:** a clause on each.

**Out of date (would mislead whoever reads it)**

4. **Test stack (L233–236):** it publishes seven ports, adding Asset 8014 and Garage 3910. Nothing scales Elasticsearch or the Worker to zero any more; the whole stack runs.
5. **Integration fixtures (L190):** "No Garage fixture until something uses object storage" is wrong. `garage_server` exists, and the Asset tests use it.
6. **Frontend types (L64):** "Types are generated from OpenAPI (D23)" is only true of Messaging and Asset. Auth's types are hand-written in `lib/auth/api.ts`, and D23 is 🟡, not settled. That matters for issue #2, which adds Auth fields.
7. **Delivery workflow (L75):** it says the acceptance-reviewer deploys the preview. The workflow deploys it, and the agent only runs `smoke.sh` against it.
8. **Smaller ones:**
   - L40 says only the Gherkin suite lives at the root, but `tests/smoke/` does too.
   - The Compose line in the repo layout leaves out Dex.

Everything else the review checked matches: the repo layout, the hooks and CH001–CH009, the testkit fixtures, and the agent count, models and paths.

Should I apply all of these on `feature/delivery-backends`? Doing so takes CLAUDE.md beyond this slice. Alternatively I can put them on a separate `docs/claude-md-refresh` branch so this branch stays about the backends; I'd recommend the separate branch.

---

## User

yes, same feature branch.

---

## Assistant

*(read CLAUDE.md from line 14 to the end, the register's D13 row, `agent-context.md`'s headings and the frontend's `generate:api` script)*

Now the edits, in file order:

*(applied the corrections to CLAUDE.md in one script, each replacement asserted to match exactly once — 36 lines changed)*

The CLAUDE.md edits are in. Dropping the settled list makes issue #2's new record line wrong, since it says "D28 joins *Settled so far*". I'll fix that through `edit` and `verify`:

*(rewrote the record line in `gh-2`'s body, then ran `issue edit` and `issue verify` — `match`)*

CLAUDE.md is updated on `feature/delivery-backends`, nothing committed. I didn't re-run any tests after these last changes: they only touch CLAUDE.md, the skill and issue #2.

**Changes for the delivery team and the issue-writer**
- **The settled-decisions list is gone.** CLAUDE.md now says to read a decision's status in the register, and keeps only what the register's status line doesn't make plain: D16, D28, and a new note that attachments are built on D13, which is still 🔴.
- **New paragraph in *Delivery workflow*.** CLAUDE.md is written for a person's session, so a delivery agent follows `agent-context.md` for how it stops (`needs_human`), how it runs tests (never `scripts/test.sh`, except the code-writer's final verification), and how it settles open points. Every fact and convention in CLAUDE.md still binds it.
  - This fits `agent-context.md`'s "CLAUDE.md wins over both", because CLAUDE.md itself now hands those points over.
- **Interactive-only rules now say so.** The worktree rule notes that `deliver.sh` creates the worktree itself, and "stop and ask" on a 🔴 notes that an agent uses `needs_human`.
- **The acceptance stage is described correctly:** the workflow deploys the preview, and the agent runs `smoke.sh` against it.

**Factual corrections**
- **Frontend types (D23):** generated for Messaging and Asset only, and D23 is marked 🟡. Auth's types are hand-written, and work that changes an Auth response has to either generate them first or update the hand-written ones and say why.
- **Integration fixtures:** `garage_server` is documented, replacing "No Garage fixture until…".
- **Test stack:** seven published ports (Asset 8014 and Garage 3910 added), and the whole stack runs, including the Worker and Elasticsearch.
- **Root tests:** `tests/smoke/` is now acknowledged at the root, and Dex added to the Compose line.

**Issue #2:** with the settled list gone, its CLAUDE.md record line now says to rewrite the D28 paragraph under *Open decisions*. I edited it through the CLI and `verify` printed `match`. Global name uniqueness, and the cross-workspace leak it causes, is still your call.

*(the user wrote a second issue from scratch with the updated skill in another session — [`05-first-gh-issue-v2.md`](./05-first-gh-issue-v2.md); meanwhile this session's context was compacted, and it resumed from a summary)*

---

## User

new issue from the updates: https://github.com/caw-project/ch09/issues/3 how does it look

---

## Assistant

*(fetched `gh-3` through the delivery CLI; checked the register's highest decision number and D18's status, the three Dex configs for ada, grace and alan, `users.deleted_at`, the 404 for a deleted account, and what status `validation_error` returns)*

Issue #3 is in good shape and a clear improvement on #2. I read it as the plan-writer would and checked its claims against the code. The skill changes all show:
- Every paragraph is one unbroken line.
- It has the Conventions branch: decision 4 takes the cross-workspace leak on purpose as a new D46, and decisions 9 and 11 cover Redis R1 being down and logging.
- Its *Record in this slice* includes CLAUDE.md.

The facts I checked hold:
- `display_name` has no uniqueness today.
- `users.deleted_at` exists, and a deleted account gets a 404 on `/users/me`.
- D45 is the highest entry in the register, so D46 is the next free number, and D18 is still 🔴.
- `alan` is a user in all three Dex configs, so the preview and the test stack both have him.

I'd fix these before anyone delivers it, most important first:

1. **"R1" means two different things.** The issue numbers its requirements R1–R8, but R1/R2/R3 are also CLAUDE.md's names for the three Redis instances. Decision 9 uses "R1" for Redis, while *Where the rules meet* uses "(R2, R1)" for requirements, and requirement 4 says "R3's suffix rule". An agent that has just read CLAUDE.md could read these either way. I'd rename the requirements to "requirement 3" or "§3".
2. **One assumption cites sources the agents can't see.** "The two reports behind this issue disagree on 400 or 422" refers to material that isn't in the issue. It's also settled now: `routers/users.py:61-64` refuses an explicit `null` with `validation_error`, and `shared/problems.py:106` makes that a 400. That line can move to *What exists already* as a fact.
3. **The D46 exception is missing from CLAUDE.md's conventions.** "A resource the caller may not see is a 404… 403 confirms the thing exists" is the rule D46 knowingly breaks with its 409. *Record in this slice* updates the D28 paragraph but adds no exception under *Conventions that are easy to get wrong*. A later agent, or the code-reviewer on this very build, could flag the 409 as a tenancy leak.
4. **The acceptance check for the 24-hour clock depends on the time of day.** "A message sent after noon" can't be done on a morning run. It should look for a time with no AM/PM marker and name the browser locale (en-US). Under en-GB, Automatic already shows 24-hour time.
5. **The `version` column has no stated purpose.** Decision 7 lists `version` in `user_preferences`, but the issue says the last write wins on the same key. One plan run might build an optimistic-concurrency 409 or 412 from it; another would leave it unused. Either drop it or say what it's for. **That one is your call.**

Two smaller points: *References* lists D28 but not D46 or D18, and at 137 lines the issue sits within the skill's 120–250 limit.

If you answer point 5, I'll make the other edits through `delivery issue edit` and run `verify` after them.

---

## User

no i'm more interested in the skill. only 1  needs fixing - it uses §3 etc for its internal numbering, unless we use that elsewhere in the docs

---

## Assistant

*(grepped the exemplar issue for how it numbers requirements, the design docs and issues for `§`, and every doc for `Req`)*

`§` is already taken. The design docs use it for sections, and issues cite them that way: #3 has "doc 01 §3" a few lines above where it would say "§3" for a requirement. So I'll use **Req N** instead, which appears nowhere in the docs. I'm changing the skill's rule and the exemplar's own cross-references, since the issue-writer copies the exemplar's shape.

*(added the `Req 3` rule to step 4's *Requirements* bullet in the skill, and changed the exemplar's five references to its own requirements)*

I've updated the skill and the exemplar issue to number requirements as `Req 3` instead of `R3`. I didn't use `§3` because the design docs use `§` for sections, and issues cite those too: #3 says "doc 01 §3" a few lines above where it would say "§3" for a requirement. `Req` appears nowhere in the docs. Neither change is committed, and nothing needed testing since only Markdown changed.

- **The skill** (`.claude/skills/issue-writer/SKILL.md`): the *Requirements* rule in step 4 now says to refer to a requirement as `Req 3`, and why: `R3` is a Redis instance in CLAUDE.md and `§3` is a design-doc section.
- **The exemplar issue** (`docs/issues/exemplar-issue.md`): its own references now use the new form, with "(Req 2, Req 1)" in *Where the rules meet* and "Req 1–5" in *Decided already*. The issue-writer copies the exemplar's shape, so it would have kept writing `R1` otherwise.

I left two kinds of `R` references as they were:
- The exemplar's `Why` notes still say "Issue 1's R3", "R4" and so on, because they quote issue 1's own labels.
- `docs/issues/001.md` to `008.md` are past issues, so I didn't touch them.

Issue #3 on GitHub still uses `R1`–`R8`. I can update it through `delivery issue edit` and check it with `verify` if you want it to match.

---

## User

yes but only change RN to Req N

---

## Assistant

*(rewrote `gh-3`'s requirement references with a script that set aside decision 9's Redis "R1" first, and printed the changed lines; then ran `issue edit` and `issue verify` — `match` — and confirmed the Redis line survived)*

I've updated issue #3 so its requirement references read `Req N` instead of `RN`. `verify` printed `match` against the new text.

- **Changed:** the 11 references to requirements, including "Req 3's suffix rule", "for Req 2 and its race" and "Scope is Req 1–8".
- **Left alone:** decision 9's "fail open when R1 is down", because that R1 is the Redis instance, not a requirement. Nothing else in the issue changed.

---

## User

summarize this branches changes

---

## Assistant

*(listed the worktree's changes and new files, and read the diff of `docs/test-report.md`, which had shrunk)*

Everything below is uncommitted in `/Users/elton/scm/manning/caw-delivery-backends` on `feature/delivery-backends`, branched from `main` at f88ba89. The branch puts delivery issues behind a swappable backend: local files as today, or GitHub. For now only the issue-writer skill uses it; `deliver.sh` and the agents don't change yet.

**New**
- **`tools/delivery/`**: a dev-only workspace package (`collabhub-delivery`) with a `delivery` command.
  - **Commands:** `check`, `issue create | get | edit | verify` and `ensure-label`.
  - **Choosing the backend:** `--backend`/`--url`, else `DELIVERY_BACKEND`/`DELIVERY_URL`, else local. The backend and URL always come as a pair from one of those places.
  - **Local** writes `docs/issues/NNN.md` in the same format as today, with keys `issue-N`.
  - **GitHub** works through the `gh` CLI, with keys `gh-N`. It refuses a body over 65,536 characters before calling `gh`.
  - `verify` compares the issue as the backend holds it against the draft.
  - **79 unit tests**, with the GitHub backend tested through a fake command runner.
- **`docs/adr/261016-pluggable-delivery-backends.md`**: the decision, why keys are namespaced (GitHub numbers clash with local issues 1–8), and the alternatives turned down.
- **`docs/plans/ch09/04-delivery-backends-plan.md`**: the plan for this work.

**Changed**
- **`.claude/skills/issue-writer/SKILL.md`**:
  - It takes `--backend`/`--url` and runs `delivery check` before any grilling.
  - It writes a title and a body draft, asks before posting to a remote backend, then creates, verifies and fixes any mismatch with `edit`, never a second create.
  - Each requirement gets a fifth branch, Conventions.
  - Remote issue bodies keep one line per paragraph, because GitHub turns every newline into a line break.
  - Requirements are referred to as `Req N`.
  - Step 5 checks that every decision is recorded everywhere it's stated, CLAUDE.md included.
- **`docs/issues/exemplar-issue.md`**: its own references now read `Req N`.
- **`CLAUDE.md`**:
  - **Delivery backends:** `tools/delivery/` is in the layout, and a new paragraph says where an issue lives is a delivery backend.
  - **Decisions:** the out-of-date "Settled so far" list is gone; read a decision's status in the register instead. A D13 note on attachments is added.
  - **Delivery agents:** a new paragraph says agents follow `agent-context.md` for how they stop, how they run tests and how they settle open points, and the interactive-only rules are marked as such.
  - **Fact fixes:** frontend types are generated for Messaging and Asset only (D23 is 🟡), plus Dex, `tests/smoke`, the `garage_server` fixture and the test stack's seven ports.
- **`src/services/testkit/testkit/plugin.py`** and its tests: "the directory decides the layer" now covers `tools/<pkg>/tests/` too.
- **`pyproject.toml`** and **`uv.lock`**: `tools/*` joins the workspace, test paths and coverage.
- **`.env.example`**: `DELIVERY_BACKEND` and `DELIVERY_URL`.

**Before you commit: `docs/test-report.md` has lost results.** My `scripts/test.sh lint unit` run rewrote it from a fresh worktree with no earlier results, so it dropped the last end-to-end result (24 passed) and every journey table. Lint and unit passed, with 1,050 tests. Either restore the file with `git checkout docs/test-report.md`, or run `scripts/test.sh e2e` to fill it back in.

**Outside the repo:** on https://github.com/caw-project/ch09 I turned issues on, created the `delivery` label, and left issues #1 (my round-trip test, still open), #2 and #3.

---

## User

that's fine, you can commit and push this branch to forge, and create a PR for review

---

## Assistant

*(read the memory note on Forgejo PRs with `tea` and the style of recent commit messages; staged everything, committed it as `a8da719`, pushed `feature/delivery-backends` to `forge`, and opened the PR with `tea pr create`)*

The branch is committed as a8da719, pushed to `forge`, and open for review as PR #7: https://forge.sixeyed/manning/claude-at-work-project/pulls/7. Forgejo reports no conflicts with `main`.

The commit includes everything from the summary, with `docs/test-report.md` as it stands. The PR description points out that integration and end-to-end show as "not run" because the tests ran from a fresh worktree, and that nothing tests the GitHub backend against real GitHub in CI yet.

---

## User

we have not been good with our handover docs, but the next agent will be moving the deliver script to python, extending the library and fixing the agents to be backend-agnostic. that could probably use a handover in docs/plans/ch09

---

## Assistant

*(listed `docs/plans/ch08/` and `ch09/`, counted the lines in `deliver.sh`, the agents and `.claude/delivery/`, and read the ch08 model-and-effort handoff for its style; grepped `deliver.sh`, the agents, `agent-context.md`, `loop-test.sh`, CLAUDE.md and the exemplar plan for every hard-coded `issue-<N>`; read the context block, `preview.sh`'s branch naming, the header and function list of `deliver.sh`, the header of `loop-test.sh`, and the decisions, out-of-scope list and handoff-03 open items)*

I'm gathering what the next agent needs (the deliver.sh structure, the agents' references to `issue-N`, the open items from the last handoff) before writing the handover.

*(read the last handoff's decisions, known gaps and next steps; wrote `docs/plans/ch09/05-delivery-backends-handoff.md`)*

I've written the handover to `docs/plans/ch09/05-delivery-backends-handoff.md` in the worktree. It isn't committed: your go-ahead covered the earlier commit, so say if you want it added to PR #7.

It covers the three jobs:
- **Porting `deliver.sh` to Python:** which parts of the state machine to carry over, with `allowed_tools` and `write_scope` ported exactly because they are the safety boundary. It suggests keeping `scripts/deliver.sh` as a thin wrapper and using `loop-test.sh` as a black-box check, first against bash, then against the port.
- **Extending the library:** a delivery takes a key and fetches the issue into `docs/plans/<key>/00-issue.md`, and every path comes from the key. It also needs a guard against two keys landing on the same path, plus probably label and comment operations.
- **Backend-agnostic agents:** every place `issue-<N>` is hard-coded, with file and line (agent descriptions, `agent-context.md`, CLAUDE.md, the exemplar plan, `deliver.sh`). The suggested shape is that the context block names the key and every path, and no agent ever calls `delivery` or `gh`.

It also explains how the library is built (the `Backend` Protocol, the injected runner, the `FakeGh` fixture, and why shared test helpers are fixtures), and records the state of the trial repo.

These are listed as open questions to put to you, not decided:
- the stage label names;
- where `needs_human` questions go on GitHub;
- who commits and pushes;
- the rest of handoff 03's GitHub list;
- whether to port first and switch to keys after, or do it all in one slice;
- a live `gh` test in CI.

Under known gaps it notes the test report showing integration and end-to-end as "not run", and that issue #3's cross-workspace decision isn't recorded under CLAUDE.md's conventions yet.

---

## User

yes commit and add to the pr

---

## Assistant

*(committed the handoff as `8f44084` and pushed it to `feature/delivery-backends`)*

The handover is committed as 8f44084 and pushed to `feature/delivery-backends`, so it's now part of PR #7 on Forgejo after the original a8da719 commit: https://forge.sixeyed/manning/claude-at-work-project/pulls/7. The worktree has no other uncommitted changes.

---

## Timing

| Stretch | UTC | What it was |
|---|---|---|
| Grilling, three rounds | 07:27–08:01 | 18 questions in about 13 minutes; the user then took 21 minutes over the summary before "yes go for it" |
| Plan and red | 08:01–08:07 | worktree, plan, 6 test files, stop at red |
| Green, skill, records, verification | 08:07–08:15 | library, skill rewrite, ADR, CLAUDE.md, `test.sh lint unit` and `loop-test.sh`; the user replied with the repo at 08:22 |
| Live GitHub round trip | 08:22–08:25 | issues found disabled, enabled, round trip proved |
| User writes issue #2 elsewhere | 08:26–10:17 | session [`04`](./04-first-gh-issue.md) |
| Review of #2, skill fixes, CLAUDE.md review and edits | 10:17–10:55 | the fact-check sub-agent reported at 10:23; the user took 31 minutes over its findings |
| User writes issue #3 elsewhere; context compacted | 10:55–13:09 | session [`05`](./05-first-gh-issue-v2.md) |
| Review of #3, `Req N`, summary, PR, handoff | 13:09–13:40 | |
