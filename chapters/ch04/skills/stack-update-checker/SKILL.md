---
name: stack-update-checker
description: >-
  Check the CollabHub platform stack for new upstream releases and notify the team.
  Trigger when the user asks to "check for stack updates", "check for platform/base-image
  updates", "run the version check", "see if anything needs patching", "check for new
  versions", or wants to run/schedule the recurring platform-update check. Reads
  docs/platform/versions.md, compares each platform's newest upstream stable release
  against its recorded watermark, posts a digest to the #stack-updates Slack channel when
  something is new, and writes the watermark back so the same release is never announced
  twice. Also use when setting up the scheduled task that runs this check.
---

# Stack Update Checker

Watches the platform-level components in `docs/platform/versions.md` (runtimes, data
stores, message/stream infra, orchestration, observability — the Docker base-image
level, not individual libraries) and tells the team when a newer upstream release is
available. It posts to the **`#stack-updates`** Slack channel and records what it
announced so it never sends a duplicate for the same version.

The source of truth is `docs/platform/versions.md`. Each platform entry carries a
`last_notified` watermark — the newest version already announced. This skill only
alerts when the upstream release is **newer than `last_notified`**, and after a
successful Slack post it writes the new version back into that field.

## Prerequisites

- Read access to `docs/platform/versions.md` in this repo.
- Web access (`WebFetch`, falling back to `WebSearch`) to read each `check_url`.
- The Slack connector, with permission to post to `#stack-updates`.

If the Slack connector is not available, do everything else, then report the findings
in chat instead of posting — but do **not** update `last_notified` (nothing was
announced, so the watermark must not move).

## Procedure

### 1. Load the tracked platforms

Read `docs/platform/versions.md` and parse the `platforms` YAML block. For each entry
keep: `id`, `name`, `pinned_track`, `current_stable`, `last_notified`, `check_url`,
`notes`, and any per-entry branch rules (e.g. Nginx "use the even/stable branch",
Kubernetes "N-2", Node "LTS line only").

### 2. Find the newest upstream stable for each platform

For each entry, fetch `check_url` and determine the newest **stable** release. Apply
the per-entry rules in `notes` and `pinned_track`:

- **Respect the pinned track for routine alerts.** A newer patch/minor *within* the
  pinned track (e.g. Python 3.12.13 → 3.12.14, Nginx 1.30.3 → 1.30.4) is a normal
  update — alert on it.
- **Flag a new major/minor beyond the pinned track separately** as a lower-priority
  "review" item, not a routine patch (e.g. PostgreSQL 18 → 19, Python 3.12 → 3.14,
  Kubernetes 1.36 → 1.37). Don't treat crossing a pinned boundary as an automatic
  upgrade — it's a decision.
- **Ignore pre-releases**: betas, RCs, mainline/odd branches (Nginx 1.31.x),
  nightly/weekly tags. Only stable/GA releases count.
- **Non-semver versions**: Garage uses a `v`-prefix (`v2.3.0`); date-stamped schemes
  (if a platform ever uses `RELEASE.YYYY-MM-DD`) compare lexically by date. Node is
  tracked by LTS *line*, so only alert when a new line becomes Active LTS, not on
  every patch.

If `check_url` returns a client-rendered page with no useful content, fall back to a
`WebSearch` for "<platform name> latest stable release" and confirm against the
project/vendor source. Never guess a version — if it can't be confirmed, skip that
entry and note it as "could not verify" in the run summary.

### 3. Decide what's new

Compare each newest stable against that entry's **`last_notified`** (not
`current_stable`). Collect an entry only when upstream is strictly newer than
`last_notified`. This is the dedup guarantee: once a version has been announced,
`last_notified` holds it and it won't be reported again.

Split the collected entries into two buckets:

- **Updates** — newer within the pinned track (routine, patch/minor).
- **Review** — a newer major/minor beyond the pinned track (needs a human decision).

### 4. Post to Slack (only if there is something new)

If both buckets are empty, post nothing. (Optionally, if the user asked for an "all
clear" confirmation, reply in chat — but don't post to the channel.)

If there is at least one item, send **one** digest message with `slack_send_message`
to `#stack-updates` (channel ID `C0BGJHF4117` in the sixeyed workspace; if that ID ever
fails, re-resolve it with `slack_search_channels` for name `stack-updates`). Suggested format:

```
:package: *CollabHub stack updates* — <today's date>

*Updates (within pinned track):*
• Python 3.12.13 → *3.12.14*  (patch) — https://www.python.org/downloads/
• Nginx 1.30.3 → *1.30.4*  (patch) — https://nginx.org/en/download.html

*Review (new major/minor — decision needed):*
• PostgreSQL 18.4 → *19.0*  (new major) — https://www.postgresql.org/support/versioning/

Source of truth: docs/platform/versions.md
```

Only include the sections that have items. Keep it to a single message so the channel
gets one clean digest per run. Include each platform's `check_url` so a human can jump
to the release notes and check for security fixes.

### 5. Write the watermark back (only after a successful post)

For every platform that was **announced** in step 4, edit `docs/platform/versions.md`:

- Set `last_notified` to the newly announced version.
- Also update `current_stable` and `released` to match (this keeps the "latest known"
  fields current). For a "Review" item you may prefer to bump `last_notified` but
  leave `pinned_track`/`base_image_hint` unchanged until the upgrade is actually
  decided — the point of the watermark is only to stop re-notifying.
- Update the top-level `last_reviewed` date to today.

Do this **only if the Slack message sent successfully.** If the post failed, leave
`last_notified` untouched so the next run retries — otherwise an update would be
silently swallowed.

If nothing was new, still update the top-level `last_reviewed` date so the file shows
when it was last checked.

### 6. Summarise the run

Give a short chat summary: which platforms were checked, what was announced (updates
vs review), anything that couldn't be verified, and confirm the watermark/`last_reviewed`
writes. Keep it brief.

## Idempotency & safety

- The watermark (`last_notified`) is the single dedup key. Never move it forward
  unless the corresponding Slack post succeeded.
- One digest message per run, not one message per platform.
- Never invent versions; skip and report anything that can't be confirmed from the
  authoritative source.
- Pinned-track boundaries are advisory, not automatic — surface major jumps as
  "review", don't apply them.

## Running on a schedule

This skill is designed to run unattended. Claude Code discovers it from
`.claude/skills/stack-update-checker/`. To automate it, create a scheduled task
(e.g. monthly, or weekly during heavy-CVE periods) whose prompt is:

> Run the stack-update-checker skill: check docs/platform/versions.md against upstream,
> post any new versions to the #stack-updates Slack channel, and update the watermarks.

The check is safe to run as often as you like — the watermark ensures the channel only
ever sees each release once.
