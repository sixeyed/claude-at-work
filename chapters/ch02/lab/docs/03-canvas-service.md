# CollabHub — Canvas Service

> Collaborative design documents: Yjs CRDT relay, presence, and snapshot persistence.
> Read [Platform Conventions](./00-platform-conventions.md) first.

**Status:** Draft · **Runtime:** .NET 10 / ASP.NET Core + SignalR
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
- ASP.NET Core REST (metadata + lifecycle) + SignalR hub (`CanvasHub`) on the R2 backplane.
- EF Core + Npgsql; Yjs state stored as `bytea`/JSONB (see §4).
- StackExchange.Redis: R2 (relay backplane + awareness), R1 (active-doc cache).
- The server treats Yjs updates as opaque `byte[]`. It does **not** need a server-side Yjs
  implementation for correctness; an optional server-side `Ydotnet`/`y-crdt` binding may be
  used only to compute compacted snapshots (see Open Decisions).

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

### 3.2 SignalR Hub — `CanvasHub` (path `/hubs/canvas`)

The sync protocol mirrors the Yjs sync protocol carried over SignalR. All update payloads are
`byte[]` (Yjs binary), opaque to the server.

**Client → Server**

| Method | Args | Effect |
|--------|------|--------|
| `JoinDocument(documentId)` | guid | Authorize, join groups `doc:{id}` + `presence:{id}`. Server responds with `SyncStep1` (its state vector). |
| `SyncStep1(documentId, stateVector)` | guid, byte[] | Client/server exchange of state vectors; server replies `SyncStep2` with the diff it holds. |
| `SyncUpdate(documentId, update)` | guid, byte[] | Broadcast a Yjs update to others in `doc:{id}` and buffer it for snapshotting. |
| `AwarenessUpdate(documentId, awareness)` | guid, byte[] | Cursor/selection/presence; fan out to `presence:{id}`; **not persisted**. |
| `LeaveDocument(documentId)` | guid | Leave groups; emit awareness removal. |

**Server → Client (events)**

| Event | Payload | Notes |
|-------|---------|-------|
| `SyncStep1` | `byte[]` (state vector) | Sent on join so the client can compute its diff. |
| `SyncStep2` | `byte[]` (update) | The server's buffered/persisted state as a Yjs update. |
| `Update` | `byte[]` | A peer's `SyncUpdate`, relayed. |
| `AwarenessUpdate` | `byte[]` | A peer's awareness, relayed. |
| `PeerLeft` | `{ userId }` | For clearing remote cursors. |

**Join sequence:** client `JoinDocument` → server `SyncStep1` → client `SyncStep1`/`SyncStep2`
exchange → steady state where `SyncUpdate`/`Update` flow both ways. New updates are relayed via
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
- **R2:** SignalR backplane for relaying `Update`/`AwarenessUpdate`; awareness is ephemeral
  and lives only in R2/in-memory, never Postgres.
- **R1:** cache of the active document's latest state vector + recent updates to serve fast
  `SyncStep1`/`SyncStep2` without a Postgres round-trip while a doc is "hot".

---

## 5. Internal Design — Edit & Snapshot
Mirrors the architecture's sequence diagram:
1. Client A emits `SyncUpdate(documentId, update)`.
2. Server relays via R2 to `doc:{id}`; other clients receive `Update`.
3. Server buffers the update (and, in strategy b, appends to `document_updates`).
4. **Snapshot trigger** — whichever comes first: every N seconds (default 10) of activity, or
   every M buffered updates (default 200), or on last-editor-leaves. Server folds buffered
   updates into `document_state.yjs_state`, refreshes `state_vector`, bumps `update_seq`.
5. On cold start / first joiner, load `yjs_state` (+ replay `document_updates` for strategy b)
   to seed the relay.

Snapshotting requires applying Yjs updates server-side; either compute it with a y-crdt .NET
binding, or store the latest full state the client sends on a debounce. (Open Decision.)

---

## 6. Configuration
Common vars (Conventions §8). Plus `Canvas__SnapshotIntervalSeconds` (10),
`Canvas__SnapshotEveryUpdates` (200), `Canvas__MaxDocBytes` (e.g. 25 MB),
`Canvas__AwarenessTimeoutSeconds` (30).

## 7. Cross-Cutting
Auth on the hub connection per Conventions §6 (`access_token` query string). Errors, health,
observability per Conventions. Metrics: `canvas_updates_relayed_total`,
`canvas_snapshots_total`, `canvas_active_docs` gauge, `canvas_awareness_msgs_total`.

## 8. Non-Functional & Limits
- Update relay p99 < 500 ms.
- Max document size cap (`Canvas__MaxDocBytes`) enforced on snapshot.
- Awareness is best-effort and lossy by design; updates are not.
- No update is acknowledged to a peer until relayed; persistence is async to keep latency low,
  but the append log (strategy b) prevents data loss between snapshots.

## 9. Open Decisions
- **Storage strategy:** (a) snapshot-only with periodic client-driven full state, vs.
  (b) snapshot + append log replayed on recovery (stronger durability). Recommend (b).
- **Server-side Yjs:** use a y-crdt .NET binding to compute snapshots server-side, vs. trust a
  debounced full-state push from a designated client. Affects correctness on crash.
- **JSONB vs bytea** for `yjs_state` (architecture says JSONB; binary suggests bytea + optional
  derived JSONB for search).
- Whether canvas content is indexed in Elasticsearch (the architecture lists "canvas content"
  under search) — requires a derived text projection produced by the Worker.
