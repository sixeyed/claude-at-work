# Claude at Work

Source code, transcripts, and artifacts for the book *Claude at Work* by [Elton Stoneman](https://blog.sixeyed.com), published by Manning.

This repo is the companion to the book. Every practical exercise has an objective, and you work through it in conversation with Claude — so your output will be different from mine. What's here is *my* output: the transcripts of my sessions, the documents and artifacts Claude produced, and the input files you'll need to follow along. Use it to compare your approach with mine, or to pick up the thread if a session doesn't take you as far as you expected.

## Following along

You don't need anything from this repo to start — you can bring your own idea and your own system. But most chapters have input files you can use if you'd rather work with the same example as the book, and every chapter has my output so you can see where the exercises lead.

The running example throughout the book is **CollabHub**, an internal real-time collaboration platform — a simplified hybrid of Slack and Figma. You design it in Phase 1, build it in Phase 2, and hand it over to agents to run in Phase 3.

## The other two repos

This repo is the book's scrapbook — a chapter-by-chapter record of what came out of each session, frozen at the point the chapter describes it. Two other repos hold the living versions:

- **https://github.com/sixeyed/claude-at-work-project** — CollabHub itself. The design documents, then the code, then the deployment and the agents that run it, plus the project's own skills in `.claude/skills`. This is the one to follow if you're building along; it has the full commit history and it keeps moving through all three phases.

- **https://github.com/sixeyed/claude-at-work-skills** — the plugin marketplace. This is what you install from in chapter 4, and where updated plugins get published. It's separate from the project because plugins are built to be shared beyond any one project.

Where this repo and those two overlap, they're the golden source and what's here is the snapshot. The snapshots are deliberate: they let you check your own output against mine at the right point in the story, without the later chapters' changes already applied.

## What's in here

Everything lives under [`chapters`](chapters), one folder per chapter. Each chapter folder holds the artifacts Claude produced and the input files you need, with the session transcripts in a `conversations` subfolder.

### [`chapters/ch01`](chapters/ch01) — Meet Claude

The first design conversation, and a comparison of how the three models handle the same question.

| File | What it is |
| --- | --- |
| [`architecture-sketch.png`](chapters/ch01/architecture-sketch.png) | The deliberately awful whiteboard sketch. Upload this to Claude to start the exercise |
| [`architecture.md`](chapters/ch01/architecture.md) | The finished CollabHub architecture document |
| [`conversations/architecture-session.md`](chapters/ch01/conversations/architecture-session.md) | Transcript of the six-exchange design conversation |
| [`conversations/dotnet-opus.md`](chapters/ch01/conversations/dotnet-opus.md) | Opus asked "what's coming up in the next version of .NET?", saved as markdown |
| [`conversations/dotnet-sonnet.html`](chapters/ch01/conversations/dotnet-sonnet.html) | The same question to Sonnet, saved as a styled HTML transcript |
| [`conversations/dotnet-haiku.html`](chapters/ch01/conversations/dotnet-haiku.html) | The same question to Haiku, saved as an HTML chat log |

The three `dotnet-*` files are the artifacts from the sidebar in section 1.4.2 — one conversation per model, same two prompts each time. Read them side by side to see how the models differ in depth, accuracy, and presentation.

### [`chapters/ch02`](chapters/ch02) — Your side of the conversation

Prompting, structured output, and the component designs produced from the chapter 1 architecture.

| File | What it is |
| --- | --- |
| [`lab/docs`](chapters/ch02/lab/docs) | One design document per component, plus shared conventions and the open decisions register |
| [`lab/files.zip`](chapters/ch02/lab/files.zip) | The same eight documents, zipped as Claude delivered them |
| [`CEP-0001-collaborative-canvas.md`](chapters/ch02/CEP-0001-collaborative-canvas.md) | The RFC for the collaborative canvas, written to the Kubernetes KEP format |
| [`cloud-migration-guide-v1.md`](chapters/ch02/cloud-migration-guide-v1.md) | Output from the deliberately vague opening prompt |
| [`cloud-migration-guide-v2.md`](chapters/ch02/cloud-migration-guide-v2.md) | Output from the structured version of the same question — compare the two |
| [`design-system`](chapters/ch02/design-system) | The DTCG tokens, CSS, and rebuilt HTML pages from the Widgetario exercise |
| [`homepage-v3.png`](chapters/ch02/homepage-v3.png) | The Widgetario homepage mockup that design system was derived from |
| [`conversations`](chapters/ch02/conversations) | The Akka.NET tracing review, and the Alex Honnold conversation from the *Claude at home* sidebar |

### [`chapters/ch03`](chapters/ch03) — Claude Desktop and Cowork

| File | What it is |
| --- | --- |
| [`lab/docs`](chapters/ch03/lab/docs) | The design documents rewritten from .NET to Python in the Cowork session — this is the set the build runs from |
| [`Connectivity-Research-Orbit-Report.docx`](chapters/ch03/Connectivity-Research-Orbit-Report.docx) | The research report Claude produced from the Our World in Data datasets |

### [`chapters/ch04`](chapters/ch04) — Skills and schedules

| File | What it is |
| --- | --- |
| [`skills`](chapters/ch04/skills) | The `adr-writer` and `stack-update-checker` project skills. Copy these into `.claude/skills` in your own project |
| [`docs`](chapters/ch04/docs) | What those skills produced — an ADR, and the agent-readable platform versions list |
| [`CollabHub-Application-Overview.docx`](chapters/ch04/CollabHub-Application-Overview.docx) | The stakeholder summary, built by the docx skill |
| [`CollabHub-Build-Phases.xlsx`](chapters/ch04/CollabHub-Build-Phases.xlsx) | Build phases and estimates, built by the xlsx skill |
| [`claude-at-work-skills`](chapters/ch04/claude-at-work-skills) | A copy of the plugin marketplace repo, for reading before you install. Install from https://github.com/sixeyed/claude-at-work-skills |

## A note on model versions

The transcripts here are from the models available when I wrote each chapter, and they're named in the book alongside each response. Models are updated every few months and each generation is more accurate and more capable — so if you run the same prompts you will definitely get different output from mine, and probably *better* output. Where a response in the book looks dated, that's the platform moving on.
