# Unread counts and read markers in the SPA — implementation plan

> **For agentic workers:** this plan is executed by `scripts/deliver.sh`: the test-writer does every
> RED task, the code-writer every GREEN one. Three project rules override the superpowers skills.
> **Never commit** — every task ends with the worktree dirty. **Red first** — no production code
> until the test-reviewer has approved the failing tests. **Plans live in `docs/plans/`.**

**Goal:** The sidebar shows each channel's unread count, reading a channel clears it (here and in the
user's other tabs), and opening a channel with unread messages shows a "New messages" divider.

**Architecture:** SPA only. Pure rules and cache writers live in one module (`readState.ts`); a
per-socket, per-channel throttle (`readThrottle.ts`) sends `mark_read`; a `useReadMarker` hook in
`MessageList` decides when the open channel is *being read* and publishes that as client state
(`readingChannelId` in Zustand) so the sidebar can hide the open channel's badge. Counts come from
the server only — the list query polls every 30s, and refetches on focus, reconnect and channel
switch. `read_receipt_updated` writes the caches or invalidates the list.

**Tech Stack:** React 19, TypeScript, TanStack Query, Zustand, socket.io-client, Tailwind v4 ·
Vitest + MSW + `FakeSocket` · pytest-bdd + Playwright.

**Issue:** `docs/plans/issue-1/00-issue.md` — read it first. This plan argues from it and does not
repeat it. Requirement numbers below (R1–R8) are the issue's.

**Worktree:** `../caw-issue-1`, branch `feature/issue-1`, from `main` at `39b3a5c`.

## Decisions

Decided by the issue:

| # | Question | Answer |
|---|---|---|
| 1 | Scope | R1–R8; *Not in this issue* stays out |
| 2 | What "read" means | Visible, focused and within `STICK_THRESHOLD` (80px) of the bottom |
| 3 | The marker target | Newest non-pending loaded message, own messages and tombstones included |
| 4 | Transport | Socket `mark_read`, ≤ 1 per channel per second, latest id wins; REST unused |
| 5 | Badge | Pill, `99+` above 99, bold name; hidden on the open channel only while it is being read |
| 6 | After a read | Write list and detail caches directly, no refetch |
| 7 | Divider | Fixed at open-time, follows the server's unread rule |
| 8 | Background counts | Polling (30s visible-only) + focus, reconnect, channel switch |
| 9 | Open-channel indicator | None |
| 10 | Register | D31 (🟢) covers the data; nothing settled, no 🔴 depended on |

Taken in this plan — each needs the plan-reviewer's yes or no:

| # | Question | Answer | Why, and the alternative |
|---|---|---|---|
| 11 | Throttle edge | **Leading and trailing**: the first read in an idle channel emits at once; reads inside the 1s window are held and the *latest* goes out when it ends | Decision 4 says "trailing edge" meaning the latest id wins (R3). A pure trailing throttle delays every read by 1s and makes the badge lag a click. `useTyping.ts:8-11` already leads, for the same reason |
| 12 | Where the throttle lives | One per socket, from a `WeakMap<Socket, ReadThrottle>` in `lib/realtime/readThrottle.ts` | `ChannelView` renders "Loading…" while the next channel's detail loads (`ChannelView.tsx:47-53`), which unmounts `MessageList` — a throttle held there would drop the trailing read of the channel just left. Alternative: a React context beside `SocketProvider`, more plumbing for the same lifetime |
| 13 | The emit | `socket.emit('mark_read', { channelId, messageId })` with **no ack callback** | R3 ignores every ack outcome, so a callback would be code that does nothing. `emit` on a disconnected socket buffers, so the send checks `socket.connected` first (R3: queue nothing) |
| 14 | When the divider is placed | Decided **once the boundary is loaded** (a loaded message with id ≤ the captured `lastReadId`, or no older page left), then frozen for the visit — including "no divider". A message arriving live never creates one | Decision 7 "fixed at open-time". Re-evaluating every render would put a divider above Ada's next live message whenever Grace opened a fully read channel. Covers R7's "appears once scrolling back loads it" |
| 15 | Sharing "being read" | Zustand `readingChannelId: string \| null` | Sidebar and message list are siblings under `ChatLayout`. It is client state (a fact about the window), so D24 allows it; no channel data goes in the store |
| 16 | Capturing `lastReadId` | `MessageList` gets a `lastReadId` prop from `ChannelView` and captures it once per `channelId` in a ref | `ChannelView` stays mounted across channels (`App.tsx:103-136`, no `key`), so a ref keyed by channel id is the reset R7 needs ("gone when they leave and come back") |
| 17 | Refresh on reconnect / switch | Reconnect: `useChannelSocket`'s `connect` handler invalidates the list on every connect **after the first**. Switch: new `useChannelListRefresh(workspaceId, activeChannelId)` in `useChannels.ts`, called by `ChatLayout`, invalidates when the active id changes to a different non-null id, not on first render | The first connect and first render coincide with the list's own first fetch; invalidating then cancels and repeats it. `ChannelView` sets `null` then the new id on each switch (`ChannelView.tsx:32-35`), so reacting to `null` would refetch twice |
| 18 | A list refetch in flight when a read is written | `markChannelRead` re-applies its write when that fetch lands, **only if** the fetched `lastReadId` is null or sorts before the written id | Otherwise a refetch started by the channel switch lands with the pre-read count and the badge comes back until the next poll. Same idea as `reapplyAfterFetch` (`useChannelSocket.ts:81-90`). Alternative: `cancelQueries` — loses the refetch entirely |
| 19 | Attention | `document.visibilityState === 'visible' && document.hasFocus()`, re-read on `visibilitychange`, `focus` and `blur` | The two browser facts R2 names; no library |
| 20 | Badge `data-count` | The text shown (`"99+"` above 99) | R8: "holding the number shown" |

**Register.** Nothing here touches a 🔴 entry. Nearest: **D28** (per-user preferences) — muting a
channel or hiding badges would need it; this adds no per-user setting and stores nothing but the
server's own marker. **D16** (tombstone retention) — tombstones may be marked read and are skipped by
the divider, but nothing here keeps or deletes one.

## Corrections to the issue

None to the requirements. Two stale statements the record task fixes: doc 06 §5.2 already says the
SPA subscribes to `read_receipt_updated` (`06-frontend-spa.md:159-161`) — it does not until Task 6;
and `giveLayout()` is a local helper in `MessageList.test.tsx:52`, not a shared one, so only tests in
that file can use it.

## Test approach — recommendation to the test pair

**BDD outside-in, with one journey.** This is a new capability every user sees in the sidebar, and
only a real browser against the real server proves that a message Ada writes becomes a count in
Grace's sidebar and that Grace reading it clears it. Write the journey first; everything under it
goes down the pyramid to Vitest. The server contract is already proven by Messaging's
`test_read_state.py` and `test_realtime*.py`, so no Python test is added.

| Behaviour | Layer | File |
|---|---|---|
| Ada posts in #random; Grace, switching channel, sees a badge; opening #random clears it | **BDD** | `tests/bdd/features/read_state.feature` |
| Badge text and `99+`; the marker target; divider placement; cache writes; receipt branches | Vitest (pure) | `features/channels/readState.test.ts` |
| Throttle: leading send, latest-wins trailing, per channel, per socket | Vitest (pure, fake timers) | `lib/realtime/readThrottle.test.ts` |
| The read rule (visibility, focus, scroll), no-op on equal id, disconnect/reconnect, cache write on emit | Vitest (hook) | `features/channels/useReadMarker.test.tsx` |
| Scroll position drives the rule; the divider renders, stays put, resets | Vitest (component) | `features/channels/MessageList.test.tsx` |
| Badge render, `aria-label`, hidden while being read | Vitest (component) | `features/channels/ChannelList.test.tsx` |
| Poll every 30s, paused when hidden, refetch on focus and on switch | Vitest (hook) | `features/channels/useChannels.test.tsx` |
| Receipt handling; list refetch on reconnect | Vitest (hook) | `lib/realtime/useChannelSocket.test.tsx` |

**What no test covers:** the bold channel name (a style — checked in the first real run, Task 8);
that the server received a `mark_read` in the journey (the badge clearing while being read is R1's
hide rule, so the journey cannot tell; the emit is proven in Vitest and the server's handling in
Messaging's integration suite); a second tab clearing without reload (the BDD harness has one page
per person — covered by the receipt tests and the first real run).

**Baseline**, from `docs/test-report.md` at `e4d3396`: frontend Vitest 145 passed; end-to-end 19
passed; Messaging unit 94, integration 211 (untouched here). Expected after: Vitest 200 or more,
end-to-end 20 or more — "or more", because a sibling branch may land first.

## Global constraints

- **TanStack Query owns every channel and message** (D24). The store gains `readingChannelId` only.
- **Vitest queries by role, label or text** — never a `data-testid`. `data-testid` and `data-count`
  are for `tests/bdd`'s page object, and a BDD step never contains a selector.
- **MSW stubs are typed from `src/types/messaging.ts`** (`test/api.ts`); no regeneration is needed —
  `Channel` already has `lastReadId` and `unreadCount`.
- **UUIDv7 ids compare as strings in time order — server ids only.** `temp:` ids sort *after* every
  UUID (`t` > any hex digit), so every comparison skips pending messages first.
- The divider and the badge are light-palette Tailwind classes (D26); no new colour tokens.
- No backend, chart, compose, env var or script change. Everything else is as CLAUDE.md says; the
  lint hook runs eslint on every `.ts`/`.tsx` touched.

## Review focus

The failure modes most likely to bite a person that the spec implies without testing:

1. A `temp:` id taken as "newest" — marks read an id the server 404s, or compares above everything.
   Pinned by `readTarget` and `applyReadReceipt` tests in Task 1.
2. A list refetch in flight when the read is written brings the badge back. Task 1, decision 18.
3. Leaving a channel inside the throttle window loses the trailing read. Task 2, decision 12.
4. A channel opened with only the reader's own messages, or empty — no emit, no divider. Tasks 1, 3.
5. A workspace switch with a read pending — the old socket is closed, so nothing goes out on it.
   Task 3's disconnect test and Task 2's per-socket test.

## File map

Paths under `src/frontend/src/` unless they start `tests/` or `docs/`.

| File | Change | Responsibility | Task |
|---|---|---|---|
| `features/channels/readState.test.ts` | create | pure rules and cache writers | 1 |
| `lib/realtime/readThrottle.test.ts` | create | the throttle | 2 |
| `test/attention.ts` · `test/setup.ts` | create · modify | `setAttention` / `resetAttention`; reset after each test | 3 |
| `features/channels/useReadMarker.test.tsx` | create | the read rule | 3 |
| `features/channels/MessageList.test.tsx` | modify | scroll → rule; divider; **`renderList` gains `lastReadId`** | 3 |
| `features/channels/ChannelList.test.tsx` | modify | badge | 3 |
| `features/channels/useChannels.test.tsx` | create | polling and switch refresh | 3 |
| `lib/realtime/useChannelSocket.test.tsx` | modify | receipts; reconnect refresh | 3 |
| `tests/bdd/features/read_state.feature` · `steps/test_read_state_steps.py` | create · create | the journey | 4 |
| `tests/bdd/steps/conftest.py` · `steps/test_realtime_steps.py` | modify · modify | **move** `Given Grace is looking at the "{name}" channel` into the shared steps | 4 |
| `tests/bdd/pages/chat_page.py` | modify | `has_unread_count`, `has_no_unread_badge` | 4 |
| `features/channels/readState.ts` | create | Task 1's interface | 5 |
| `lib/realtime/readThrottle.ts` | create | Task 2's interface | 5 |
| `stores/chat.ts` | modify | `readingChannelId`, `setReadingChannel` | 6 |
| `features/channels/useReadMarker.ts` | create | attention, rule, submit | 6 |
| `features/channels/MessageList.tsx` · `ChannelView.tsx` | modify · modify | `atBottom` state, hook, divider; pass `lastReadId` | 6 |
| `features/channels/ChannelList.tsx` | modify | badge, bold name | 6 |
| `features/channels/useChannels.ts` · `ChatLayout.tsx` | modify · modify | poll options, `useChannelListRefresh`, called from the layout | 6 |
| `lib/realtime/useChannelSocket.ts` | modify | `read_receipt_updated`; list refresh on reconnect | 6 |
| `docs/design/06-frontend-spa.md` · `docs/adr/<yymmdd>-unread-state-polls-rather-than-pushes.md` · `docs/adr/260915-read-state-follows-channel-visibility.md` | modify · create · modify | the record | 7 |

Deliberately unchanged: `tests/bdd/conftest.py` — its truncation already lists `channel_reads`
(`conftest.py:64`), so every scenario starts with no markers. `lib/api/messaging.ts`,
`openapi/messaging.json`, `types/messaging.ts`, `test/factories.ts` — the contract is already there.
`stores/chat.test.ts` — it asserts fields one at a time, so a new field breaks nothing.
`docs/design/07-open-decisions-register.md` — settles nothing (decision 10).

## How this plan runs

| Phase | Tasks | Who | Ends with |
|---|---|---|---|
| **RED** | 1–4 | test-writer | failing Vitest and BDD tests, each failing for the reason given — **test-reviewer gate** |
| GREEN — rules | 5 | code-writer | Tasks 1–2 pass |
| GREEN — wiring | 6 | code-writer | Task 3 passes, `tsc` clean, then the journey |
| Finish | 7–8 | code-writer | the record, then verification |

One RED phase: every type the tests need already exists in the generated schema. Until Task 5/6,
`tsc` is red for the same reason as the tests (missing modules, a missing `lastReadId` prop).

---

## Task 1: Rules and cache writers (RED)

**Files:** `features/channels/readState.test.ts` (create)

**Interfaces** — produces the contract Task 5 implements, in `features/channels/readState.ts`:

```ts
export const UNREAD_DISPLAY_CAP = 99
/** null for 0; "1".."99"; "99+" above 99. */
export function badgeText(unreadCount: number): string | null
/** Messages oldest-first (useMessages' select order). Newest id not starting "temp:"; null if none. */
export function readTarget(messages: Message[]): string | null
/**
 * The id of the message the divider sits above; null = decided, no divider;
 * undefined = undecided (boundary older than the loaded pages).
 * null lastReadId → null. Boundary loaded ⇔ reachedStart || some loaded id <= lastReadId.
 * Qualifies: id > lastReadId, authorId !== userId, deletedAt === null, not pending.
 */
export function placeDivider(
  messages: Message[], lastReadId: string | null, userId: string, reachedStart: boolean,
): string | null | undefined
/** lastReadId from the cached list, else the cached detail; undefined when neither is cached. */
export function cachedLastReadId(qc: QueryClient, workspaceId: string | null, channelId: string): string | null | undefined
/** Writes { lastReadId: messageId, unreadCount: 0 } into channelKeys.list (a ChannelPage) and
 *  channelKeys.detail (a Channel). No-op on an absent entry. Decision 18 on an in-flight list fetch. */
export function markChannelRead(qc: QueryClient, workspaceId: string | null, channelId: string, messageId: string): void
export interface ReadReceiptEvent { channelId: string; userId: string; messageId: string }
/** R6: newest *non-pending* cached message of messageKeys.list(ws, event.channelId);
 *  cached and event.messageId >= it → markChannelRead; else invalidate channelKeys.list(ws). */
export function applyReadReceipt(qc: QueryClient, workspaceId: string | null, event: ReadReceiptEvent): void
```

Note the list cache holds the raw `ChannelPage` (`{ items, nextCursor }`) — `useChannels`' `select`
maps it — and the message cache holds `InfiniteData<MessagePage>` newest-first
(`useMessages.ts:4-18`). Seed both with `queryClient.setQueryData`, as `useChannelSocket.test.tsx:44`
does. Use `aChannel()` / `aMessage()`; build ordered ids with fixed UUIDv7-shaped strings
(`0199a000-0000-7000-8000-00000000000N`) so the order is explicit, never from `crypto.randomUUID()`.

| Test | Proves | Expected red |
|---|---|---|
| `shows no badge for a read channel` | 0 → `null` | `Failed to resolve import "./readState"` |
| `shows the exact count up to 99` | 1 → `"1"`, 99 → `"99"` | same |
| `caps the display at 99+ above 99` | 100 and 5000 → `"99+"` | same |
| `targets the newest confirmed message` | last non-pending id | same |
| `skips an optimistic temp: message at the live end` | `temp:` never the target | same |
| `targets the reader's own message and a tombstone` | R2 includes both | same |
| `targets nothing when only pending messages are loaded` | `null` | same |
| `puts the divider above the first newer message someone else wrote` | the basic rule | same |
| `skips the reader's own newer messages` | author rule | same |
| `skips a newer tombstone` | deleted rule | same |
| `places no divider in a channel never read` | null marker → `null` | same |
| `places no divider when nothing newer qualifies` | `null`, not `undefined` | same |
| `leaves the divider undecided while the boundary is older than the loaded pages` | `undefined` | same |
| `decides the divider once the oldest page is in` | `reachedStart` true → the first qualifying id | same |
| `writes the marker and a zero count into the cached list and detail` | R4 | same |
| `leaves the other channels in the list alone` | only one row changes | same |
| `creates no cache entry for a channel list that is not cached` | no-op on absent | same |
| `keeps the read when a list refetch in flight lands with the old count` | decision 18: hold a list fetch with `fetchQuery` + a pending promise (`holdHistoryFetch` pattern, `useChannelSocket.test.tsx:57-84`), write, release with `unreadCount: 3, lastReadId: null`; expect 0 | same |
| `clears the count when a receipt reaches the newest cached message` | R6 branch one | same |
| `invalidates the list when a receipt is older than the newest cached message` | R6 branch two (`getQueryState(...).isInvalidated`) | same |
| `invalidates the list when the channel's messages are not cached` | R6 branch two | same |
| `ignores a pending message when finding the newest cached` | a `temp:` head must not force the invalidate branch | same |

- [ ] Write the tests, one-line comment each saying what breaks if the rule goes. Run
  `(cd src/frontend && npx vitest run src/features/channels/readState.test.ts)`: every test fails
  on the missing import. Leave uncommitted.

## Task 2: The throttle (RED)

**Files:** `lib/realtime/readThrottle.test.ts` (create)

**Interfaces** — in `lib/realtime/readThrottle.ts`:

```ts
export const MARK_READ_INTERVAL_MS = 1000
export interface ReadThrottle {
  /** Idle channel: call send(messageId) now and open a window. In a window: remember
   *  (messageId, send), replacing any earlier one. Window end: call the remembered send with
   *  the remembered id and open a new window; nothing remembered → the channel goes idle. */
  submit(channelId: string, messageId: string, send: (messageId: string) => void): void
  /** Clear every timer and remembered send. */
  cancel(): void
}
export function createReadThrottle(intervalMs?: number): ReadThrottle
/** The same throttle for the same socket, for the socket's lifetime (WeakMap). */
export function readThrottleFor(socket: Socket): ReadThrottle
```

`vi.useFakeTimers()`; `send` is a `vi.fn()`.

| Test | Proves | Expected red |
|---|---|---|
| `sends the first read in an idle channel at once` | leading edge (decision 11) | `Failed to resolve import "./readThrottle"` |
| `sends only the latest id held during the window, when it ends` | R3: three submits in 1s → calls `[a]`, then `[c]` at 1000ms | same |
| `sends nothing at the window's end when nothing new was submitted` | no duplicate of the leading send | same |
| `throttles each channel on its own` | two channels, both lead at once | same |
| `still sends the held read after the channel is left` | Review focus 3: submit twice, advance, second send fires with no further submits | same |
| `drops held reads when cancelled` | `cancel()` | same |
| `gives one throttle per socket` | `readThrottleFor(a) === readThrottleFor(a)`, `!== readThrottleFor(b)` (two `asSocket(new FakeSocket(...))`) | same |

- [ ] Write, run, see each fail on the import. Leave uncommitted.

## Task 3: The read rule, the components and the socket (RED)

**Files:** `test/attention.ts` (create), `test/setup.ts` (modify), `useReadMarker.test.tsx` (create),
`MessageList.test.tsx`, `ChannelList.test.tsx`, `useChannelSocket.test.tsx` (modify),
`useChannels.test.tsx` (create)

**Test helper** — `test/attention.ts`, test infrastructure the test-writer owns:

```ts
/** Stub document.visibilityState and document.hasFocus(), then dispatch visibilitychange on
 *  document and focus|blur on window, inside act(). */
export function setAttention(state: { visible: boolean; focused: boolean }): void
/** Remove both stubs. setup.ts calls it in afterEach. */
export function resetAttention(): void
```

Existing tests never call `setAttention`, and their `FakeSocket` is never connected, so nothing they
do emits `mark_read` — they stay green without change except `renderList`'s new prop.

**Interfaces** consumed from Task 6:

```ts
// features/channels/useReadMarker.ts — reads useSocket(), useQueryClient(), the store.
export function useReadMarker(args: {
  workspaceId: string | null; channelId: string; messages: Message[]; atBottom: boolean
}): boolean                                   // true while the channel is being read
// stores/chat.ts
readingChannelId: string | null; setReadingChannel: (channelId: string | null) => void
// features/channels/useChannels.ts
export const CHANNEL_POLL_MS = 30_000
export function useChannelListRefresh(workspaceId: string | null, activeChannelId: string | null): void
// MessageList gains a prop:  lastReadId: string | null
```

**What `useReadMarker` does** (the tests pin it): being read ⇔ attention (decision 19) ∧ `atBottom`.
While being read, `setReadingChannel(channelId)`, else `null` (and `null` on unmount or channel
change). While being read with `target = readTarget(messages)` non-null and
`target !== cachedLastReadId(...)`, it submits to `readThrottleFor(socket)`; re-evaluated on every
change of attention, `atBottom`, target, and on the socket's `connect` event. The `send` it passes:
return if `!socket.connected` or the id equals the cached `lastReadId`; otherwise
`socket.emit('mark_read', { channelId, messageId })` then `markChannelRead(...)`.

`useReadMarker.test.tsx` — `renderHookWithProviders` with a `FakeSocket` passed as `socket` and
`serverConnect()`ed; list and detail seeded; `setAttention({ visible: true, focused: true })` unless
the test says otherwise. Emits read from `socket.emitted`.

| Test | Proves | Expected red |
|---|---|---|
| `marks read up to the newest message when visible, focused and at the bottom` | R2 | import of `./useReadMarker` fails |
| `does not mark read while the document is hidden` | R2 visibility | same |
| `does not mark read while the window is unfocused` | R2 focus | same |
| `does not mark read while scrolled back` | R2 scroll (`atBottom: false`) | same |
| `marks read when the window regains focus` | "whenever it becomes true" | same |
| `marks read again when a new message arrives while being read` | R2; fake timers, second emit after the window | same |
| `sends the latest id when the throttle window ends, not the first` | R3 through the hook | same |
| `sends nothing when the newest message is already the cached marker` | R3 no-op | same |
| `sends nothing while disconnected, and does not send it later on its own` | R3 queue nothing; advance 5s | same |
| `sends on reconnect when the channel is still being read` | R3; `serverDisconnect()` then `serverConnect()` | same |
| `never retries a read the server did not acknowledge` | R3; no responder, advance 10s, one emit | same |
| `writes the read into the cached list and detail as it emits` | R4 | same |
| `reports the channel as being read, and stops when it is not` | store `readingChannelId` follows the rule | same |
| `emits nothing for a channel whose only messages are pending` | Review focus 4 | same |

`MessageList.test.tsx` (modify). `renderList` passes `lastReadId={null}` by default and takes an
override; use a connected `FakeSocket` in the read tests, `giveLayout()` for scroll.

| Test | Proves | Expected red |
|---|---|---|
| `marks the channel read when it opens at its live end` | wiring: `mark_read` with `newest.id` | no emit (`toContainEqual` fails); `tsc`: unknown prop `lastReadId` |
| `stops marking read when scrolled back, and marks read on returning to the bottom` | `atBottom` follows `onScroll`; seed marker = newest, scroll up, message arrives, no emit; scroll down, emit | same |
| `shows a New messages divider above the first message someone else wrote since the marker` | R7, R8: `getByRole('separator', { name: 'New messages' })` directly precedes that `article` | no separator |
| `keeps the divider where it was as the marker moves on` | decision 14: rerender with `lastReadId={newest.id}` | same |
| `shows no divider in a channel the reader has never read` | R7 null | passes vacuously today — **assert the history rendered first** (`findByText`) so it is a real check; it is a guard, and is expected to stay green |
| `shows the divider once scrolling back loads the boundary` | R7 not loaded → appears after `fetchNextPage` | no separator after scroll |
| `drops the divider after leaving the channel and coming back` | R7 reset: rerender other channel, then back with the moved marker | separator still present is impossible today; fails on the first `getByRole` |

`ChannelList.test.tsx` (modify) — seed `unreadCount` through `aChannel()`:

| Test | Proves | Expected red |
|---|---|---|
| `shows how many messages are unread beside each channel` | R1: `getByLabelText('3 unread messages')` with text `3` | not found |
| `shows no count for a channel with nothing unread` | R1 | guard; assert the link rendered first |
| `shows 99+ above 99` | R1, R8: label `99+ unread messages` | not found |
| `hides the open channel's count while it is being read` | R1: `useChatStore.setState({ readingChannelId })`; asserts the *other* channel's count shows as well, so absence is anchored | the other channel's count is not found |
| `shows the open channel's count while its reader is scrolled back` | R1: `activeChannelId` set, `readingChannelId` null | not found |

`useChannels.test.tsx` (create) — `vi.useFakeTimers({ shouldAdvanceTime: true })`,
`vi.advanceTimersByTimeAsync`, `focusManager` from `@tanstack/react-query` (reset with
`focusManager.setFocused(undefined)` after each), requests counted with `requests()`:

| Test | Proves | Expected red |
|---|---|---|
| `refetches the channel list every 30 seconds` | R5 | one request, not two |
| `stops polling while the tab is hidden` | R5: `focusManager.setFocused(false)`, advance 60s, no request | guard today — fails once the interval exists without the pause; write it anyway |
| `refetches the channel list when the window regains focus` | R5 | passes today (TanStack default) — kept as a guard against someone setting `refetchOnWindowFocus: false` |
| `refetches the channel list when a different channel opens` | R5 switch (`useChannelListRefresh`) | import fails |
| `does not refetch on first render or when the channel closes` | decision 17 | import fails |

`useChannelSocket.test.tsx` (modify), new `describe('read state')`:

| Test | Proves | Expected red |
|---|---|---|
| `clears the channel's count when another tab has read to the newest message` | R6 via the event | count still 3 |
| `refetches the channel list when another tab's read is older than what is cached` | R6 other branch | not invalidated |
| `ignores a receipt for someone else` | defensive `userId` check | guard (passes today); keep |
| `refetches the channel list on reconnect, not on the first connect` | R5, decision 17 | not invalidated |

- [ ] Write `attention.ts`, wire `resetAttention` into `setup.ts`'s `afterEach`, then the tests.
- [ ] Run `(cd src/frontend && npx vitest run)`: the new tests fail for the reasons above; the tests
  marked *guard* pass and say so in a comment; every pre-existing test still passes except where
  `tsc` refuses `lastReadId` (Vitest does not type-check, so they run). Leave uncommitted.

## Task 4: The journey (RED)

**Files:** `tests/bdd/features/read_state.feature`, `tests/bdd/steps/test_read_state_steps.py`
(create); `steps/conftest.py`, `steps/test_realtime_steps.py`, `pages/chat_page.py` (modify)

```gherkin
@bdd
Feature: Read state

  Every channel in the sidebar says how many messages in it you have not read,
  counting only what other people wrote. Reading a channel — looking at its latest
  messages in a window you are using — clears the count.

  Background:
    Given Ada is signed in

  # The one journey a browser is needed for: a message in one person's window
  # becoming a count in another's sidebar, and reading clearing it. The read rule,
  # the throttle, the divider and receipts from other tabs are proven in Vitest.
  Scenario: Grace sees a count for a channel Ada posted in, and reading it clears the count
    Given Ada has created a public channel named "general"
    And Ada has created a public channel named "random"
    And Ada has created a public channel named "dev"
    And Grace is looking at the "general" channel
    When Ada opens the "random" channel
    And Ada sends "lunch at noon?"
    And Grace opens the "dev" channel
    Then Grace sees 1 unread message on "random"
    When Grace opens the "random" channel
    Then Grace sees "lunch at noon?" in the channel
    And Grace sees no unread messages on "random"
```

- Ada's send comes **after** Grace has loaded (vocabulary ruling 9), so the count can only reach
  Grace through the switch refetch — R5, not the 30s poll and not the first load.
- Every phrase is existing vocabulary except the two `Then … on "{name}"` steps, which go in
  `test_read_state_steps.py`. The last one is anchored on `Grace sees "lunch at noon?"` (ruling 23).
- **Move** `Given Grace is looking at the "{name}" channel` from `test_realtime_steps.py:39-53` into
  `steps/conftest.py`, docstring and all, and delete it from the realtime module: pytest-bdd does not
  resolve steps from a sibling `test_*` module (`steps/conftest.py:3-7`). `realtime.feature` must
  still pass unchanged.
- Page object: `has_unread_count(name: str, count: int) -> bool` — `_settle()`, then `_holds` on
  `expect(self._channel_item(name).get_by_test_id("unread-badge")).to_have_attribute("data-count",
  str(count))`; `has_no_unread_badge(name: str) -> bool` — `to_have_count(0)` on the same locator.
  The badge sits inside the `channel-list-item` link (Task 6).
- Expected red: the scenario fails at `Then Grace sees 1 unread message on "random"` — the
  assertion returns False because no `unread-badge` exists. Not on an undefined step, not in
  setup. Run `scripts/test.sh e2e -- -k read_state` and `-k realtime` (the moved step).
- [ ] Leave uncommitted.

## Task 5: Rules and throttle (GREEN)

**Files:** `features/channels/readState.ts`, `lib/realtime/readThrottle.ts`

- [ ] `readState.ts` to Task 1's interface. Every comparison filters `isPending` (from
  `useMessages.ts:162`) before comparing ids. `markChannelRead` uses `setQueryData` updaters that
  return the input unchanged when it is `undefined` (the `upsertMessage` rule, `useMessages.ts:102-113`);
  decision 18 subscribes to the query cache for the list key while `isFetching` is non-zero and
  re-writes once it is idle and successful, if the landed row's `lastReadId` is null or `< messageId`.
- [ ] `readThrottle.ts` to Task 2's interface: a `Map<channelId, { timer, held? }>` per instance;
  `readThrottleFor` keeps a module-level `WeakMap<Socket, ReadThrottle>`.
- [ ] Tasks 1–2: 29 passed. Leave uncommitted.

## Task 6: Wiring (GREEN)

- [ ] `stores/chat.ts`: `readingChannelId` (initially `null`) and `setReadingChannel`, with a doc
  comment saying it is a fact about the window, not server state.
- [ ] `useReadMarker.ts` as described in Task 3. Module doc comment: the rule, why the throttle is
  per socket (decision 12), and why there is no ack callback (decision 13).
- [ ] `MessageList.tsx`: `atBottom` state beside the `wasAtBottom` ref, set in `onScroll` only when
  it changes, reset to `true` in the `channelId` effect; call `useReadMarker`; capture `lastReadId`
  once per `channelId` in a ref, and freeze the result of
  `placeDivider(messages, captured, userId, !hasNextPage)` the first time it is not `undefined`
  (decision 14); render before that message:
  `<div role="separator" aria-label="New messages" data-testid="new-messages-divider">New messages</div>`.
  `ChannelView.tsx` passes `lastReadId={channel.lastReadId}`.
- [ ] `ChannelList.tsx`: `badgeText(channel.unreadCount)`, hidden when
  `channel.id === readingChannelId`; the pill is
  `<span data-testid="unread-badge" data-count={text} aria-label={`${text} unread messages`}>{text}</span>`
  inside the `NavLink`, and the name is `font-semibold` when the pill shows.
- [ ] `useChannels.ts`: `refetchInterval: CHANNEL_POLL_MS`, `refetchIntervalInBackground: false`,
  `refetchOnWindowFocus: true` (explicit, so the guard test documents it);
  `useChannelListRefresh` per decision 17; `ChatLayout.tsx` calls it with `activeChannelId`.
- [ ] `useChannelSocket.ts`: `live.on('read_receipt_updated', …)` → ignore another `userId`, else
  `applyReadReceipt`; in `onConnect`, invalidate `channelKeys.list(workspaceId)` on every connect
  after the first for this socket. Add a paragraph to the module doc comment.
- [ ] Task 3 passes; `(cd src/frontend && npx tsc --noEmit && npx vitest run)` clean.
- [ ] `scripts/test.sh e2e -- -k "read_state or realtime"`. **If the journey fails with the badge
  still showing in #random**, check `document.hasFocus()` in Grace's page first: Playwright emulates
  focus for every page, but if that ever fails here the fix is in the harness, never in the rule.
- [ ] Leave uncommitted.

## Task 7: The record

- [ ] `docs/design/06-frontend-spa.md` §5.2: replace "Debounce `typing`; throttle `mark_read`."
  with "Debounce `typing`." and add **Read state — added <date>**: the read rule (R2), the target,
  the leading-and-trailing per-channel throttle over the socket with no ack handling (decisions
  11–13), local cache writes (R4, decision 18), the poll and its triggers (R5, decision 17), receipt
  handling (R6), the badge (R1, R8) and the divider (R7, decision 14). Link the new ADR.
- [ ] ADR with the `adr-writer` skill, `docs/adr/<yymmdd>-unread-state-polls-rather-than-pushes.md`,
  dated the day it is written: context (no push for background channels); decision (poll 30s,
  visible only, plus focus, reconnect, switch); alternatives from the issue — a `channel_activity`
  event to the user room, joining every visible channel's room, refetching on focus only; revisit
  when the lag or the list query's load hurts — the fix is a push event to the user room.
- [ ] `docs/adr/260915-read-state-follows-channel-visibility.md`: rewrite the paragraph beginning
  "What the unit tests written for this feature cannot reach" (lines ~96–99) to say
  `src/services/messaging/tests/integration/test_read_state.py` now covers the count's rules, the
  forward-only guard and the 404s.
- [ ] Sweep: `grep -rn "mark_read\|unread\|read_receipt" docs/design/06-frontend-spa.md src/frontend/src`
  for anything still saying the SPA ignores read state. Leave uncommitted.

## Task 8: Verification

- [ ] `scripts/test.sh lint unit`, then `scripts/test.sh e2e`: green; Vitest 200 or more, end-to-end
  20 or more, nothing below the baseline.
- [ ] `.claude/hooks/security.sh` (semgrep and gitleaks); `python3 .claude/hooks/checks/conventions.py
  $(git diff --name-only HEAD)` for completeness — it checks Python, which this touches only in `tests/bdd`.
- [ ] **First real run**, on the Compose stack (`docker compose up -d --build`), Ada and Grace in two
  browsers, Grace with a second tab — the issue's *Acceptance* list:
  1. Ada posts where Grace isn't looking; Grace's count appears within 30s, or at once on switch or refocus. The name is bold.
  2. Grace opens it: divider above Ada's first new message; badge clears; Grace's second tab clears without reload.
  3. Grace scrolls back while Ada posts: the badge returns on the next refresh and clears at the bottom.

  Expect this to find something the tests didn't. Fix it with a test, and record it below.
- [ ] If a sibling branch merged meanwhile, merge `main` and rerun the above.
- [ ] Fill in *Found while building*. Leave the worktree dirty and report.

## Found while building

*Filled in by the code-writer: every deviation from this plan, and every bug the first real run
found, each with the test that now pins it down. Empty until then.*

## Not in this plan

Everything in the issue's *Not in this issue*: a live push for background channels, a "↓ N new
messages" pill, opening at the first unread, a title or favicon count, a cross-workspace badge,
mentions, "mark all as read", DM behaviour, a server-side cap.

## Self-review

- **Issue coverage:** R1 → Tasks 1, 3, 6; R2 → 1, 3, 6; R3 → 2, 3, 5, 6; R4 → 1, 3, 5; R5 → 3, 6;
  R6 → 1, 3, 6; R7 → 1, 3, 6; R8 → 3, 4, 6; the journey → 4; *Record in this slice* → 7;
  *Acceptance* → 8.
- **Names:** `readingChannelId` / `setReadingChannel`; `markChannelRead`, `applyReadReceipt`,
  `cachedLastReadId`, `readTarget`, `placeDivider`, `badgeText`; `readThrottleFor`,
  `MARK_READ_INTERVAL_MS`; `CHANNEL_POLL_MS`, `useChannelListRefresh`; `unread-badge`,
  `new-messages-divider`; events `mark_read`, `read_receipt_updated` — the same everywhere.
- **Known ripple:** `MessageList.test.tsx`'s `renderList` (new required prop);
  `test_realtime_steps.py` (the moved step); `setup.ts` (attention reset). Budget for them.
