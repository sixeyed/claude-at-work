# Chapter 2 — Your side of the conversation

Four exercises here, all about what *your* half of the conversation does to the output. The end-of-chapter lab turns the chapter 1 architecture into buildable component designs.

## Vague vs. structured prompting

Section 2.4 — *Starting with a good first prompt*.

The same question about migrating a Node app to the cloud, asked two ways:

- [`cloud-migration-guide-v1.md`](cloud-migration-guide-v1.md) — from the vague prompt. Claude had to ask three rounds of clarifying questions first: tech stack, then traffic, then cloud preference. Those answers are recorded in the Context block at the top.
- [`cloud-migration-guide-v2.md`](cloud-migration-guide-v2.md) — from the structured prompt, which carried all three of those up front. No clarifying questions.

Read the provider recommendation in each. v1 commits to AWS as "the safest bet"; v2 declines to pick, calling AWS and GCP jointly strongest. Same question, same model, different answer — which is the point. The structured prompt didn't just save the round trips, it changed the conclusion.

## Generating an RFC from a public format

Section 2.6.1 — *Try it now: generating RFCs*.

[`CEP-0001-collaborative-canvas.md`](CEP-0001-collaborative-canvas.md) is a 4,700-word RFC on the Yjs and SignalR canvas layer, written to the Kubernetes Enhancement Proposal format. The prompt named three real KEPs as examples and left Claude to infer the structure — no format description, no template. The release signoff checklist, the goals/non-goals split, and the graduation criteria all come from reading those examples.

This is the few-shot technique doing the work. Try it with any structured format you already use: OpenAPI specs, runbooks, postmortems, ADRs.

## Reading unstructured input

Section 2.6.3 — *Try it now: assess a technical approach*.

[`conversations/akka-net-tracing-review.md`](conversations/akka-net-tracing-review.md) is the transcript of Claude reviewing two of my old blog posts on distributed tracing with Akka.NET. The prompt gave no URLs — Claude found the posts, read them, followed the link to the GitHub repo, cloned it, and reviewed the code.

Watch what it does with the licence: it noticed there isn't one, and correctly concluded you'd need to ask me before reusing the code.

## Building a design system from a screenshot

Section 2.6.4 — *Try it now: build a design system*.

[`homepage-v3.png`](homepage-v3.png) is the input — a single mockup image of the Widgetario homepage, no code. Everything in [`design-system`](design-system) was derived from it:

| File | What it is |
| --- | --- |
| [`widgetario.tokens.json`](design-system/widgetario.tokens.json) | The design system in W3C DTCG format |
| [`widgetario.tokens.css`](design-system/widgetario.tokens.css) | CSS custom properties generated from those tokens |
| [`README.md`](design-system/README.md) | Claude's own notes on how the system fits together |
| [`widgetario-home-v3.html`](design-system/widgetario-home-v3.html) | The mockup rebuilt as a working page from the tokens |
| [`widgetario-home.html`](design-system/widgetario-home.html) | The earlier homepage for comparison |

The dark mode toggle works, even though the source screenshot only showed the light variant.

## The lab — component designs

Section 2.8 — *Your turn: produce the component designs for your app*.

[`lab/docs`](lab/docs) has the eight documents Claude produced from the chapter 1 architecture: a shared conventions document, one design per service (auth, messaging, canvas, asset, worker), the frontend SPA, and an open decisions register. [`lab/files.zip`](lab/files.zip) is the same set as Claude delivered it.

Start with [`00-platform-conventions.md`](lab/docs/00-platform-conventions.md) — it holds the cross-cutting decisions the other seven depend on. Then read [`07-open-decisions-register.md`](lab/docs/07-open-decisions-register.md), which is the most interesting one: 24 points Claude flagged as needing a human call, each with its own suggested answer. Working through that register is a good way to see where you actually add value in the collaboration.

These carry forward. Chapter 3 picks up this document set and revises it in Cowork.

## Elsewhere

The *Claude at home* sidebar in section 2.2 mentions a conversation about whether Alex Honnold's Taipei 101 climb was faked — magnets, hidden winches, secret NASA anti-gravity technology. It's in [`conversations/honnold-skyscraper-live.md`](conversations/honnold-skyscraper-live.md). It's not technical, but it is a good look at how Claude handles a bad-faith premise pushed over ten turns.
