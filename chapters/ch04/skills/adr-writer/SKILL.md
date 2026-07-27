---
name: adr-writer
description: >-
  Write an Architecture Decision Record (ADR) capturing a single significant
  technical decision. Trigger whenever the user states a decision and its
  reasoning — e.g. "use Redis Streams instead of Kafka for async jobs because
  Kafka is too heavy", "we're going to store sessions in Postgres not memory",
  "record a decision to adopt trunk-based development", or asks to "write an
  ADR", "document this architecture decision", "add a decision record", or
  "log why we chose X over Y". Also use when the user describes a
  choice-with-a-rationale that future developers will need explained, even if
  they don't say the words "ADR" or "decision record". Produces a markdown file
  at docs/adr/{yymmdd}-{title}.md with Status, Context, Decision, Consequences,
  and Alternatives Considered sections.
---

# ADR Writer

An Architecture Decision Record documents one significant technical decision so a
future developer can understand *what* was chosen and, more importantly, *why* —
including the options that were rejected and what the team is now living with as a
result. This skill turns a one-line decision from the user into a well-structured
ADR file.

The format is Michael Nygard's original ADR structure (title, status, context,
decision, consequences), extended with an explicit "Alternatives Considered"
section because the rejected options are often the most valuable thing a reader
comes looking for.

## What makes a good ADR

Write the ADR as if it's a conversation with a developer who joins the team in two
years and asks "why on earth did we do it this way?" That framing drives every
choice below:

- **Capture one decision.** If the user's input bundles several decisions, either
  focus on the single load-bearing one or ask which to record. Don't cram several
  into one file.
- **The rationale matters more than the choice.** Anyone can read the code to see
  *what* was built. The ADR exists to preserve *why* — the forces, constraints,
  and trade-offs that were obvious at the time and will be forgotten later.
- **Be honest about consequences.** List the negative and neutral results, not
  just the wins. A decision that looks all-upside usually means the downsides
  weren't thought through.
- **Write in prose.** Full sentences in short paragraphs, not terse bullet
  fragments. One to two pages is the target. Bullets are fine inside Consequences
  and Alternatives where they genuinely aid scanning.

## Workflow

1. **Extract the decision, the alternatives, and the reasoning** from what the
   user said. A prompt like *"use Redis Streams instead of Kafka for async jobs
   because Kafka is too heavy to operate"* gives you the decision (Redis Streams
   for async jobs), one alternative (Kafka), and the headline reason (operational
   overhead). That's enough to start — you don't need to interrogate the user.

2. **Do light research to write a genuinely useful record.** You usually know the
   technologies involved well enough to flesh out the trade-offs. Where a
   comparison is non-obvious or fast-moving (pricing, current feature parity,
   scaling limits), do a quick web search so the Consequences and Alternatives
   sections are accurate rather than hand-wavy. The goal is an ADR a senior
   engineer would nod along to, not a restating of the one-liner.

3. **Ask only when it genuinely changes the record.** Proceed with sensible
   defaults for anything you can reasonably infer. Ask the user when:
   - the decision is ambiguous or could be read several ways;
   - the status is unclear (see below) and it materially affects the framing;
   - you need a constraint only they know (team size, existing stack, deadline,
     compliance) to judge the trade-offs honestly.

   Keep it to one or two focused questions, not a questionnaire.

4. **Check for an existing ADR directory.** Look for `docs/adr/` (or `docs/adrs/`,
   `doc/adr/`, `architecture/decisions/`). If one exists, match its conventions —
   filename style, whether entries carry a sequential number, heading style — so
   the new record fits in. If none exists, create `docs/adr/`.

5. **Write the file** to `docs/adr/{yymmdd}-{title}.md` using the structure in the
   next section. Read `assets/template.md` for the exact skeleton to fill in.

6. **Tell the user** the path, the status you assigned, and note any assumptions
   you made or facts you looked up, so they can correct anything.

## Filename

`docs/adr/{yymmdd}-{title}.md`

- `{yymmdd}` is today's date, e.g. `260701` for 1 July 2026. Get the real date
  rather than guessing.
- `{title}` is a short, kebab-cased slug of the decision, e.g.
  `redis-streams-for-async-jobs`. Keep it to roughly 3–6 words — enough to
  identify the decision when scanning a directory listing. Lowercase, hyphens for
  spaces, no punctuation.

Full example: `docs/adr/260701-redis-streams-for-async-jobs.md`

If the existing directory uses sequential numbers (`0007-...`), follow that
convention instead of, or alongside, the date — consistency within the log beats
this default.

## ADR structure

Fill in this template. `assets/template.md` holds the same skeleton as a file you
can copy and populate.

```markdown
# {Number if the log uses them}. {Decision title as a noun phrase}

- **Status:** {Proposed | Accepted | Deprecated | Superseded by ADR-xxxx}
- **Date:** {YYYY-MM-DD}
- **Deciders:** {names/roles if known, otherwise omit this line}

## Context

{The forces at play: the problem, the constraints, the requirements, and the
relevant background. Explain the situation so the decision below feels inevitable
rather than arbitrary. This is where a future reader rebuilds the mental state the
team was in. Write in prose.}

## Decision

{State the decision plainly and in the active voice: "We will use Redis Streams
for async job processing." Then explain the specifics — how it's applied, any
scope boundaries, and the primary reason it wins given the context above.}

## Consequences

{What becomes true once this decision is in effect — positive, negative, and
neutral. What gets easier, what gets harder, what new work or risk it introduces,
and anything the team now has to watch. Be honest about the downsides.}

## Alternatives Considered

{Each realistic option that was weighed and rejected, with a sentence or two on
why it lost. This is often the section future readers value most, because it
answers "did they think about X?" before they waste time re-litigating it.}

### {Alternative 1}

{What it was and why it wasn't chosen.}

### {Alternative 2}

{What it was and why it wasn't chosen.}
```

## Choosing the status

- **Proposed** — the decision is being put forward but not yet ratified. Use this
  when the user is drafting for review ("we're thinking of…", "proposal to…").
- **Accepted** — the decision is made and in effect. Use this when the user states
  the decision as settled ("we're using X", "use X instead of Y"). This is the
  most common default for a decision phrased as already taken.
- **Deprecated** — no longer the recommended approach but not formally replaced.
- **Superseded by ADR-xxxx** — replaced by a later record; link to it.

When the user phrases the decision as already made, default to **Accepted** with
today's date. If it reads like a proposal, use **Proposed**. If it's genuinely
unclear and matters, ask.

## Example

**Input:** "use Redis Streams instead of Kafka for async jobs because Kafka is too
heavy to operate"

**Output:** `docs/adr/260701-redis-streams-for-async-jobs.md`

```markdown
# Use Redis Streams for asynchronous job processing

- **Status:** Accepted
- **Date:** 2026-07-01

## Context

Our services need a durable, at-least-once mechanism to hand off background
work — sending emails, generating reports, syncing third-party data — without
blocking request handlers. We already run Redis for caching and rate limiting,
and the team is small with no dedicated platform or SRE function. The volume is
in the low thousands of jobs per minute, well within the range a single Redis
instance handles comfortably.

## Decision

We will use Redis Streams as the transport for asynchronous jobs, with consumer
groups providing at-least-once delivery and per-consumer acknowledgement. Redis
is already in our stack and operational surface, so this adds a messaging
capability without introducing a new system to run, secure, and upgrade.

## Consequences

Producers and consumers share the Redis instance we already operate, so there is
no new cluster to provision or monitor. Consumer groups give us delivery
tracking and replay of unacknowledged messages.

The trade-off is durability and scale ceiling: Redis persistence is weaker than a
log-structured broker's, so a hard failure between fsyncs can lose recent
entries, and throughput is bounded by a single instance until we sacrifice into a
cluster. We also take on responsibility for trimming streams and handling
poison messages ourselves, which a heavier broker would manage for us. If job
volume grows by an order of magnitude, this decision should be revisited.

## Alternatives Considered

### Apache Kafka

The obvious durable, high-throughput option, but operationally heavy: it needs
its own cluster (brokers plus coordination), tuning, and monitoring that a
small team without a platform function cannot sustain. The capability exceeds
our current scale by a wide margin, so the operational cost is not justified.

### A database-backed job table

Polling a Postgres table is simple and transactional, but couples job throughput
to database load and requires building the polling, locking, and retry
machinery by hand. Redis Streams gives us delivery semantics off the shelf.
```

Notice how the Context makes the decision feel reasonable, the Consequences admit
the real downsides, and the Alternatives answer the questions a reviewer would
actually ask.
