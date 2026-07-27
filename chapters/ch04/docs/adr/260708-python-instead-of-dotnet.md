# Use Python instead of .NET for the project

- **Status:** Accepted
- **Date:** 2026-07-08

## Context

We need to choose the primary implementation language and platform for this
project. The team is genuinely comfortable in both .NET and Python, so this is not
a decision forced by a skills gap — either stack would be a viable technical
choice, and both have strong ecosystems, tooling, and long-term support.

Two factors tipped the balance. First, we judged that Python lets us build and
iterate more quickly for the kind of work in front of us: less ceremony, a fast
edit-run loop, and a large library ecosystem that covers most of what we need off
the shelf. Second, we lean heavily on Claude Code as part of our development
workflow, and our team has the most experience driving Claude Code against Python
codebases. Agent-assisted development is materially smoother in a language the
team already knows how to prompt for and review.

## Decision

We will use Python as the primary language for this project. .NET remains a
language the team knows and can fall back on where a specific component genuinely
warrants it, but new work targets Python by default. The decision rests on
delivery speed and on maximising the effectiveness of our Claude Code-assisted
workflow, where our Python experience is deepest.

## Consequences

Development velocity should improve for early iterations: less boilerplate, a
quicker feedback loop, and a shorter path from idea to working code. Our Claude
Code sessions become more productive because the team can steer and review
Python output confidently, which compounds across the life of the project.

The trade-offs are the usual ones for choosing Python over .NET. We give up
static typing by default and the compile-time safety net that comes with it; we
can recover much of this with type hints and a checker such as mypy or pyright,
but that is opt-in discipline rather than a guarantee. Raw CPU-bound performance
and threading are weaker than .NET's, so any hot path or heavily concurrent
component may need care, native extensions, or a targeted rewrite. Packaging and
dependency management in Python are less uniform than the .NET toolchain, so we
should standardise early on tooling (for example uv or Poetry) to avoid drift.
None of these outweigh the speed and workflow benefits for this project, but they
are worth watching as it grows.

## Alternatives Considered

### .NET

The main alternative and a strong one: statically typed, excellent performance,
first-class tooling, and equally familiar to the team. It lost not on capability
but on fit — we expect slower initial iteration for this work, and our Claude
Code experience is less developed against .NET than Python, which reduces the
leverage we get from agent-assisted development. If a future component becomes
performance- or concurrency-critical, .NET remains the natural candidate for that
piece.
