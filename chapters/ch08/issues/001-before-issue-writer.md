# Issue 1 — Unread counts and read markers in the SPA

## Summary

The Messaging service already tracks how far each user has read in every channel
they can see, and reports an unread count on every channel (D31, built in
`00a1e3c`, tested in `f72b551`). The SPA ignores all of it. This work makes read
state visible and keeps it current:

- each channel in the sidebar shows how many messages the user hasn't read;
- reading a channel moves the user's marker, so the count clears — here and in
  the user's other tabs and devices;
- opening a channel with unread messages shows a "New messages" divider where
  the user left off.

## Services touched

**The SPA only** (`src/frontend`). No backend, chart, compose or script change.
Read `docs/design/06-frontend-spa.md` (§5.2 is the section this rewrites) and
`docs/design/02-messaging-service.md` §3.1.3, §3.1.7 and §3.2 for the server
contract, which this work consumes unchanged.

## What the backend already provides

Do not change any of this. It is here so the plan starts from the right shapes.

- `GET /api/v1/channels` and `GET /api/v1/channels/{id}` return every `Channel`
  with `lastReadId: uuid | null` and `unreadCount: number`, both required. The
  count is exact and uncapped. It is computed by the server only — there is no
  separate unread endpoint.
- **Unread**, server-side, means a message whose id is greater than
  `lastReadId` (or any, when it is null), written by someone other than the
  caller, and not deleted. The marked message itself is not unread.
- Socket event `mark_read` `{ channelId, messageId }` (client→server, namespace
  `/messaging`) acks `{ ok: true }`, or an error ack (404 problem for a channel
  the caller can't see or a message not in it). The marker only moves forward;
  an older id is a successful no-op. A tombstone may be marked read.
- Server→client `read_receipt_updated` `{ channelId, userId, messageId }` goes to
  the room `user:{workspaceId}:{userId}` only, which every connection joins on
  connect. It is sent only when the marker moved, and never to the connection
  that sent the `mark_read`.
- `POST /api/v1/channels/{channel_id}/read` `{ messageId }` → 204 exists too. The
  SPA does not use it (decision 4).
- `src/frontend/openapi/messaging.json` and `src/frontend/src/types/messaging.ts`
  already carry all of the above; `test/factories.ts` `aChannel()` defaults to
  `lastReadId: null, unreadCount: 0`. No regeneration is needed.
- **There is no push for activity in channels the user doesn't have open.** The
  SPA joins only the open channel's room, so `message_received` never arrives
  for other channels. Background counts come from refetching (requirement 5).

## Requirements

1. **Sidebar badge.** Each channel in `ChannelList` whose `unreadCount` is above
   zero shows a count pill and a bold name. Counts above 99 display as `99+`.
   The open channel shows no badge while it is being read (requirement 2); if
   the user is scrolled back in it, its badge shows as for any other channel.
2. **The read rule.** The open channel is *being read* while all three hold:
   the document is visible, the window has focus, and the message list is
   scrolled to within the existing `STICK_THRESHOLD` (80px) of the bottom.
   Whenever it becomes true, and whenever a new message arrives while it is
   true, the SPA marks read up to the **newest non-pending message** in the
   loaded history — skipping optimistic `temp:` ids, but including the user's
   own messages and tombstones.
3. **Sending the read.** Over the socket with `mark_read`, throttled to at most
   one emit per channel per second; when the throttle window ends it sends the
   *latest* id, not the first. It sends nothing when the id equals the cached
   `lastReadId`. It sends nothing while the socket is disconnected and queues
   nothing; on reconnect it re-evaluates the rule and sends if it holds. An
   error ack or an ack timeout is ignored — no toast, no retry.
4. **Local update on read.** As the SPA emits `mark_read`, it writes
   `lastReadId` and `unreadCount: 0` for that channel into the cached channel
   list and the cached channel detail directly — no refetch.
5. **Refreshing the counts.** The channel list query refetches every 30 seconds
   while the tab is visible (paused when hidden — `refetchIntervalInBackground:
   false`), on window focus, on socket reconnect, and on every channel switch.
6. **Other tabs and devices.** On `read_receipt_updated` for the current user:
   if messages for that channel are cached and the event's `messageId` is at or
   after the newest cached message, write `lastReadId` and `unreadCount: 0` into
   the list and detail caches; otherwise invalidate the channel list. Message
   ids are UUIDv7, so comparing them as strings compares them in time order.
7. **"New messages" divider.** When a channel is opened, capture its
   `lastReadId` once. Render a divider above the first *loaded* message whose id
   is greater than that captured id, written by someone else, and not deleted.
   The divider stays where it is while the user remains in the channel, even as
   the marker moves on, and is gone when they leave and come back. No divider
   when the captured id is null, or no loaded message qualifies — including when
   the boundary is older than the loaded pages; it appears once scrolling back
   loads it.
8. **Accessibility and test hooks.** The badge has
   `aria-label="N unread messages"` (N as displayed, so `99+`). The divider is
   `role="separator"` with the accessible name "New messages". Both carry a
   `data-testid` for the BDD page object, and the badge a `data-count` holding
   the number shown — the pattern `has_reaction_count` uses.

## Decided already

1. Scope is requirements 1–8. Everything in *Not in this issue* stays out.
2. Read means visible, focused and at the bottom — not merely open.
3. The marker target is the newest non-pending loaded message; the server's
   forward-only guard makes an older id harmless.
4. `mark_read` goes over the socket, throttled to 1 per second per channel,
   trailing edge. REST stays for other clients.
5. Badge: count pill, `99+` above 99, bold name; hidden on the open channel
   only while it is being read.
6. After a read, write the caches directly, as reactions do.
7. The divider is fixed at open-time and follows the server's unread rule.
8. Background counts come from polling (30s, visible tabs only, plus focus,
   reconnect and channel switch), not from a push event. This keeps the work
   SPA-only and means the client never re-implements the unread rule.
9. No "new messages below" indicator in the open channel; its badge updates on
   the next refetch.
10. D31 (🟢) covers the data. This work settles no register entry and depends on
    no 🔴 one.

## Tests

- **Vitest** for everything below the journey: the read rule (visibility, focus,
  scroll), throttling and the trailing id (fake timers), the no-op when the id
  is unchanged, disconnect/reconnect, cache writes on read and on
  `read_receipt_updated` (both branches), the poll interval and its pause when
  hidden, badge display and `99+`, and divider placement (own messages,
  tombstones, null marker, boundary not loaded). Use the existing helpers —
  `FakeSocket`, the MSW `messaging` stubs, `aChannel()` / `aMessage()`, and
  `MessageList.test.tsx`'s `giveLayout()` for scroll.
- **One BDD journey** in `tests/bdd` (new `read_state.feature`):
  Grace is in #general. Ada posts in #random. Grace switches to #dev and sees an
  unread badge on #random. Grace opens #random and the badge clears. This relies
  on the channel-switch refetch, not the 30-second poll, so it needs no long
  wait.

## Record in this slice

- Rewrite `docs/design/06-frontend-spa.md` §5.2 to state the rules above: the
  read rule, the throttle, polling for counts, receipt handling and the divider.
  Replace the bare "throttle `mark_read`" bullet.
- An ADR in `docs/adr/`: *unread state in the SPA polls rather than pushes*.
  Alternatives: a `channel_activity` event to the user room (fan-out per
  message to every viewer of a public channel), joining every visible channel's
  room, refetching on focus only. Revisit when the 30-second lag or the list
  query's load becomes a problem — the fix is a push event to the user room.
- Correct `docs/adr/260915-read-state-follows-channel-visibility.md` lines
  94–99, which say the Postgres-only rules have no integration tests;
  `src/services/messaging/tests/integration/test_read_state.py` now covers them.

## Not in this issue

- **A live push for background channels** — a backend change to Messaging; its
  own issue once polling proves too slow.
- **A "↓ N new messages" pill in the open channel** — needs client-side counting,
  which duplicates the server's unread rule.
- **Opening a channel at the first unread message** — history would have to load
  around the marker instead of from the newest message; a scroll-model change.
- **An unread count in the browser tab title or favicon.**
- **An unread badge across all workspaces** — out of scope in doc 06 §4; a token
  is scoped to one workspace.
- **Mentions counts** — not specified or built on the server.
- **"Mark all as read"** — no server support.
- **DM-specific behaviour** — DMs can't be created yet.
- **Capping the count on the server** — deferred in the D31 ADR; the SPA caps
  only the display.

## Acceptance — first real run on Compose

With two users signed in in different browsers:
- Ada posts in a channel Grace isn't viewing; within 30 seconds, or at once when
  Grace switches channel or refocuses the tab, Grace's sidebar shows the count.
- Grace opens it: the divider sits above Ada's first new message, and the badge
  clears. In a second tab of Grace's, the badge clears too without a reload.
- Grace scrolls back while Ada posts again: the badge returns on the next
  refresh, and clears when Grace scrolls to the bottom.

## References

- `docs/design/02-messaging-service.md` §3.1.3, §3.1.7, §3.2
- `docs/design/06-frontend-spa.md` §4, §5.2
- `docs/design/07-open-decisions-register.md` D31
- `docs/adr/260915-read-state-follows-channel-visibility.md`
- `docs/plans/ch07/02-read-markers-implementation-plan.md` — the backend slice
- Commit `c02dcd7` (message reactions) — the nearest template for socket events,
  cache writers and their tests in the SPA
