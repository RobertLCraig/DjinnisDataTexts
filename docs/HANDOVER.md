# HANDOVER: Djinni's Data Texts (DDT)

> A World of Warcraft Retail addon: a suite of LDB DataText modules with rich tooltips,
> shown by any LDB display addon. Shipped and in active development. Read this, then
> `docs/board/`, before changing anything.

**Stage:** shipped
**Category:** addon
**Status:** v0.9.14 is the last release that matters, out 2026-08-15 to GitHub and CurseForge.
`v0.9.15` followed the same day and is a no-op republish of it, published by accident; see Key
files. **An unreleased 0.9.16 now sits in the tree**: the Delve tracker recognises 12.1.0 Lairs
(card 0008 in `ai-review/`). It parses and nothing more; it has not been in a game client.
**A shipped defect was found by reading on 2026-08-24 and is now card 0010**: the SimC export
on the Item Level module never reaches the SimulationCraft addon and the string it copies
instead is not the format Raidbots parses.
**A second shipped defect was reported from the game on 2026-08-25 and is card 0011**: Saved
Instances kept every character it had ever seen forever, including one on an MDI tournament
realm that Blizzard has since taken down, so a character nobody can log in to again had its
own tooltip column. **Fixed, checked in the client by Rob, and `done/`.**

**0.9.16 is packaged and deliberately held.** `RELEASE_NOTES.md` carries all three changes,
`release.ps1 -DryRun` is clean at 54 files, and the tag has not been cut. Rob was asked on
2026-08-25 whether to publish with two of the three changes never run in a game, and chose to
check them first. **The release is one command away and the only thing standing in front of it
is the in-game check on cards 0008 and 0010.** Do not cut the tag until those are ticked.
_Last updated: 2026-08-29 (card 0006: PRD and DATA-MODEL written; this doc now links them)_

## Goal & success criteria

**Owned by [docs/PRD.md](PRD.md).** One addon replacing a pile of single-purpose LDB brokers:
one tooltip style, one settings home, any LDB display, no Lua errors and no taint.

**The PRD's non-goals section is still an open gap and needs Rob.** Everything else in it was
reconstructed from the repository; the non-goals could not be, and were marked rather than
invented.

## Canonical data shape

**Owned by [docs/DATA-MODEL.md](DATA-MODEL.md).** One flat, account-wide saved variable,
`DjinnisDataTextsDB`, merged from per-module defaults at load and versioned by a schema stamp.

Read that doc before touching saved settings. Its "Known divergences" section is the part
that bites.

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
  the zip into gitignored `releases/`. Card 0005 is closed and sits in `done/`; the argument
  guard described below is the other half of its ask, and it has shipped.
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
- **Uncommitted at the head of this doc:** an unreleased 0.9.16 covering **12.1.0 Lairs**,
  card 0008. A Lair is a queueable delve added on 2026-08-18, and the game reports every Lair
  as an active delve, so the tracker labelled one "Delve". `Modules/Delve.lua` now carries an
  `inLair` flag from `C_DelvesUI.IsInLair()`, a `KindLabel()` helper and a `<kind>` label tag;
  the default template moved to `<kind>: <progress>` with schema migration v2 behind it.
  Verified against `wow-ui-source` at `12.1.0 (69382)` that nothing else we consume changed:
  the `ScenarioHeaderDelves` widget is byte-identical and was only relocated, and no
  `C_DelvesUI` call we make was removed. **It parses under Lua 5.1 and that is all.**
- **In progress:** nothing is in `in-progress/`. Card 0001 is released and, as of 0.9.14,
  **partly verified in a live client**: the Modules panel and Active Activity's tracker rows
  were confirmed by screenshot on 2026-08-15, including the row count, the eight
  "updates on its own" modules, dropdowns greying out on disabled rows, and enable flags
  surviving a reload. That single look found three bugs, one of which (the wrong saved key)
  had been shipping silently for releases. **What is still unverified is everything else**:
  the toggles have not been exercised through an actual enable, reload and disable cycle, and
  the 12.1.0 pass has had no in-game check at all. Card 0001 has since had its adversarial
  pass and moved to `human-review/`, where it stays until Rob walks its test script.
- **Known bugs / broken: one open, card 0010.** The SimC export on `Modules/ItemLevel.lua`
  is broken in both of its two paths, and it is released. The delegation branch looks up the
  SimulationCraft addon's slash handler under the key `SIMULATIONCRAFT`, but a command
  registered as `/simc` lives under `SIMC`, so it misses even when that addon is installed and
  the fallback always runs. The fallback then emits no `talents=`, `region=`, `role=` or
  `professions=` line and writes gear as a raw `item:` link rather than the keyed
  `head=,id=N,bonus_id=...` form, so Raidbots cannot read it. Found by reading, not by running.
  **This is the second fault static checks would never surface**, alongside the wrong saved key
  fixed in 0.9.14: the code runs, throws nothing, and produces output nobody had validated.
- **Card 0011 is fixed, checked in the client, and `done/`.** `ns.db.altLockouts` grew one
  entry per character ever logged in and nothing ever removed one, so an entry saved on
  2026-04-16 under the key `Djinni - EU Mythic Dungeons` rendered as a permanent extra tooltip
  column carrying last season's keys. **`EU Mythic Dungeons` is a real realm, not a bad string**:
  a temporary MDI tournament realm that Blizzard has since taken down, which is why nothing
  self-corrected. A character on a dead realm can never log in to refresh its own entry, so any
  rule that waits for a login would never fire. The wider fault behind it: only the current
  character's weekly data was ever wiped at reset, so every stored alt showed last week's keys
  as current. `PruneStaleAltData()` in `Modules/SavedInstances.lua` now forgets any stored
  character not seen within `altPruneWeeks` weekly resets, a new 0 to 26 slider defaulting to
  **3** at Rob's request (0 = never). It keeps a character still holding an unexpired extended
  raid lockout whatever the setting, and prunes nothing at all if the reset time cannot be
  read. **This is the third fault of that same class**: no error, no failing parse, wrong data
  on screen for months. Note that commit `520cde5` names a cause the card has since corrected.
- Beyond that, read "none open" narrowly. There is no automated
  verification of behaviour at all: what has been checked is that all 45 Lua files parse under
  5.1, every `.toc` entry resolves, and nothing calls a global that exists only in a
  `Blizzard_Deprecated*` shim. None of that exercises a single frame or tooltip. Everything
  behavioural is confirmed by loading the addon in game, and 0.9.13 has not been. The 0.9.16
  Lair work adds a second unverified layer on top of that.

## What's next (in order)

The queue is [docs/board/todo/](board/todo/), one card per file. Do not restate it here.
At the head:

1. **0008 in `ai-review/`: verify the Lair work in the game client.** `deploy.ps1`, `/reload`,
   then enter a Lair and an ordinary delve and check the four label and template criteria.
   **This and item 2 are the only things holding the packaged 0.9.16 release.**
2. **0010's slash-key half: click the Item Level SimC export with Simulationcraft installed**
   and confirm that addon's own window opens rather than Data Texts' simpler copy box. That
   half is committed and unverified. The Raidbots-format half of the card is untouched and
   does not gate the release, because the notes say so plainly.
3. **Then publish 0.9.16.** `pwsh -File release.ps1`, then clear `RELEASE_NOTES.md` and bump
   its heading in the same sitting. The dry run was clean on 2026-08-25 at 54 files.
4. **Load the shipped code in the game client too**, in the same sitting. Card 0001 sits in
   `human-review/` with its test script unticked: work the Modules panel, and while in there
   exercise the three areas the 12.1.0 pass changed, which is workspace card 0008 on the
   `C:\Dev\WoWAddons` board: Professions tooltips, Pet Info's Safari Hat row, and the SimC
   export on Item Level.
5. **0010's other half: the export format.** The slash-key half is committed, so what is left
   is that Data Texts' own fallback string is not what Raidbots parses. It needs a real
   `/simc` export captured from the Simulationcraft addon first, to compare against.
6. **0006 is written and in review.** [docs/PRD.md](PRD.md) and
   [docs/DATA-MODEL.md](DATA-MODEL.md) now exist and this handover links them instead of
   carrying their text. What is left of that card is one answer from Rob: **the PRD's
   non-goals**, which is the only thing in it that could not be derived from the repository.

## Blockers / open questions

**The 0.9.16 release is held on two in-game checks**, cards 0008 and 0010, listed as items 1
and 2 in the queue above. It is packaged and one command from going out. Rob made that call on
2026-08-25 rather than publish two changes nobody had run.

Two cards sit in [docs/board/human-review/](board/human-review/):

- **0002: how to answer the CurseForge comment.** A decision card, options and a
  recommendation inside it. Genuinely blocking, and the only time-sensitive item here: it is
  a public comment awaiting a reply, and it gates the scope decisions on cards 0003 and 0004.
  A draft reply is ready for each option.
- **0001: per-module enable / disable toggles.** Not a decision, a build awaiting acceptance.
  It has had its adversarial pass; what it needs is Rob walking its test script in game.

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
| `/scaffold-docs` | If `docs/DECISIONS.md` is ever opened as a card. It owns the doc-set templates; PRD and DATA-MODEL are already written. |
| `/code-review` | Before releasing card 0001. It touches ~23 module files plus the core load path, which is exactly the shape of change that benefits. |
| ProgressBoard (`C:\Dev\ProgressBoard`) | To see this board alongside every other project's, ordered by what is waiting on Rob. |

For WoW API questions, the memory note `wow-api-audit-method` records the method: check calls
against wow-ui-source rather than generated docs, which are incomplete, and cross-check
Blizzard's own Lua usage.

## Sibling docs

| Doc | Purpose |
|-----|---------|
| [docs/PRD.md](PRD.md) | Purpose, goals, success criteria, scope, requirements, constraints. Non-goals are an open gap. |
| [docs/DATA-MODEL.md](DATA-MODEL.md) | The `DjinnisDataTextsDB` shape, the defaults merge, and the schema-migration mechanism. |
| [CLAUDE.md](../CLAUDE.md) | Orient tripwire and project conventions. Auto-loaded. |
| [docs/board/README.md](board/README.md) | The board convention. Owned by the `/handover` skill; never edit the local copy. |
| [docs/build/PLAN-module-toggles.md](build/PLAN-module-toggles.md) | Full design for card 0001. Read before starting it. |
| [docs/build/task.md](build/task.md) | Historical phase tracker, phases 1 to 9. Superseded by the board; kept for history. |
| [docs/build/check-alt-prune.lua](build/check-alt-prune.lua) | One-off: runs card 0011's prune cutoff over a real SavedVariables file. Not a test suite; `docs/` never ships. |
| [docs/ARTWORK_PROMPTS.md](ARTWORK_PROMPTS.md) | Image-generation prompts for logo and banner art. |
| [README.md](../README.md) | User-facing module documentation with screenshots. |
| [CURSEFORGE.md](../CURSEFORGE.md) | Addon page copy. |
| [CHANGELOG.md](../CHANGELOG.md) / [RELEASE_NOTES.md](../RELEASE_NOTES.md) | Release history and the pending release's notes. |
| `docs/DECISIONS.md` | **Missing.** Card 0006 wrote the other two and explicitly excluded this one; no card owns it yet. |

## Branch status

On `master`, tagged `v0.9.15`, **ahead of `origin/master` by the whole unreleased 0.9.16**: the
Lair work, the SimC slash-key fix, the card 0011 alt prune, and the release notes for all
three. Nothing is pushed and no `v0.9.16` tag exists yet, by choice. No branch was cut for any
of it: these are single-module changes, which is the size this project lands directly on
`master`.
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
