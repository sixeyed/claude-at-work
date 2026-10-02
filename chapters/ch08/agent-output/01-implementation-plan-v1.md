# Unread counts and read markers in the SPA — implementation plan

> **For agentic workers:** this plan is executed by `scripts/deliver.sh`: the test-writer does every
> RED task, the code-writer every GREEN one. Three project rules override the superpowers skills.
> **Never commit** — every task ends with the worktree dirty. **Red first** — no production code
> until the test-reviewer has approved the failing tests. **Plans live in `docs/plans/`.**

**Goal:** The sidebar shows how many messages each channel holds that the user hasn't read. Reading a
channel clears that count, here and in the user's other tabs. Opening a channel the user had fallen
behind in shows a "New messages" divider.

**Architecture:** SPA only; Messaging's read-state contract is consumed unchanged. Pure rules live
in `readState.ts`. `useMarkRead`, called in `MessageList`, runs the read rule and sends `mark_read`
through a per-socket throttle, then writes the list and detail caches. Zustand's `readingChannelId`
tells `ChannelList` which badge to hide. Background counts come from refetching the channel list:
a 30-second poll while the tab is visible, plus refetches on focus, connect and channel switch.

**Tech Stack:** React 19, TypeScript, TanStack Query 5, Zustand 5, socket.io-client 4, Tailwind v4 ·
Vitest 5 + MSW 2 + Testing Library · pytest-bdd 8 + Playwright (sync).

**Issue:** `docs/plans/issue-1/00-issue.md`. Read it first. This plan argues from it and does not
repeat it.

**Worktree:** `../caw-issue-1`, branch `feature/issue-1`, from `main` at `39b3a5c`.

## Decisions

Decided by the issue (its *Decided already* 1–10, and requirements 1–8):

| # | Question | Answer |
|---|---|---|
| 1 | What "being read" means | Document visible, window focused, and within `STICK_THRESHOLD` (80px) of the bottom |
| 2 | Marker target | Newest non-pending loaded message, own messages and tombstones included |
| 3 | Transport | Socket `mark_read`, at most 1 per channel per second, trailing edge sends the latest id; nothing while disconnected; ack errors and timeouts ignored |
| 4 | After a read | Write `lastReadId` and `unreadCount: 0` into the list and detail caches. No refetch |
| 5 | Background counts | Poll the list every 30s while visible, plus on focus, reconnect and channel switch |
| 6 | Other tabs | `read_receipt_updated`: write the caches if it reaches the newest cached message, otherwise invalidate the list |
| 7 | Divider | Uses the `lastReadId` captured when the channel opens and the server's unread rule. Fixed while the user stays in the channel |
| 8 | Badge | Pill, `99+` above 99, bold name, `aria-label="N unread messages"`, `data-count`. Hidden on the open channel only while it is being read |

Taken in this plan. Each needs the plan-reviewer's yes or no:

| # | Question | Answer | Why, and the alternative |
|---|---|---|---|
| 9 | Throttle edge | **Leading and trailing.** The first read in a window goes at once. A later id in the window goes when the window ends | Trailing-only would hold every badge clear back by a second. The issue asks for "at most one per second" and "latest on the trailing edge", and leading+trailing meets both |
| 10 | Throttle lifetime | One throttle **per socket** (a `WeakMap<Socket, ReadThrottle>`), keyed by channel inside. It is not tied to `MessageList`'s lifetime | `MessageList` unmounts when the user switches to an uncached channel. A throttle owned by the component would either drop the pending trailing id, so the marker lags and the badge comes back, or flush it early, which breaks 1/s. A new socket (token renewal) starts a new throttle. A timer left on a closed socket finds it disconnected and sends nothing |
| 11 | Where "being read" lives | `readingChannelId: string \| null` in `stores/chat.ts`. It is set only while the rule holds **and** the history is loaded **and** the boundary is ready (#12) | It is client state, which D24 allows in Zustand. `ChannelList` and `MessageList` are siblings. Setting it in the same effect that pushes the read means a hidden badge always means the read went out, and the BDD journey relies on that. Alternative: set it from the rule alone, so the badge hides before anything is sent |
| 12 | Capturing the divider boundary | `useReadBoundary` takes `lastReadId` from the channel **detail** query the first time that query has fetched after mount (`isFetchedAfterMount`). No read is sent before then (`ready`) | A value taken from the cache on open could be our own local write from a previous visit, or could be overwritten by the refetch that opening triggers. Either way the divider lands in the wrong place or disappears. Gating reads on `ready` stops our own write from racing the capture |
| 13 | A boundary older than the loaded pages | `firstUnreadId` returns null when older pages exist **and** the oldest loaded id is greater than the boundary | Without that check, every loaded message is "after the marker" and the divider would sit above the first loaded row. That breaks requirement 7's "appears once scrolling back loads it" |
| 14 | "Newest cached message" for a receipt | The newest **non-pending** message in the channel's cached history. An empty cached history takes the invalidate branch | A `temp:` id compares greater than every UUID string (`t` > `f`), so counting it would send every receipt down the invalidate branch |
| 15 | Refresh triggers | Reconnect: `onConnect` in `useChannelSocket` invalidates the list on **every** connect. Channel switch and window `focus`: a new `useChannelListRefresh` mounted in `ChatLayout`, which skips its first render. Every refresh is `invalidateQueries(…, { cancelRefetch: false })`. TanStack's own `refetchOnWindowFocus` (v5 listens to `visibilitychange`) stays on | v5 does not listen to `window` `focus`. Side-by-side windows never change visibility, so the issue's "on window focus" needs its own listener. `cancelRefetch: false` stops a refresh from cancelling the first load it overlaps |
| 16 | A failed background refetch | `ChannelList` shows its error only when it has **no data**. A failed poll keeps the last list on screen | With a 30-second poll, today's `if (error)` branch would replace the whole sidebar with an error on one network blip. The alternative is to keep that behaviour and accept that regression |
| 17 | `data-count` | Holds the text shown: `"3"`, or `"99+"` | The issue says "the number shown". The page object compares strings anyway |
| 18 | Receipt vs. a list fetch already in flight | The receipt's list write is re-applied when that fetch lands, using the existing `reapplyAfterFetch` in `useChannelSocket.ts` | That is the same race the file already handles for messages: a refetch that started before the marker moved would restore the old count for up to 30s |
| 19 | The ack | `socket.timeout(5000).emit('mark_read', payload, () => {})`. The callback does nothing | Requirement 3: no toast, no retry. The timeout stops a dropped connection from leaving a callback pending forever |

No 🔴 entry is touched, and no register row changes. D31 (🟢) covers the server contract. The
nearest 🔴 entry is **D37** (what the SPA does on a 401 from a revoked token). Polling makes a
background 401 more likely, but this plan changes nothing about 401 handling: decision 16 keeps the
last list on screen whatever the error. **D28** (no per-user preferences) is also close. This plan
adds no per-user setting, such as muting a channel or hiding its badge.

## Corrections to the issue

- **ADR line numbers.** The sentence to correct ("…covered today by a manual check…") is at
  **lines 97–100** of `260915-read-state-follows-channel-visibility.md`, not 94–99.
- **"On window focus".** TanStack Query v5's own focus refetch fires on `visibilitychange`, so
  decision 15 adds the `focus` listener the issue asks for.

## Test approach — recommendation to the test pair

**BDD outside-in, with one journey.** This changes a journey the suite already has (the sidebar and
opening a channel), and it adds a capability users see. Only a real browser against the real server
can show that a count set by one person's post clears when another person reads it, and that it
stays clear after a reload. Write the journey first. Everything under it goes down to Vitest. No
backend test changes: the issue changes no server behaviour, and
`messaging/tests/integration/test_read_state.py` already proves it.

| Behaviour | Layer | File |
|---|---|---|
| Ada posts in #random; Grace, in #dev, sees 1 unread; opening #random clears it, and it stays clear after a reload | **BDD** | `tests/bdd/features/read_state.feature` |
| Badge text and `99+`; the marker target; divider placement (own messages, tombstones, null marker, boundary not loaded) | Vitest unit | `features/channels/readState.test.ts` |
| Throttle: leading, 1/s, trailing latest, per channel | Vitest unit | `features/channels/readThrottle.test.ts` |
| Cache writes on read; receipt, both branches; 30s poll, paused when hidden | Vitest | `features/channels/useChannels.test.ts` |
| Refetch on focus and on channel switch | Vitest | `features/channels/useChannelListRefresh.test.ts` |
| Refetch on connect; `read_receipt_updated` routed to the caches | Vitest | `lib/realtime/useChannelSocket.test.tsx` |
| Visibility and focus tracking | Vitest | `features/channels/usePageAttention.test.ts` |
| Boundary captured once, after the fresh fetch | Vitest | `features/channels/useReadBoundary.test.ts` |
| The read rule end to end: attention, scroll, reconnect, no-op, ack ignored, cache writes, `readingChannelId` | Vitest | `features/channels/useMarkRead.test.tsx` |
| Badge rendering, hidden while being read, list kept on a failed refresh | Vitest | `features/channels/ChannelList.test.tsx` |
| Divider rendered in place; appears after scrolling back; one wiring test that `MessageList` marks read | Vitest | `features/channels/MessageList.test.tsx` |

**What no test covers:**
- Real `document.hasFocus()` with two windows side by side. jsdom is stubbed, so this is left to
  Task 9's first real run.
- The 30-second poll against a real server. Vitest proves it with fake timers, and the journey uses
  the channel-switch refetch instead.
- A second tab clearing its badge in a browser. Vitest proves the cache write. The suite has no
  fixture that gives one user two tabs, so Task 9's acceptance item 2 covers it.

**Baseline**, from `docs/test-report.md` at `e4d3396`: Unit 467 passed (frontend 145 of them),
integration 381 passed, end-to-end 19 passed. Expected counts are "N or more", because a sibling
branch may land first.

## Global constraints

- **TanStack Query owns server state (D24).** No channel, count or marker goes into Zustand. The
  only store addition is `readingChannelId`, a fact about this browser.
- Cache writers **no-op on an absent entry**, the same rule `upsertMessage` follows. A read for a
  channel whose list or detail is not cached invents nothing.
- Message ids are UUIDv7 strings. Compare them with `<` and `>` on the string, never by parsing.
  `temp:` ids are never compared (decision 14).
- Event names come from doc 02 §3.2: `mark_read` (client→server), `read_receipt_updated`
  (server→client). No other event is added.
- Vitest queries use role, label or text. `data-testid` is for the BDD page object only. Selectors
  go in `pages/chat_page.py` and never in a step.
- No env var, chart, compose, script, OpenAPI or backend change. `openapi/messaging.json` and
  `types/messaging.ts` already carry `lastReadId` and `unreadCount` (checked), so nothing is
  regenerated.
- Everything else is as CLAUDE.md says. The lint hook blocks on eslint and ruff findings.

## File map

Paths under `src/frontend/src/` are shortened to `features/…`, `lib/…`, `stores/…`, `test/…`.

| File | Change | Responsibility | Task |
|---|---|---|---|
| `features/channels/readState.test.ts` · `readThrottle.test.ts` | create | rules, throttle | 1 |
| `features/channels/useChannels.test.ts` · `useChannelListRefresh.test.ts` | create | cache writers, receipts, poll · focus and switch refetch | 2 |
| `lib/realtime/useChannelSocket.test.tsx` | modify: new `describe('read state')` only | connect refetch, receipt routing | 2 |
| `test/attention.ts` | create | `setAttention`, `resetAttention` for jsdom | 3 |
| `test/setup.ts` | modify | `resetAttention()` at load and in `afterEach` | 3 |
| `features/channels/usePageAttention.test.ts` · `useReadBoundary.test.ts` · `useMarkRead.test.tsx` | create | read rule | 3 |
| `features/channels/ChannelList.test.tsx` | modify: add tests | badge | 3 |
| `features/channels/MessageList.test.tsx` | modify: add tests, **and `renderList` passes the two new props** | divider, wiring | 3 |
| `tests/bdd/features/read_state.feature` · `steps/test_read_state_steps.py` | create | the journey and its steps | 4 |
| `tests/bdd/steps/conftest.py` | modify | new shared `When Ada sends "…" in "…"`; `Given Grace is looking at the "…" channel` **moved in** | 4 |
| `tests/bdd/steps/test_realtime_steps.py` | modify | `Given Grace is looking at…` **moved out** (unchanged body) | 4 |
| `tests/bdd/pages/chat_page.py` | modify | `has_unread_count`, `has_no_unread` | 4 |
| `features/channels/readState.ts` · `readThrottle.ts` | create | rules, throttle | 5 |
| `features/channels/useChannels.ts` | modify | poll options, `markChannelRead`, `applyReadReceipt`, `cachedLastReadId` | 6 |
| `features/channels/useChannelListRefresh.ts` | create | focus + switch | 6 |
| `lib/realtime/useChannelSocket.ts` | modify | list invalidation in `onConnect`; `read_receipt_updated` handler | 6 |
| `features/channels/ChatLayout.tsx` | modify | mount `useChannelListRefresh` | 6 |
| `stores/chat.ts` | modify | `readingChannelId`, `setReadingChannel` | 7 |
| `features/channels/usePageAttention.ts` · `useReadBoundary.ts` · `useMarkRead.ts` | create | read rule | 7 |
| `features/channels/MessageList.tsx` | modify | `atBottom` state, `useMarkRead`, divider | 7 |
| `features/channels/ChannelView.tsx` | modify | `useReadBoundary`, pass props | 7 |
| `features/channels/ChannelList.tsx` | modify | badge, bold, hide, error-without-data | 7 |
| `docs/design/06-frontend-spa.md` · `docs/adr/<yymmdd>-unread-state-polls-rather-than-pushes.md` · `docs/adr/260915-read-state-follows-channel-visibility.md` | modify · create · modify | the record | 8 |

Deliberately unchanged: `tests/bdd/conftest.py`, because `MESSAGING_TABLES` already truncates
`channel_reads` (line 64). `stores/chat.test.ts`, because the new field is proven through
`useMarkRead.test.tsx`. `lib/api/messaging.ts`, `test/api.ts` and `test/factories.ts`, because
`aChannel()` already defaults `lastReadId: null, unreadCount: 0`. `ChatLayout.test.tsx`, because its
FakeSocket has no `mark_read` responder, so an emit just times out. If it goes red, record it under
*Found while building*.

Sweep results: no importer is moved or renamed. `MessageList`'s props gain two required fields, and
its only callers are `ChannelView.tsx` and `MessageList.test.tsx`'s `renderList`, both listed above.
`useChannels` has one caller (`ChannelList`), and `select` is unchanged. Sibling branches: the
`feature/issue-1-spec` worktree sits at the same commit, and no other unmerged branch touches
`src/frontend` read state.

## How this plan runs

| Phase | Tasks | Who | Ends with |
|---|---|---|---|
| **RED** | 1–4 | test-writer | failing Vitest tests and the failing journey, each failing for the reason given. **Test-reviewer gate** |
| GREEN — rules | 5 | code-writer | Task 1 passes |
| GREEN — caches and refresh | 6 | code-writer | Task 2 passes |
| GREEN — read rule and UI | 7 | code-writer | Task 3 passes, then the journey |
| Finish | 8–9 | code-writer | the record, then verification |

There is one RED phase. Nothing new is generated, so no test waits on a contract. `tsc` stays red
through RED, because the new test files import modules that don't exist yet and `renderList` passes
props `MessageList` doesn't declare yet. Vitest does not type-check, so each test still fails for
its runtime reason.

---

## Task 1: The rules and the throttle (RED)

**Files:** `features/channels/readState.test.ts`, `features/channels/readThrottle.test.ts` (create)

**Interfaces.** Task 5 implements these.

```ts
// features/channels/readState.ts
export function formatUnread(count: number): string          // "1".."99", "99+" above 99
export function newestReadableId(messages: Message[]): string | null
  // messages oldest-first (DOM order); newest whose id does not start with PENDING_PREFIX
export function firstUnreadId(
  messages: Message[], boundary: string | null, myUserId: string, hasOlder: boolean,
): string | null
  // null if boundary is null; null if hasOlder && messages[0].id > boundary;
  // else first m with m.id > boundary && m.authorId !== myUserId && m.deletedAt === null
export function isAtOrAfter(id: string, other: string): boolean   // id >= other, string order

// features/channels/readThrottle.ts
export interface ReadThrottle { push(channelId: string, messageId: string): void; cancel(): void }
export function createReadThrottle(
  send: (channelId: string, messageId: string) => void, intervalMs?: number, // default 1000
): ReadThrottle
```

The throttle sends the first `push` for a channel at once and opens a 1s window for that channel.
Any later pushes in the window are kept, latest wins. When the window closes, the latest one is
sent if it differs from what was last sent, and that send opens a new window. `cancel()` clears
every timer. The throttle does not decide *whether* to send: `send` makes the connection check and
the no-op check (Task 7).

| Test | Proves | Expected red |
|---|---|---|
| `formatUnread shows the count up to 99, and 99+ above it` (1, 99, 100, 5000) | requirement 1 | `Failed to resolve import "./readState"` |
| `newestReadableId skips pending sends` | `temp:` never becomes a marker | same |
| `newestReadableId includes the reader's own messages and tombstones` | requirement 2 | same |
| `newestReadableId is null when only pending messages are loaded` | nothing to send | same |
| `firstUnreadId is the first message after the marker that someone else wrote` | requirement 7 | same |
| `firstUnreadId skips the reader's own messages and tombstones` | server's unread rule | same |
| `firstUnreadId is null for a null marker` | no divider for a never-read channel | same |
| `firstUnreadId is null when older pages exist and the loaded history starts after the marker` | decision 13 | same |
| `firstUnreadId finds the boundary once the older page that holds it is loaded` | same, with `hasOlder` false | same |
| `firstUnreadId is null when nothing after the marker qualifies` | only own messages/tombstones after it | same |
| `sends the first read for a channel at once` | decision 9 | `Failed to resolve import "./readThrottle"` |
| `sends at most one read per channel per second` · `sends the latest id when the window ends, not the first` | requirement 3 | same |
| `sends nothing when the window ends with nothing new` · `throttles each channel on its own` | no duplicate trailing send; per channel | same |

Build messages with `aMessage()` and give them sortable ids, for example
`0199a000-0000-7000-8000-00000000000N`. `crypto.randomUUID()` is v4 and doesn't sort. Throttle
tests use `vi.useFakeTimers()` and a `vi.fn()` for `send`, as in `useTyping.test.ts`. Leave
uncommitted.

## Task 2: Caches, refresh and the socket (RED)

**Files:** `features/channels/useChannels.test.ts`, `useChannelListRefresh.test.ts` (create);
`lib/realtime/useChannelSocket.test.tsx` (modify: a new `describe('read state')`, with no existing
test edited)

**Interfaces.** Task 6 implements these.

```ts
// features/channels/useChannels.ts (additions)
export const CHANNEL_POLL_MS = 30_000
// useChannels query gains: refetchInterval: CHANNEL_POLL_MS, refetchIntervalInBackground: false
export interface ReadReceiptEvent { channelId: string; userId: string; messageId: string }
export function markChannelRead(qc: QueryClient, workspaceId: string | null,
  channelId: string, messageId: string): void
  // list cache (ChannelPage at channelKeys.list) and detail cache (Channel at channelKeys.detail):
  // that channel gets { lastReadId: messageId, unreadCount: 0 }; absent entry → untouched
export function cachedLastReadId(qc: QueryClient, workspaceId: string | null,
  channelId: string): string | null | undefined   // detail first, then list; undefined if neither
export function applyReadReceipt(qc: QueryClient, workspaceId: string | null,
  event: ReadReceiptEvent, myUserId: string): 'written' | 'invalidated' | 'ignored'
  // ignored if event.userId !== myUserId; written if the channel's message history is cached,
  // non-empty, and isAtOrAfter(event.messageId, newest non-pending cached id); else invalidates list

// features/channels/useChannelListRefresh.ts
export function useChannelListRefresh(workspaceId: string | null, activeChannelId: string | null): void
  // invalidates channelKeys.list(workspaceId) with { cancelRefetch: false } on window 'focus'
  // and whenever activeChannelId changes after the first render
```

`applyReadReceipt` returns a value so the socket handler knows whether to re-apply after a fetch
(decision 18), and so tests can assert the branch directly.

| Test | File | Expected red |
|---|---|---|
| `markChannelRead writes the marker and a zero count into the cached list and detail` · `…leaves uncached entries absent` | useChannels | `markChannelRead is not a function` (the import is undefined) |
| `applyReadReceipt writes the caches when the receipt reaches the newest cached message` (an equal id and a later id) · `…ignores a pending message when finding the newest` | useChannels | `applyReadReceipt is not a function` |
| `applyReadReceipt refetches the list for a receipt older than the newest cached message` · `…when the channel's history is not cached` · `…ignores a receipt for another user` | useChannels | same |
| `polls the channel list every 30 seconds while the tab is visible` | useChannels | one request after 30s where two are expected |
| `does not poll while the tab is hidden` | useChannels | fails vacuously today. So assert the **visible** case first in the same test (one poll), then hide and advance 60s (no more polls). It is red on the first half |
| `refetches the channel list when the window regains focus` | useChannelListRefresh | `Failed to resolve import "./useChannelListRefresh"` |
| `refetches the channel list when the open channel changes` | useChannelListRefresh | same |
| `does not refetch on the first render` | useChannelListRefresh | same |
| `refetches the channel list on every connect` (seed the list, `serverConnect()`, and again after `serverDisconnect()` + `serverConnect()`) | useChannelSocket | the list key's `isInvalidated` is falsy |
| `applies another tab's read receipt to the cached channel` | useChannelSocket | `unreadCount` still 3 after `serverEmit('read_receipt_updated', …)` |
| `refetches the channel list for a receipt behind the cached history` | useChannelSocket | the list key's `isInvalidated` is falsy |

Test notes:
- Seed the caches with `queryClient.setQueryData(channelKeys.list(WS), { items: [...], nextCursor:
  null })` and `channelKeys.detail(WS, id)`. Seed messages as in `useChannelSocket.test.tsx`'s
  `seedHistory`.
- **Invalidation:** assert `getQueryState(key)?.isInvalidated`, the idiom `isInvalidated` already
  uses in that file.
- **Poll tests:** render `useChannels` through `renderHookWithProviders` with a `messaging.get
  ('/api/v1/channels', …)` stub, and count `requests()`. Use
  `vi.useFakeTimers({ toFake: ['setTimeout', 'setInterval'] })` with `advanceTimersByTimeAsync`,
  so MSW's promises still settle. Toggle visibility with `setAttention` from Task 3's helper. It is
  written in this RED phase too, so write it first.

Leave uncommitted.

## Task 3: The read rule, the badge and the divider (RED)

**Files:** `test/attention.ts` (create), `test/setup.ts` (modify),
`features/channels/usePageAttention.test.ts`, `useReadBoundary.test.ts`, `useMarkRead.test.tsx`
(create), `ChannelList.test.tsx`, `MessageList.test.tsx` (modify)

**Test helper.** jsdom has no real focus or visibility.

```ts
// test/attention.ts
export function setAttention(next: { visible?: boolean; focused?: boolean }): void
  // defines document.visibilityState / document.hidden getters and document.hasFocus();
  // dispatches 'visibilitychange' on document, and 'focus' / 'blur' on window, for what changed
export function resetAttention(): void   // visible and focused, no events
```

`setup.ts` calls `resetAttention()` once at import and again in `afterEach`, so every test starts
visible and focused.

**Interfaces.** Task 7 implements these.

```ts
// stores/chat.ts (additions)
readingChannelId: string | null            // initial null
setReadingChannel: (channelId: string | null) => void

// features/channels/usePageAttention.ts
export function usePageAttention(): { visible: boolean; focused: boolean }

// features/channels/useReadBoundary.ts
export function useReadBoundary(channelId: string, lastReadId: string | null | undefined,
  fresh: boolean): { boundary: string | null; ready: boolean }
  // captures lastReadId the first render where fresh is true for this channelId; keeps it until
  // channelId changes; ready is false until captured

// features/channels/useMarkRead.ts
export const MARK_READ_TIMEOUT_MS = 5000
export function useMarkRead(args: { workspaceId: string | null; channelId: string;
  messages: Message[]; atBottom: boolean; ready: boolean }): void
  // socket from useSocket(); connected = store connectionStatus === 'connected';
  // reading = visible && focused && atBottom && ready && newestReadableId(messages) !== null
  // sets readingChannelId to channelId while reading (null otherwise, and on unmount);
  // while reading && connected && newest !== cachedLastReadId → throttle.push(channelId, newest)
  // send(): skip if !socket.connected or id === cachedLastReadId; else
  //   socket.timeout(MARK_READ_TIMEOUT_MS).emit('mark_read', { channelId, messageId }, () => {})
  //   then markChannelRead(...)

// MessageList props gain:  readBoundary: string | null;  readReady: boolean
```

`MessageList` keeps `atBottom` as state alongside the existing `wasAtBottom` ref, updated in
`onScroll` from the same `fromBottom < STICK_THRESHOLD` test and reset to `true` on channel change.
The divider is:

```tsx
<div role="separator" aria-label="New messages" data-testid="new-messages-divider">New messages</div>
```

It is rendered immediately before the `MessageItem` whose id is
`firstUnreadId(messages, readBoundary, userId, hasNextPage)`. The badge, inside the `NavLink` after
the name, is:

```tsx
<span data-testid="unread-badge" data-count={shown} aria-label={`${shown} unread messages`}>{shown}</span>
```

The name is bold (`font-semibold`) whenever the badge shows. The badge is omitted when
`unreadCount === 0` or `channel.id === readingChannelId`.

| Test | File | Expected red |
|---|---|---|
| `attends while the tab is visible and the window focused` · `stops attending when the tab is hidden` · `…when the window loses focus` · `resumes when both return` | usePageAttention | `Failed to resolve import "./usePageAttention"` |
| `captures the marker once the channel has been fetched fresh` · `is not ready before the fresh fetch` · `keeps the captured marker while the cached one moves on` · `captures again for a different channel` | useReadBoundary | `Failed to resolve import "./useReadBoundary"` |
| `marks the newest confirmed message read while the channel is being read` | useMarkRead | `Failed to resolve import "./useMarkRead"` |
| `marks nothing while the tab is hidden` · `…while the window is unfocused` · `…while scrolled back` | useMarkRead | same |
| `marks read when the reader returns to the bottom` · `marks nothing until the read boundary is ready` | useMarkRead | same |
| `marks a newly arrived message read, at most once a second, sending the latest id` | useMarkRead | same |
| `sends nothing when the newest message is already the cached marker` · `sends nothing while disconnected, queues nothing, and marks read on reconnect` | useMarkRead | same |
| `writes the marker and a zero count into the caches as it sends` · `ignores an error ack and a timed-out ack, without retrying` | useMarkRead | same |
| `reports the channel as being read, and stops when the reader scrolls back` | useMarkRead | same |
| `shows the unread count beside a channel and bolds its name` | ChannelList | `getByLabelText('3 unread messages')` not found |
| `shows 99+ above 99` | ChannelList | `'99+ unread messages'` not found |
| `shows no badge for a channel with nothing unread` | ChannelList | **passes today, so pair it** with the 3-unread channel in the same render and assert that only that one has a badge. It is red on the first half |
| `hides the badge of the channel being read` | ChannelList | same pairing. Set `readingChannelId` on one of two unread channels. Red because no badge exists at all |
| `keeps showing the list when a background refresh fails` | ChannelList | the `alert` replaces the list after an invalidation answered by `messaging.problem('get', '/api/v1/channels', 500, …)` |
| `draws a New messages divider above the first message someone else wrote after the marker` | MessageList | `getByRole('separator', { name: 'New messages' })` not found |
| `draws no divider for a null marker` | MessageList | **passes today, so pair it** with a non-null render in the same test |
| `draws the divider only once scrolling back loads the marker` | MessageList | separator absent after the older page loads. The history is two pages with sortable ids: the older page holds the marked message, and the newest page holds Grace's messages after it. Before the scroll there is no divider. After `fireEvent.scroll` loads the older page, the divider sits above the first message after the marker |
| `marks the channel read when the reader is at the bottom` | MessageList | `socket.emitted` has no `mark_read` (connected FakeSocket via the `socket` option, `connectionStatus: 'connected'`, `readReady: true`) |

Test notes:
- `useMarkRead` tests use `renderHookWithProviders(…, { socket: fake })` with `fake.connected =
  true` and `useChatStore.setState({ connectionStatus: 'connected' })`. Change `messages`,
  `atBottom` and `ready` through `rerender`.
- Seed the detail cache for the no-op test. For the ack test, `fake.onEmit('mark_read', () => ({ ok:
  false, problem: { status: 404 } }))`. For the timeout case, give no responder and advance 5s.
  Neither may produce a second emit.
- The existing `stubHistory()` messages have v4 ids, which don't sort, so the divider tests build
  their own history with sortable ids (see Task 1's note). `firstUnreadId`'s `hasOlder` is
  `useMessages`' `hasNextPage`.
- **Ripple:** `MessageList.test.tsx`'s `renderList` passes `readBoundary={null} readReady={false}`,
  so the six existing tests are unchanged in behaviour.

Leave uncommitted.

## Task 4: The journey (RED)

**Files:** `tests/bdd/features/read_state.feature`, `steps/test_read_state_steps.py` (create);
`steps/conftest.py`, `steps/test_realtime_steps.py`, `pages/chat_page.py` (modify)

```gherkin
@bdd
Feature: Unread messages

  Each channel in the sidebar says how many messages are waiting there that you
  have not read, so you can see at a glance where the conversation moved on
  without you. Your own messages never count, and neither do deleted ones.

  A channel counts as read when you are actually reading it — the window is in
  front of you and you are at the latest message — not merely because it is
  open. Reading it clears the count, and it stays clear when you come back.
  Opening a channel you had fallen behind in shows a "New messages" line where
  you left off.

  Background:
    Given Ada is signed in

  # The one journey a browser is needed for: a count set by Ada's post and
  # cleared by Grace's reading, in the real server. The read rule, the throttle,
  # the badge's text and the divider are proven in Vitest. The poll is not
  # waited for: switching channel refetches the counts.
  Scenario: Grace sees what she missed, and reading it clears the count
    Given Ada has created a public channel named "general"
    And Ada has created a public channel named "random"
    And Ada has created a public channel named "dev"
    And Grace is looking at the "general" channel
    When Ada sends "lunch is in the kitchen" in "random"
    And Grace opens the "dev" channel
    Then Grace's channel list shows 1 unread message in "random"
    When Grace opens the "random" channel
    Then Grace's channel list shows no unread messages in "random"
    When Grace opens CollabHub
    Then Grace's channel list shows no unread messages in "random"
```

The final reload proves the server's marker moved; before it, a cleared badge could be the local
hide alone. `Grace opens CollabHub` lands on `/`, where no channel is open.

- **Reused verbatim:** `Given Ada is signed in`, `Given Ada has created a public channel named
  "{name}"`, `When Grace opens the "{name}" channel`, `When Grace opens CollabHub`.
- **Moved, not copied (vocabulary ruling 26):** `Given Grace is looking at the "{name}" channel`
  moves from `test_realtime_steps.py:39` to `steps/conftest.py`, with its body and docstring
  unchanged. `realtime.feature` must still pass.
- **New and shared, in `steps/conftest.py`:**
  `@when(parsers.re(r'Ada sends "(?P<body>[^"]*)" in "(?P<channel>[^"]*)"'))` runs
  `ada.open_channel(channel)`, then `ada.send_message_and_wait(body)`. pytest-bdd 8's `re` parser
  full-matches, so the existing `Ada sends "…"` step can't take this line. `steps/conftest.py:121-123`
  anticipates this.
- **New, in `test_read_state_steps.py`:**
  `@then(parsers.re(r"Grace's channel list shows (?P<count>\d+) unread messages? in \"(?P<name>[^\"]*)\"", converters={"count": int}))`
  → `assert grace.has_unread_count(name, count)`, and
  `@then(parsers.parse('Grace\'s channel list shows no unread messages in "{name}"'))` →
  `assert grace.has_no_unread(name)`. The module docstring follows `test_reaction_steps.py`'s.
- **Page object** (`chat_page.py`, beside `has_channel`). `has_unread_count(name, count)`:
  `_settle()`, then a retrying `expect` that `_channel_item(name).get_by_test_id("unread-badge")`
  has `data-count == str(count)`. `has_no_unread(name)`: `_settle()`, then the item has count 1
  **and** its badge has count 0. The item check anchors the negative.

Expected red: the step `Grace's channel list shows 1 unread message in "random"` fails because no
`unread-badge` exists. The test-reviewer checks that it fails at that step, **not** earlier on a
missing step. Run it with `scripts/test.sh e2e -- -k read_state`. Leave uncommitted.

---

## Task 5: The rules and the throttle (GREEN)

**Files:** `features/channels/readState.ts`, `readThrottle.ts` (create)

- [ ] `readState.ts` to Task 1's interface. It imports `PENDING_PREFIX` from `useMessages.ts` and
  does not redefine it. The module docstring says the divider follows the server's unread rule
  (doc 02 §3.1.7) and why `hasOlder` matters (decision 13).
- [ ] `readThrottle.ts` to Task 1's interface, as a plain module with `setTimeout`. It also exports
  `throttleFor(socket: Socket, send): ReadThrottle`, backed by a module-level
  `WeakMap<Socket, ReadThrottle>` (decision 10). The docstring states that the socket owns the
  throttle's lifetime.
- [ ] `(cd src/frontend && npx vitest run src/features/channels/readState.test.ts src/features/channels/readThrottle.test.ts)`:
  15 passed.
- [ ] Leave uncommitted.

## Task 6: Caches, refresh and the socket (GREEN)

**Files:** `features/channels/useChannels.ts`, `useChannelListRefresh.ts`, `ChatLayout.tsx`,
`lib/realtime/useChannelSocket.ts`

- [ ] `useChannels.ts`: add `refetchInterval: CHANNEL_POLL_MS, refetchIntervalInBackground: false`
  to the list query. Add `markChannelRead`, `cachedLastReadId` and `applyReadReceipt` to Task 2's
  interface. They write with `setQueryData` updaters that return `cached` unchanged when it is
  absent. The file docstring gains a paragraph on why counts poll instead of being pushed, citing
  the ADR from Task 8.
- [ ] `useChannelListRefresh.ts` to Task 2's interface. It uses a `useRef` to skip the first render,
  a `window` `focus` listener, and `cancelRefetch: false`.
- [ ] `ChatLayout.tsx`: `useChannelListRefresh(current.activeWorkspaceId, activeChannelId)`.
- [ ] `useChannelSocket.ts`: in `onConnect`, before the `if (!current) return`, call
  `void queryClient.invalidateQueries({ queryKey: channelKeys.list(workspaceId) }, { cancelRefetch: false })`.
  Register `live.on('read_receipt_updated', onReadReceipt)`. `onReadReceipt` calls
  `applyReadReceipt`, and when that returns `'written'` while the list key is fetching, it
  re-applies through the existing `reapplyAfterFetch` (decision 18). Add a fifth rule to the file's
  header comment: counts are refreshed on connect, and receipts from other tabs.
- [ ] Task 2's tests pass. Then run the whole of `useChannelSocket.test.tsx`: every existing test
  still passes.
- [ ] Leave uncommitted.

## Task 7: The read rule, the badge and the divider (GREEN)

**Files:** `stores/chat.ts`, `usePageAttention.ts`, `useReadBoundary.ts`, `useMarkRead.ts`,
`MessageList.tsx`, `ChannelView.tsx`, `ChannelList.tsx`

- [ ] `stores/chat.ts`: `readingChannelId` and `setReadingChannel`. The comment says this is a fact
  about the browser, not server state (D24).
- [ ] `usePageAttention.ts`: initial state from `document.visibilityState === 'visible'` and
  `document.hasFocus()`, updated on `visibilitychange`, `focus` and `blur`.
- [ ] `useReadBoundary.ts` to Task 3's interface. Hold the captured value in state keyed by
  `channelId`, not in a bare ref, so a channel change re-renders.
- [ ] `useMarkRead.ts` to Task 3's interface, using `throttleFor(socket, send)`. The effect depends on
  `reading`, `connected`, the newest id and `channelId`. Its cleanup clears `readingChannelId` **only
  if it still equals this channel**, so a fast switch doesn't clear the new channel's flag.
- [ ] `ChannelView.tsx`: `const { boundary, ready } = useReadBoundary(channel.id, channel.lastReadId,
  query.isFetchedAfterMount)`. Call it above the early returns (hooks rule), with `channelId ?? ''`.
  Pass `readBoundary` and `readReady` to `MessageList`.
- [ ] `MessageList.tsx`: `atBottom` state, `useMarkRead(...)`, and the divider.
- [ ] `ChannelList.tsx`: the badge (Task 3's markup, with `formatUnread`) and bold name.
  `readingChannelId` comes from the store. Change `if (error)` to `if (error && !channels)`, with a
  comment giving decision 16.
- [ ] Task 3's tests pass. Run `(cd src/frontend && npm test && npm run typecheck && npm run lint)`:
  all green, 145 + the new tests or more.
- [ ] `scripts/test.sh e2e -- -k "read_state or realtime"`: the journey passes, and so do the realtime
  scenarios, which prove the step move. If the badge never clears because `document.hasFocus()` is
  false under Playwright, call `page.bring_to_front()` in the page object's `open_channel`, and
  record it under *Found while building*.
- [ ] Leave uncommitted.

## Task 8: The record

- [ ] Doc 06 §5.2: drop "throttle `mark_read`" from its bullet and add a dated **Read state** block
  covering decisions 1–19: the read rule, the target, the throttle, disconnects, the ack, the cache
  writes, `readingChannelId`, the refresh triggers, receipts and the divider.
- [ ] ADR, written with the `adr-writer` skill: *Unread state in the SPA polls rather than pushes*.
  Include the issue's three alternatives and its revisit trigger.
- [ ] The D31 ADR, lines 97–100: `messaging/tests/integration/test_read_state.py` now covers the
  count's rules, the forward-only guard and the 404s.
- [ ] Sweep doc 06 and `src/frontend/src` for "unread" and "mark_read": nothing should still say
  the SPA ignores read state.
- [ ] Leave uncommitted.

## Task 9: Verification

- [ ] `scripts/test.sh lint unit integration`, then `scripts/test.sh e2e`: green. Unit at 467 +
  new tests or more, integration 381 or more, end-to-end 20 or more.
- [ ] `python3 .claude/hooks/checks/conventions.py $(git diff --name-only HEAD)` and
  `.claude/hooks/security.sh`.
- [ ] **First real run** on Compose (`docker compose up -d --build`), with Ada and Grace in two
  browsers, following the issue's *Acceptance*:
  1. Ada posts in a channel Grace isn't viewing. Grace's count appears within 30s, and at once when
     she switches channel or refocuses the window.
  2. Grace opens it: the divider is above Ada's first new message, and the badge clears. In a
     second tab of Grace's, the badge clears without a reload.
  3. Grace scrolls back while Ada posts again: the badge returns on the next refresh, and clears
     when Grace scrolls to the bottom.

  Expect this run to find something the tests didn't. Fix it with a test, and record it below.
- [ ] If a sibling branch merged while this was in flight, merge `main` and rerun all of the above.
- [ ] Fill in *Found while building*. Leave the worktree dirty and report.

## Found while building

*Filled in by the code-writer: every deviation from this plan, and every bug the first real run
found, each with the test that now pins it down. Empty until then.*

## Not in this plan

Everything in the issue's *Not in this issue*: a live push for background channels, a "↓ N new"
pill, opening at the first unread message, a title or favicon count, cross-workspace counts,
mentions, "mark all as read", DM behaviour, and a server-side cap.

## Review focus

Conditions no single test above exercises end to end, most likely first:
1. **Fast channel switching.** A trailing read for A fires after the user is in B. Decision 10 keeps
   it, and the cleanup guard in Task 7 must not clear B's flag.
2. **A tab visible but unfocused all day** (a second monitor) never marks read. That is correct by
   the rule, and the first real run should show it.
3. **Token renewal mid-throttle.** The old socket's timer finds it closed and sends nothing.
4. **A poll landing just after a local read** can restore a stale count on a channel that isn't
   being read, for one poll at most. This is accepted.
5. **An open channel with only pending messages** has no read target, so its badge shows until the
   send confirms.

## Self-review

- **Issue coverage:** req 1 → Tasks 3, 7; 2 → Tasks 1, 3, 5, 7; 3 → Tasks 1, 3, 5, 7; 4 → Tasks 2,
  3, 6, 7; 5 → Tasks 2, 6; 6 → Tasks 2, 6; 7 → Tasks 1, 3, 5, 7; 8 → Tasks 3, 4, 7; *Record in
  this slice* → Task 8; BDD journey → Task 4.
- **Names:** `mark_read` and `read_receipt_updated` everywhere. `readingChannelId` /
  `setReadingChannel`, `readBoundary` / `readReady`, `unread-badge` / `new-messages-divider` are
  spelled the same in every task.
- **Known ripple:** `MessageList.test.tsx`'s `renderList` (Task 3); one realtime step moved (Task 4).
