# HANDOVER: Djinni's Data Texts (DDT)

> A World of Warcraft Retail addon: a suite of LDB DataText modules with rich tooltips,
> shown by any LDB display addon. Shipped and in active development. Read this, then
> `docs/board/`, before changing anything.

**Stage:** shipped
**Status:** v0.9.14 is the release that matters, out 2026-08-15 to GitHub and CurseForge. `v0.9.15`
followed the same day and is a no-op republish of it, published by accident; see Key files.
**Card 0001's Modules panel has now been seen working in a live client**, the first in-game
verification this project has had, and the three bugs it found are what 0.9.14 fixes. Deployed to
the game folder as 54 files, clean in git, `master` in sync with `origin`.
_Last updated: 2026-08-15 (0.9.14 released and verified in game; 0.9.15 published in error)_

## Goal & success criteria

**No PRD exists. This section is an interim home and a real gap** (card 0006 owes
`docs/PRD.md`). The goal and criteria below are inferred from `README.md`, `CURSEFORGE.md`
and the phase history in [docs/build/task.md](build/task.md), not from a stated spec. The
non-goals in particular are unknown and need Rob.

Goal: one addon that replaces a pile of single-purpose LDB brokers, giving every DataText
the same rich tooltip style, the same configurability, and one settings home. It absorbs and
replaces the author's earlier DjinnisGuildFriends addon, migrating its saved variables on
first load.

Success criteria, as they appear to be operating in practice:
- Every module carries a configurable label template, tooltip width and scale, sort order
  and click actions, all from the Blizzard Settings UI.
- Tooltips look and behave the same across every module (dark backdrop, gold headers,
  class-coloured names, grey hint bar).
- Works with any LDB display (ElvUI, Titan Panel, Bazooka, ChocolateBar), so nothing may
  depend on a particular display addon's API.
- No Lua errors and no taint. Several past releases were entirely about combat-lockdown
  guards and secret-taint fixes, so this is a live constraint rather than a background one.

## Canonical data shape

**Owner is `Core.lua` until `docs/DATA-MODEL.md` exists** (card 0006). One saved variable,
declared in the `.toc`:

```
DjinnisDataTextsDB = {
    global = { ... },          -- cross-module settings: fonts, number formatting,
                               -- gold display, custom URLs, tag separator
    [moduleKey] = { ... },     -- one table per module, keyed by its registration key
    _migratedFromDGF = bool,   -- set once, after DjinnisGuildFriends settings are pulled in
    _schemaVersion   = int,    -- migration stamp; fresh DB starts at 0
}
```

- Flat, no profiles. Per-character data is not separated; the DB is account-wide.
- A module contributes its own defaults through `ns:RegisterModule(key, mod, defaults)`
  ([Core.lua:194](../Core.lua#L194)), which stores them at `ns.defaults[key]`. At
  `ADDON_LOADED`, `MergeDefaults` copies anything missing from `ns.defaults` into the saved
  DB, so new settings appear on upgrade without a migration.
- **Additive defaults need no migration; changed defaults do.** `SCHEMA_VERSION`
  ([Core.lua:318](../Core.lua#L318)) plus `RunSchemaMigrations` handle the second case. v1
  raised saved tooltip widths that still equalled a known old default. Bump the constant
  whenever a step is added.
- **Divergence to be aware of:** module keys are lowercase (`bagvalue`, `savedinstances`,
  `petinfo`) except `ActiveActivity`, registered CamelCase. Its saved table is therefore
  `DjinnisDataTextsDB.ActiveActivity`. Do not tidy this without a migration step; renaming
  the key orphans every existing user's settings for that module. **This divergence had
  already caused a live bug**: `GetDB()` read `ns.db.activeactivity`, which is not the key
  `MergeDefaults` creates, so it always missed and returned the shared `DEFAULTS` table.
  Reads therefore ignored saved values and writes landed on the defaults table in memory.
  Fixed in 0.9.14. If a fourth module is ever registered CamelCase, check its `GetDB()`
  first; the whole-codebase check is to compare each file's `RegisterModule("…")` key
  against the `ns.db.<key>` it reads.
- Broker names are a separate namespace from module keys: `DDT-<Name>`, and they are what
  the display addon persists in *its* config. Renaming a broker breaks users' bars.

## Architecture / stack

Pure Lua, no build step, no test suite. Load order is `.toc` order.

```
LibStub + CallbackHandler + LibDataBroker-1.1   (Libs/, vendored)
        |
Core.lua        namespace `ns`, module registry, saved-variables load and migration,
                shared formatting/sort/tooltip helpers, the periodic refresh ticker
Settings.lua    widget helpers + one Blizzard Settings subcategory per module
        |
Modules/*.lua   one file per DataText. Each registers with ns:RegisterModule(),
                creates its LDB broker at file-load time, and exposes UpdateData()
Modules/Professions/   a sub-framework: Core.lua plus one Data_*.lua per profession,
                       creating its brokers dynamically in Init rather than at load
```

Three modules are not one-broker-one-file: **PreyTracker** and **Delve** feed plain-table
dataobjs into **ActiveActivity**, which owns the combined broker. Treat them as a unit.
As of 0.9.14 they declare `moduleKey` on their tracker definition, which puts them in
`ns.subTrackerModules` and keeps them out of the Modules panel; their row, dropdown and all,
is rendered in ActiveActivity's panel instead via the exported `AddModuleRow`. **A module
that owns no broker must never appear in the Modules panel**, because that panel's promise
is "turning this off removes a DataText" and for a sub-tracker there is nothing to remove.

**Professions** is the third, in the other direction: one module, many brokers. It calls
`LDB:NewDataObject("DDT-Prof-…")` directly in `Init` rather than `ns:NewBroker`, so it sits
outside the deferred-broker mechanism entirely. Disabling it still works, because `Init` is
what is gated, but it works by a different route than every other module.

The refresh model, which is the thing most likely to be misunderstood:

- **Brokers are deferred.** A module calls `ns:NewBroker(key, name, spec)` at file-load time,
  which queues the spec and hands the same table straight back; `ADDON_LOADED` then registers
  only the enabled ones with LDB. This exists because module files run before saved variables
  do, so nothing can know it is disabled when it registers, and LDB has no unregister.
- **Enable state and poll interval live in `ns.db.modules`**, outside each module's own
  settings table, so neither reset path can reach them. Both default to the old behaviour.
- **A 1s driver refreshes at most one due module per tick**, each on its own interval. One
  per tick, and one per frame during the initial refresh, both exist for the same reason:
  Experience scans the quest log, SavedInstances iterates characters and BagValue walks every
  bag slot, and running them together trips WoW's "script ran too long" watchdog.
- **Only modules defining `UpdateData` are ever polled.** Eight are not: ActiveActivity,
  AudioOutput, BagValue, Coordinates, MicroMenu, PlayedTime, TimeDate, VolumeControl. They
  are event-driven or keep their own throttled `OnUpdate`. This was already true of the old
  ticker, whose comment wrongly claimed it refreshed bag value and played time.
- Heavy work (tooltip contents, deep scans) is hover-gated and never runs on the timer.

## Key files / structure

```
CLAUDE.md                  orient tripwire, conventions
README.md                  user-facing docs (root: the repo entry point)
CHANGELOG.md               root, and it must stay there: release.ps1 prepends to it
RELEASE_NOTES.md           root. The "## Version: x.y.z" line is the release source of truth
CURSEFORGE.md              addon page copy. Root, and currently ships inside the zip (below)
DjinnisDataTexts.toc       module list and load order. Commenting a module out is supported
Core.lua                   ~1500 lines. Namespace, registry, DB load/migrate, refresh ticker
Settings.lua               all settings panels and the shared widget helpers
DemoMode.lua               fake data injector; commented out in the .toc, excluded from builds
Modules/                   one file per DataText
Modules/Professions/       profession sub-framework, brokers created in Init
release.ps1 / deploy.ps1   release and local-deploy scripts, both with exclusion lists
pkgmeta.yaml               CurseForge packager config, with its own ignore list
docs/                      HANDOVER + board + build/ + spec/ + images/
```

Non-obvious things worth knowing before you touch them:
- **There is one exclusion list, and it lives in `pkgmeta.yaml`** (2026-08-14). Its `ignore:`
  block is parsed at runtime by `release.ps1` and `deploy.ps1`, so the CurseForge zip, the
  release zip and the game folder cannot disagree. **Add exclusions there and nowhere else.**
  Both scripts throw rather than continue if the file is missing or the block is empty, so
  the failure mode is a refusal, not a silent ship of everything.

  This replaces three hand-synced lists that had already drifted: `CURSEFORGE.md` and
  `.gitattributes` were shipping inside every zip, and `DemoMode.lua` plus the retired
  `Modules/MajesticBeast.lua` were being copied into the game folder. The rule the list
  encodes: **if the addon does not need it to run in the game, it is ignored.** That is 54
  files shipped, identical in all three destinations.
- **`--help/DjinnisDataTexts-v0.9.11.zip` was tracked in git**: a 793KB build artefact in a
  directory created from a mistyped `release.ps1` argument. `12f483c` untracked it and moved
  the zip into gitignored `releases/`. Card 0005 stays open for the other half of its ask:
  `release.ps1` still turns an unparsed `--help` into a directory rather than refusing.
- **`RELEASE_NOTES.md` must be cleared after every release, and this is not housekeeping.**
  `release.ps1` takes the version from that file and rewrites the `.toc` to match, so stale
  notes do not just look wrong, they rename the build. It happened on 2026-08-14: 0.9.12's
  notes had sat in the file since May, a release run read `0.9.12` from them, rewrote a
  0.9.13 `.toc` backwards, and published 0.9.13's code to GitHub and CurseForge as `v0.9.12`
  with May's changelog entry. Superseded by a correct `v0.9.13` the same day rather than
  unpicked, because deleting a tag CurseForge has already ingested achieves nothing. The
  `v0.9.12` tag therefore points at 0.9.13's code and is expected to; do not try to fix it.
  The file now carries the warning in its own header.
- **`-DryRun` is dry as of 0.9.15**, including the auto-bump path, which used to rewrite
  `RELEASE_NOTES.md` and the `.toc` without checking the switch. Verified against a throwaway
  clone with the tag already present: it previews the bumped version end to end and leaves the
  tree untouched.
- **`release.ps1` refuses unrecognised arguments, and it took two goes to get right.** The two
  ways of launching a PowerShell script bind arguments differently:

  | Invocation | Where `--help` ends up |
  |---|---|
  | `pwsh -File release.ps1 --help` | `$args`, with `$OutputDir` left at its default |
  | `& .\release.ps1 --help` | bound positionally to `$OutputDir` |

  The first guard only inspected `$OutputDir`, so it caught the `&` form and sailed straight past
  the `-File` form. **That published v0.9.15 by accident**, from a command whose entire purpose was
  to prove the guard worked. Both are covered now: a non-empty `$args` is refused outright, since
  every real parameter is declared. If you add a parameter, do not add a positional one.
- **The dirty-tree check in section 3 is load-bearing.** It is what stops an unintended invocation
  going all the way, and it has now done so once for real. Treat it as a safety mechanism rather
  than a convenience and do not relax it.
- **`v0.9.15` is a no-op release** and is expected to be. Byte-identical to `v0.9.14` but for the
  `.toc` version. Left in place rather than withdrawn, on the same reasoning as `v0.9.12`.
- **The version regex runs before comments are stripped.** `release.ps1` finds the version
  with a plain regex over the raw file, then strips HTML comments later, so a version heading
  written inside a comment wins if it appears first. A draft `RELEASE_NOTES.md` did this and
  resolved the version to a single backtick, which propagated into the tag name and zip path.
- `Libs/` is vendored third-party code. Do not edit it.

## Decisions locked

No `DECISIONS.md` yet, so the ones a fresh session must not reverse are recorded here.

- **Module toggles apply on `/reload`, not live** (2026-06-23). Matches the workflow users
  already have from editing the `.toc`, and avoids the hard part: LDB has no unregister, so
  a broker cannot be withdrawn once created.
- **Brokers must be created before saved variables exist**, which is why a disabled module
  cannot simply skip its own registration. Card 0001's deferred-broker mechanism is the
  answer, and it was checked against LDB internals: `NewDataObject` mutates and returns the
  same table, so a module's `dataobj` upvalue stays valid when registration is deferred.
- **"Only refresh what is displayed" is not implementable.** LDB exposes no visibility
  signal; that state lives inside the display addon with no universal API. The per-module
  poll interval is the deliberate approximation, and answering a user's request for it
  should say so rather than promise the real thing.
- **Enable state lives outside per-module settings**, so "Reset to Defaults" cannot silently
  re-enable a module the user turned off.
- **The refresh ticker walks one module per frame** rather than looping them, because
  Experience scans the quest log, SavedInstances iterates characters and BagValue walks
  every bag slot; together they trip the script watchdog.
- **The initial refresh is delayed 1s, not one frame.** `GetProfessions`, `C_CurrencyInfo`
  and `C_QuestLog` all return nil during `ADDON_LOADED`.
- **MajesticBeast is retired**, migrated into the Professions framework. Its file is still
  in the tree but commented out of the `.toc`.
- **Docs live under `docs/`** as of 2026-08-06, except README / CHANGELOG / RELEASE_NOTES /
  CURSEFORGE, which the release toolchain and the addon page read from the root.
- **`pkgmeta.yaml` owns the one exclusion list** (2026-08-14), parsed by both PowerShell
  scripts rather than duplicated into them. Rejected keeping three lists and re-aligning
  them: they had drifted once already, and a list that must be edited in three places is a
  list that will drift again. The scripts duplicate a twelve-line parser instead, which is
  the cheaper thing to keep in step because it has no reason to change.
- **Nothing ships that the addon does not need to run** (2026-08-14). This is what decided
  the open `CURSEFORGE.md` question, and it also drops `DemoMode.lua` and the retired
  `Modules/MajesticBeast.lua`, both of which are in the tree but absent from the `.toc` and
  therefore incapable of running.

## Current state

- **Done:** v0.9.13 is released and on CurseForge, at interface `120100` alone. It carries the
  12.1.0 pass and card 0001, and it ships 54 files after the exclusion lists were consolidated.
  Twenty-five DataText module files plus the thirteen-file Professions framework are loaded
  from the `.toc`, covering social, character, economy, instances, time and location,
  system, professions and audio. Every module has a Blizzard Settings subcategory with label
  templates, tooltip sizing, sort order, click actions and a per-module Reset to Defaults.
  A global panel owns fonts, number formatting and gold display. DjinnisGuildFriends
  settings migrate automatically and a coexistence warning fires if both are loaded.
  Recent releases have mostly been Midnight-era compatibility: combat-lockdown guards on
  secure tooltip parents, secret-taint pcalls, and the 12.1 support pass.
- **In progress:** nothing is in `in-progress/`. Card 0001 is released and, as of 0.9.14,
  **partly verified in a live client**: the Modules panel and Active Activity's tracker rows
  were confirmed by screenshot on 2026-08-15, including the row count, the eight
  "updates on its own" modules, dropdowns greying out on disabled rows, and enable flags
  surviving a reload. That single look found three bugs, one of which (the wrong saved key)
  had been shipping silently for releases. **What is still unverified is everything else**:
  the toggles have not been exercised through an actual enable, reload and disable cycle, and
  the 12.1.0 pass has had no in-game check at all. Card 0001 stays in `ai-review/` until its
  test script is actually walked.
- **Known bugs / broken:** none open, and read that narrowly. There is no automated
  verification of behaviour at all: what has been checked is that all 45 Lua files parse under
  5.1, every `.toc` entry resolves, and nothing calls a global that exists only in a
  `Blizzard_Deprecated*` shim. None of that exercises a single frame or tooltip. Everything
  behavioural is confirmed by loading the addon in game, and 0.9.13 has not been.

## What's next (in order)

The queue is [docs/board/todo/](board/todo/), one card per file. Do not restate it here.
At the head:

1. **Load 0.9.13 in the game client.** It is released, so this is no longer a gate before
   shipping but a check on something already shipped. One session covers both unverified
   halves. Card 0001 in `ai-review/` is the bigger one: `/reload`, then work the Modules panel,
   whose acceptance criteria are the test script and none of which are ticked. While in there,
   exercise the three areas the 12.1.0 pass changed, which is workspace card 0008: Professions
   tooltips, Pet Info's Safari Hat row, and the SimC export on Item Level.
2. **0006 write PRD.md and DATA-MODEL.md.** Closes the two loudest gaps in this handover.
   Needs one answer from Rob on non-goals; everything else is derivable.
3. **0003 / 0004 Achievements and Quest Log module scope.** Both waiting on card 0002.

## Blockers / open questions

Two cards sit in [docs/board/human-review/](board/human-review/), each carrying its own
options and a recommendation:

- **0002: how to answer the CurseForge comment.** Genuinely blocking, and the only
  time-sensitive item here: it is a public comment awaiting a reply, and it gates the scope
  decisions on cards 0003 and 0004. A draft reply is ready for each option.
- **0005: the stray `--help/` release zip.** Not blocking anything, a one-minute answer.

Nothing is waiting on an outside party, so no card carries a `waiting_on:` date.

## How to pick up

```bash
cd /c/Dev/WoWAddons/DjinnisDataTexts
git log --format='%ad %s' --date=short -10        # recent history
ls docs/board/todo docs/board/in-progress docs/board/human-review

# deploy a working copy into the game client and test
pwsh -File deploy.ps1 -DryRun                     # check what would be copied first
pwsh -File deploy.ps1
# then in game: /reload, and exercise the module you changed, watching for Lua errors

# cut a release (Rob drives this; the version comes from RELEASE_NOTES.md)
pwsh -File release.ps1 -DryRun
```

There is no test suite and no linter. **Verification is loading the addon in game.** Say so
plainly when a change has only been reasoned about, and never report an in-game behaviour as
confirmed when it has not been run.

## Suggested skills / next tools

| Tool | When |
|------|------|
| `/handover resume` | Start of the next session. Reads this doc and the board, then starts the head card. |
| `/checkpoint` | After a chunk of work, to update the docs and commit. |
| `/scaffold-docs` | When starting card 0006; it owns creating PRD / DATA-MODEL / DECISIONS. |
| `/code-review` | Before releasing card 0001. It touches ~23 module files plus the core load path, which is exactly the shape of change that benefits. |
| ProgressBoard (`C:\Dev\ProgressBoard`) | To see this board alongside every other project's, ordered by what is waiting on Rob. |

For WoW API questions, the memory note `wow-api-audit-method` records the method: check calls
against wow-ui-source rather than generated docs, which are incomplete, and cross-check
Blizzard's own Lua usage.

## Sibling docs

| Doc | Purpose |
|-----|---------|
| [CLAUDE.md](../CLAUDE.md) | Orient tripwire and project conventions. Auto-loaded. |
| [docs/board/README.md](board/README.md) | The board convention. Owned by the `/handover` skill; never edit the local copy. |
| [docs/build/PLAN-module-toggles.md](build/PLAN-module-toggles.md) | Full design for card 0001. Read before starting it. |
| [docs/build/task.md](build/task.md) | Historical phase tracker, phases 1 to 9. Superseded by the board; kept for history. |
| [docs/ARTWORK_PROMPTS.md](ARTWORK_PROMPTS.md) | Image-generation prompts for logo and banner art. |
| [README.md](../README.md) | User-facing module documentation with screenshots. |
| [CURSEFORGE.md](../CURSEFORGE.md) | Addon page copy. |
| [CHANGELOG.md](../CHANGELOG.md) / [RELEASE_NOTES.md](../RELEASE_NOTES.md) | Release history and the pending release's notes. |
| `docs/PRD.md`, `docs/DATA-MODEL.md`, `docs/DECISIONS.md` | **Missing.** Card 0006 owes the first two; no card yet for DECISIONS. |

## Branch status

On `master`, clean, in sync with `origin/master`, and tagged `v0.9.13`.
`claude/wow-12.1.0-patch-update` fast-forwarded in on 2026-08-14 carrying the 12.1.0 pass and
the exclusion-list consolidation, closing a ten-commit gap in which nothing since v0.9.12 had
reached GitHub. That was workspace card 0007. The merged branch still exists locally and is
safe to delete.

No branching convention in the history otherwise: work lands directly on `master` and
releases are tagged from it, so that branch was the exception rather than a new habit.

Tags now match the code, with one deliberate scar: **`v0.9.12` points at 0.9.13's code** from
the mis-versioned run described under Key files. `v0.9.13` is the real release and the one to
reason from. Do not attempt to reconcile `v0.9.12`.

## Session log

The narrative is the commit history: `git log --format='%ad %s%n%b' --date=short`.
Decision rationale belongs in `docs/DECISIONS.md` once card 0006's follow-up creates it, and
in the Decisions locked section above until then.
