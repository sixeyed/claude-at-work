# Chapter 6 — Planning and building in stages with BDD

Eight sessions in this chapter, which is more than the rest of the book put together. That's the point of it: the work gets broken into a hierarchy of plans, and each plan is cheap enough to throw away. The plans themselves are project documents so they live in the project repo, **https://github.com/sixeyed/claude-at-work-project**, under `docs/plans/ch06/`. What's here is the transcripts, and the one artifact you're actually meant to review closely — the Gherkin.

## The sessions

All eight ran on 15–16 August 2026, back to back. The timings and token counts come from the sessions' own logs.

| Transcript | Section | Ran for | What happened |
| --- | --- | --- | --- |
| [`01-messaging-bdd-plan.md`](conversations/01-messaging-bdd-plan.md) | 6.3 — *Try it now: enter plan mode* | 24m | The strategy plan: BDD from Gherkin, driven through Playwright against the Compose stack |
| [`02-messaging-delivery-plan.md`](conversations/02-messaging-delivery-plan.md) | 6.6 — *Try it now: build the delivery plan* | 34m | Seven vertical slices, each starting with Gherkin and ending in a demo |
| [`03-slice-01-build.md`](conversations/03-slice-01-build.md) | 6.8 — *Try it now: write the implementation plan for slice 1* | 2h 19m window | Plan, review the Gherkin, build slice 1 — channels end to end |
| [`04-generate-parallel-plan.md`](conversations/04-generate-parallel-plan.md) | 6.10 — *Try it now: use subagents to build all the implementation plans* | 34m | Asking Claude to write the 350-line prompt that fans planning out across subagents |
| [`05-build-implementation-plans.md`](conversations/05-build-implementation-plans.md) | 6.10 | 55m | Running that prompt: six planner subagents, then three reviewers |
| [`06-parallel-gherkin-prompt.md`](conversations/06-parallel-gherkin-prompt.md) | 6.11 — *Your turn* | 13m | The second fan-out prompt — write every slice's scenarios, then stop |
| [`07-build-gherkin-parallel.md`](conversations/07-build-gherkin-parallel.md) | 6.11 | ~38m | Running it: five writers, two reviewers, 34 scenarios for slices that don't exist yet |
| [`08-build-all-slices.md`](conversations/08-build-all-slices.md) | 6.11 | ~81m | Slices 2 to 7 built in one unbroken run, no input from me in the middle |

The chapter walks through the first four in detail and summarizes the rest. The last four are the interesting ones to read if you want to see what the parallel approach actually costs and returns.

## The plans

Only two of these are quoted in the chapter, but the full set is worth a skim to see how the detail changes as you go down the levels. They're all in the project repo under [`docs/plans/ch06/`](https://github.com/sixeyed/claude-at-work-project/tree/main/docs/plans/ch06):

| File | What it is |
| --- | --- |
| `01-messaging-core-strategy-plan.md` | The strategy — goal, approach, and the QA mechanism |
| `02-messaging-core-delivery-plan.md` | The seven slices, plus the delivery protocol every slice follows |
| `03-slice-01-implementation-plan.md` | Slice 1 in detail, written by hand-holding Claude through one session |
| `04-slice-contracts.md` | The rulings that stop six parallel planners closing the same gap two different ways |
| `05` – `10` | The implementation plans for slices 2 to 7, all written in one 55-minute fan-out |
| `prompts/parallel-slices.md` | The prompt Claude wrote for me to paste into the next session |
| `prompts/parallel-gherkin.md` | The same trick for the scenarios |
| `gherkin/` | The staged `.feature` files from the parallel writers, and the frozen scenario vocabulary |

The strategy plan is the one I deliberately *didn't* iterate on — section 6.3 explains why. The delivery plan is the one to read properly, because the delivery protocol and the stop-and-wait-for-approval gate in it are what every later session obeys.

## The Gherkin

[`features/channels.feature`](features/channels.feature) is the file from listing 6.5 — slice 1's scenarios, exactly as Claude presented them at the review gate, before I'd said a word about them. Five scenarios, 45 lines, and it takes about two minutes to read.

That's the artifact this whole chapter is arranged around, so read it as a reviewer. Two things I picked up, and you can see both in [`03-slice-01-build.md`](conversations/03-slice-01-build.md):

- The feature description talks about "slices" and work that hasn't been built yet. That's delivery process leaking into a document that's supposed to describe the product.
- The last scenario is "a channel name cannot be blank", and blank is the only rule there is. Real channel names need a minimum length, an allowed character set, and a rule about what they can start with. Asking for that turned one scenario into a `Scenario Outline` with a table of names and complaints — which reads as documentation for the rule as well as testing it.

The version in the project repo at [`tests/bdd/features/channels.feature`](https://github.com/sixeyed/claude-at-work-project/blob/main/tests/bdd/features/channels.feature) is where that ended up: 100 lines, with the naming rules and slice 2's rename, archive and private-channel scenarios added. Diff the two and you're looking at the value of the review gate. The rest of the suite — `messages.feature`, `realtime.feature`, `permissions.feature` — is alongside it, 34 more scenarios written by the parallel run in session 07.

## What the parallelism actually bought

Worth knowing before you decide how far to take this yourself:

- The six implementation plans came back in 55 minutes. The nine subagents underneath that session reported 1.42 million output tokens between them, against 389,000 in the main session — the fan-out is where the cost goes, and it stays out of the coordinator's context.
- Both Gherkin reviewers in session 07 independently found the same defect, which would have made three scenarios pass vacuously. One reviewer would have been enough to catch it; the second is what told me the first wasn't guessing.
- The slices themselves couldn't be parallelized at all — each depends on the one before. Section 6.9 is about what to do when the answer is a solid no: plan in parallel, build in sequence, and review slice N+1 while Claude builds slice N.
- Session 08 built six slices in 76 minutes of unbroken build time, with no input from me. The interesting parts of that transcript are the four bugs the tests caught, a `ruff` cache that had been hiding five failures, and my laptop running out of disk at the final verification step.

## Not in the repo

The messaging code, the BDD harness and the test suite are all in the project repo. At the end of the chapter that's 7,400 new lines with 43 BDD tests, 287 integration tests and 102 unit tests. The `ch05` tag marks the point where this chapter starts — the tags were cut under the book's old chapter numbering so they run one behind — and `main` is where it finishes.

```
git clone https://github.com/sixeyed/claude-at-work-project.git
git checkout ch05
```
