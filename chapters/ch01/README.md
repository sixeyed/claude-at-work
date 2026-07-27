# Chapter 1 — Meet Claude

Two exercises in this chapter: comparing the models on a single question, and the first design conversation for CollabHub.

## The architecture conversation

Section 1.5 — *Your first collaborative conversation*.

Start by uploading [`architecture-sketch.png`](architecture-sketch.png) to a new chat at `claude.ai` with the opening prompt:

> what do you make of this?

The sketch is deliberately bad — illegible labels, arrows with no direction, generic to the point of meaninglessness. That's what makes it a useful starting point: it could be any system, so the design is yours to shape.

- [`architecture-session.md`](conversations/architecture-session.md) — my full transcript. Six exchanges from the sketch to the finished document, including the parts where I argued with Claude about technology choices.
- [`architecture.md`](architecture.md) — the artifact Claude produced at the end.

The architecture document is not a finished piece of work, and it's worth reading critically rather than as a model answer. On a real project I'd rewrite the prose in my own words, add links to the open source projects, and add a section recording the decisions we made and why. Spotting that gap for yourself is the exercise.

## Same question, three models

Section 1.4.2 — the *Different models, different responses* sidebar.

I asked each model the same two prompts, in separate conversations:

> what's coming up in the next version of .net?

then:

> can you capture this conversation in an artifact — with timestamps for the prompt and response

Each model chose its own format for the artifact, with no steer from me:

| Model | Artifact | What stood out |
| --- | --- | --- |
| Opus | [`dotnet-opus.md`](conversations/dotnet-opus.md) | ~300 words, correct throughout, with upgrade advice and a read on the project's direction. Saved as markdown |
| Sonnet | [`dotnet-sonnet.html`](conversations/dotnet-sonnet.html) | ~200 words, a few details different from Opus, and it picked up community reaction rather than direction. Saved as styled HTML with a sepia theme |
| Haiku | [`dotnet-haiku.html`](conversations/dotnet-haiku.html) | ~200 words, but a version behind — it described the current release, not the next one, and got confused about version numbers at the end. Saved as HTML, presented as a chat exchange with a robot emoji |

Each file holds the whole conversation, so you can see both turns and how the model reasoned. Reading them side by side is the quickest way to get a feel for the trade-off: Haiku's answer is confidently wrong about the thing that matters most, which is exactly the failure mode the book asks you to watch for.

Your results will differ. These were captured with the models current at the time of writing, and the .NET release they discuss will have shipped by the time you read this.
