# HANDOVER: Djinni's Data Texts (DDT)

> A World of Warcraft Retail addon: a suite of LDB DataText modules with rich tooltips,
> shown by any LDB display addon. Shipped and in active development. Read this, then
> `docs/board/`, before changing anything.

**Stage:** shipped
**Status:** v0.9.12 is the last release; the tree is at 0.9.13, carrying the 12.1.0 pass and
per-module toggles and poll control (card 0001). Neither has been run in the game client, and
0.9.13 is unreleased. Deployed to the game folder and clean in git, on a branch, unpushed.
_Last updated: 2026-08-14 (12.1.0 pass reviewed and confirmed deployed; changelog corrected)_

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
  `petinfo`) except `ActiveActivity`, registered CamelCase at
  [Modules/ActiveActivity.lua:228](../Modules/ActiveActivity.lua#L228). Its saved table is
  therefore `DjinnisDataTextsDB.ActiveActivity`. Do not tidy this without a migration step;
  renaming the key orphans every existing user's settings for that module.
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
- **Three exclusion lists must agree**: `pkgmeta.yaml`, `release.ps1` (`$ExcludeNames`) and
  `deploy.ps1` (`$ExcludeFiles` / `$ExcludeFolders`). Adding a root-level dev file means
  editing all three, or it ships to users. **They currently disagree**, because the 12.1.0
  pass edited only `deploy.ps1`, which is exactly the trap this note warns about:

  | File | `deploy.ps1` | `release.ps1` | `pkgmeta.yaml` | Effect |
  |---|---|---|---|---|
  | `CURSEFORGE.md` | excluded | — | — | ships inside both zips |
  | `.gitattributes` | excluded | — | — | ships inside both zips |
  | `DemoMode.lua` | — | excluded | excluded | copied into the game folder |

  `DemoMode.lua` is harmless: it is commented out of the `.toc`, so it is copied and never
  loaded. The other two are the live question, and it is still Rob's rather than a tidy-up,
  for the reason below.
- **`CURSEFORGE.md` ships inside the addon zip**, and did so in every release to date. That
  is probably unintended, but removing it changes what users receive, so it is Rob's call.
  Left as found and flagged, now with the added wrinkle that `deploy.ps1` alone stopped
  copying it as of `12f483c`.
- **`--help/DjinnisDataTexts-v0.9.11.zip` was tracked in git**: a 793KB build artefact in a
  directory created from a mistyped `release.ps1` argument. `12f483c` untracked it and moved
  the zip into gitignored `releases/`. Card 0005 stays open for the other half of its ask:
  `release.ps1` still turns an unparsed `--help` into a directory rather than refusing.
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

## Current state

- **Done:** v0.9.12 is released and on CurseForge, supporting interface 120007 and 120100.
  The tree has since moved to 0.9.13 and interface `120100` alone, which is the 12.1.0 pass.
  Twenty-five DataText module files plus the thirteen-file Professions framework are loaded
  from the `.toc`, covering social, character, economy, instances, time and location,
  system, professions and audio. Every module has a Blizzard Settings subcategory with label
  templates, tooltip sizing, sort order, click actions and a per-module Reset to Defaults.
  A global panel owns fonts, number formatting and gold display. DjinnisGuildFriends
  settings migrate automatically and a coexistence warning fires if both are loaded.
  Recent releases have mostly been Midnight-era compatibility: combat-lockdown guards on
  secure tooltip parents, secret-taint pcalls, and the 12.1 support pass.
- **In progress:** nothing is in `in-progress/`. Card 0001 sits in `ai-review/`: per-module
  enable/disable toggles and per-module refresh intervals are written and committed, but
  **have never been run in the game client**, and the new Modules settings panel has not had
  a single frame constructed. The `.toc` reads 0.9.13 and 0.9.13 is unreleased, so the version
  bump covers both card 0001 and the 12.1.0 pass. Both are deployed to the game folder and
  both are still waiting on the same thing: someone loading the addon and looking.
- **Known bugs / broken:** none open. Note that this is the absence of a bug list rather
  than the presence of a green test suite; there is no automated verification at all, and
  everything is confirmed by loading the addon in game.

## What's next (in order)

The queue is [docs/board/todo/](board/todo/), one card per file. Do not restate it here.
At the head:

1. **Load 0.9.13 in the game client.** One session covers two things, because both are already
   deployed and both are unverified. Card 0001 in `ai-review/` is the bigger half: `/reload`,
   then work the Modules panel, whose acceptance criteria are the test script and none of which
   are ticked. While in there, exercise the three modules the 12.1.0 pass changed — Professions
   tooltips, Pet Info's Safari Hat row, and the SimC export on Item Level — which is workspace
   card 0008. Together they are the only thing standing between 0.9.13 and a release.
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

On `claude/wow-12.1.0-patch-update`, clean, no PR. It is one commit ahead of `master`
(`12f483c`, the 12.1.0 pass), and `master` is itself **7 commits ahead of `origin/master`**.
Nothing since v0.9.12 has reached GitHub. The merge is a fast-forward; this is workspace
card 0007.

There is otherwise no branching convention in the history: work lands directly on `master`
and releases are tagged from it, so this branch is the exception rather than a new habit.

## Session log

The narrative is the commit history: `git log --format='%ad %s%n%b' --date=short`.
Decision rationale belongs in `docs/DECISIONS.md` once card 0006's follow-up creates it, and
in the Decisions locked section above until then.
