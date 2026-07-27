# CollabHub — Worker Service

> Headless background processor: indexing, thumbnails, notifications, exports, retention.
> Read [Platform Conventions](./00-platform-conventions.md) first.

**Status:** Draft · **Runtime:** .NET 10 worker (headless, no HTTP except health)
**Owns:** all async job processing + the Elasticsearch index lifecycle
**Depends on:** Redis Streams (R3), Elasticsearch, MinIO, PostgreSQL (read-mostly, see §5)

---

## 1. Purpose & Responsibilities

A headless .NET worker that consumes jobs from **Redis Streams (R3)** and does the heavy,
non-interactive work. Scales horizontally via **KEDA** based on stream depth.

**Owns:**
- Consuming all `jobs:*` streams (Conventions §7).
- The **Elasticsearch index lifecycle**: mappings, aliases, reindexing, and writes. ES is
  write-only from the Worker; services read from ES directly (or via a search gateway).
- Image thumbnailing/optimisation (ImageSharp).
- Notification dispatch.
- Export generation (canvas → PNG/SVG/PDF).
- Data retention / cleanup sweeps.

**Does NOT:** serve user requests, own any service's primary database (it reads to enrich jobs;
writes back via the owning service's internal endpoint where possible — see §5).

---

## 2. Runtime & Dependencies
- `Microsoft.Extensions.Hosting` `BackgroundService`, one hosted consumer per job type.
- StackExchange.Redis (R3 consumer groups, `XREADGROUP` / `XAUTOCLAIM`).
- `Elastic.Clients.Elasticsearch` for ES.
- `SixLabors.ImageSharp` for image work.
- S3-compatible client (`IObjectStore`) for MinIO (shared with Asset service via Shared lib).
- Npgsql for read access where needed.
- Exposes only `/health/live` and `/health/ready` (Conventions §10); no business HTTP.

---

## 3. Interface — Jobs Consumed

All jobs use the Conventions §7 envelope. One consumer group `worker` per stream; handlers keyed
by `type`.

| Stream | `type` | Payload | Handler action |
|--------|--------|---------|----------------|
| `jobs:index` | `message.upsert` / `message.delete` | `{ messageId, op }` | Read message (or accept payload), upsert/delete in `messages` ES index. |
| `jobs:index` | `document.index` | `{ documentId, textProjection }` | Index canvas text projection (if canvas search enabled). |
| `jobs:index` | `asset.index` | `{ assetId }` | Index file metadata for file search. |
| `jobs:thumbnail` | `thumbnail.generate` | `{ assetId, objectKey, variants[] }` | Fetch from MinIO, generate variants (ImageSharp), store back, report variants to Asset svc. |
| `jobs:notify` | `notify.dispatch` | `{ userId, kind, data }` | Deliver notification (push/email/in-app). |
| `jobs:export` | `canvas.export` | `{ documentId, format, requestedBy }` | Render document to PNG/SVG/PDF, store in MinIO, notify requester. |
| `jobs:retention` | `retention.sweep` | `{ scope }` | Hard-delete soft-deleted rows/objects past policy; clean orphan `pending` assets. |

The Worker emits no events of its own except results delivered back through owning services
(e.g. Asset `POST /assets/{id}/variants`) or notifications.

---

## 4. Elasticsearch Index Design

Worker owns mappings + aliases. Read-side queries (from Messaging/SPA) hit the aliases.

| Alias | Doc shape (key fields) | Source |
|-------|------------------------|--------|
| `messages` | `messageId, channelId, workspaceId, authorId, body, createdAt` | `jobs:index` |
| `files` | `assetId, workspaceId, fileName, contentType, ownerId, createdAt` | `jobs:index` |
| `canvas` | `documentId, workspaceId, name, textProjection, updatedAt` | `jobs:index` (if enabled) |

- Use index-per-alias with date or version suffix to allow zero-downtime reindex
  (`messages-v1` ← alias `messages`).
- Analyzer: standard + edge-ngram field for autocomplete on names/file names.
- Reindex is a maintenance job (manual trigger or a `jobs:index` `reindex` type).

---

## 5. Internal Design

### 5.1 Consumer loop (per stream)
1. `XREADGROUP GROUP worker {consumer} COUNT n BLOCK m STREAMS jobs:x >`.
2. For each entry: parse envelope, dispatch by `type`, run handler **idempotently** (keyed on
   `jobId`/natural key).
3. On success `XACK`. On handler exception, do **not** ack; increment `attempt` on reclaim.
4. Periodically `XAUTOCLAIM` stale pending entries (crashed consumers) past the visibility
   timeout. After `maxAttempts` (5), `XADD` to `jobs:x:dead` and `XACK` the original.

### 5.2 Write-back rule
Worker must not write to another service's primary tables directly. For results that must
update a service's DB (e.g. asset variants), call that service's internal endpoint
(`POST /assets/{id}/variants`) authenticated with a service token, or emit a result the owning
service consumes. ES and MinIO are shared infrastructure the Worker is authorized to write.
(See Asset Open Decisions.)

### 5.3 Scaling (KEDA)
`ScaledObject` with the Redis Streams scaler on `pendingEntriesCount` per stream; scale 0→N
on depth, scale to zero when idle (except a floor for latency-sensitive `jobs:notify`).

---

## 6. Configuration
Common vars (Conventions §8). Plus:

| Var | Notes |
|-----|-------|
| `Elasticsearch__Url` | ES endpoint. |
| `Worker__Streams` | Which streams this deployment consumes (allows specialised worker pools). |
| `Worker__MaxAttempts` | Default 5. |
| `Worker__VisibilityTimeoutSeconds` | Reclaim threshold. |
| `Worker__BatchSize` | `COUNT` per read. |
| `Retention__MessageDays` / `__AssetPendingHours` / etc. | Retention policy knobs. |
| `Notify__*` | Provider config for push/email. |

## 7. Cross-Cutting
No inbound auth (no business HTTP); uses a **service token** for outbound internal calls.
Trace continuity: read `traceId` from the job envelope and continue the span (Conventions §9).
Metrics: `jobs_processed_total{type,result}`, `jobs_dead_total{stream}`, handler duration
histograms, ES bulk latency.

## 8. Non-Functional & Limits
- Every handler idempotent and safe to retry.
- No user-facing latency contract except `jobs:notify` (target < 5 s p95).
- Back-pressure handled by stream depth + KEDA, never by dropping jobs.
- Poison messages land in `*:dead` for inspection, never block the stream.

## 9. Open Decisions
- **Specialised worker pools** (separate deployments per stream for independent scaling) vs.
  one deployment consuming all streams. Recommend splitting CPU-heavy (thumbnail/export) from
  IO-heavy (index/notify).
- Notification channels in scope for v1 (in-app only vs. push + email).
- Whether canvas search (`canvas` index) ships in v1 — depends on Canvas producing a text
  projection.
- Result write-back mechanism (internal endpoint vs. event) — align with Asset doc.
- Export rendering engine for canvas (headless renderer / server-side Yjs + skia) — non-trivial;
  may defer.
