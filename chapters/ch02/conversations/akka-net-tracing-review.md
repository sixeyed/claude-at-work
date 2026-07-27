# Chat Transcript

**Topic:** Elton Stoneman's blog posts on distributed tracing with Akka.NET — summary, validity check, and repo reusability
**Date:** 2 June 2026

---

## User

elton stoneman did two blog posts a while ago on distributed tracing with akka.net - can you summarize the approach, check if you think it's valid and see if the github repo is usable for other projects?

---

## Assistant

*(Searched the web for the posts, fetched both in full, then cloned and inspected the GitHub repo `sixeyed/tracing-external-workflows` — reading the OpenTelemetry setup, the generic actor base class, the concrete monitor actors, and the child-span parenting code.)*

**Sources**

- Part 1 (The Code): https://blog.sixeyed.com/tracing-external-processes-with-akka-net-and-opentelemetry-part-1-the-code/
- Part 2 (Running the Demo): https://blog.sixeyed.com/tracing-external-processes-with-akka-net-and-opentelemetry-part-2-running-the-demo/
- Repo: https://github.com/sixeyed/tracing-external-workflows

### The approach

The problem being solved: observing long-running jobs ("Workflows") inside an external system that only exposes a polling REST API and no useful instrumentation. Each Workflow runs three sequential stages ("Entities" — Data Loader, Processor, Output Generator) lasting minutes to hours. The goal is a proper distributed-tracing waterfall view (Jaeger/Tempo-style) rather than point-in-time status snapshots.

The design uses Akka.NET as a supervision tree of pollers:

- A background service subscribes to Redis for "workflow started" events and forwards them to a supervisor actor.
- The supervisor spins up one **WorkflowMonitor** actor per workflow. Each runs an Akka periodic timer to poll the external API, plus a one-shot timer as a timeout so stalled jobs aren't watched forever.
- As stages appear in the API response, the WorkflowMonitor creates child **WorkflowEntityMonitor** actors, one per stage.
- Each actor owns an OpenTelemetry `Activity` (the .NET span primitive). The workflow activity is the root; each entity activity is a child span linked to it. Tags (workflow ID, namespace) and timestamped events (status transitions) are attached as the actors poll.
- The real start/end times come back from the API and are written onto the spans retroactively via `SetStartTime`/`SetEndTime`, so the trace reflects the *actual* durations in the external system rather than the polling cadence.
- Two exporters: console (logs) and OTLP → Grafana Tempo, visualized in Grafana. Part 2 packages it all in Docker Compose with a dummy API and a load generator.

### Is it valid?

Broadly yes — a sound and fairly elegant fit for the problem.

- The actor model is a genuinely good match: one actor per workflow gives isolated lifetime, timers, and state without manual thread/parallelism management, and ~500 concurrent watchers is comfortable for a single node.
- The retroactive timestamp approach is the right instinct — it's what makes the spans accurate despite coarse polling.

The main thing to scrutinize is child-span parenting. In `WorkflowEntityMonitor.StartActivity` it does `Activity.Current = _workflowActivity;` immediately before calling `StartActivity()`, relying on the SDK picking up the ambient `Activity.Current` as the parent. That works, but `Activity.Current` is an `AsyncLocal`, and actors share dispatcher threads — it mutates ambient state on the pool thread and never restores it. In practice it self-corrects (each entity monitor re-sets it before starting its own span), but the cleaner, less fragile idiom is the explicit-parent overload: capture `_workflowActivity.Context` (an `ActivityContext`) and call `StartActivity(name, kind, parentContext)`. No ambient mutation, no thread-sharing footguns.

Two design limits that are fine for his case but matter generally:

- The actors aren't persistent (no Akka.Persistence/cluster sharding), so a worker restart mid-workflow loses in-flight state and produces orphaned/incomplete traces.
- It's single-node — multi-instance scale is handled via a `service.namespace` tag pushing into a shared Tempo, rather than clustering.

### Is the repo reusable for other projects?

Partly — there's a genuinely reusable kernel, but it's wrapped in project-specific coupling, and there's a licensing snag.

**Reusable core:** `EntityMonitorBase<TStarted, TUpdated, TEnded>` — a clean abstract actor with sensible extension points (`ActivityName`, `SetStartedTags`, `SetUpdatedTags`, `GetUpdatedMessage`, `GetEndedMessage`) and the timer/refresh/timeout/terminate plumbing already done. Good starting template for "poll an external thing and emit spans."

**What you'd rip out or rewrite:**

- **Redis** is hardwired as the trigger source.
- **The API client** is generated from one specific OpenAPI spec (`External.Api.Client`), so `WorkflowService`/`Workflow` are bespoke.
- **The child `WorkflowEntityMonitor` does *not* use the generic base** — it's a hand-written `ReceiveActor`, so the entity/stage level is largely a rewrite.
- Config is convention-bound (`TracingSample:{ActorTypeName}:IntervalSeconds/InitialDelaySeconds/TimeoutMinutes`) and the `ActivitySource` name is a hardcoded constant (`"sample-tracing"`).

**Dependencies:** .NET 8, Akka 1.5.21, OpenTelemetry 1.8.1 — current-ish, nothing breaking. The Docker Compose and Helm charts are useful reference scaffolding for wiring Tempo + Grafana.

**Practical blocker:** there's **no LICENSE file** in the repo and no license section in the README. Under default copyright that's "all rights reserved" — you can read and learn from it, but can't lift the code into your own project without permission. As an explicit blog companion sample he'd likely say yes, but worth asking rather than assuming.

**Bottom line:** treat it as an excellent reference implementation and copy the *pattern* (especially the generic base actor and the retroactive-timestamp technique), fix the `Activity.Current` parenting to use an explicit parent context, and sort out licensing before pulling any code in wholesale.

---

## User

can you save a full transcript of the chat as a md artifact

---

## Assistant

*(Created this markdown transcript.)*
