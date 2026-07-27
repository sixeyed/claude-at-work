# CollabHub — Messaging Service

> Channels, threads, messages, reactions, read receipts, and real-time delivery.
> Read [Platform Conventions](./00-platform-conventions.md) first.

**Status:** Draft · **Runtime:** .NET 10 / ASP.NET Core + SignalR
**Owns:** channels, membership, messages, threads, reactions, read receipts
**Depends on:** PostgreSQL (own DB), Redis Real-time (R2), Redis Cache (R1), Redis Streams (R3)

---

## 1. Purpose & Responsibilities

The chat half of CollabHub. Provides Slack-like channels and threaded messaging with
sub-second real-time delivery.

**Owns:** channels and their membership/permissions, messages, threads, reactions,
read receipts, typing indicators.
**Produces:** index jobs to `jobs:index` (R3) for Elasticsearch (consumed by Worker).
**Does NOT own:** search querying (read path goes to Elasticsearch directly or via a thin
search endpoint — see §3), file attachments (Asset Service owns blobs; messages reference asset IDs).

---

## 2. Runtime & Dependencies
- ASP.NET Core REST + a SignalR hub (`MessagingHub`) with the R2 backplane (Conventions §6).
- EF Core + Npgsql.
- StackExchange.Redis for R1 (hot data), R2 (backplane/pub-sub), R3 (index jobs).

---

## 3. Public Interface

### 3.1 REST (`/api/v1`)

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| GET | `/channels` | member | List channels visible to the user (cursor paginated). |
| POST | `/channels` | member | Create channel. |
| GET | `/channels/{id}` | channel member | Channel detail. |
| PATCH | `/channels/{id}` | channel admin | Rename / change topic / archive. |
| DELETE | `/channels/{id}` | channel admin | Soft-delete (archive). |
| GET | `/channels/{id}/members` | channel member | List members. |
| POST | `/channels/{id}/members` | channel admin | Add member(s). |
| DELETE | `/channels/{id}/members/{userId}` | channel admin | Remove member. |
| GET | `/channels/{id}/messages` | channel member | History, cursor paginated, newest-first. |
| POST | `/channels/{id}/messages` | channel member | Send message (REST fallback; prefer hub). |
| GET | `/messages/{id}` | channel member | Single message (+ thread root). |
| PATCH | `/messages/{id}` | author | Edit message. |
| DELETE | `/messages/{id}` | author or channel admin | Delete message. |
| GET | `/messages/{id}/thread` | channel member | Replies in a thread (cursor paginated). |
| POST | `/messages/{id}/reactions` | channel member | Add reaction `{ "emoji": ":+1:" }`. |
| DELETE | `/messages/{id}/reactions/{emoji}` | channel member | Remove own reaction. |
| POST | `/channels/{id}/read` | channel member | Mark read up to `{ "messageId": "..." }`. |
| GET | `/search/messages?q=` | member | Thin proxy to Elasticsearch (optional). |

`Message` DTO:
```json
{
  "id": "uuid", "channelId": "uuid", "authorId": "uuid",
  "threadRootId": "uuid|null", "body": "markdown text",
  "attachments": ["assetId", "..."],
  "reactions": [{ "emoji": ":+1:", "count": 3, "mine": true }],
  "createdAt": "...", "editedAt": "...|null", "deletedAt": "...|null"
}
```

### 3.2 SignalR Hub — `MessagingHub` (path `/hubs/messaging`)

**Client → Server**

| Method | Args | Effect |
|--------|------|--------|
| `JoinChannel(channelId)` | guid | Authorize + join group `channel:{id}`. |
| `LeaveChannel(channelId)` | guid | Leave group. |
| `SendMessage(channelId, body, threadRootId?, attachmentIds?)` | | Persist + broadcast. Returns the created `Message`. |
| `EditMessage(messageId, body)` | | Author-only edit + broadcast. |
| `DeleteMessage(messageId)` | | Author/admin delete + broadcast. |
| `AddReaction(messageId, emoji)` / `RemoveReaction(messageId, emoji)` | | Broadcast reaction change. |
| `MarkRead(channelId, messageId)` | | Update read receipt; broadcast to user's other sessions. |
| `Typing(channelId)` | | Ephemeral; fan out `UserTyping` (not persisted). |

**Server → Client (events)**

| Event | Payload |
|-------|---------|
| `MessageReceived` | `Message` |
| `MessageEdited` | `Message` |
| `MessageDeleted` | `{ messageId, channelId }` |
| `ReactionChanged` | `{ messageId, emoji, count, userId, added }` |
| `ReadReceiptUpdated` | `{ channelId, userId, messageId }` |
| `UserTyping` | `{ channelId, userId }` |

Groups and naming follow Conventions §6. Presence (online/away) is published to R2 and
mirrored to the Canvas service's presence as needed (shared R2).

---

## 4. Data Model (PostgreSQL)

```sql
CREATE TABLE channels (
    id           uuid PRIMARY KEY,
    workspace_id uuid NOT NULL,
    name         text NOT NULL,
    topic        text NULL,
    kind         text NOT NULL DEFAULT 'public',  -- public | private | dm
    created_by   uuid NOT NULL,
    created_at   timestamptz NOT NULL DEFAULT now(),
    updated_at   timestamptz NOT NULL DEFAULT now(),
    archived_at  timestamptz NULL,
    version      integer NOT NULL DEFAULT 0,
    UNIQUE (workspace_id, name) WHERE kind = 'public'
);

CREATE TABLE channel_members (
    channel_id   uuid NOT NULL REFERENCES channels(id),
    user_id      uuid NOT NULL,
    role         text NOT NULL DEFAULT 'member',  -- admin | member
    last_read_id uuid NULL,                        -- read receipt pointer
    joined_at    timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (channel_id, user_id)
);

CREATE TABLE messages (
    id             uuid PRIMARY KEY,                -- UUID v7 → time-ordered
    channel_id     uuid NOT NULL REFERENCES channels(id),
    author_id      uuid NOT NULL,
    thread_root_id uuid NULL REFERENCES messages(id), -- NULL = top-level
    body           text NOT NULL,
    attachments    uuid[] NOT NULL DEFAULT '{}',     -- Asset service IDs
    created_at     timestamptz NOT NULL DEFAULT now(),
    edited_at      timestamptz NULL,
    deleted_at     timestamptz NULL
);
CREATE INDEX ix_messages_channel_time ON messages (channel_id, id DESC) WHERE deleted_at IS NULL;
CREATE INDEX ix_messages_thread ON messages (thread_root_id, id) WHERE thread_root_id IS NOT NULL;

CREATE TABLE reactions (
    message_id   uuid NOT NULL REFERENCES messages(id),
    user_id      uuid NOT NULL,
    emoji        text NOT NULL,
    created_at   timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (message_id, user_id, emoji)
);
```

Threading is single-level: a reply sets `thread_root_id` to the top-level message; replies to
replies still point at the root. Read state is a per-member pointer (`last_read_id`); unread
counts are derived (messages with `id > last_read_id`).

### 4.1 Redis usage
- **R1:** cache channel membership sets and recent-message windows for fast hub authorization.
- **R2:** SignalR backplane + presence pub/sub.
- **R3:** `jobs:index` — one job per created/edited/deleted message for ES sync.

---

## 5. Internal Design — Send Message
Mirrors the architecture's sequence diagram:
1. Client calls `SendMessage` on the hub.
2. Persist to `messages` (PostgreSQL).
3. Broadcast `MessageReceived` to `channel:{id}` via R2 backplane.
4. `XADD jobs:index` with payload `{ messageId, op: "upsert" }`.
5. Worker consumes and indexes into Elasticsearch (Worker doc owns the mapping).

Edits/deletes follow the same persist → broadcast → enqueue(`op: upsert|delete`) pattern.

---

## 6. Configuration
Common vars (Conventions §8): owns `ConnectionStrings__Postgres`, uses `Redis__Cache`,
`Redis__Realtime`, `Redis__Streams`. Plus `Messaging__MaxBodyChars` (default 8000),
`Messaging__MaxAttachments` (default 10).

## 7. Cross-Cutting
Auth, errors, pagination, observability, health per Conventions. Metrics:
`messages_sent_total`, `messages_edited_total`, `reactions_total`, hub connection gauge.

## 8. Non-Functional & Limits
- Real-time delivery p99 < 500 ms end-to-end.
- Max message body 8000 chars; max 10 attachments; emoji from an allow-list.
- History reads served from Postgres; full-text from Elasticsearch.

## 9. Open Decisions
- Threading depth: single-level (assumed) vs. nested.
- DM modelling: as `kind='dm'` channels (assumed) vs. separate table.
- Whether `/search/messages` lives here (thin proxy) or clients query a dedicated search gateway.
- Edit/delete windows and tombstone retention policy (coordinate with Worker retention jobs).
