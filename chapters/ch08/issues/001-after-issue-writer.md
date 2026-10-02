Issue: 1

# Issue 1 — Unread counts and read markers in the SPA

## Summary

The Messaging service already tracks how far each user has read in every channel they can
see, and reports an unread count on every channel (D31, built in `00a1e3c`, tested in
`f72b551`). The SPA ignores all of it. This work makes read state visible and keeps it
current:

- each channel in the sidebar shows how many messages the user hasn't read;
- reading a channel moves the user's marker, so the count clears — here and in the user's
  other tabs and devices;
- opening a channel with unread messages shows a "New messages" divider where the user left
  off.

## Services touched

**The SPA only** (`src/frontend`). No backend, chart, compose or script change. Read
`docs/design/06-frontend-spa.md` (§5.2 is the section this rewrites) and
`docs/design/02-messaging-service.md` §3.1.3, §3.1.7 and §3.2 for the server contract, which
this work consumes unchanged.

## What exists already

Do not change any of this.

- `GET /api/v1/channels` and `GET /api/v1/channels/{id}` return every `Channel` with
  `lastReadId: uuid | null` and `unreadCount: number`, both required. The count is exact,
  uncapped and computed by the server only — there is no unread endpoint.
- **Unread**, server-side: a message whose id is greater than `lastReadId` (or any, when it
  is null), written by someone other than the caller, and not deleted. The marked message
  itself is not unread.
- Socket `mark_read` `{ channelId, messageId }` (client→server, `/messaging`) acks
  `{ ok: true }`, or a 404 problem for a channel the caller can't see or a message not in
  it. The marker only moves forward; an older id is a successful no-op. A tombstone may be
  marked read. The ack is sent after the write commits.
- Server→client `read_receipt_updated` `{ channelId, userId, messageId }` goes to the room
  `user:{workspaceId}:{userId}` only, which every connection joins on connect. It is sent
  only when the marker moved, and never to the connection that sent the `mark_read`.
- `POST /api/v1/channels/{channel_id}/read` exists too. The SPA does not use it (decision 4).
- The OpenAPI document and `types/messaging.ts` already carry all of the above.
  `test/factories.ts`'s `aChannel()` defaults to `lastReadId: null, unreadCount: 0`; its ids
  are UUIDv4, so factory messages don't sort in time order.
- **No push for channels the user doesn't have open.** The SPA joins only the open
  channel's room, so `message_received` never arrives for other channels. Background counts
  come from refetching (R5).
- `MessageList` keeps `STICK_THRESHOLD` (80px) and scrolls to the newest message **only when
  the number of loaded messages grows**. It stays mounted across a channel switch when the
  next channel is cached.

## Requirements

1. **Sidebar badge.** Each channel whose `unreadCount` is above zero shows a count pill and
   a bold name. Counts above 99 display as `99+`. The open channel shows no badge while it
   is being read (R2); when it isn't — scrolled back, tab hidden — its badge shows as for any
   other channel.
2. **The read rule.** The open channel is *being read* while all three hold: the document is
   visible, the window has focus, and the message list **is** within `STICK_THRESHOLD` of the
   bottom — as measured, never assumed. Whenever it becomes true, and whenever a new message
   arrives while it is true, the SPA marks read up to the **newest non-pending message** in
   the loaded history: skipping optimistic `temp:` ids, including the user's own messages
   and tombstones.
3. **Sending the read.** Over the socket with `mark_read`, at most one emit per channel per
   second, the latest id winning (see *Timing*). Nothing is sent when the cached `lastReadId`
   is already at or past the id.
4. **No queue, no retry.** Nothing is sent while the socket is disconnected, and nothing is
   queued; on reconnect the rule is evaluated again and sends if it holds. An error ack or an
   ack timeout (5s) is ignored — no toast, no retry.
5. **Local update on read.** As the SPA emits `mark_read`, it writes `lastReadId` and
   `unreadCount: 0` for that channel into the cached list and detail directly — no refetch.
   A cached marker never moves backwards.
6. **Refreshing the counts.** The channel list refetches every 30 seconds while the tab is
   visible (none while hidden), when the window regains focus, on every socket connect, and
   on every channel switch. A refetch that fails keeps the list the sidebar already shows.
7. **Other tabs and devices.** On `read_receipt_updated` for the current user: if the
   channel's messages are cached and the event's `messageId` is at or after the newest
   cached one, write `lastReadId` and `unreadCount: 0` into the list and detail; otherwise
   refetch the list. Message ids are UUIDv7, so string order is time order.
8. **"New messages" divider.** When a channel is opened, capture its `lastReadId` once, and
   draw a divider above the first *loaded* message after it, by someone else, not deleted.
   Only messages that existed when the channel was opened can qualify. The divider stays
   where it is for the visit — as the marker moves, as messages arrive, and when its message
   is deleted (it stays above the tombstone) — and is gone when the user leaves and comes
   back. No divider when the captured id is null or nothing loaded qualifies; when the
   boundary is older than the loaded pages, none until scrolling back loads it.
9. **Accessibility and test hooks.** The badge has `aria-label="N unread messages"` — "1
   unread message" for one — with N as displayed. The divider is `role="separator"` named
   "New messages". Both carry a `data-testid` for the BDD page object, and the badge a
   `data-count` holding the number shown, as `has_reaction_count` does.

## Where the rules meet

- **A local read and a refetch (R5, R6, R7).** A list or detail fetch that started before the
  server moved the marker lands with the old count. Until the `mark_read` is acknowledged,
  such a fetch must not bring the badge back: the local read is re-applied to it. After the
  ack, fetches are taken as they come.
- **The divider and the SPA's own read (R8, R2).** The divider captures the marker the server
  holds at open, not one the SPA has just written: no read is sent for a channel until its
  divider has captured.
- **The divider and live messages (R8, R2).** A message that arrives while the user is in the
  channel never grows a divider, even in a channel read to the end.
- **The badge and a refetch (R1, R6).** A refetch that brings a count for the channel being
  read doesn't show its badge; the badge follows R1, not the count alone.
- **A pending read and leaving (R3).** A read still waiting in its window when the user
  switches channel or the page unmounts the list is sent then. On a socket change or a
  workspace switch it is dropped, never sent on the new connection.
- **Polling and failure (R6).** A failed background refetch keeps the sidebar; only a list
  that never loaded shows the error.

## Paths each rule holds on

| Path | What must be true |
|---|---|
| First open of a channel | the divider and the badge come from the server's marker |
| Return to a channel whose detail and history are cached | the divider waits for both refetches, so the marker is today's and messages that arrived while away sit above it; the list shows its newest message, and nothing is marked read until it is measured at the bottom |
| Switch from a channel scrolled back, to a cached one of the same length | the new channel is not marked read while the list sits mid-history |
| Switch while a read waits in its window | the read for the old channel is sent (R3) |
| Reconnect | the list refetches; the read rule is evaluated again and sends once |
| A second tab or device | its badge clears on the receipt, without a reload (R7) |
| Tab hidden, or window blurred with the tab visible | no read; no poll while hidden; one refetch on return |
| Workspace switch mid-window | the pending read is dropped |
| Scrolling back loads the page holding the boundary | the divider appears then, above the right message |

## What this assumes — check before building on it

- **TanStack Query 5's `refetchOnWindowFocus` listens to tab visibility only**, not window
  `focus` (checked, 5.101.4). An alt-tab back to a visible window needs its own listener.
- **Queries have no `staleTime`** (`main.tsx`), so a cached detail or history renders at once
  and refetches on mount: `isFetching` is already true on the first render.
- **The join ack refetches the channel's history** (`useChannelSocket.ts`), so a channel
  opened fresh can see its history fetched twice.
- **`document.hasFocus()` is false while devtools has focus**, so no read goes out then.
  Accepted.
- **The server's forward-only marker** makes a late or duplicate `mark_read` harmless.

## Timing

The throttle, per channel — leading and trailing, the window counted from each send:

```
t=0      target m2 → sent at once; a 1s window opens
t=500    targets m3, m4 → held; m4 is the latest
t=999    nothing sent
t=1000   m4 sent; a new window opens
t=1400   target m5 → held
t=2000   m5 sent; a new window opens
t=3000   nothing new asked → nothing sent; the window closes
```

A local read against a poll already in flight:

```
t0   poll GET starts; the server's count is 3
t1   Grace reads → count 0 in the caches, mark_read emitted
t2   the GET lands with count 3 → the local read is re-applied: the badge stays clear
t3   ack → later fetches are taken as they come
```

## Decided already

1. Scope is R1–R9. Everything in *Not in this issue* stays out.
2. Read means visible, focused and at the bottom — not merely open.
3. The marker target is the newest non-pending loaded message; the server's forward-only guard
   makes an older id harmless.
4. `mark_read` goes over the socket, as *Timing* shows. REST stays for other clients.
5. Badge: a pill, `99+` above 99, a bold name, hidden on the open channel only while it is
   being read; the singular label for one.
6. After a read, write the caches directly, as reactions do, and hold the write against older
   fetches until the ack.
7. The divider is fixed for the visit and follows the server's unread rule.
8. Background counts come from polling, not a push event. This keeps the work SPA-only, and
   the client never re-implements the unread rule.
9. No "new messages below" indicator in the open channel; its badge updates on the next
   refetch.
10. D31 (🟢) covers the data. This work settles no register entry and depends on no 🔴 one.
    The nearest: **D28** (no per-user setting, so no "don't mark read"), **D37** (a 401 on
    REST: a failed poll behaves as today), **D16** (a tombstone may be marked read and never
    qualifies for the divider).

Left to the plan, on purpose: how the local read is held, where the throttle lives, how the
divider's capture is kept, and how the list is brought to the bottom on a switch.

## Tests

- **Vitest** for everything below the journey: the read rule and each of its inputs, the
  throttle against *Timing* (fake timers), the no-op, disconnect and reconnect, cache writes
  and their hold, receipts both ways, the poll and its pause, the badge and `99+`, the
  divider's placement and its fixes, and the cached-switch path. Use `FakeSocket`, the MSW
  stubs, `aChannel()` / `aMessage()`, and `MessageList.test.tsx`'s `giveLayout()` for scroll.
- **One BDD journey** in a new `read_state.feature`: Ada posts in #random while Grace is
  elsewhere; Grace switches channel and sees the badge; she opens #random, leaves, reloads,
  and the badge stays clear. It relies on the channel-switch refetch, not the 30-second poll.
  It is the first journey to create several channels in a row, so its setup waits for each.

## Record in this slice

- Rewrite `docs/design/06-frontend-spa.md` §5.2: the read rule, the throttle, the hold,
  polling, receipts and the divider. Replace the bare "throttle `mark_read`" bullet.
- An ADR in `docs/adr/`: *unread state in the SPA polls rather than pushes*. Alternatives: a
  `channel_activity` event to the user room, joining every visible channel's room, refetching
  on focus only. Revisit when the 30-second lag or the list query's load becomes a problem —
  the fix is a push to the user room.
- Correct `docs/adr/260915-read-state-follows-channel-visibility.md` lines 96–99, which say
  the Postgres-only rules have no integration tests;
  `src/services/messaging/tests/integration/test_read_state.py` now covers them.

## Not in this issue

- **A live push for background channels** — a Messaging change; its own issue once polling
  proves too slow.
- **A "↓ N new messages" pill in the open channel** — client-side counting would duplicate
  the server's rule.
- **Opening a channel at the first unread message** — a scroll-model change.
- **An unread count in the tab title or favicon.**
- **A badge across workspaces** — out of scope in doc 06 §4; a token is scoped to one.
- **Mentions counts**, **"mark all as read"**, **DM-specific behaviour**, and **capping the
  count on the server** — none is specified or built on the server.

## Acceptance — first real run on Compose

With Ada and Grace in two browsers:
- Ada posts in a channel Grace isn't viewing: within 30 seconds, or at once when Grace
  switches channel or refocuses the window, Grace's sidebar shows the count.
- Grace opens it: the divider sits above Ada's first new message, and the badge clears. In
  Grace's second tab the badge clears too, without a reload.
- Grace scrolls back while Ada posts: the badge returns on the next refresh, and clears when
  Grace scrolls to the bottom.
- Grace scrolls back in #general, switches to #random (visited minutes ago, Ada has posted
  since): #random's badge stays until Grace is at its newest message.
- Grace alt-tabs away and back without hiding the tab: one list refetch, one read.

## References

- `docs/design/02-messaging-service.md` §3.1.3, §3.1.7, §3.2
- `docs/design/06-frontend-spa.md` §4, §5.2
- `docs/design/07-open-decisions-register.md` D31
- `docs/adr/260915-read-state-follows-channel-visibility.md`
- `docs/plans/ch07/02-read-markers-implementation-plan.md` — the backend slice
- Commit `c02dcd7` (message reactions) — the template for socket events, cache writers and
  their tests
