# Chat Transcript

**Topic:** The display-name issue again, from scratch. The user tells the `issue-writer` skill to disregard the issue the previous session posted, and the same one-line idea is grilled into a new one. This session covers:
- two `Explore` sub-agents finding the server half already built, names resolved only through the member directory, and no settings UI at all
- five rounds of questions, in which the user widened the scope three times: unique names, unique *globally* (accepting a cross-tenant leak over impersonation), and deciding register D28 by building its store with one real preference, a 12/24-hour clock
- the coverage table, the post to `caw-project/ch09` as `gh-3`, and a read-back that found D28 stated in five places the issue didn't list, and two sentences two plan runs could read two ways — put back to the user as Q34 and Q35, still unanswered when the session was exported

**Date:** 16 October 2026
**Project:** `caw-project` — CollabHub, the *Claude at Work* sample project
**Model:** Claude Opus 5.5, Claude Code CLI
**Session:** `ee2ab8f6-498b-4a03-90a6-a7922ae979ed` · 10:58–13:23 UTC, of which 11:03–12:45 was the first round of questions waiting on an answer (about 43 minutes of exchange)

Messages are verbatim. Tool calls are summarised in italics — one note per run of them — so the work is visible without pages of command output. 18 tool calls ran in this session before the export, plus about 49 in its two sub-agents; 67,000 output tokens. Sub-agent reports and background-task notifications are summarised the same way.

This follows on from [`04-first-gh-issue.md`](./04-first-gh-issue.md), which grilled the same idea into `gh-2`. This session was started fresh on purpose, against the same repo, to compare.

---

## User

*(`/clear`, then `/rename caw-ch09-display-name-v2`)*

/issue-writer --url https://github.com/caw-project/ch09 we are going to let users change their display name - there is an existing issue which describes this. DISREGARD IT. we are starting fresh

---

## Assistant

*(the `issue-writer` skill loaded)*

Starting with the backend check.

*(ran `uv run delivery --url https://github.com/caw-project/ch09 check`, which printed `github https://github.com/caw-project/ch09: ok`)*

Backend is **github**, repo **https://github.com/caw-project/ch09** — check passed. Now reading the exemplar, register, and dispatching fact-finding in parallel (ignoring the existing display-name issue, as you said).

*(read the exemplar issue in full, and the one-line status of every register entry; a first attempt to print both at once failed on a stray `echo`, and the second overflowed to a file, so the exemplar's paths table was read in a third call)*

Exemplar and register read. Now dispatching fact-finders, then loading the grilling skill.

*(launched two `Explore` sub-agents in the background — Auth and the backend, the SPA and the BDD suite — each told to ignore `docs/issues/` and the existing issue; loaded the `mattpocock-skills:grilling` skill)*

Fact-finders are still running on Auth's `users` table, `PATCH /users/me`, and how the SPA resolves names. These questions don't depend on what they find, so here's the first round.

❓ **Q1** - **Whose name can be changed**: Can people change only their own display name, or can a workspace `owner`/`admin` also rename other members?

➡️ Only their own. Letting admins rename others brings in a role check, an audit question and the fail-closed rules for role-sensitive operations. That belongs in its own issue.

---

❓ **Q2** - **Global or per-workspace**: A user can belong to several workspaces (D2). Does one change apply everywhere, or can someone go by a different name in each workspace?

➡️ Global, one name per user. A per-workspace name would need a new table and lookups keyed by workspace. (The fact-finder is confirming that the name lives on `users` today. If it doesn't, I'll come back to this.)

---

❓ **Q3** - **Uniqueness**: Can two people have the same display name?

➡️ Yes, no uniqueness check. A name that had to be unique across all workspaces would tell one tenant what names exist in another. That crosses a convention. A name unique within one workspace collides with Q2, because the user may belong to several workspaces. Names are labels, and user IDs stay the identity.

---

❓ **Q4** - **What counts as a valid name**: What validation applies?

➡️ Trim leading and trailing whitespace. After trimming, the name must be 1–64 characters (or whatever the column allows, which I'll confirm). Refuse empty or whitespace-only names with a 422 Problem Details that says why. Allow any Unicode except control characters. Saving the unchanged name succeeds and changes nothing.

---

❓ **Q5** - **Does sign-in overwrite it**: Today the name probably comes from the IdP's claims at sign-in (being confirmed). After a user picks their own name, does the next sign-in through Dex replace it with the IdP's name?

➡️ No. Once a user has set a name, sign-in never overwrites it. The IdP name is only the starting value on the first sign-in. Without this rule the feature undoes itself at the next login, and the acceptance check would have to sign out and back in to prove it.

---

❓ **Q6** - **Who sees the change, and when**: Do other people looking at the workspace see the new name live, without a reload? Or is it enough for them to see it on their next load or refetch?

➡️ Live, for everyone currently in the same workspace(s): message authors, member lists, DM names and the user's own header all update without a reload. This one is the most expensive to build, and the cost depends on whether a workspace-wide socket room exists (being checked). If none exists, the cheaper option is the user's own tabs live, and everyone else on their next directory refetch (focus, reconnect, channel switch). Tell me which you want, and I'll come back with the cost once the facts land.

---

❓ **Q7** - **Where the control lives**: Where does the user change their name?

➡️ In a "Profile" dialog opened from the user menu in the header, with one text field plus Save and Cancel. Errors show inline, and the dialog closes on success.

---

## Assistant

*(the backend sub-agent reported: `users.display_name` is `text NOT NULL` with no length limit, uniqueness or index; it is set once, in `provision_user` on a first sign-in, which also names the user's own workspace `"{display_name}'s Workspace"`; `PATCH /users/me` exists with a 1–100 rule, no trimming and no concurrency check, and nothing in the SPA calls it; the token's `name` claim stays stale until refresh and nothing reads it; no service but Auth stores a name; Auth publishes no events and Messaging has no user or member event; the route is not in the R1 fail-closed set)*

The backend report is in, and it changes three of my recommendations:

- **Q4 (validation):** `PATCH /users/me` already exists and accepts 1–100 characters. It doesn't trim, so a name of only spaces (`"   "`) gets through, and the error is a 400, not the 422 I suggested. Revised recommendation: keep the 100-character limit and the existing 400, and add the trim, so a name that is empty or only spaces is refused.
- **Q5 (sign-in overwrite):** this is already how it works. The IdP name is used only when the account is created and never synced afterwards. So it's a rule the issue keeps rather than one it builds, and it can't be an acceptance check, because it already passes on `main`.
- **Q6 (live updates):** Auth publishes no events, and Messaging has no `user_updated` event and no workspace-wide room, only channel rooms. Other users' SPAs pick up names from `useWorkspaceMembers`, which treats the list as fresh for 5 minutes and refetches on focus, reconnect or an id it doesn't know. Making the change live for other people therefore means a new event from Auth to Messaging, plus a workspace room. That's a large step, and I now recommend the cheaper option: the user's own tabs update immediately; everyone else sees it on their next member refetch. Of those triggers, only focus or reconnect fires on demand; otherwise it's within the 5-minute window.

Two new facts that will need decisions in the next round:
- The user's own workspace is named `"{display_name}'s Workspace"`, set once at sign-up and never updated.
- The access token carries a `name` claim that stays stale for up to 15 minutes, until the next refresh.

Over to you for Q1–Q7. The SPA report is still running, and Q7 (where the control lives) may shift when it comes in.

---

## Assistant

*(the SPA sub-agent reported: the user's own name lives in the session store's `profile`, re-read only on sign-in, renewal or a workspace switch, and is shown once, as `current-user` in `WorkspaceSwitcher.tsx`; every other name — authors, DMs, members, typing, search — comes from `useWorkspaceMembers`; there is no user menu, header or profile UI; channel rename is the nearest edit form; the Dex users are ada, grace and alan, and the BDD suite uses only Ada and Grace; it also said an explicit `displayName: null` returns 422, where the backend agent had said 400)*

The SPA report is in too. It changes Q6 and Q7:

- **There is no user menu, header or profile UI at all.** The user's own name appears in exactly one place: a plain `current-user` line under the workspace name in the sidebar (`WorkspaceSwitcher.tsx:26`). The nearest form to copy is channel rename (`ChannelHeader.tsx`, `useRenameChannel`): edit in place, with Problem Details errors shown on the form. **Revised Q7:** make `current-user` editable in place the same way: a small edit button, an input, then Save or Cancel. No new dialog.
- **The user's own name comes from two places in their SPA.** The sidebar line reads the session's `profile`, which is only re-read on sign-in, token renewal or a workspace switch. Their own messages read `useWorkspaceMembers`, like everyone else's. So "the user sees it at once" means a successful save must update both: the session profile and the directory cache (invalidated or written).
- **The user's other tabs are no different from anyone else's.** No event reaches them, so they behave like Grace's browser, and the trade-off in Q6 covers them too.
- **The precedent:** issue #7's note in doc 06 §5.2 says "Renames are not covered": a new name shows after the 5-minute `staleTime`, on focus, reconnect or mount. If Q6 goes the cheap way, the issue keeps that sentence true and says so. If it goes live, it overturns it. The template for live is `channel_added` on the per-user `reader_room`, but a rename has to reach a whole workspace. That needs a new workspace room in Messaging plus a way for Auth to tell Messaging, which doesn't exist today (Auth publishes nothing).

One discrepancy for the plan to settle: the two reports disagree on whether an explicit `displayName: null` returns 400 or 422.

Your answers on Q1–Q7 are next.

---

## User

3 - no, unique; 7 - no, let’s add the user pref page here; rest as you suggest

---

## Assistant

Settled: **Q1** a user changes only their own name · **Q2** one global name per user · **Q4** keep the 1–100 limit, add trimming, keep the existing 400 · **Q5** sign-in never overwrites the name (already true; the issue keeps it) · **Q6** the user's own tab updates at once, everyone else (including their other tabs) on the next member refetch.

Q3 and Q7 open the next round. Unique names cross a convention, so that one comes with its cost.

❓ **Q8** - **Unique across what**: The name is global (Q2), so "unique" can mean two things:

- **(a) Unique across every user in CollabHub.** It needs a unique index, which makes it race-proof. But a refusal tells Ada that someone in a workspace she can't see already uses "Bob". That is the cross-tenant leak the conventions warn about. Two more costs: first sign-in also has to deal with a clash (two IdPs each sending "John Smith" means the second sign-up fails unless the name gets a suffix), and the migration fails if the data already holds duplicates.
- **(b) Unique among everyone the user shares a workspace with**, checked when they rename. Nothing leaks, because Ada can already see every name it is checked against. But it is enforced at rename time only. Clashes can still arise when someone joins a workspace or signs in for the first time, and the issue says so plainly. There is no index to lean on, so the plan has to make concurrent renames safe.

➡️ (b). It is the only form that doesn't leak one tenant's names to another. Joins and first sign-ins are left alone: refusing a workspace add because of a name would be a far bigger change.

---

❓ **Q9** - **What counts as the same name**: Is "ada" the same as "Ada"? Is "Ada  Lovelace" (two spaces) the same as "Ada Lovelace"?

➡️ Compare names after trimming and ignoring case, so "ada" and "Ada" clash. Leave inner whitespace exactly as typed: no collapsing. A user may change only the capitals of their own name (`ada` → `Ada`), because it doesn't clash with themselves.

---

❓ **Q10** - **The clash response**: What does the user see when the name is taken?

➡️ A 409 Problem Details with `errors.displayName`: "Someone in one of your workspaces already uses that name." It doesn't say which workspace or who. Nothing changes.

---

❓ **Q11** - **Two people pick the same name at the same moment**: Grace and Alan share a workspace and both save "Sam" at the same instant.

➡️ Exactly one of them succeeds and the other gets the 409. The workspace never holds two Sams through renames. The mechanism (lock, serializable transaction) is left to the plan.

---

❓ **Q12** - **The preferences page and D28**: D28 ("where per-user preferences live") is still 🔴, and CLAUDE.md says a preference feature needs it decided first. Does this page store any preference?

➡️ No. The page holds the display name only, which already lives on `users`. It stores no new per-user setting, so D28 stays 🔴 and untouched. The issue says the page is the future home for preferences once D28 is decided. If you want something like a theme on it now, D28 has to be decided first.

---

❓ **Q13** - **The page itself**: How do users reach it, and what does it hold?

➡️ A route at `/settings`, titled "Settings" with one "Profile" section. You get there by clicking your name (`current-user`) in the sidebar; it becomes a link. The section has the display-name field prefilled with your current name, and a Save button that is disabled while the value is unchanged or invalid. A "Back to chat" link returns to the last channel. Loading `/settings` directly, or reloading it, works. The page reads `GET /users/me` fresh on every visit and never uses a cached profile.

---

❓ **Q14** - **After a save**: What does the user see?

➡️ They stay on the page with a "Saved" confirmation. Their sidebar name and their own message authors show the new name straight away: the session profile and the member directory are both updated. If they leave the page with unsaved edits, nothing warns them; the edit is simply dropped.

---

❓ **Q15** - **What the rename leaves alone**: Three things carry the old name today. Their own workspace is named "ada's Workspace", set at sign-up. The access token's `name` claim, and so `/auth/userinfo`, stays stale for up to 15 minutes. And the issue #7 note in doc 06 §5.2 says "Renames are not covered".

➡️ Leave all three:
- The workspace keeps its name. It belongs to the workspace, not the person, and renaming it is a different feature.
- The `name` claim catches up at the next refresh. Nothing in the SPA reads it, and the issue says so.
- The doc 06 note stays true for other people, and the issue updates it to say the renamer's own view updates at once.

---

## User

8 - a, unique globally - leaking an existing name is better than allowing impersonation; 12 - let’s resolve d28 here; others fine

---

## Assistant

Settled: **Q8** names are unique across all of CollabHub; a refusal may reveal that a name exists, which you prefer to impersonation. **Q9–Q11, Q13–Q15** as recommended. **Q12** D28 is decided in this issue.

Global uniqueness opens new branches, and so does D28:

❓ **Q16** - **A first sign-in whose IdP name is taken**: Accounts are created from the IdP's `name` claim, falling back to `preferred_username`, then the email local part. Two people at different IdPs can both be "John Smith". Today both sign-ups succeed. What now?

➡️ The new account gets the first free name in the sequence "John Smith", "John Smith 2", "John Smith 3", and so on. Their own workspace is named from that result ("John Smith 2's Workspace"). Refusing the sign-up would lock someone out over a name they never chose.

---

❓ **Q17** - **Duplicates already in the data**: A unique index can't be created while duplicates exist. Environments created before this change may hold them. (The preview's ada, grace and alan are distinct.)

➡️ Before creating the index, the migration renames every duplicate except the oldest account, using Q16's suffix rule in `created_at` order. It is a one-way data change, and the issue says so. The oldest account keeps the plain name.

---

❓ **Q18** - **Lookalike names**: You chose uniqueness to stop impersonation. Comparing with case ignored stops "ada" against "Ada". It doesn't stop "Аda" (Cyrillic А) against "Ada", or a name with a zero-width character inside.

➡️ Ignoring case only, plus the existing refusal of control characters. Add a refusal of zero-width and other invisible format characters, which is cheap. Full lookalike detection (Unicode TR39 confusables) is out of scope, and the issue names it as a known gap.

---

❓ **Q19** - **Names held by deleted accounts**: Does a deleted account keep its name, so nobody else can take it?

➡️ Yes. A deleted account's name stays taken forever (until D16 retention ever purges it), so nobody can take over a departed colleague's name in old history. It also falls out of a plain unique index.

---

❓ **Q20** - **How far D28 goes in this issue**: "Decide D28 here" can mean:

- **(a) Decide it and build only the home.** Record the decision: register 🟢, an ADR, doc 01, and CLAUDE.md's D28 paragraph. Build the Settings page with Profile only, and no preference store, because a store with no keys can't be tested.
- **(b) Decide it and build it, with one real preference** so the store is proven end to end. Example: a 12/24-hour clock for message timestamps. A dark theme is out: it collides with D26's light-only palette. Notification settings are blocked on D18 🔴. This adds a table, two routes and a second page section, and pushes the issue toward its upper size limit.

➡️ (a). Uniqueness already makes this a full issue, and the first preference can arrive as its own issue against a 🟢 D28.

---

❓ **Q21** - **The D28 answer itself**: Where do preferences live, and in what shape?

➡️ Auth owns them, in a `user_preferences` table: one row per user, global and not per workspace (matching Q2). Columns are `user_id`, `prefs jsonb`, `version` and `updated_at`. The server validates a known set of keys and refuses unknown ones with a 400. The routes are `GET` and `PATCH /api/v1/users/me/preferences`. The SPA reads them through a TanStack query and never copies them into Zustand. The display name stays on `users`; it is profile, not a preference. CLAUDE.md's "light-only because of D28" line changes to: light-only until a theme preference is built against D28.

---

❓ **Q22** - **The clash message, now that names are global**:

➡️ A 409 with `errors.displayName`: "That name is already taken." It gives no hint of who has it or where.

---

## User

20 - b; others ok

---

## Assistant

*(searched the SPA for how times are formatted: three places, `MessageItem.tsx`, `ThreadSummary.tsx` and `SearchResult.tsx`, all with the browser's locale; the first search failed on a zsh glob)*

The preference currently has no setting behind it: message times, thread summaries and search results all call `toLocaleTimeString([], …)` with the browser's own locale. Settled: **Q16–Q19, Q21, Q22** as recommended. **Q20** is (b): this issue builds D28's store with one real preference.

❓ **Q23** - **Which preference**: Is it the 12/24-hour clock?

➡️ Yes, as a key `clock` with the values `"12h"` and `"24h"`. A missing key means "Automatic", which follows the browser exactly as today, so nobody's display changes until they choose. On the page it's a three-way choice: Automatic, 12-hour, 24-hour. Choosing Automatic removes the key (PATCH `{"clock": null}`).

---

❓ **Q24** - **Where the clock applies**: There are three places today: the time on each message (`MessageItem`), the time of a thread's last reply (`ThreadSummary`), and the date and time on search results (`SearchResult`).

➡️ All three. A setting that changes some times and not others reads as a bug.

---

❓ **Q25** - **Saving the clock**: Does it get its own Save button, or apply when chosen?

➡️ It applies when chosen. It sends the PATCH, the tab's times change at once, and a failed PATCH puts the previous choice back with the error shown. Profile keeps its Save button, because a text field needs one.

---

❓ **Q26** - **PATCH semantics for preferences**:

➡️ The PATCH merges only the keys sent, and `null` removes a key. An unknown key or a bad value gets a 400 with `errors.<key>`, and nothing changes. There's no `If-Match`: with merges per key, two tabs that set different keys don't lose each other's change, and on the same key the last write wins. A user with no row gets `{}` from `GET`; reading never creates a row. A deleted account gets a 404, as on `/users/me`.

---

❓ **Q27** - **Other tabs and devices**:

➡️ The tab that changed it updates at once. Other tabs and devices pick it up on the next preferences refetch: TanStack's defaults on focus or remount, with no push. That matches Q6.

---

❓ **Q28** - **R1 down**: Should either PATCH fail closed when R1 is unreachable?

➡️ No. Neither is in Conventions §5.2's sensitive set, so both stay on `require_user` and fail open. The issue names this as a decision, so the plan doesn't add a 503.

---

❓ **Q29** - **The BDD journey and its leftover state**: The e2e suite clears only the messaging tables, and it relies on Ada being named "ada" (`ADA_NAME`). A journey that renames Ada would break later scenarios.

➡️ One journey: Ada renames herself on Settings, and Grace, after a reload, sees the new name on Ada's message. Ada's name goes back to "ada" in the scenario's teardown, pass or fail. The clock, the clash and first-sign-in suffixes are all proven below the journey, in Vitest and integration tests.

---

❓ **Q30** - **Acceptance checks on the preview**: The preview keeps its data between runs, and names are now unique.

➡️ Each check has its own user, and each fails on `main` because `/settings` doesn't exist there:
- **Ada** renames herself to `ada-<run id>`. Her sidebar and her own messages show the new name at once. Grace reloads and sees it. Ada is renamed back to "ada" at the end.
- **Alan** tries to take "grace" (Grace's name is never changed by any check) and reads "That name is already taken". His name is unchanged.
- **Grace** chooses 24-hour: a message sent in the afternoon shows `HH:MM` in 24-hour form. She chooses Automatic again at the end.

The first sign-in suffix can't be checked on the preview, because every Dex user has a distinct name. It's covered by integration tests only, and the issue says so.

---

## User

29 - no existing tests use Alan i think; other ok

---

## Assistant

*(searched the tests for Alan — he appears only in Auth's integration tests, never in `tests/bdd`, whose conftest has `ada` and `grace` fixtures only; then looked up the highest register entry, D45, and every place D28 or "light-only" is stated in `CLAUDE.md` and the design docs)*

You're right. No BDD test uses Alan; he appears only in Auth's integration tests, which start their own containers. So the journey renames **Alan** and leaves Ada's `ADA_NAME` alone. The harness gains an `alan` context and page fixture next to `ada` and `grace`. Everything else in Q23–Q30 is settled.

Three last questions. With them the frontier is empty, so the coverage table follows for your confirmation.

❓ **Q31** - **Alan's leftover state**: The e2e suite never resets Auth's tables, so Alan's new name outlives the run.

➡️ Alan renames to a fixed name, "Alan Turing". There's no teardown: no other test depends on his name, and renaming to the name he already has is a no-op success, so a `KEEP_STACK` rerun still passes. The issue says why there's no teardown.

---

❓ **Q32** - **Auth's TypeScript types**: CLAUDE.md says work that changes an Auth response either generates Auth's types first, or extends the hand-typed `lib/auth/api.ts` and says why.

➡️ Extend the hand-typed ones (`updateMe`, `preferences`, `updatePreferences`). Adding an `auth.openapi` module plus generation is a separate change, and the issue gives that as the reason.

---

❓ **Q33** - **Opening `/settings` while signed out**:

➡️ It does what any other route does today: sign in, then land back on `/settings`. (The plan should check whether the existing return-to supports that. It goes in as an assumption, not a fact.)

---

### Coverage

| Requirement | Meet | Paths | Assumptions | Timeline | Conventions |
|---|---|---|---|---|---|
| **R1** Rename own name on `/settings` (trim, 1–100, no control or invisible chars, 400 on invalid) | Rename + own messages: the session profile and the directory cache are both updated (Q14) | Direct load and reload of `/settings`, a signed-out visit (Q33), unmount mid-save: the response still updates the caches | `PATCH /users/me` exists, doesn't trim, returns 400 (the reports disagree on null giving 400 or 422; the plan checks); session `profile` is only re-read in `adopt` | n/a, no throttle | Own user only (Q1); a name in a log is PII (CH008), so it never goes in one; JSON camelCase |
| **R2** Globally unique, case-insensitive, 409 "That name is already taken." | Concurrent renames: exactly one wins (Q11); a rename racing a first sign-in: the index decides | Changing only the case of your own name is allowed; a deleted account's name stays taken (Q19) | A unique index on the trimmed, lower-cased name is enough; duplicates already in the data block it (Q17) | Worked race: t0 Grace and Alan both PATCH "Sam" → one 200, one 409 | **Crosses tenancy**: a refusal reveals that a name exists somewhere. Accepted to stop impersonation (Q8), recorded as D46. Lookalike characters are a known gap (Q18) |
| **R3** First sign-in suffixes a taken IdP name ("X 2", "X 3"…); the workspace is named from the result; sign-in never overwrites | Two simultaneous first sign-ins of "X": one gets "X 2" | Email-link and existing-identity paths are untouched | `link_identity`/`provision_user` are the only places a name is created (verified) | Two-sign-up race as a timeline | Same leak as R2, accepted |
| **R4** Migration renames existing duplicates, oldest keeps the plain name | Uses R3's suffix rule | n/a, a one-off | Preview names are distinct | n/a | One-way data change, stated |
| **R5** Others see the new name on their next directory refetch; the renamer's own tab at once | The token's `name` claim stays stale ≤15 min; nothing in the SPA reads it (Q15) | The user's own other tabs behave like Grace (Q6); reconnect, focus and mount refetch | `useWorkspaceMembers` defaults (5 min stale, focus and reconnect refetch) verified | t0 rename · Grace focuses → refetch → new name; else ≤5 min | No new broadcast; no cross-workspace room |
| **R6** D28: `user_preferences` in Auth, `GET`/`PATCH /users/me/preferences`, merge, `null` removes, unknown key 400, no row → `{}` | Two tabs setting different keys don't lose updates; the same key: last write wins (Q26) | A deleted account gets 404; reading never creates a row | TanStack owns it, never Zustand (D24) | n/a | Fail-open on R1 (Q28); per user, not per workspace; hand-typed client (Q32) |
| **R7** `clock`: Automatic / 12h / 24h, applied to message, thread-summary and search times, saved when chosen, reverted on a failed save | Clock + a cached message list: times re-render with no refetch | Other tabs and devices on the next refetch (Q27) | Today all three use `toLocale*String([], …)` (verified) | t0 choose 24h → t0 render → t1 PATCH fails → revert and error | n/a |
| **R8** Settings page: Profile + Preferences, entered from `current-user`, Back to chat | n/a | Workspace switch while there: nothing changes (global) | No existing settings route | n/a | D28 recorded 🟢 everywhere it's stated |

**Out of scope:** renaming someone else, a workspace's name, lookalike-character detection, live push of renames, any preference beyond `clock`, a dark theme, generating Auth's OpenAPI types.

**Record in this slice:** register D28 🟢 and a new D46 (global unique names). An ADR for each. Doc 01 §3/§4 and its provisioning rule. Doc 06 §5.2's renames note, the settings page, and §9. CLAUDE.md's D28 paragraph and its "light-only because of D28" line.

**Acceptance:** Ada renames herself and Grace sees it after a reload; Alan's clash with "grace" is refused; Grace switches to 24-hour. Each fails on `main` because `/settings` doesn't exist. The BDD journey is Alan's rename.

Do Q31–Q33 and this table match your understanding? Once you confirm, I'll draft the issue. Posting to `caw-project/ch09` waits for a separate go-ahead from you.

---

## User

looks good

---

## Assistant

Drafting now.

*(wrote the issue body to the scratchpad — Summary through References, in the exemplar's order, one line per paragraph for GitHub — and counted it: 136 lines)*

> **Excerpt from the draft — *Decided already*, item 4:**
> **Names are unique across all of CollabHub (new register D46).** This crosses the tenancy convention on purpose: a 409 tells a user that a name exists in some workspace they can't see. Revealing that a name exists was judged better than allowing impersonation. The response names nobody and no workspace.

The draft is written, at 136 lines: `/private/tmp/claude-501/-Users-elton-scm-manning-caw-delivery-backends/ee2ab8f6-498b-4a03-90a6-a7922ae979ed/scratchpad/display-name-issue.md`

**Title:** Change your display name, with unique names and a preferences page

It keeps the exemplar's sections in order. Paragraphs and list items are one line each, so the GitHub page won't read ragged.

**Choices I made that you didn't state directly:**
- **New register entry D46** for globally unique names. D45 is the highest entry today.
- **One ADR each for D28 and D46.**
- **Alan's clash check tries "GRACE" in capitals**, so the same check also proves the case-insensitive comparison.
- **Two facts are written as assumptions for the plan to check:**
  - whether an explicit `displayName: null` returns 400 or 422 today (the two fact-finders disagreed);
  - whether Postgres `lower()` is good enough for the case-insensitive comparison.

Shall I post it to **https://github.com/caw-project/ch09** with the `delivery` label?

---

## User

yes

---

## Assistant

*(ran `delivery ensure-label delivery` and `delivery issue create` with the `delivery` label — the issue came back as key `gh-3`; `issue verify gh-3` printed `Match`, exit 0; fetched it back with `issue get`)*

The issue is posted, and verify reports a match. Now reading it back the way the plan-writer will, and checking that every place D28 and the subjects it settles are stated today is listed under *Record in this slice*.

*(searched `CLAUDE.md`, `docs/`, the SPA source and `.claude/` for D28, "user preferences", "light-only" and "Renames are not covered" — the first attempt failed on a zsh glob; then read the hits outside the issue's list: doc 06 §2's Styling row, the Tailwind ADR `260815`, and the header comments of `index.css`, `MessageItem.tsx`, `SearchResult.tsx` and `ThreadSummary.tsx`)*

I read it back as the plan-writer would, and found two things to fix:

**Not yet recorded.** D28 is also stated in places *Record in this slice* doesn't list:
- doc 06 §2's Styling row ("Light palette only — there is no user-preferences feature…");
- the code comments in `index.css`, `MessageItem.tsx` and `SearchResult.tsx`. The last two are the very formatters the clock changes, and they say "register D28 is open".

The Tailwind ADR (`260815`) gives the same reason. ADRs aren't rewritten, so the new D28 ADR points back to it. `MessageItem`'s comment also says the acceptance suite asserts on `<time dateTime>`, not the text. So the clock must change only the visible text, and its checks must read the text. That goes into *What this assumes*.

**Sentences two plan runs could read two ways:**

❓ **Q34** - **Which invisible characters are refused**: "Invisible format characters (zero-width and the like)" is vague. Unicode's format category (Cf) includes the zero-width joiner, which emoji sequences like 👨‍👩‍👧 rely on. The same joiner placed between letters makes "A‍da" look like "Ada".

➡️ Refuse every control (Cc) and format (Cf) character, the joiner included. Emoji joined into sequences are refused too, and that cost is named in the issue. Single emoji are still fine.

---

❓ **Q35** - **IdP names that break the rules at first sign-in**: An IdP name may be over 100 characters, only spaces, or contain refused characters. A 99-character name plus " 2" goes over the limit.

➡️ First sign-in applies R1's rules to the IdP name. If it fails them, it falls through the existing fallbacks (`preferred_username`, then the email's local part). A suffix is made to fit by cutting the base name so the result is at most 100 characters. The migration also trims every existing name before checking for duplicates.

---

I'll also tighten two wordings myself; neither changes a decision:
- "Back to chat" goes to the channel the user came from, or the workspace's default view on a direct load.
- Grace's acceptance check stops depending on the time of day: her browser is en-US, so "Automatic" shows AM/PM, and after choosing 24-hour no message time shows AM/PM.

---

*(`/manning-book-workflow:extract-transcript` — the session was exported here, with Q34 and Q35 unanswered and `gh-3` not yet edited for them)*
