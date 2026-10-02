# Unread counts and read markers in the SPA — implementation plan

> **For agentic workers:** this plan is executed by `scripts/deliver.sh`: the test-writer does every
> RED task, the code-writer every GREEN one. Three project rules override the superpowers skills.
> **Never commit** — every task ends with the worktree dirty. **Red first** — no production code
> until the test-reviewer has approved the failing tests. **Plans live in `docs/plans/`.**

**Goal:** The sidebar shows how many messages the user hasn't read in each channel; reading a
channel moves their marker and clears the count here and in their other tabs; opening a channel
with unread messages shows a "New messages" divider where they left off.

**Architecture:** SPA only. Three pure rules (`readState.ts`: the display cap, the marker target,
the divider position) and two cache writers (`useChannels.ts`) carry the logic. A `useMarkRead`
hook in `MessageList` evaluates the read rule (visible ∧ focused ∧ at bottom) and hands reads to a
per-socket throttle that emits `mark_read` at most once a second per channel, trailing with the
latest id. Whether the open channel is being read is client state in Zustand, so the sidebar can
hide its badge. Background counts come from polling the channel list (30s, visible only) plus
refetches on focus, reconnect and channel switch; `read_receipt_updated` either writes the caches
or invalidates the list.

**Tech Stack:** React 19, TypeScript, TanStack Query 5, Zustand, socket.io-client 4, Tailwind v4 ·
Vitest 5 + MSW 2 + the repo's `FakeSocket` · pytest-bdd 8.1 + Playwright 1.62.

**Issue:** `docs/plans/issue-1/00-issue.md` — read it first. This plan argues from it and does not
repeat it. Requirements are cited as **R1–R8**, its decisions as **I-1–I-10**.

**Worktree:** `../caw-issue-1`, branch `feature/issue-1`, from `main` at `229fcc3`.

## Decisions

Decided by the issue:

| # | Question | Answer |
|---|---|---|
| 1 | Scope | R1–R8 only; *Not in this issue* stays out (I-1) |
| 2 | What "read" means | Visible, focused and within `STICK_THRESHOLD` of the bottom (I-2, R2) |
| 3 | The marker target | Newest non-pending loaded message, own and tombstones included (I-3) |
| 4 | Transport | `mark_read` over the socket, ≤1/s per channel, trailing latest id; REST unused (I-4) |
| 5 | Badge | Pill, `99+` above 99, bold name, hidden on the open channel only while it is being read (I-5) |
| 6 | After a read | Write the list and detail caches directly, no refetch (I-6) |
| 7 | The divider | Fixed at open-time, follows the server's unread rule (I-7) |
| 8 | Background counts | Polling, not push (I-8, I-9) |
| 9 | The register | D31 (🟢) covers the data; nothing settled, nothing 🔴 depended on (I-10) |

Taken in this plan — each needs the plan-reviewer's yes or no:

| # | Question | Answer | Why, and the alternative |
|---|---|---|---|
| 10 | Where "the open channel is being read" lives | `readingChannelId` in the Zustand chat store, set by `useMarkRead` | It is client state the server has no opinion on (D24), and the sidebar (`ChatLayout`) and the list (`ChannelView`) are in different subtrees. Alternative: a new context — a second channel for state the store already carries (`joinedChannelId` is the precedent) |
| 11 | Who owns the throttle | One throttle **per socket**, from a module `WeakMap<Socket, MarkReadThrottle>` in `markRead.ts` | A trailing read must still go out after the user leaves the channel, or the last message they saw stays unread on the server. Alternatives: a ref in `MessageList` (the trailing read dies on unmount) or a flush on unmount (can emit twice inside one second, breaking I-4) |
| 12 | The no-op check | Done **at send time**, against `cachedLastReadId`, and a window opens only when something was emitted | A trailing id may already have been written by a receipt from another tab; checking at request time would emit it anyway. A no-op must not delay the next real read by a second |
| 13 | The ack | `socket.timeout(5000).emit('mark_read', payload, () => {})`, result ignored | Same shape as `useSendMessage`, so the callback is released on timeout rather than held until disconnect. Alternative: no ack callback — then R3's "error ack is ignored" has nothing to prove |
| 14 | "The boundary is older than the loaded pages" (R7) | Detected as: **no loaded message has an id ≤ the captured `lastReadId`** → no divider | Marked messages are never removed (tombstones stay, D8d; D16 deletes nothing), so the boundary is loaded exactly when something at or before it is. Alternative: `!hasNextPage` — wrong while the boundary is loaded but older pages remain |
| 15 | Where the captured `lastReadId` comes from | The `Channel` detail `ChannelView` already renders (`channel.lastReadId`), passed to `MessageList` as a new prop and captured the first time `MessageList` renders a given `channelId` | It is on screen before the first `mark_read` can go (ChannelView renders nothing until the detail exists), so the capture can't race our own cache write. Alternative: wait for the open's refetch — which can land *after* our first read and capture the new marker, so no divider |
| 16 | "On window focus" (R5) | TanStack's `refetchOnWindowFocus: true` **plus** a `window` `focus` listener in `useChannels` that invalidates the list | TanStack 5's `focusManager` listens to `visibilitychange` only, so focusing a window that was visible but not focused would not refetch. Alternative: replace the global `focusManager` listener — changes every query's behaviour, including infinite message history |
| 17 | "On socket reconnect" (R5) | Invalidate the list on every `connect` **after the first** | The first connect coincides with the list's own first load. Alternative: every connect — one wasted request per page load |
| 18 | "On every channel switch" (R5) | `ChannelView`'s existing `channelId` effect invalidates `channelKeys.list(workspaceId)` | It is where a switch is already observed (`setActiveChannel`). Alternative: `useChannelSocket`'s join effect — skipped while the socket is down, which is when a refetch matters most |
| 19 | Scroll state | `MessageList` keeps `wasAtBottom` (ref) for the layout effect and adds `atBottom` **state**, set in `onScroll` only when it changes | The read rule must re-run when the user reaches the bottom; a ref change renders nothing. React bails out of an unchanged `setState`, so scrolling doesn't re-render |
| 20 | Pending messages and the divider | A `temp:` row never takes the divider | It is always the user's own (and `temp:` sorts after hex, so an id comparison would otherwise count it as new) |
| 21 | BDD step home | `Given Grace is looking at the "{name}" channel` **moves** from `test_realtime_steps.py` to `steps/conftest.py` | A second feature now needs it; pytest-bdd doesn't resolve steps across sibling modules, and a copy is the defect `steps/conftest.py`'s docstring exists to prevent |
| 22 | Test hooks (R8) | `data-testid="channel-unread-badge"` with `data-count`; `data-testid="new-messages-divider"` | Named for what they are; only the badge gets a page-object method, because only the badge is in a journey |

Nothing here touches a 🔴 entry. The nearest are **D16** (tombstone retention): a tombstone may be
the marker target and never takes the divider, and both hold whether or not tombstones are ever
purged. The other is **D28** (user preferences): nothing here stores a per-user choice. A mute or
a "don't show counts" setting would need it, and neither is in scope.

## Corrections to the issue

- **The ADR lines are 96–99, not 94–99.** `docs/adr/260915-read-state-follows-channel-visibility.md:96-99`
  is the "What the unit tests … cannot reach" paragraph; lines 94–95 end the receipts paragraph and
  stay. Task 9 edits 96–99.
- **Doc 06 §5.2's bullet is stale in both halves**: "Debounce `typing`" contradicts the same
  section's *Typing* paragraph (`06-frontend-spa.md:234-238`, a leading-edge throttle). Task 9
  rewrites the whole bullet, not only the `mark_read` half.

## Test approach — recommendation to the test pair

**BDD outside-in, with the one journey the issue names.** This is a new capability the user sees
in the sidebar, and it depends on a behaviour only a whole stack shows: a message written in one
browser turns into a count in another after a channel switch. Write the journey first (Task 5).
Every rule under it goes down to Vitest.

| Behaviour | Layer | File |
|---|---|---|
| Ada posts in `random`; Grace, switching to `dev`, sees 1 unread on `random`; opening it clears it | **BDD** | `tests/bdd/features/read_state.feature` |
| `99+` cap; marker target (skip `temp:`, keep own and tombstones); divider position (own, tombstone, null, boundary not loaded) | Vitest unit | `features/channels/readState.test.ts` |
| Throttle: leading emit, ≤1/s, trailing latest, no window after a no-op | Vitest unit | `features/channels/markRead.test.ts` |
| Cache writes on read; receipt covers the history → write, else invalidate; polling at 30s, paused hidden; focus refetch | Vitest | `features/channels/useChannels.test.ts` |
| The read rule (visibility, focus, scroll); no-op on unchanged id; disconnect/reconnect; error ack and timeout ignored; `readingChannelId` | Vitest | `features/channels/useMarkRead.test.tsx` |
| `read_receipt_updated` routed into the caches; reconnect refetches the list | Vitest | `lib/realtime/useChannelSocket.test.tsx` |
| Channel switch refetches the list | Vitest | `features/channels/ChannelView.test.tsx` |
| Badge, `99+` label, hidden while being read, shown when scrolled back | Vitest | `features/channels/ChannelList.test.tsx` |
| Divider rendered and placed; stays as the marker moves; gone after leaving; list marks read on open | Vitest | `features/channels/MessageList.test.tsx` |

**What no test here covers:**
- **The bold name.** It is a class, not a role or a label. The first real run checks it (Task 10).
- **That the SPA's emit moves the server's marker.** The journey's last step passes if the badge is
  hidden while the channel is being read, whether or not `mark_read` landed. The emit is proven in
  Vitest and the server side in `messaging/tests/integration/test_read_state.py`. The join between
  them is the first real run's reload check.
- **Cross-tab clearing in a real browser.** Vitest proves the receipt handler; the first real run
  proves the second tab.
- **The 30-second poll in a real browser.** Fake timers only; the journey uses the switch refetch
  (as the issue asks), so it needs no wait.

**Baseline**, from `docs/test-report.md` at `e4d3396`: frontend (Vitest) 145 passed; end-to-end 19
passed; Messaging unit 94 and integration 211, which this work doesn't touch. Expected counts
below are "N or more".

## Global constraints

- **TanStack Query owns server state, Zustand client state only** (D24). `readingChannelId` is the
  only addition to the store. No copy of a channel, count or marker goes into it.
- **An event for an uncached key never creates an entry** (`useChannelSocket.ts:32-37`). Both new
  cache writers no-op on an absent list or detail entry.
- **Message ids are UUIDv7 and compare as strings in time order** (R6). Compare only real ids —
  never a `temp:` one (decision 20).
- **Vitest queries by role, label or text.** A `data-testid` is added for the BDD page object and
  is never read by a Vitest test (CLAUDE.md). `data-count` is not a test id, but tests use the
  `aria-label` anyway.
- **BDD selectors live in `pages/chat_page.py` only**, `data-testid` only; a step has none.
- No backend, chart, Compose, script or env-var change (the issue's *Services touched*). No
  OpenAPI regeneration: `types/messaging.ts` already has `lastReadId`/`unreadCount`, and
  `aChannel()` defaults them (`test/factories.ts:33-34`) — checked.
- Everything else is as CLAUDE.md says. The hooks block on lint (eslint for `.ts`/`.tsx`, ruff for
  the step modules).

## File map

Paths under `src/frontend/src/` unless they start with `tests/` or `docs/`.

| File | Change | Responsibility | Task |
|---|---|---|---|
| `features/channels/readState.test.ts` | create | the pure rules | 1 |
| `features/channels/markRead.test.ts` | create | the throttle | 1 |
| `features/channels/useChannels.test.ts` | create | cache writers, receipt, polling, focus | 2 |
| `lib/realtime/useChannelSocket.test.tsx` | modify | receipt routing, reconnect refetch | 2 |
| `features/channels/ChannelView.test.tsx` | create | switch refetch | 2 |
| `test/attention.ts` | create | `setAttention()` — stubs visibility and focus, fires the events | 3 |
| `features/channels/useMarkRead.test.tsx` | create | the read rule, end to end through the hook | 3 |
| `features/channels/ChannelList.test.tsx` | modify | badge | 4 |
| `features/channels/MessageList.test.tsx` | modify | divider, marking — **existing `renderList` gains the `lastReadId` prop** | 4 |
| `tests/bdd/features/read_state.feature` | create | the journey | 5 |
| `tests/bdd/steps/test_read_state_steps.py` | create | its steps | 5 |
| `tests/bdd/steps/conftest.py` · `steps/test_realtime_steps.py` | modify · modify | `Given Grace is looking at …` moves (decision 21) | 5 |
| `tests/bdd/pages/chat_page.py` | modify | `has_unread_count`, `has_no_unread` | 5 |
| `features/channels/readState.ts` | create | `formatUnreadCount`, `isAtOrAfter`, `markTarget`, `dividerBefore` | 6 |
| `features/channels/markRead.ts` | create | `createMarkReadThrottle`, `throttleFor`, the two constants | 6 |
| `features/channels/useChannels.ts` | modify | polling + focus; `markChannelReadInCache`, `cachedLastReadId`, `applyReadReceipt`, `ReadReceiptEvent` | 6 |
| `features/channels/useMessages.ts` | modify | `newestCachedMessageId` | 6 |
| `stores/chat.ts` | modify | `readingChannelId`, `setReadingChannel` | 7 |
| `features/channels/useMarkRead.ts` | create | `usePageAttention`, `useMarkRead` | 7 |
| `lib/realtime/useChannelSocket.ts` | modify | `read_receipt_updated` handler; list refetch on reconnect | 7 |
| `features/channels/ChannelList.tsx` | modify | badge, bold, hidden while being read | 8 |
| `features/channels/MessageList.tsx` | modify | `lastReadId` prop, `atBottom` state, `useMarkRead`, divider | 8 |
| `features/channels/ChannelView.tsx` | modify | pass `lastReadId`; refetch the list on switch | 8 |
| `docs/design/06-frontend-spa.md` · `docs/adr/260930-unread-state-polls-rather-than-pushes.md` · `docs/adr/260915-read-state-follows-channel-visibility.md` | modify · create · modify | the record | 9 |

Deliberately unchanged: `test/socket.ts` (`FakeSocket` already has `connected`, `onEmit`, `timeout`,
`serverConnect/Disconnect`); `test/api.ts` (the list and detail stubs are already typed with the
two fields); `test/setup.ts` (it snapshots the whole chat store, so `readingChannelId` resets
between tests unasked; `restoreMocks: true` in `vite.config.ts:21` undoes `setAttention`'s spies);
`tests/bdd/conftest.py` (no new table; the truncation already names `channel_reads`, `:64`);
`ChatLayout.tsx` (the sidebar reads the store itself). `ChatLayout.test.tsx` and `App.test.tsx`
need no change: their channels default to `unreadCount: 0` and their name queries stay exact
(checked).

Sweep results: no importer of anything renamed; `useChannels` has one caller (`ChannelList.tsx:19`);
`channelKeys` callers only read keys. `worktree list` shows one sibling touching this area,
`experiment/planted-scroll-bug` (`MessageList` scroll) — an experiment, not for merging; Task 10
rechecks `git branch --no-merged main`.

## How this plan runs

| Phase | Tasks | Who | Ends with |
|---|---|---|---|
| **RED** | 1–5 | test-writer | failing Vitest tests and a failing journey, each failing for the reason given — **test-reviewer gate** |
| GREEN — rules and caches | 6 | code-writer | Tasks 1 and 2's `useChannels.test.ts` pass |
| GREEN — the read rule | 7 | code-writer | Tasks 2 and 3 pass |
| GREEN — components | 8 | code-writer | Task 4 and the journey pass |
| Finish | 9–10 | code-writer | the record, then verification and the first real run |

One RED phase: there is no contract to regenerate, so every stub and factory types today.

---

## Task 1: The pure rules and the throttle (RED)

**Files:** `features/channels/readState.test.ts`, `features/channels/markRead.test.ts` (create)

**Interfaces** — produced for Task 6, in `features/channels/readState.ts`:
- `formatUnreadCount(count: number): string` — `"1"`…`"99"`, then `"99+"`.
- `isAtOrAfter(id: string, other: string): boolean` — `id >= other`, as strings.
- `markTarget(messages: readonly Message[]): string | null` — `messages` oldest-first (what
  `useMessages`' `select` returns); the id of the last one that isn't `temp:`; `null` if none.
- `dividerBefore(messages: readonly Message[], lastReadId: string | null, myUserId: string): string | null`
  — `null` if `lastReadId` is null, or no loaded message has id ≤ `lastReadId` (decision 14);
  otherwise the id of the first message with id > `lastReadId`, `authorId !== myUserId`,
  `deletedAt === null`, and not `temp:`; `null` if none qualifies.

…and in `features/channels/markRead.ts`:
- `MARK_READ_INTERVAL_MS = 1000`, `MARK_READ_ACK_TIMEOUT_MS = 5000`
- `interface MarkReadThrottle { request(channelId: string, attempt: () => boolean): void }` —
  `attempt` emits and returns `true`, or returns `false` if it sent nothing.
- `createMarkReadThrottle(intervalMs = MARK_READ_INTERVAL_MS): MarkReadThrottle` — per channel: no
  open window → run `attempt` now, and open a window only if it returned `true`. Open window →
  keep only the latest `attempt`. At the window's end, run the kept one (if any), and reopen the
  window only if it returned `true`.
- `throttleFor(socket: Socket): MarkReadThrottle` — one per socket, from a `WeakMap`.

Build ids for ordering with fixed UUIDv7-shaped strings (`0199a000-0000-7000-8000-00000000000N`),
not `aMessage()`'s random v4 ids, which don't sort in time.

| Test (`readState.test.ts`) | Proves | Expected red |
|---|---|---|
| `shows counts up to 99 as they are` · `shows 99+ above 99` | R1 cap | `Failed to resolve import "./readState"` |
| `marks up to the newest confirmed message, skipping a pending one` | R2 `temp:` skip | same |
| `marks the user's own message and a tombstone when they are newest` | R2 inclusions | same |
| `has nothing to mark in an empty or all-pending history` | null case | same |
| `puts the divider above the first message after the marker from someone else` | R7 | same |
| `skips the user's own messages and tombstones for the divider` | R7 | same |
| `puts no divider when the channel has never been read` | R7 null | same |
| `puts no divider while the boundary is older than every loaded message` | R7, decision 14 | same |
| `puts no divider when nothing after the marker qualifies` | R7 | same |
| `compares UUIDv7 ids in time order` | R6 | same |

| Test (`markRead.test.ts`, fake timers) | Proves | Expected red |
|---|---|---|
| `sends the first read at once` | leading edge | `Failed to resolve import "./markRead"` |
| `sends at most once a second per channel, then the latest id` | R3 trailing — three requests in the window, one trailing call, the third's | same |
| `throttles each channel on its own` | "per channel" | same |
| `does not hold the next read back after one that sent nothing` | decision 12 | same |
| `gives the same throttle for the same socket, and another for another` | decision 11 | same |

- [ ] Write both files; run `(cd src/frontend && npx vitest run src/features/channels/readState.test.ts src/features/channels/markRead.test.ts)`; confirm each fails for the reason given. Leave uncommitted.

## Task 2: Caches, polling and refetch triggers (RED)

**Files:** `features/channels/useChannels.test.ts`, `features/channels/ChannelView.test.tsx`
(create); `lib/realtime/useChannelSocket.test.tsx` (modify)

**Interfaces** — produced for Tasks 6–8:

```ts
// useChannels.ts
export const CHANNEL_POLL_MS = 30_000
export interface ReadReceiptEvent { channelId: string; userId: string; messageId: string }
export function markChannelReadInCache(qc: QueryClient, workspaceId: string | null, channelId: string, messageId: string): void
export function cachedLastReadId(qc: QueryClient, workspaceId: string | null, channelId: string): string | null | undefined
export function applyReadReceipt(qc: QueryClient, workspaceId: string | null, event: ReadReceiptEvent, myUserId: string): void
// useMessages.ts
export function newestCachedMessageId(qc: QueryClient, key: readonly unknown[]): string | null | undefined
```

- `markChannelReadInCache` sets `lastReadId: messageId, unreadCount: 0` on the channel in the list
  entry (the raw `ChannelPage`, `{ items, nextCursor }`) and in the detail entry. Either absent →
  that one is left absent.
- `cachedLastReadId`: the detail entry's `lastReadId`, else the list entry's, else `undefined`.
- `newestCachedMessageId`: `undefined` with no entry; else the first non-`temp:` id in
  `pages[0].items` (newest first — `useMessages.ts:4-18`), or `null` if there is none.
- `applyReadReceipt`: ignore `event.userId !== myUserId`. If `newestCachedMessageId` for the
  event's channel is a string and `isAtOrAfter(event.messageId, it)` → `markChannelReadInCache`.
  Otherwise → `invalidateQueries(channelKeys.list(workspaceId))`.

| Test (`useChannels.test.ts`) | Proves | Expected red |
|---|---|---|
| `writes the marker and a zero count into the list and the detail` | R4 | `SyntaxError: … does not provide an export named 'markChannelReadInCache'` (whole file) |
| `leaves a channel with nothing cached uncached` | global constraint | same |
| `reads the cached marker from the detail, then the list` | `cachedLastReadId` | same |
| `writes the caches for a receipt at the newest cached message` · `… after it` | R6 first branch, both edges | same |
| `invalidates the list for a receipt older than the newest cached message` | R6 second branch | same |
| `invalidates the list for a receipt in a channel with no cached history` | R6 second branch | same |
| `ignores a pending message when finding the newest cached one` | decision 20 | same |
| `ignores someone else's receipt` | guard | same |
| `refetches the channel list every 30 seconds while the tab is visible` | R5 poll | same |
| `does not poll while the tab is hidden` | `refetchIntervalInBackground: false` | same |
| `refetches the channel list when the window regains focus` | decision 16 | same |

The polling tests render `useChannels` with `renderHookWithProviders` and count
`requests()` to `/api/v1/channels`. Use `vi.useFakeTimers({ toFake: ['setTimeout', 'clearTimeout',
'setInterval', 'clearInterval'] })` and `await vi.advanceTimersByTimeAsync(…)`, so MSW's promises
still resolve. Hide the tab with Task 3's `setAttention({ visible: false, focused: false })`, which
TanStack's `focusManager` reads through `document.visibilityState`.

| Test (`useChannelSocket.test.tsx`, new `describe('read state')`) | Proves | Expected red |
|---|---|---|
| `writes a read receipt that covers the cached history into the channel caches` | R6 routing | assertion: `unreadCount` still 3 |
| `refetches the channel list for a receipt older than the cached history` | R6 routing | assertion: list not invalidated |
| `refetches the channel list when the socket reconnects, not on the first connect` | R5, decision 17 | assertion: not invalidated after the second `serverConnect()` |

Seed with `seedHistory`-style helpers already in the file; the list with
`queryClient.setQueryData(channelKeys.list(WORKSPACE), { items: [...], nextCursor: null })`.

| Test (`ChannelView.test.tsx`) | Proves | Expected red |
|---|---|---|
| `refetches the channel list when the user switches channel` | R5, decision 18 | `waitFor` times out: no list request after the click |

Render `<ChannelList/>` and `<ChannelView/>` together with `{ route: '/c/A', path: '/c/:channelId' }`.
Stub the list (A and B), both details, their messages and members, and `auth.members`. Note the
count of list requests, click B's link, and wait for it to grow.

- [ ] Write the three files; run them; confirm each red as given. Leave uncommitted.

## Task 3: The read rule (RED)

**Files:** `test/attention.ts`, `features/channels/useMarkRead.test.tsx` (create)

**Interfaces:**

```ts
// test/attention.ts — a test helper, so the test-writer creates it
export function setAttention(state: { visible: boolean; focused: boolean }): void
// spies Document.prototype's `visibilityState` getter and `hasFocus`, then dispatches
// `visibilitychange` on document and `focus` or `blur` on window. Callers wrap it in act().

// features/channels/useMarkRead.ts — produced for Task 7
export function usePageAttention(): { visible: boolean; focused: boolean }
export function useMarkRead(options: {
  workspaceId: string | null
  channelId: string
  messages: readonly Message[]   // oldest first, as MessageList holds them
  atBottom: boolean
}): { beingRead: boolean }
// stores/chat.ts
readingChannelId: string | null
setReadingChannel: (channelId: string | null) => void
```

`useMarkRead`'s behaviour, which the tests pin:
- `beingRead = visible && focused && atBottom`. While true, `setReadingChannel(channelId)`; when it
  stops, or on unmount, clear it — only if it still holds this `channelId`.
- Whenever `beingRead`, `connectionStatus === 'connected'` (store) and `markTarget(messages)` is
  non-null — re-evaluated when any of the three changes — call
  `throttleFor(socket).request(channelId, attempt)`.
- `attempt`: return `false` if `socket` is null or `!socket.connected`, or the target equals
  `cachedLastReadId(...)`. Otherwise `socket.timeout(MARK_READ_ACK_TIMEOUT_MS).emit('mark_read',
  { channelId, messageId }, () => {})`, then `markChannelReadInCache(...)`, and return `true`.

Setup for every test: a `FakeSocket` passed as `socket` to `renderHookWithProviders`, with
`connected = true` and `useChatStore.setState({ connectionStatus: 'connected' })`; list and detail
caches seeded with `lastReadId: null, unreadCount: 2`; `onEmit('mark_read', () => ({ ok: true }))`;
`setAttention({ visible: true, focused: true })`. Change props through `rerender`.

| Test | Proves | Expected red |
|---|---|---|
| `marks read up to the newest message when visible, focused and at the bottom` | R2 | `Failed to resolve import "./useMarkRead"` |
| `marks nothing while the tab is hidden, and marks once it is shown` | R2 visibility | same |
| `marks nothing while the window lacks focus, and marks when it returns` | R2 focus | same |
| `marks nothing while scrolled back, and marks on reaching the bottom` | R2 scroll | same |
| `marks again when a new message arrives while being read` | R2 | same |
| `skips a pending message and marks the newest confirmed one` | R2 | same |
| `sends nothing when the newest id is already the cached marker` | R3 no-op | same |
| `sends one read a second, then the latest id` (fake timers) | R3 through the hook | same |
| `writes the marker and a zero count into the list and detail as it sends` | R4 | same |
| `sends nothing while disconnected and queues nothing` | R3 | same |
| `sends on reconnect when the rule holds` | R3 | same |
| `ignores an error ack: no retry` (responder returns `{ ok: false, problem: { status: 404 } }`) | R3 | same |
| `ignores an ack timeout: no retry` (no responder; advance 5s) | R3 | same |
| `reports the channel as being read, and clears it when the rule stops holding` | decision 10 | same |
| `still sends the trailing read after the channel is left` | decision 11 | same |

- [ ] Write both files; run; confirm the red. Leave uncommitted.

## Task 4: The badge and the divider (RED)

**Files:** `features/channels/ChannelList.test.tsx`, `features/channels/MessageList.test.tsx` (modify)

**Interfaces** — the rendered contract for Task 8:
- Badge, inside the channel's link, only when `unreadCount > 0` and the channel isn't
  `readingChannelId`: `<span data-testid="channel-unread-badge" data-count={shown}
  aria-label={`${shown} unread messages`}>{shown}</span>`, `shown = formatUnreadCount(count)`. The
  name gets `font-semibold`.
- `MessageList` gains `lastReadId: string | null` (the open channel's, from `ChannelView`).
- Divider, a sibling of the `article`s, directly before the one `dividerBefore` names:
  `<div role="separator" aria-label="New messages" data-testid="new-messages-divider">`, with
  visible text "New messages".

| Test (`ChannelList.test.tsx`) | Proves | Expected red |
|---|---|---|
| `shows how many messages are unread beside the channel` | R1, R8 label | no element labelled "3 unread messages" |
| `shows no count on a channel with nothing unread` | R1 | passes today — keep it: it guards the next one against vacuity |
| `caps the count at 99+` | R1, R8 | no element labelled "99+ unread messages" |
| `hides the count on the channel being read` | I-5 | fails on its positive half: the badge on the other channel isn't there either |
| `shows the count on the open channel while the user is scrolled back` | R1 | no labelled badge |

Set `readingChannelId` with `useChatStore.setState`; the route (`/c/{id}`) makes the channel active.

| Test (`MessageList.test.tsx`) | Proves | Expected red |
|---|---|---|
| `puts a New messages divider above the first message after the marker` | R7, R8 | no `separator` named "New messages" |
| `puts the divider after the user's own messages and any tombstone` | R7 | same |
| `puts no divider in a channel never read` | R7 | passes today — anchor it on a history that has messages |
| `shows the divider only once the page holding the marker is loaded` | R7, decision 14 | no separator after the older page loads |
| `keeps the divider where it was as the marker moves` | I-7 | no separator |
| `drops the divider after leaving the channel and coming back` | I-7 | no separator on the first render |
| `marks the channel read when it opens at its newest message` | R2 wired into the list | no `mark_read` in `socket.emitted` |

- Add `lastReadId` to `renderList` (default `null`), so the six existing tests still type-check and
  pass. Ids that must order are UUIDv7-shaped (Task 1). Scroll with `giveLayout` and
  `fireEvent.scroll`, as the file already does. The marking test uses `setAttention` and a
  connected socket, as in Task 3.
- [ ] Write; run; confirm the red. Leave uncommitted.

## Task 5: The journey (RED)

**Files:** `tests/bdd/features/read_state.feature`, `tests/bdd/steps/test_read_state_steps.py`
(create); `tests/bdd/pages/chat_page.py`, `tests/bdd/steps/conftest.py`,
`tests/bdd/steps/test_realtime_steps.py` (modify)

```gherkin
@bdd
Feature: Unread messages

  Every channel in the sidebar shows how many messages in it you have not read
  yet, so you can see where the conversation went while you were somewhere else.
  Your own messages never count. Reading a channel — having it open, in front of
  you and scrolled to its latest message — clears its count, in this window and
  in your others.

  The counts are checked again whenever you move to another channel, so what
  happened elsewhere shows up as soon as you look away from where you were.

  Background:
    Given Ada is signed in

  # One journey: a count appears in one browser for a message written in
  # another, and reading clears it. The cap, the read rule, the throttle, the
  # divider and the receipts are all proven in Vitest.
  Scenario: Grace sees a count for what she missed, and reading it clears the count
    Given Ada has created a public channel named "general"
    And Ada has created a public channel named "random"
    And Ada has created a public channel named "dev"
    And Grace is looking at the "general" channel
    When Ada sends "lunch at noon" in "random"
    And Grace opens the "dev" channel
    Then Grace sees 1 unread message in "random"
    When Grace opens the "random" channel
    Then Grace sees no unread messages in "random"
```

- **Reused verbatim:** `Given Ada is signed in`, `Given Ada has created a public channel named
  "{name}"`, `Given Grace is looking at the "{name}" channel`, `When Grace opens the "{name}"
  channel`.
- **New phrases**, in `test_read_state_steps.py`:
  - `When Ada sends "{body}" in "{channel}"` → `ada.open_channel(channel)`, then
    `ada.send_message_and_wait(body)`. It doesn't collide with `steps/conftest.py:124`: pytest-bdd
    8's `parsers.re` full-matches, and `[^"]*` can't cross a quote.
  - `Then Grace sees {count} unread message(s) in "{name}"` — use `parsers.re(r'Grace sees
    (?P<count>\d+) unread messages? in "(?P<name>[^"]*)"', converters={"count": int})`.
    It asserts `grace.has_unread_count(name, count)`, with `grace.channel_names()` as the message.
  - `Then Grace sees no unread messages in "{name}"` → `assert grace.has_no_unread(name)`.
- **Move** `Given Grace is looking at the "{name}" channel` (`test_realtime_steps.py:39-50`,
  docstring and all) into `steps/conftest.py`, and delete it from the realtime module (decision 21).
  `realtime.feature` must still pass unchanged.
- **Page object**, in a new `# --- unread counts ---` section:
  - `has_unread_count(name, count) -> bool`: settle, then a retrying `expect` that
    `self._channel_item(name).get_by_test_id("channel-unread-badge")` has `data-count == str(count)`.
  - `has_no_unread(name) -> bool`: settle, then a retrying `to_have_count(0)` on that badge.
- **Why no wait is needed, and why it isn't vacuous:** Ada's send is confirmed before Grace moves
  (`send_message_and_wait`). Grace's list loaded before it, so a `1` can only come from the switch
  refetch. The "no unread" assertion follows a positive `1` on the same badge (vocabulary ruling
  23).
- **Expected red:** `Then Grace sees 1 unread message in "random"` fails — `has_unread_count`
  returns `False`, because no `channel-unread-badge` exists. Run it with `scripts/test.sh e2e --
  -k read_state`. Every earlier step must pass; if one fails, the arrangement is wrong, not the
  feature.
- [ ] Write; `ruff check`/`ruff format` the Python; run `-k "read_state or realtime"`: realtime green,
  read_state red as given. Leave uncommitted.

**— Test-reviewer gate. No production code before approval. —**

## Task 6: Rules, throttle and caches (GREEN)

**Files:** `readState.ts`, `markRead.ts` (create); `useChannels.ts`, `useMessages.ts` (modify)

- [ ] `readState.ts` and `markRead.ts` to Task 1's interfaces. Each file opens with a docstring in
  the house style (see `reactions.ts`, `useTyping.ts`). Include the *why* of decisions 11, 12 and 14.
- [ ] `useChannels.ts`: the four exports from Task 2. `useChannels` gains:
  ```ts
  refetchInterval: CHANNEL_POLL_MS,
  refetchIntervalInBackground: false, // R5: a hidden tab polls nothing
  refetchOnWindowFocus: true,         // TanStack 5: fires on visibilitychange only…
  ```
  …and an effect that adds a `window` `focus` listener, which invalidates
  `channelKeys.list(workspaceId)` (decision 16), and removes it on cleanup.
- [ ] `useMessages.ts`: `newestCachedMessageId`, reading the raw pages (newest first), skipping
  `isPending`.
- [ ] Task 1 passes; `useChannels.test.ts` passes. Leave uncommitted.

## Task 7: The read rule, the store and the socket (GREEN)

**Files:** `stores/chat.ts`, `features/channels/useMarkRead.ts`, `lib/realtime/useChannelSocket.ts`

- [ ] `stores/chat.ts`: `readingChannelId` (initially `null`) and `setReadingChannel`. The comment
  says why it is client state: the server knows the marker, not whether you are looking.
- [ ] `useMarkRead.ts`: `usePageAttention` from `document.visibilityState` and `document.hasFocus()`,
  kept current by `visibilitychange` on `document` and `focus`/`blur` on `window`. `useMarkRead`
  to Task 3's behaviour. The socket comes from `useSocket()`, and the connection status from the
  store.
- [ ] `useChannelSocket.ts`: `live.on('read_receipt_updated', (e: ReadReceiptEvent) =>
  applyReadReceipt(queryClient, workspaceId, e, userId))`. In `onConnect`, after a previous
  connect in the same effect run (a closure flag), invalidate `channelKeys.list(workspaceId)`. Add
  a fifth rule to the file docstring: receipts either prove the cache current, or refetch.
- [ ] Tasks 2 and 3 pass. Leave uncommitted.

## Task 8: The badge, the divider and the wiring (GREEN)

**Files:** `ChannelList.tsx`, `MessageList.tsx`, `ChannelView.tsx`

- [ ] `ChannelList.tsx`: read `readingChannelId`; render Task 4's badge and bold name. Put the
  badge at the right of the row (`ml-auto`, a pill: `rounded-full px-1.5 text-xs`), and make it
  legible on the active row's `bg-accent`. Light palette tokens only (D26).
- [ ] `MessageList.tsx`: the `lastReadId` prop. Capture it per `channelId` with the render-time
  state pattern: store `{ channelId, lastReadId }`, and replace it when `channelId` differs. Add
  `atBottom` state beside `wasAtBottom` (decision 19), reset to `true` on a channel change. Call
  `useMarkRead({ workspaceId, channelId, messages, atBottom })`. Render the divider from
  `dividerBefore(messages, captured, userId)` as a keyed fragment sibling, so `article` order and
  the scroller's children stay as the existing tests expect.
- [ ] `ChannelView.tsx`: pass `lastReadId={channel.lastReadId}`. In the `channelId` effect,
  `void queryClient.invalidateQueries({ queryKey: channelKeys.list(workspaceId) })`.
- [ ] Task 4 passes; all of Vitest passes; `(cd src/frontend && npm run typecheck)` is clean. Then `scripts/test.sh e2e --
  -k "read_state or realtime"`. Leave uncommitted.

## Task 9: The record

- [ ] **Doc 06 §5.2**: replace the bullet at `06-frontend-spa.md:161` with "Throttle `typing`
  (leading edge — see *Typing* below); mark read as *Read state* below says". Add a **Read state —
  added 2026-09-30** block after *Typing*. It gives the read rule (R2), the throttle (decisions
  11–13), the local write (R4), polling and its four triggers (R5, decisions 16–18), receipt
  handling (R6), and the divider (R7, decisions 14, 15, 20). Point at the new ADR.
- [ ] **ADR**, with the `adr-writer` skill: `docs/adr/260930-unread-state-polls-rather-than-pushes.md`.
  Use the alternatives and the revisit trigger exactly as the issue's *Record in this slice* lists
  them.
- [ ] **`docs/adr/260915-read-state-follows-channel-visibility.md:96-99`**: replace the paragraph.
  The four count rules, the forward-only guard and the 404s are now covered by
  `src/services/messaging/tests/integration/test_read_state.py` (added in `f72b551`).
- [ ] Register: no change (I-10). Check that D31's row doesn't say the SPA ignores read state:
  `grep -n "D31" docs/design/07-open-decisions-register.md`.
- [ ] Sweep: `grep -rn "throttle \`mark_read\`\|mark_read\|unread" docs/design src/frontend/src` for
  anything that still says the SPA doesn't use them. Leave uncommitted.

## Task 10: Verification

- [ ] `scripts/test.sh lint unit`, then `scripts/test.sh e2e`: green. Vitest is 145 + this plan's
  tests or more, and end-to-end is 20 or more.
- [ ] `python3 .claude/hooks/checks/conventions.py $(git diff --name-only HEAD)` and
  `.claude/hooks/security.sh`.
- [ ] **First real run**, on Compose (`docker compose up -d --build`), with Ada and Grace in two
  browsers and a second Grace tab:
  1. Ada posts in a channel Grace isn't in. Grace's count shows within 30s, or at once when she
     switches channel or refocuses. Check that the name is bold.
  2. Grace opens it. The divider sits above Ada's first new message, the badge clears, and Grace's
     second tab clears without a reload. **Reload Grace** — the count stays clear, which proves
     the server's marker moved.
  3. Grace scrolls back while Ada posts: the badge returns on the next refresh, and clears when
     she scrolls to the bottom.
  4. Headless check: if the journey's last step ever fails because the page reports no focus, the
     fix belongs in `ChatPage.open()` (`page.bring_to_front()`), not in the app. Playwright
     emulates focus in Chromium, so it shouldn't happen.

  Expect this run to find something the tests didn't. Fix it with a test, and record it below.
- [ ] If a sibling branch merged meanwhile, merge `main` and rerun the above.
- [ ] Fill in *Found while building*. Leave the worktree dirty and report.

## Found while building

*Filled in by the code-writer: every deviation from this plan, and every bug the first real run
found, each with the test that now pins it down. Empty until then.*

## Not in this plan

Everything in the issue's *Not in this issue*: push for background channels, a "↓ N new" pill,
opening at the first unread, tab title or favicon counts, cross-workspace badges, mentions, "mark
all as read", DM behaviour, a server-side cap.

## Self-review

- **Issue coverage:** R1 → Tasks 1, 4, 8 · R2 → 1, 3, 4, 7, 8 · R3 → 1, 3, 6, 7 · R4 → 2, 3, 6, 7 ·
  R5 → 2, 6, 7, 8 · R6 → 2, 6, 7 · R7 → 1, 4, 8 · R8 → 4, 5, 8 · the journey → 5 · *Record in this
  slice* → 9.
- **Names:** `markChannelReadInCache`, `cachedLastReadId`, `applyReadReceipt`,
  `newestCachedMessageId`, `ReadReceiptEvent`, `readingChannelId`/`setReadingChannel`,
  `throttleFor`, `MARK_READ_INTERVAL_MS`, `CHANNEL_POLL_MS`, `channel-unread-badge`,
  `new-messages-divider` — each spelled one way throughout.
- **Known ripple:** `MessageList`'s new required prop touches its existing test helper (Task 4) and
  `ChannelView` (Task 8). Moving the Grace `Given` touches `test_realtime_steps.py` (Task 5).
- **Review focus** — the conditions most likely to bite, each pinned by a test:
  a trailing read after leaving the channel (Task 3) · a receipt landing while history is cached
  but stale (Task 2) · the divider when the boundary isn't loaded (Tasks 1, 4) · reconnect after a
  read was dropped while down (Task 3) · a poll landing while the open channel is being read — the
  badge stays hidden by `readingChannelId`, not by the count (Task 4).
