# Chat Transcript

**Topic:** The first delivery issue written straight to GitHub. The `issue-writer` skill, now
going through the `delivery` CLI's `github` backend, grills a one-line idea — let users change
their display name — into a 213-line issue. This session covers:
- three `Explore` sub-agents finding that the server half already existed, and that renames
  were deliberately left out of issue 7
- three rounds of questions, in which the user widened the scope twice: unique names, and
  deciding register D28 (where user preferences live) with a Settings page to go with it
- the coverage table, the post to `caw-project/ch09` as `gh-2`, and a read-back that found
  three sentences two plan runs could read two ways

**Date:** 16 October 2026
**Project:** `caw-project` — CollabHub, the *Claude at Work* sample project
**Model:** Claude Opus 5.5, Claude Code CLI
**Session:** `ed50d540-82fc-43af-9689-0a4732f34f48` · 08:30–09:42 UTC (72 min), of which
08:35–09:05 was the first round of questions waiting on an answer

Messages are verbatim. Tool calls are summarised in italics — one note per run of them — so the
work is visible without pages of command output. 17 tool calls ran in this session before the
export, plus about 66 in its three sub-agents; 61,000 output tokens. Sub-agent reports and
background-task notifications are summarised the same way.

This runs inside the gap in [`03-issue-writer-gh.md`](./03-issue-writer-gh.md), which built the
`delivery` CLI and its `github` backend on `feature/delivery-backends` and rewrote the skill to
use them; that session reviews this issue when the user comes back.

---

## User

*(`/rename caw-ch09-display-name`)*

/issue-writer --url https://github.com/caw-project/ch09 we are going to let users change their display name

---

## Assistant

*(the `issue-writer` skill loaded)*

I'll start by checking the delivery backend against that repo.

*(ran `uv run delivery --url https://github.com/caw-project/ch09 check`, which printed `github https://github.com/caw-project/ch09: ok`)*

Backend check passed: **github** at https://github.com/caw-project/ch09. Next I'll read the exemplar, the open-decisions register and the grilling method, and send off fact-finding agents at the same time.

*(read the exemplar issue in full and listed `docs/issues/`; launched three `Explore` sub-agents in the background — Auth and the backend, the SPA and the BDD suite, the register and history — and read the vendored `grilling.md`; then loaded the installed `mattpocock-skills:grilling` skill)*

The fact-finding agents are still running. While they work, here are the questions that don't depend on what they find.

❓ **Q1** - **Uniqueness**: Must display names be unique within a workspace? If they must, two people called "Sam" collide and one gets refused. If they needn't be, a member can take another member's name and pass as them in chat.

➡️ Not unique. Impersonation is a moderation problem, and that's out of scope here. The member directory still tells people apart by user ID and avatar.

---

❓ **Q2** - **Validation**: What makes a name valid?

➡️ Whitespace trimmed at both ends, then 1–64 characters. Runs of internal whitespace collapse to one space, and control characters are refused. Any Unicode letters and emoji are allowed. If the `users` column already has a narrower limit, the column's limit wins. I'll confirm that once the facts are in.

---

❓ **Q3** - **Where it's edited**: Where does the user change their name?

➡️ An "Edit profile" item in the existing user menu, if there is one, that opens a small dialog with one text field, Save and Cancel. A full settings page needs D28, user preferences, which is 🔴, and this feature shouldn't add one.

---

❓ **Q4** - **History shows the current name**: After Ada renames herself to "Ada L", should her old messages show the new name or the name she had when she wrote them?

➡️ The current name everywhere: messages, the member list, mentions, presence. A name is a label on the person, not part of the message.

---

❓ **Q5** - **Live for others**: Should someone else who has the app open see the new name without a reload?

➡️ Yes, everyone in the workspace who has it open sees the change live, and so do the renamer's own other tabs. If the facts show that needs a new cross-service event, that's still in scope, and the mechanism is left to the plan.

---

❓ **Q6** - **Scope of a name**: A token is scoped to one workspace (D2), but `users` might be global, so is the name per workspace or per user? If a user belongs to two workspaces, does renaming in one rename them in both?

➡️ One name per user, as the `users` table holds it now, so the rename shows in every workspace. A per-workspace nickname would be a new feature. I'll confirm the table shape once the facts come back.

The agents' findings will shape the next round: whether the IdP overwrites the name at each sign-in, whether the name sits in the JWT, and where other services copy it.

---

## Assistant

*(the register-and-history sub-agent reported: no register entry covers renames; `PATCH /users/me` is already built in Auth with a 1–100 character rule and no trimming or uniqueness, and nothing in the SPA calls it; the IdP name is used only when an account is created; doc 06 says "Renames are not covered" — others see a rename at the next directory refetch after 5 minutes; issue 7 left renames out on purpose; `caw-project/ch09` holds one closed test issue)*

The register and docs agent has reported back. Three of its findings bear on the questions above:

- **The server side mostly exists already.** Auth has `PATCH /users/me` (`src/services/auth/auth/routers/users.py:39`), which accepts 1–100 characters, with no trimming and no uniqueness check. It emits no event. Nothing in the SPA calls it yet.
- **The identity provider sets the name only when the account is first created** (`identities.py:162`). Signing in again never overwrites it, so a name the user sets survives the next login.
- **Other users would not see a rename for up to 5 minutes.** `06-frontend-spa.md:309` says "renames are not covered": the member directory picks up a new name only at its next refetch once 5 minutes have passed. Issue 7 deliberately left this out, so this feature is its follow-on. The `name` claim in the access token also stays stale until the next token refresh.

Two of my recommendations change as a result:
- **Q2:** the existing limit is 100 characters, not 64. My recommendation is now to keep 100 and add trimming and the control-character rule.
- **Q6:** confirmed. `users` is one row per person, so a name applies in every workspace.

I'm waiting on the other two agents and on your answers to Q1–Q6.

---

## Assistant

*(the backend sub-agent reported: `PATCH /users/me` accepts a name of only spaces and has no optimistic concurrency; the token's `name` claim is minted at issue and refresh and read by no service; the SPA shows your own name from `session.profile`, loaded from `GET /users/me`; Messaging, the search index and the Worker hold no names; a personal workspace is named `"<name>'s Workspace"` at account creation)*

The backend agent's report adds two facts to the round:

- **`PATCH /users/me` has gaps.** It accepts a name of only spaces, because `min_length=1` is checked before anything trims it. It also has no optimistic concurrency: no `version` or `If-Match`. Q2's trim rule would close the first gap.
- **The token's stale `name` claim affects no one.** No service reads `principal.display_name`. The SPA shows the user's own name from `session.profile` (`WorkspaceSwitcher.tsx:27`), which it loads from `GET /users/me`. So refreshing the token after a rename isn't needed. I'll put that to you in the next round.

One side effect to raise later: a user's own workspace is named `"<name>'s Workspace"` when the account is created. A rename won't change it, and I'll recommend leaving it as it is.

Still waiting on the frontend agent and on your answers to Q1–Q6.

---

## Assistant

*(the frontend sub-agent reported: there is no user menu — your own name appears once, as `current-user` in the sidebar; every other name comes from the `['workspace-members', wsId]` directory, stale after 5 minutes, your own messages included; no socket event touches the directory except a reconnect; `CreateChannelDialog` is the form template; the BDD suite never truncates Auth's tables, steps hard-code `ada` and `grace`, and the seeded user Alan is unused; issue 8 will turn the sidebar into a drawer on mobile)*

All three agents have reported. The frontend findings change two questions in the open round, so here are Q3 and Q5 again, revised. Q1, Q2 (now 1–100 characters, trimmed) and Q4 still stand as asked.

**New facts from the SPA:**
- **There is no user menu.** Your own name appears in one place only, `current-user` under the workspace name in the sidebar (`WorkspaceSwitcher.tsx:27`).
- **Every name comes from the member directory**, `['workspace-members', wsId]` with a 5-minute stale time. That covers message authors, threads, search, the member panel, DMs and typing. Your own messages are named from it too, not from `session.profile`. Mentions and canvas presence don't exist yet.
- **No event from Auth exists, and nothing pushes a rename to other tabs today.**
- **The BDD suite never truncates Auth's tables.** A scenario that renames Ada leaves her renamed for every scenario and run after it, and steps hard-code `ADA_NAME="ada"`. Alan is seeded in Dex and never used.

---

❓ **Q3 (revised)** - **Where it's edited**: There's no menu to hang it on. The options are:
- (a) Click your own name (`current-user`) to edit it inline in the sidebar.
- (b) A small pencil or "Edit" button beside your name that opens a dialog modelled on `CreateChannelDialog`.
- (c) A new `/profile` route.

Issue 008, the mobile issue, turns the sidebar into a drawer under 768px. That isn't built yet.

➡️ (b). It copies an existing pattern, including its field errors and pending state. It sits in the sidebar, so it moves into 008's drawer for free. And it needs no new route.

---

❓ **Q5 (revised)** - **How others learn of a rename**: The options are:
- (a) **The renamer only.** Their own tab updates `session.profile` and refetches the directory at once. Everyone else sees the new name at their next refetch: up to 5 minutes plus a focus, mount or reconnect. That is today's documented behaviour, unchanged.
- (b) **Live for everyone.** Auth tells Messaging through an internal endpoint or an R3 stream, and Messaging broadcasts `user_updated {userId}` to each affected workspace's room. Every SPA refetches its directory on that event. This is a new cross-service path and makes the feature roughly three times the size.
- (c) **Middle ground.** Do (a), and cut the directory's stale time so a focus or mount picks the name up sooner, with no event.

➡️ (a) for this issue, with (b) recorded under *Not in this issue* as its own follow-on. (b) is a cross-service event design, and that deserves its own issue and probably its own ADR. (a) is a complete feature: the person renaming sees it at once everywhere in their own tab, and others catch up as they already do for every other directory change.

---

❓ **Q7** - **Your own other tabs and workspaces**: Under Q5 (a), your second tab and your directories for other workspaces keep the old name until their own refetch. Is that acceptable, or should the renaming tab also invalidate every `workspace-members` key it holds? That covers other workspaces in the same tab, not other tabs.

➡️ Invalidate every `['workspace-members', *]` key in the renaming tab: it costs one line. Other tabs catch up through the normal refetch, and the issue says so in its paths table.

---

❓ **Q8** - **Leave the rest alone**: A rename leaves three things as they are. The access token's `name` claim stays stale until the next refresh (≤15 minutes, and nothing reads it). The personal workspace keeps its creation-time name, `"ada's Workspace"`. The IdP never overwrites the name after the account is first created. Should all three stay as they are and be stated in the issue?

➡️ Yes to all three. The issue should state each one as a fact (the agents confirmed them in the code), so the plan doesn't spend a decision on any of them.

---

## User

1 -yes, unique; 3 - let’s decide on d28 as part of this and build the pref page; 5 - a) and we have logic to fetch the name for unknown users, this could be similar; others as you suggest

---

## Assistant

*(read register entry D28 and the preference references in docs 01 and 06)*

Thanks. Your three answers open new branches, so here is the next round.

**Where we stand:**
- **Q1:** names are unique.
- **Q3:** D28, where user preferences live, gets decided in this issue, and a preferences page gets built.
- **Q5:** (a), with refetch logic modelled on the unknown-id refetch from issue 7.
- **Q2, Q4, Q6, Q7, Q8:** settled as I recommended.

---

❓ **Q9** - **Scope and comparison of uniqueness**: Q6 settled one name per user across every workspace, so uniqueness has to be one of these:
- (a) **Global**: unique across every CollabHub user. One unique index. The cost is a small leak: "name taken" tells you someone, somewhere, has that name, even outside your workspaces.
- (b) **Among co-members**: unique across everyone you share a workspace with. That leaks nothing outside your workspaces, but adding a member to a workspace can then create a clash. Membership adds would need refusing, and you'd need a rule for it.

And how two names are compared:
- (i) exactly as stored
- (ii) case-insensitively, so "Ada" and "ada" clash
- (iii) case-insensitively after Unicode NFKC normalisation, so full-width "Ａｄａ" also clashes with "Ada"

➡️ (a) global, compared with (iii): trim, collapse internal whitespace, NFKC, casefold. Store the name as the user typed it, plus a normalised key with a unique index on it. Lookalike characters from different scripts, such as Cyrillic "а" for Latin "a", are out of scope. Renaming to a different case of your own name, "ada" → "Ada", is allowed, because the key belongs to you.

---

❓ **Q10** - **Names that clash already, and the first sign-in**: Two things can break uniqueness without a rename:
1. **Existing duplicates.** Two accounts created from the same IdP `name`, such as two "Sam"s, may already exist in a database. The migration that adds the unique key fails on them.
2. **First sign-in.** A new account whose IdP name is already taken would fail to be created.

What happens in each case?

➡️ Use one rule for both: the later account gets the first free suffix, " 2", " 3" and so on, in account-creation order. The migration does it for existing rows and keeps the earliest account's name unchanged. Provisioning does it at account creation, and a clash between two sign-ins at the same moment retries with the next suffix. The user can rename afterwards. The suffix is visible to everyone, which is the point: it tells two people apart.

---

❓ **Q11** - **What D28 decides**: The register frames D28 as two options:
- (a) Preferences belong to Auth: a `preferences jsonb` column on `users`, read and written through `GET` and `PATCH /users/me`.
- (b) A separate preferences service.

➡️ (a). It needs no new service or database, the SPA already loads `/users/me` on every token adoption, and preferences are per user, not per workspace, just like `users` itself. The R1 cache is left out until something shows it's needed. The register entry goes 🟢, and an ADR records the decision in this slice.

---

❓ **Q12** - **What's on the preferences page**: D28 says the store must be decided "before the first thing that needs one ships". Which preferences actually ship with this page?
- (a) **Display name only.** The page is "Profile & preferences" with one field. The `preferences` column ships empty, with its schema and validation in place. That risks being a store nothing uses.
- (b) Display name plus **one real preference**. The candidates each have a catch:
  - theme: blocked by D26, which makes the palette light-only, so no dark palette exists to switch to
  - locale: no i18n exists
  - notification settings: D18 is 🔴
  - a cheap one that does work today, such as "time format, 12h/24h" for message timestamps or "show typing indicators"
- (c) **Display name only, and leave D28 open.** This reverses your Q3 answer, so I'm listing it only for completeness.

➡️ (b) with **time format, 12h or 24h**. It is self-contained in the SPA and touches no other register entry. It proves the store end to end, giving the column a real first key. The default follows the browser's locale until the user picks one.

---

❓ **Q13** - **Where the page lives**: A route and a way to reach it:
- (a) `/settings`, linked from your own name (`current-user`) in the sidebar, with "Back to chat" returning to the last channel.
- (b) A modal over the chat.

➡️ (a). A preferences page will grow, and a route can be deep-linked and tested. The link sits in the sidebar, so it moves into 008's drawer when that ships.

---

❓ **Q14** - **What "similar to the unknown-name logic" means**: Issue 7's tracker joins a directory fetch that is already in flight (`cancelRefetch: false`). For a rename, joining is wrong: a fetch that started before the PATCH committed can land after the rename and put the old name back. I read your answer as: after a successful rename, the renaming tab first puts the new name into the cached directory entry and `session.profile` straight from the PATCH response. It then refetches every `workspace-members` key with a fetch started after the response, never a join. Any fetch already in flight must not overwrite the new name. Is that what you meant? Or did you want other users' tabs to notice a rename by some trigger as well, which would be beyond (a)?

➡️ Renaming tab only, as I've described it. Other users and tabs catch up on their normal refetch (5 minutes stale, plus a focus, mount or reconnect), as decided in Q5 (a).

---

## User

all good

---

## Assistant

*(grepped the SPA for timestamp formatting — three call sites, each with the browser locale — and checked the preview's Dex users in `charts/collabhub-deps/templates/dex.yaml`: `ada`, `grace` and `alan`)*

Here's the third round: the preference itself, saving, tests and acceptance.

**One new fact:** timestamps are formatted in three separate places, each calling `toLocale…String([], …)` with the browser's locale:
- `MessageItem.tsx:69`, time only
- `ThreadSummary.tsx:17`, time only
- `SearchResult.tsx:23`, date and time

The preview's Dex has `ada`, `grace` and `alan`, and Alan is unused by every test.

---

❓ **Q15** - **One Save for the page**: Does the page have one form with one Save button, sent as a single `PATCH /users/me` carrying `displayName` and `preferences`?

➡️ Yes. Save is atomic: if the name is taken, nothing is saved, the time format included. The field shows "That name is already taken", and the status code is left to the plan. Save is disabled while nothing has changed or a save is pending, as in `CreateChannelDialog`. The time format applies across the app as soon as Save succeeds.

---

❓ **Q16** - **What `PATCH` does with `preferences`**: Does `preferences` merge into the stored object or replace it?

➡️ It merges top-level keys. A key that's sent is replaced, a key that's absent is kept, and `null` resets a key to its default. That way two tabs changing different preferences never undo each other once there's more than one key. An unknown key or an invalid value (`timeFormat` other than `"12h"`/`"24h"`) is refused with a field error, and nothing is saved. `GET /users/me` returns only the keys that have been set, and the SPA applies the default for any that are missing.

---

❓ **Q17** - **What time format covers**: Does `timeFormat` apply to all three places that show a time?

➡️ Yes, through one shared formatter, so the three can't drift apart. Unset means the browser locale's own convention, which is today's behaviour, so nothing changes for anyone who never sets it. Dates in search results keep the locale's date style, and only the time part follows the preference.

---

❓ **Q18** - **A preference set in one tab, seen in another**: Your other tabs reload `session.profile` from `/users/me` at every token adoption, roughly every 14 minutes. Is it acceptable that another tab picks up a changed time format only then, or after a reload?

➡️ Yes. The paths table states it, the same as for the name in Q7.

---

❓ **Q19** - **No rate limit and no audit**: Renames get no rate limit, no rename history and no audit log. Profile edits aren't in D1's fail-closed set, so a token on the denylist is still refused when R1 is reachable, and the edit fails open like any other ordinary request when it isn't. Is that right?

➡️ Yes. All three go under *Not in this issue*.

---

❓ **Q20** - **Users for the tests and the preview**: Auth's tables are never reset, either in BDD or on a preview, and names are now unique. So:
- **The one BDD journey:** Alan opens Settings and renames himself to a name carrying a per-run id. His own earlier message shows the new name at once, with no reload. Grace sees it after a reload. Teardown renames Alan back to "alan".
- **Acceptance on the preview** uses Alan for every rename and a fresh run-id name for each check, then restores "alan" at the end. Each check fails on `main` because `main` has no Settings page. The duplicate-name check also fails at the API on `main`, because `main` accepts duplicates. The checks are:
  1. Alan renames himself; his own messages and the sidebar show the new name without a reload.
  2. Alan tries "GRACE"; he's refused, and nothing changes.
  3. Alan sets 24h; message times read `14:05`-style, still after a reload.
  4. Grace, with her page open before the rename, reloads and sees Alan's new name.
- **The suffix rule** at first sign-in and in the migration can't be staged on a preview, since that would need a never-signed-in user whose name clashes. Integration tests prove it.

➡️ As described.

---

❓ **Q21** - **What gets recorded in this slice**: These records come with the work:
- D28 goes 🟢, with an ADR.
- A new register entry for display-name uniqueness and its suffix rule goes 🟢, with the decision written into the same ADR or its own.
- Doc 01 gets the `PATCH` rules, the `preferences` column, the normalised-name key, and the corrected wording of §5.1's "upserts".
- Doc 06 gets the Settings page, the shared time formatter, and the renaming tab's refresh. Its "Renames are not covered" note is rewritten to say other users still catch up in up to 5 minutes.
- The SPA's hand-written `Profile` type gains `preferences`. Auth has no generated OpenAPI types; generating them is not in this issue.

➡️ As listed, with **two ADRs**: one for where preferences live, one for global unique display names.

---

❓ **Q22** - **Not in this issue**: These stay out:
- a live rename broadcast to other users (Q5 (b))
- avatar editing
- a theme or dark mode
- locale
- notification settings
- renaming the personal workspace
- lookalike characters across scripts
- admins renaming someone else
- rate limit, audit and history
- generated OpenAPI types for Auth
- the 008 mobile layout

➡️ That list, as it stands.

---

## User

good to go

---

## Assistant

Grilling is complete. Here's the coverage table: every requirement against the four branches. Two cells (★) hold a race nothing in the rounds covered. I've filled them with my recommendation, so check those two in particular.

**Requirements**
- **R1** A `/settings` page, linked from your own name in the sidebar, with Back to chat.
- **R2** Name rules: trim, collapse whitespace, 1–100 characters, no control characters.
- **R3** Globally unique on a normalised key (NFKC + casefold). A taken name is refused and nothing changes. You can change the case of your own name, and saving your current name changes nothing.
- **R4** Existing duplicates and first sign-in clashes get " 2", " 3" in account-creation order.
- **R5** The renaming tab shows the new name at once everywhere: the sidebar and every `workspace-members` cache.
- **R6** Everyone else sees the new name at their next directory refetch, as they do today.
- **R7** `preferences jsonb` in Auth, through `/users/me`: top-level merge, `null` resets a key, unknown keys and invalid values refused.
- **R8** `timeFormat` is `12h`, `24h` or unset (locale). One formatter serves messages, threads and search.
- **R9** One Save; the PATCH is atomic.

| | Meet | Paths | Assumptions | Timeline |
|---|---|---|---|---|
| R1 | 008's drawer: the link is in the sidebar, so it moves with it | deep link, reload, back to the last channel | none | n/a: nothing timed |
| R2 | R3: normalise first, then compare | API and UI apply the same rules; the server is the authority | today's PATCH accepts `" "` (confirmed in code) | n/a |
| R3 | two users claim one name at once: exactly one wins | case change of your own name allowed; saving your current name changes nothing | the unique index on the key is what enforces it | two PATCHes at t0: one 200, the other refused |
| R4 | R3: suffixes are themselves unique; a concurrent provision retries | migration, first sign-in | the IdP name is used only at account creation (confirmed, `identities.py:154`) | two first sign-ins as "Sam" at t0: "Sam" and "Sam 2" |
| R5 | R6 and in-flight directory fetches: no older fetch overwrites the new name. ★ The same holds for `session.profile`: a `/users/me` from a token renewal or workspace switch started before the PATCH response mustn't put the old name back | own messages and other workspaces in the same tab; leaving `/settings` while a save is pending still updates the caches ★ | `setQueryData` and a pending fetch, left for the plan to check | t0 fetch starts · t1 PATCH 200, cache gets the new name · t2 old fetch lands and is discarded · t3 a fresh fetch confirms |
| R6 | R5: other tabs of the same user lag too | 5-minute stale time, plus a focus, mount or reconnect; a reload is immediate | `directoryRefresh` behaviour unchanged (doc 06:309) | n/a: unchanged |
| R7 | R9; two tabs changing different keys | set, unset, reset; another tab picks it up at its next adoption (about 14 minutes) or a reload | `adopt()` reloads `/users/me` each time it runs (confirmed, `session.ts:76`) | n/a |
| R8 | R7: unset falls back to the browser locale | all three places, after a reload, after a workspace switch | the three `toLocale…` call sites (confirmed) | n/a |
| R9 | R3 × R7: a taken name saves no preference | Save disabled while unchanged or pending | none | n/a |

★ My recommendation for both: the renaming tab applies the PATCH response last. An older `/users/me` or directory response that lands after it is discarded or refetched. Leaving the page doesn't cancel the cache update.

Does this match your understanding, including the two ★ cells? Once you confirm, I'll draft the issue and show it to you before posting it to `caw-project/ch09`.

---

## User

good to go. this issue is gong to gh yes?

---

## Assistant

Yes: it goes to GitHub at https://github.com/caw-project/ch09, labelled `delivery`. I'll draft it first, and post it once you say so.

*(wrote the 205-line draft body into the scratchpad, in the exemplar's sections and order)*

---

## User

*(sent mid-turn)*

let’s go

---

## Assistant

*(ran `ensure-label delivery` and `issue create` in one chain, which stopped at a `grep -v` that matched nothing — `ensure-label` had printed only uv's environment warning; reran `ensure-label` on its own, then `issue create`, which returned `gh-2`; `issue verify` printed `match`, and `issue get` fetched the body back for the read-back, 207 lines with the `delivery` label)*

I posted the issue and read it back: **gh-2**, https://github.com/caw-project/ch09/issues/2, labelled `delivery`. `verify` reports a match.

Reading it back as the plan-writer would, I found three sentences two plan runs could read differently. Here they are as questions; I'll update the issue with your answers.

❓ **Q23** - **Tabs, newlines and invisible characters**: R2 says "collapses whitespace" and "refuses control characters", but a tab or a newline is both. And emoji such as 👩‍💻 rely on zero-width joiners, which are invisible "format" characters.

➡️ Treat any Unicode whitespace, tabs and newlines included, as whitespace: trimmed at the ends, collapsed to one space inside. Refuse every other control character (category `Cc`). Allow format characters (`Cf`), so joined emoji survive.

---

❓ **Q24** - **IdP names and existing rows that break R2**: The IdP name at first sign-in, and names already in the database (today's PATCH accepts `"   "`), can fail R2: blank after trimming, over 100 characters, or containing control characters. A suffix can also push a 100-character name to 103. What happens?

➡️ Clean these names rather than refuse them, so sign-in never fails:
- apply R2's trim, collapse and control-character stripping
- if the name is empty after that, use the next source: `preferred_username`, then the email's local part, and for an existing row, its email's local part
- cut the base so that base plus suffix fits in 100 characters

The migration applies the same steps to existing rows before it adds suffixes.

---

❓ **Q25** - **Two acceptance checks could pass, or prove nothing**: Two of the acceptance checks have holes:
- **Check 3** ("Alan sets 24h, times read 14:05") shows nothing if the preview browser's locale already uses 24-hour times.
- **Check 2** says his time format doesn't change, but it never says he changed it in the same save.

➡️ Rewrite both:
- **Check 3:** Alan sets the format his browser's locale doesn't use by default: 12h under en-GB, 24h under en-US. Message times switch to it and keep it after a reload.
- **Check 2:** Alan changes the time format and types `GRACE` in one save. He's told the name is taken, and neither the name nor the format is saved.

---

## User

yes

---

## Assistant

*(rewrote R2, R4 and acceptance checks 2 and 3 in the draft with the three answers — now 213 lines — then ran `issue edit gh-2` and `issue verify`, which printed `match`)*

I updated **gh-2** with your three answers and read it back from GitHub. `verify` reports a match.

**Issue:** https://github.com/caw-project/ch09/issues/2 (key `gh-2`, label `delivery`). It's 213 lines and follows the exemplar's sections in order.

Besides adding the display-name feature, it decides two things:
- **D28, where preferences live:** in Auth, as a `preferences jsonb` column on `users`, read and written through `/users/me`. The issue has the build move the register entry to 🟢 and write an ADR.
- **Display names are unique across all of CollabHub.** Names are compared after trimming, NFKC normalisation and casefolding. Names that already clash, or clash at first sign-in, get a " 2", " 3" suffix.

The renaming tab shows the new name at once. Everyone else catches up at their next directory refetch, as today; a live broadcast is listed under *Not in this issue*. The one preference that ships is the time format, 12h or 24h.

Delivering it isn't possible yet: `scripts/deliver.sh` takes only a local issue file. A GitHub issue becomes deliverable with the label-triggered GitHub Actions workflow, which is the next slice of the delivery-backends plan.

---

## User

how close are we to the max issue size here (on gh)?

---

## Assistant

*(counted the draft body: 13,352 characters)*

We're nowhere near it. GitHub caps an issue body at 65,536 characters, and gh-2's body is about 13,350, roughly 20% of the cap.

The skill's own length target of 120–250 lines binds well before GitHub's cap does: an issue at the top of that range would still come in around 16,000 characters, about a quarter of the cap. The cap would only matter if an issue pasted in large logs or code.

---

## Timing

| Stretch | Wall | What it was |
|---|---|---|
| 08:30–08:35 | 5 min | backend check, exemplar, three sub-agents launched, first round of six questions; the agents reported over the next three minutes |
| 08:35–09:05 | 30 min | waiting on the user's answers to round one |
| 09:05–09:21 | 16 min | rounds two and three, each answered in one line; active time under 2 minutes |
| 09:21–09:36 | 15 min | coverage table, the draft, the post and the read-back; about 2 minutes active |
| 09:36–09:42 | 6 min | three read-back questions answered, the issue edited, the size question |

Almost all of the 72 minutes is the user reading and answering. Claude's active time across the session is about 6 minutes.
