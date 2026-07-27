# Chapter 4 — Maximizing productivity with skills and schedules

Everything here comes out of the Cowork project you set up in chapter 3. The design documents that drive it are in [`chapters/ch03/lab/docs`](../ch03/lab/docs) — they aren't duplicated here.

Two repos are involved, and it's worth keeping them straight. Everything except the marketplace copy belongs to the CollabHub project repo, https://github.com/sixeyed/claude-at-work-project — the skills, the ADR, and the version list are all part of the project and travel with it. The plugin marketplace is separate, at https://github.com/sixeyed/claude-at-work-skills, because it's built to be shared beyond this one project.

## The stakeholder pack

Section 4.2 — *Try it now: produce a stakeholder project pack*.

| File | What it is |
| --- | --- |
| [`CollabHub-Application-Overview.docx`](CollabHub-Application-Overview.docx) | The high-level application summary, written for a non-technical audience |
| [`CollabHub-Build-Phases.xlsx`](CollabHub-Build-Phases.xlsx) | Build phases with estimates, showing what can run in parallel and where the dependencies are |

Both came from one prompt against the design docs. The interesting part isn't the output, it's that the prompt never mentioned skills — the words "document" and "spreadsheet" were enough for Claude to match the built-in docx and xlsx skills and load them on its own.

The spreadsheet totals about 20 sprints of work. Worth a look before Phase 2, since that's what the rest of the book builds.

## The skills

Section 4.4 — *Try it now: write a custom skill to generate ADRs*, and the chapter 4 lab.

| Skill | What it does |
| --- | --- |
| [`skills/adr-writer`](skills/adr-writer) | Writes an Architecture Decision Record from a stated decision. `SKILL.md` plus an `assets/template.md` reference file |
| [`skills/stack-update-checker`](skills/stack-update-checker) | Checks the platform versions list against current upstream releases and posts to Slack when something moves |

These live in `.claude/skills/` in the real project, which is what makes them available in Claude Code as well as Desktop. They're one level up here so they're easy to browse — copy the folder into `.claude/skills/` in your own project to use them.

Read `adr-writer/SKILL.md` for the description field in particular. That's the part Claude reads at startup to decide when the skill applies, and it's the difference between a skill that fires when you want it and one that never fires at all.

### The golden source

Both of these are **project** skills — they belong to CollabHub and live in the project repo, at `.claude/skills/`. The canonical versions are in **https://github.com/sixeyed/claude-at-work-project**, along with the ADR and the version list they produced.

That's the distinction the chapter draws in section 4.5: a skill in your project repo travels with the code and is available to anyone who clones it, which is what you want for a team convention like an ADR format. Skills you want to share more widely get bundled as a plugin instead — that's the marketplace repo further down, and it's a different repo for a reason.

The copies here are snapshots taken at the end of this chapter, so what you read matches what the book describes. Go to the project repo for the current versions.

## What the skills produced

| File | What it is |
| --- | --- |
| [`docs/adr/260708-python-instead-of-dotnet.md`](docs/adr/260708-python-instead-of-dotnet.md) | The ADR recording the .NET → Python switch, written by `adr-writer` |
| [`docs/platform/versions.md`](docs/platform/versions.md) | The tracked platform versions — the input `stack-update-checker` runs against |

Both are project files, so the current versions are in the project repo under the same paths.

`versions.md` is the more interesting of the two. It's written for an agent to consume rather than a human to read: each platform carries a `check_url` pointing at the authoritative upstream release list, and a `last_notified` watermark so repeat runs don't re-announce the same version. That watermark is the fix for the problem described in section 4.6 — a scheduled run that tries to edit its own skill will stall waiting for permission and block every run after it. Keep run state in a separate file.

## The plugin marketplace

Section 4.8 — *Try it now: install my plugin and create a GitHub issue*.

[`claude-at-work-skills`](claude-at-work-skills) is a copy of the marketplace repo, matching the layout in listing 4.1 — `marketplace.json` at the root, then one folder per plugin, each with its own `plugin.json` and a `skills` folder. The `github-workflow` plugin bundles three skills: `create-issue`, `create-pr`, and `work-on-issue`.

**To install it, don't use this copy** — add the marketplace from https://github.com/sixeyed/claude-at-work-skills, as the chapter describes. Installing from the golden source is also how you get updates; this snapshot is frozen at the chapter.

The copy is here so you can read the skills before you install them, which is exactly what section 4.8 recommends for any third-party marketplace. Three short `SKILL.md` files is a quick read, and it's a habit worth forming — a skill you install runs with your permissions.

## Not in the repo

Schedules are saved to your user folder, not the project, so there's nothing to publish for the daily repo digest in section 4.7 or the stack-update schedule in the lab. Ask Claude where yours live and you'll get the path — mine are under `~/Claude/Scheduled/`. Each one is a `SKILL.md`, so once you find the folder they read exactly like the skills above.
