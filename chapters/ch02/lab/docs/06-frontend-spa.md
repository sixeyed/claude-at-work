# CollabHub — Frontend SPA

> React + TypeScript single-page app: chat, collaborative canvas, presence.
> Read [Platform Conventions](./00-platform-conventions.md) first.

**Status:** Draft · **Stack:** React + TypeScript (Vite) · React Native / PWA path for mobile
**Talks to:** Auth, Messaging, Canvas, Asset services (REST + SignalR), MinIO (direct uploads)

---

## 1. Purpose & Responsibilities

The single client application. Combines a Slack-like chat experience and a Figma-like
collaborative canvas in one app. Communicates over **REST** for standard CRUD and **SignalR**
for all real-time interactions; runs the **Yjs CRDT** locally for the canvas (the backend is a
relay — Canvas doc §1).

**Owns:** all UI, client-side CRDT state, optimistic updates, presence rendering, the OIDC
login flow (PKCE), and direct-to-MinIO uploads.
**Does NOT own:** merge conflict resolution beyond what Yjs provides; any persistence
(everything authoritative lives server-side).

---

## 2. Tech & Key Libraries

| Concern | Choice | Notes |
|---------|--------|-------|
| Framework | React 18+ + TypeScript | |
| Build | Vite | Fast dev, PWA plugin for the mobile path. |
| Routing | React Router | |
| Server state / data fetching | TanStack Query | Caching, mutations, optimistic updates over REST. |
| Client/UI state | Zustand (or Redux Toolkit) | Lightweight global state (current user, presence). |
| Real-time | `@microsoft/signalr` | Two hub connections: messaging + canvas. |
| CRDT | `yjs` + a SignalR provider (custom, see §5.3) | Canvas document state. |
| Canvas rendering | `react-konva` / `pixi.js` / custom WebGL | Pick per perf needs (Open Decision). |
| Auth | `oidc-client-ts` | Authorization Code + PKCE against Auth service. |
| Forms / validation | React Hook Form + Zod | Zod schemas mirror `CollabHub.Shared.Contracts`. |
| Styling | (team choice) Tailwind / CSS Modules | |

---

## 3. App Structure

```
/src
  /app            # bootstrap, providers, router
  /lib
    /api          # typed REST clients per service (generated from OpenAPI ideally)
    /realtime     # SignalR connection managers (messaging, canvas)
    /auth         # OIDC client, token storage, refresh, auth guard
    /yjs          # Yjs doc factory + SignalR sync provider
  /features
    /channels     # channel list, channel view, composer
    /threads
    /canvas       # document view, toolbar, layers, cursors
    /presence     # online users, live cursors, awareness
    /assets       # upload widget, image/file rendering
  /components      # shared UI
  /types           # shared DTO types (mirrors Shared.Contracts)
```

---

## 4. Auth Flow (OIDC + PKCE)

1. Unauthenticated → redirect to Auth service `/auth/login/{provider}`.
2. After provider callback, the SPA receives an auth code at its redirect URI.
3. SPA exchanges code + PKCE verifier at `POST /auth/token` → access + refresh tokens.
4. **Token storage:** access token in memory; refresh token in an HttpOnly cookie if the
   deployment supports same-site cookies, else secure storage (Open Decision — avoid
   localStorage for refresh tokens).
5. An Axios/fetch interceptor attaches `Authorization: Bearer`; on 401 it calls `/auth/refresh`
   once (rotation) and retries, else routes to login.
6. SignalR connections pass the access token via the `accessTokenFactory` (sent as the
   `access_token` query param per Conventions §6) and re-acquire on reconnect.

---

## 5. Real-Time Integration

### 5.1 Connection management
Two long-lived `HubConnection`s — `/hubs/messaging` and `/hubs/canvas` — created lazily,
with automatic reconnect (exponential backoff). On reconnect, re-join the groups/documents the
user was in and re-sync. A single shared "connection state" surfaces offline/reconnecting UI.

### 5.2 Messaging
- On entering a channel: `JoinChannel(channelId)`; load history via REST
  `GET /channels/{id}/messages` (cursor paginated, newest-first) and merge.
- Send via hub `SendMessage`; render **optimistically** with a temp id, reconcile on the
  returned `Message` / `MessageReceived`.
- Subscribe to `MessageReceived/Edited/Deleted`, `ReactionChanged`, `ReadReceiptUpdated`,
  `UserTyping` and update TanStack Query caches.
- Debounce `Typing`; throttle `MarkRead`.

### 5.3 Canvas (Yjs over SignalR)
- One `Y.Doc` per open document. A **custom SignalR provider** bridges Yjs ↔ `CanvasHub`:
  - On `JoinDocument`, perform the sync handshake (`SyncStep1`/`SyncStep2`, Canvas doc §3.2),
    feeding the server's state into the local `Y.Doc`.
  - Local Yjs `update` events → `SyncUpdate(documentId, update)`.
  - Incoming `Update` → `Y.applyUpdate(doc, update)`.
  - Yjs **awareness** (cursor, selection, user color) → `AwarenessUpdate`; incoming awareness
    renders remote cursors; `PeerLeft` clears them.
- Initial load may also use REST `GET /documents/{id}/snapshot` to seed before the hub
  handshake on slow connections.
- The renderer subscribes to the `Y.Doc` and redraws on change; all editing mutates the
  `Y.Doc`, never local-only state.

---

## 6. Assets (direct upload)
1. `POST /assets/upload-url` → presigned PUT.
2. `PUT` the file bytes **directly to MinIO** (show progress).
3. `POST /assets/{id}/confirm`.
4. Reference the returned `assetId` in a message (`attachments`) or canvas image node.
5. Render via `GET /assets/{id}/download-url` / `thumbnail-url` (short-lived URLs; refetch on
   expiry).

---

## 7. Cross-Cutting
- **Error handling:** parse RFC 7807 Problem Details (Conventions §4.2) into typed UI errors;
  show `errors` map on forms.
- **Offline / reconnect:** queue outgoing chat sends while disconnected; Yjs naturally
  reconciles canvas edits on reconnect.
- **Observability:** browser OTel SDK → collector; propagate `traceparent` on REST calls so
  traces stitch across SPA → service → worker.
- **Accessibility & i18n:** plan from the start (Open Decision on i18n lib).

## 8. Non-Functional & Limits
- First meaningful paint and channel-switch should feel instant (optimistic + cached).
- Canvas target 60 fps with N live cursors; throttle awareness broadcasts (~30–60 ms).
- Respect server limits (message length, attachment count/size) client-side before sending.
- PWA/offline shell for the mobile path; service worker caches the app shell, not data.

## 9. Open Decisions
- **React Native vs. PWA** for mobile — separate codebase vs. shared (the architecture lists
  both). Affects how much of `/lib` is platform-agnostic.
- **Canvas renderer:** Konva (DOM/2D, simpler) vs. PixiJS/WebGL (perf) vs. custom. Driven by
  expected document complexity.
- **Refresh-token storage:** HttpOnly cookie vs. in-app secure storage.
- **Typed clients:** generate REST clients + types from each service's OpenAPI doc vs.
  hand-write against `Shared.Contracts`. Recommend generated.
- State manager choice (Zustand vs. Redux Toolkit).
