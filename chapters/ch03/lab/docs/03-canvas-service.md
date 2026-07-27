# CollabHub — Canvas Service

> Collaborative design documents: Yjs CRDT relay, presence, and snapshot persistence.
> Read [Platform Conventions](./00-platform-conventions.md) first.

**Status:** Draft · **Runtime:** Python 3.12 / FastAPI + Socket.IO
**Owns:** documents, document membership/permissions, snapshot persistence
**Depends on:** PostgreSQL (own DB), Redis Real-time (R2), Redis Cache (R1)

---

## 1. Purpose & Responsibilities

The Figma-like half of CollabHub. Hosts real-time, conflict-free collaborative editing of
design documents.

**Critical design point:** the **CRDT merge logic lives entirely in the Yjs client library**.
This service is a **relay + persistence layer**, not a merge engine. It moves opaque Yjs
binary updates between clients and periodically snapshots document state to Postgres. It does
not interpret or merge the document's internal structure.

**Owns:** document metadata, membership/permissions, persisted Yjs state (snapshots),
awareness/presence routing.
**Does NOT own:** the document's semantic structure (layers/components live inside the Yjs
doc, opaque to the backend), thumbnails/exports (Asset + Worker), font/image blobs (Asset).

---

## 2. Runtime & Dependencies
- FastAPI REST (metadata + lifecycle) + a Socket.IO server on the `/canvas` namespace, on
  the R2 backplane. Both run on one Uvicorn process.
- SQLAlchemy 2.0 (async) + asyncpg; Yjs state stored as `bytea`/JSONB (see §4). Alembic migrations.
- `redis-py` (`redis.asyncio`): R2 (relay backplane + awareness), R1 (active-doc cache).
- The server treats Yjs updates as opaque `bytes`. It does **not** need a server-side Yjs
  implementation for correctness; an optional server-side **`pycrdt`** (y-crdt Python binding)
  may be used only to compute compacted snapshots (see Open Decisions).

---

## 3. Public Interface

### 3.1 REST (`/api/v1`)

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| GET | `/documents` | member | List documents the user can access. |
| POST | `/documents` | member | Create document (empty Yjs doc). |
| GET | `/documents/{id}` | doc viewer | Metadata (name, owner, updatedAt, members). |
| PATCH | `/documents/{id}` | doc editor | Rename / move / change visibility. |
| DELETE | `/documents/{id}` | doc owner | Soft-delete. |
| GET | `/documents/{id}/snapshot` | doc viewer | Latest persisted Yjs state (binary) for initial load over REST. |
| GET | `/documents/{id}/members` | doc viewer | Membership + roles. |
| POST | `/documents/{id}/members` | doc owner/editor | Share with a user/role. |
| DELETE | `/documents/{id}/members/{userId}` | doc owner | Unshare. |
| POST | `/documents/{id}/export` | doc viewer | Enqueue export job (PNG/SVG/PDF) → returns job id. |

### 3.2 Socket.IO namespace — `/canvas`

The sync protocol mirrors the Yjs sync protocol carried over Socket.IO. All update payloads
are `bytes` (Yjs binary), opaque to the server. These event names follow the Yjs sync
protocol rather than the generic verb/past-tense convention.

**Client → Server**

| Event | Args | Effect |
|--------|------|--------|
| `join_document` | documentId | Authorize, join rooms `doc:{id}` + `presence:{id}`. Server responds with `sync_step1` (its state vector). |
| `sync_step1` | documentId, bytes | Client/server exchange of state vectors; server replies `sync_step2` with the diff it holds. |
| `sync_update` | documentId, bytes | Broadcast a Yjs update to others in `doc:{id}` and buffer it for snapshotting. |
| `awareness_update` | documentId, bytes | Cursor/selection/presence; fan out to `presence:{id}`; **not persisted**. |
| `leave_document` | documentId | Leave rooms; emit awareness removal. |

**Server → Client (events)**

| Event | Payload | Notes |
|-------|---------|-------|
| `sync_step1` | `bytes` (state vector) | Sent on join so the client can compute its diff. |
| `sync_step2` | `bytes` (update) | The server's buffered/persisted state as a Yjs update. |
| `update` | `bytes` | A peer's `sync_update`, relayed. |
| `awareness_update` | `bytes` | A peer's awareness, relayed. |
| `peer_left` | `{ userId }` | For clearing remote cursors. |

**Join sequence:** client `join_document` → server `sync_step1` → client `sync_step1`/`sync_step2`
exchange → steady state where `sync_update`/`update` flow both ways. New updates are relayed via
the R2 backplane so any pod can serve any client.

---

## 4. Data Model (PostgreSQL)

```sql
CREATE TABLE documents (
    id            uuid PRIMARY KEY,
    workspace_id  uuid NOT NULL,
    name          text NOT NULL,
    owner_id      uuid NOT NULL,
    visibility    text NOT NULL DEFAULT 'private',  -- private | workspace | link
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now(),
    deleted_at    timestamptz NULL,
    version       integer NOT NULL DEFAULT 0
);

CREATE TABLE document_members (
    document_id   uuid NOT NULL REFERENCES documents(id),
    user_id       uuid NOT NULL,
    role          text NOT NULL DEFAULT 'editor',   -- owner | editor | viewer
    PRIMARY KEY (document_id, user_id)
);

-- Persisted Yjs state. Two viable storage strategies (pick one — see Open Decisions):
--  (a) latest compacted snapshot only
--  (b) snapshot + an append log of updates since the snapshot
CREATE TABLE document_state (
    document_id   uuid PRIMARY KEY REFERENCES documents(id),
    yjs_state     bytea NOT NULL,            -- compacted Yjs document (binary)
    state_vector  bytea NOT NULL,            -- for fast SyncStep1
    snapshot_at   timestamptz NOT NULL DEFAULT now(),
    update_seq    bigint NOT NULL DEFAULT 0  -- updates folded into this snapshot
);

-- Optional append log (strategy b): durable between snapshots, replayed on recovery.
CREATE TABLE document_updates (
    document_id   uuid NOT NULL REFERENCES documents(id),
    seq           bigint NOT NULL,
    update        bytea NOT NULL,
    created_at    timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (document_id, seq)
);
```

> The architecture mentions storing canvas docs as **JSONB**. Yjs state is binary, so `bytea`
> is the natural fit; a JSONB column can hold a *derived, human-readable* representation for
> search indexing if needed. Confirm in Open Decisions.

### 4.1 Redis usage
- **R2:** Socket.IO backplane for relaying `update`/`awareness_update`; awareness is ephemeral
  and lives only in R2/in-memory, never Postgres.
- **R1:** cache of the active document's latest state vector + recent updates to serve fast
  `sync_step1`/`sync_step2` without a Postgres round-trip while a doc is "hot".

---

## 5. Internal Design — Edit & Snapshot
Mirrors the architecture's sequence diagram:
1. Client A emits `sync_update(documentId, update)`.
2. Server relays via R2 to room `doc:{id}`; other clients receive `update`.
3. Server buffers the update (and, in strategy b, appends to `document_updates`).
4. **Snapshot trigger** — whichever comes first: every N seconds (default 10) of activity, or
   every M buffered updates (default 200), or on last-editor-leaves. Server folds buffered
   updates into `document_state.yjs_state`, refreshes `state_vector`, bumps `update_seq`.
5. On cold start / first joiner, load `yjs_state` (+ replay `document_updates` for strategy b)
   to seed the relay.

Snapshotting requires applying Yjs updates server-side; either compute it with the `pycrdt`
(y-crdt) binding, or store the latest full state the client sends on a debounce. (Open Decision.)

---

## 6. Configuration
Common vars (Conventions §8). Plus `CANVAS_SNAPSHOT_INTERVAL_SECONDS` (10),
`CANVAS_SNAPSHOT_EVERY_UPDATES` (200), `CANVAS_MAX_DOC_BYTES` (e.g. 25 MB),
`CANVAS_AWARENESS_TIMEOUT_SECONDS` (30).

## 7. Cross-Cutting
Auth on the Socket.IO connection per Conventions §6 (handshake `auth` payload). Errors, health,
observability per Conventions. Metrics: `canvas_updates_relayed_total`,
`canvas_snapshots_total`, `canvas_active_docs` gauge, `canvas_awareness_msgs_total`.

## 8. Non-Functional & Limits
- Update relay p99 < 500 ms.
- Max document size cap (`CANVAS_MAX_DOC_BYTES`) enforced on snapshot.
- Awareness is best-effort and lossy by design; updates are not.
- No update is acknowledged to a peer until relayed; persistence is async to keep latency low,
  but the append log (strategy b) prevents data loss between snapshots.

## 9. Open Decisions
- **Storage strategy:** (a) snapshot-only with periodic client-driven full state, vs.
  (b) snapshot + append log replayed on recovery (stronger durability). Recommend (b).
- **Server-side Yjs:** use the `pycrdt` (y-crdt) binding to compute snapshots server-side, vs.
  trust a debounced full-state push from a designated client. Affects correctness on crash.
- **JSONB vs bytea** for `yjs_state` (architecture says JSONB; binary suggests bytea + optional
  derived JSONB for search).
- Whether canvas content is indexed in Elasticsearch (the architecture lists "canvas content"
  under search) — requires a derived text projection produced by the Worker.
