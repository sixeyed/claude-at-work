# Chapter 5 — Getting started with Claude Code

This is where the build starts, and from here on the real output is code. That all lives in the project repo, **https://github.com/sixeyed/claude-at-work-project** — there's no point copying thousands of lines of Python in here. What's in this folder is the three session transcripts, which are the interesting part anyway: they show how much Claude does on its own, and where I stepped in.

The input for the whole chapter is the design documentation from chapter 3, in [`chapters/ch03/lab/docs`](../ch03/lab/docs). Copy that into a repo of your own and you're at the same starting line.

## The sessions

| Transcript | Section | What happened |
| --- | --- | --- |
| [`conversations/01-project-scaffold.md`](conversations/01-project-scaffold.md) | 5.7 — *Try it now: build out the application scaffolding in auto mode* | The walking skeleton: every component scaffolded, containerized, Compose file, Helm chart |
| [`conversations/02-auth-mvp.md`](conversations/02-auth-mvp.md) | 5.10 — *Try it now: build the MVP for your first service* | The auth MVP — brainstormed scope, dev-login stub, RS256 tokens, tests |
| [`conversations/03-full-auth-implementation.md`](conversations/03-full-auth-implementation.md) | 5.11 — *Your turn: complete the first service* | The full auth service, federating to Dex, with an SPA login page |

## Setting up the repo

Section 5.5 — *Try it now: use Claude to build the agent documentation*.

There's no transcript for this one; the output is the `CLAUDE.md` file, and it belongs to the project: https://github.com/sixeyed/claude-at-work-project/blob/main/CLAUDE.md. Read the file history rather than just the current version — it starts as a straight `/init` write-up of the design docs, and grows the working rules (never commit, ignore `docs/project/`) as I hit things I didn't like.

The prompt I used was `/init` with the extra detail about Docker and Helm, so Claude documented how to run the stack as well as how the code is laid out. Yours will look different if you picked a different platform stack, and that's fine — the point of the file is that the *next* agent doesn't have to work any of it out.

## Scaffolding the whole app

Section 5.7. Transcript: [`conversations/01-project-scaffold.md`](conversations/01-project-scaffold.md).

One prompt — "we're ready to make a start on the code. scaffold everything." — and about 2,800 lines of code and infrastructure came back. The session ran overnight in `auto` mode with 12 user turns in it, and most of those aren't really steering: two are skill payloads, two are interruptions, one is me pasting a PowerShell path.

This is the raw render of the session log, so it's nearly 7,000 lines and includes the tool calls and their output. That's deliberate — it's the one transcript in the book where the volume is the message. Things worth looking for as you skim:

- Claude invoking the `superpowers:brainstorming` skill before writing anything, and offering three depths of scaffolding. I picked the walking skeleton.
- The *phase 0* option in that list, which came from Claude finding my [`CollabHub-Build-Phases.xlsx`](../ch04/CollabHub-Build-Phases.xlsx) from chapter 4 and reading it. That workbook was stakeholder material, not project input — the fix is the `docs/project/` rule in `CLAUDE.md`.
- Claude branching, committing under its own ID and opening a PR at the end. That's the workflow decision you hand over when you run in `auto` mode. The last few turns are me taking it back.

The other two transcripts are curated in the book's house style — messages verbatim, runs of tool calls summarized in italics — so they read in a few minutes each.

## The auth MVP

Section 5.10. Transcript: [`conversations/02-auth-mvp.md`](conversations/02-auth-mvp.md).

The prompt is one line, and the session opens with Claude asking the questions I should have answered at design time. The one that matters is open decision **D5** — does the auth service federate to an upstream identity provider, or act as an OIDC provider itself? `CLAUDE.md` says stop and ask on an open decision, so it stopped and asked. We settled on a dev-login stub that issues real tokens, which keeps everything downstream honest and defers the IdP.

Then `/goal get the mvp working and tested with unit and integration tests` and Claude ran to 4,500 lines of Python and 109 passing tests. Read the middle of this one for how it verifies its own work — building the containers, running the suite, reading the logs — rather than for the code.

## The full service

Section 5.11. Transcript: [`conversations/03-full-auth-implementation.md`](conversations/03-full-auth-implementation.md).

The MVP becomes a real OpenID Connect service: Dex and OAuth Proxy in the Compose stack, the federation endpoints, PKCE code exchange, and a login page in the SPA. Two open decisions get settled along the way — D5 (federate) and D22 (refresh token in an HttpOnly cookie).

The `api.http` REST Client file from listing 5.3 came out of this session and lives in the project repo at `src/services/auth/api.http`. It's worth opening even if you don't use VS Code — read top to bottom it's a readable description of the login flow, and it's a good example of asking Claude for the artifact that gives *you* confidence, rather than another test suite.

## Following the code

The project repo has milestone tags, so you can check out the exact position at each stage:

| Tag | Where it is |
| --- | --- |
| `ch04-setup` | End of the `/init` session — decisions closed, `CLAUDE.md` written, no code |
| `ch04-scaffold` | The walking skeleton merged |
| `ch04-mvp` | The auth MVP |
| `ch04-full` | The full auth service running with Dex |

The tags say `ch04` because they were cut when this was chapter 4 — the chapter numbers moved, the tags didn't. Names aside, the order is the order of this chapter.

```
git clone https://github.com/sixeyed/claude-at-work-project.git
git checkout ch04-scaffold
```

## Your output will be bigger than the book's

Both of the later sessions here ran to thousands of lines of code from a handful of prompts, and the transcripts are the only part small enough to publish. If your session went the same way, you'll have a similar problem — which is really the point of section 5.8. Don't try to read it all. Decide what "good" looks like for the task, run those checks outside Claude, and spend your review time on the things that would be expensive to get wrong.
