# CLAUDE.md — Djinni's Data Texts (DDT)

## Orient before changing anything

Read these before writing or changing any code, doc or config:

1. `docs/HANDOVER.md` — current state, what is next, how to pick up. It indexes the rest.
2. `docs/board/` — the work queue. One card per file; the folder it sits in is its state.
3. The docs it indexes that bear on your task.

Restate the goal, the success criteria and the data shape back before proposing changes.
Never conclude something is absent from reading one file; check the whole set.

## What this is

A World of Warcraft Retail addon: a suite of LDB (LibDataBroker) DataText modules with
rich tooltips, shown by any LDB display addon (ElvUI, Titan Panel, Bazooka, ChocolateBar).
Pure Lua, no build step. It absorbs and replaces the older DjinnisGuildFriends addon and
migrates its SavedVariables on first load.

## Conventions

- **Modules** live in `Modules/`, one file per DataText, listed in `DjinnisDataTexts.toc`.
  Load order is the `.toc` order. Commenting a module out of the `.toc` is a supported way
  to drop it; registration is dynamic and tolerates absence.
- **Registration**: each module calls `ns:RegisterModule(key, mod, defaults)` (`Core.lua`)
  and creates its LDB broker at file-load time, named `DDT-<Name>`.
- **Settings**: `Settings.lua` builds one Blizzard Settings subcategory per module,
  sorted alphabetically. Widget helpers are on `ns.SettingsWidgets`.
- **Saved variables**: single `DjinnisDataTextsDB`, per-module tables keyed by module key.
- **Releases** are driven by `RELEASE_NOTES.md`: the `## Version: x.y.z` line is the source
  of truth. `release.ps1` syncs the `.toc`, prepends to `CHANGELOG.md`, tags and zips.
  `deploy.ps1` copies a working copy into the game's AddOns folder for testing.
- **Docs** live under `docs/`. `README.md`, `CHANGELOG.md`, `RELEASE_NOTES.md` and
  `CURSEFORGE.md` stay at the repo root because the release toolchain and the addon page
  read them there.
- British spelling in prose. No em dashes.

## Verification

There is no test suite. Changes are verified in-game: `deploy.ps1`, then `/reload` and
exercise the affected module, watching for Lua errors. Say so plainly when something has
only been reasoned about and not run.
