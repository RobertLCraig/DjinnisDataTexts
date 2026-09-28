# PRD: Djinni's Data Texts (DDT)

> One World of Warcraft Retail addon holding a suite of LDB DataText modules with rich
> tooltips, shown by any LDB display addon.

**Stage:** shipped
_Last updated: 2026-08-29_

> **How this document was written.** DDT was built before it had a PRD. Everything below is
> reconstructed from [README.md](../README.md), [CURSEFORGE.md](../CURSEFORGE.md), the phase
> history in [docs/build/task.md](build/task.md) and the code itself, not from a spec Rob
> wrote up front. It records what the addon **is** and what it demonstrably **optimises for**.
> Where a section could not be grounded in the repository it says so loudly rather than
> guessing; see [Non-goals](#non-goals) and [Open questions](#open-questions).

## Purpose

A player who wants information on their DataText bar ends up installing one single-purpose
LDB broker per thing they want to see. Each has its own author, its own tooltip style, its
own settings home (or none), and its own idea of how often to refresh. The result is a bar
that looks like a committee built it and a settings tree with a dozen unrelated entries.

DDT replaces that pile with one addon: every DataText shares the same tooltip style, the same
configuration vocabulary (label template, tooltip size, sort order, click actions) and one
settings home under the Blizzard Settings panel. It also absorbs and replaces the author's
earlier addon, **DjinnisGuildFriends**, migrating its saved variables on first load so an
existing user loses nothing by switching.

## Goals

In priority order, as the code and release history show them operating:

1. **One addon, one look, one settings home.** Every module renders the same tooltip (dark
   backdrop, gold headers, class-coloured names, grey hint bar) and exposes the same
   configuration shape, so learning one module teaches all of them.
2. **Display-addon neutrality.** Works on ElvUI, Titan Panel, Bazooka, ChocolateBar or
   anything else that shows LDB objects. Nothing may depend on a particular display addon's
   API.
3. **Breadth of coverage.** 24+ modules spanning social, character, economy, instances, time
   and location, system, professions and audio, so the suite is a genuine replacement for the
   pile rather than a subset of it.
4. **Configurability without a config addon.** Label templates, tooltip sizing, sort orders
   and nine click-action slots per module, all through the stock Blizzard Settings API.
5. **Cost the player nothing they are not using.** Per-module enable/disable, a per-module
   poll interval, deferred broker creation, and heavy work gated behind tooltip hover.
6. **No Lua errors and no taint.** Several releases have been entirely about combat-lockdown
   guards and secret-taint fixes, so this is a live constraint, not a background aspiration.

## Success criteria

Concrete and checkable, though note the [Constraints](#constraints): almost all of these can
only be confirmed by loading the addon in a game client.

- Every module carries a configurable label template, tooltip width and scale, sort order and
  click actions, all reachable from the Blizzard Settings UI, plus a per-module
  **Reset to Defaults**.
- Tooltips are visually identical in style across every module.
- The addon loads and functions with no LDB display addon assumptions: any LDB display shows
  every enabled broker.
- Disabling a module in the Modules panel and reloading removes its DataText from the display
  addon's list entirely, and that module then registers no events and runs no timers.
- A DjinnisGuildFriends user's settings appear in DDT on first load, and a warning fires if
  both addons are loaded at once.
- Upgrading never loses a saved setting: new defaults appear automatically, and a changed
  default only rewrites a saved value that still equals the old default.
- No Lua error in normal play, including in combat and around secret-valued unit data.

## Scope

**Modules.** 25 module files loaded from `DjinnisDataTexts.toc`, plus the thirteen-file
Professions sub-framework, grouped as:

| Category | Modules |
|----------|---------|
| Social | Guild, Friends, Communities |
| Character | Character Info, Experience, Item Level, Spec Switch, Movement Speed, Account Status |
| Inventory and economy | Currency, Bag Value, Mail |
| Instances and progress | Saved Instances, LFG Status, Prey Tracker, Delve, Active Activity, Pet Info |
| Time and location | Time / Date, Coordinates |
| System | System Performance, Played Time, Micro Menu |
| Audio *(alpha)* | Volume Control, Audio Output |
| Professions *(alpha)* | One broker per detected profession, across 11 professions |

The per-module feature detail lives in [README.md](../README.md) and
[CURSEFORGE.md](../CURSEFORGE.md); this document does not restate it.

**Also in scope:**

- The shared framework: module registry, deferred brokers, saved-variables load and migration,
  formatting and sort helpers, the refresh scheduler, and the tooltip toolkit (`Core.lua`).
- One Blizzard Settings subcategory per module, alphabetically sorted, plus a General panel
  owning fonts, number formatting and gold display (`Settings.lua`).
- Per-module enable/disable and poll interval, in a Modules panel.
- Migration in from DjinnisGuildFriends, and from the standalone MajesticBeastTracker addon.
- Optional integration with other addons where present and graceful absence where not:
  TradeSkillMaster, SavedInstances, Auctionator, SimulationCraft, TomTom.
- The release toolchain: `release.ps1`, `deploy.ps1`, and `pkgmeta.yaml` as the single
  exclusion list.

## Non-goals

**UNKNOWN: confirm with Rob. This is the loudest gap in this document.**

No non-goals have ever been stated for DDT. The section is deliberately left unfilled rather
than invented, because a made-up non-goal is worse than an absent one: it would be quoted back
as a decision nobody made, and the whole value of the section is that it is the part of a PRD
a future session is not allowed to argue with. Card 0006 flagged this as the one thing in the
PRD that could not be lifted from existing files.

What the repository *does* evidence, which is not the same thing as a stated non-goal list:

- **"Only refresh what is displayed" is not implementable and will not be attempted.** LDB
  exposes no visibility signal; that state lives inside the display addon with no universal
  API. The per-module poll interval is the deliberate approximation.
  (Recorded under Decisions locked in [HANDOVER.md](HANDOVER.md).)
- **Live module toggling is not offered.** Toggles apply on `/reload`, because LDB has no
  unregister and a broker cannot be withdrawn once created.
- **No settings profiles.** The saved database is flat and account-wide, with no per-character
  or per-spec profile layer. See [DATA-MODEL.md](DATA-MODEL.md).
- **A standalone durability DataText was deprioritised** as already covered by EnhanceQoL
  ([docs/build/task.md](build/task.md), "Deprioritised").
- **Nothing ships that the addon does not need to run in the game.** Docs, demo mode and
  retired modules are excluded from every build.

Two open scope questions are cards, not non-goals: an Achievements module (card 0003) and a
Quest Log module (card 0004), both waiting behind the CurseForge reply on card 0002.

## Requirements

**Functional**

- Each module registers itself with `ns:RegisterModule(key, mod, defaults)` and supplies its
  own defaults; registration is dynamic and tolerates a module being commented out of the
  `.toc`.
- Each module's LDB broker is named `DDT-<Name>` and is queued at file-load time via
  `ns:NewBroker`, then created at `ADDON_LOADED` only if the module is enabled.
- Label text is a user template using `<tag>` syntax, with module-specific tags, clickable
  tag-insert buttons and preset suggestions in the settings panel.
- Nine modifier click-action slots per module: Left, Right, Middle, and Shift / Ctrl / Alt
  variants of left and right.
- Number formatting is global: eight locale presets or a custom separator, decimal and
  abbreviation setting, applied across every module.
- Fonts are global: one face and size, applied through three shared font objects
  (`DDTFontHeader`, `DDTFontNormal`, `DDTFontSmall`).
- Settings persist to one saved variable, `DjinnisDataTextsDB`, whose shape is owned by
  [DATA-MODEL.md](DATA-MODEL.md).
- `/ddt` (and `/djdata`) opens the settings panel.

**Non-functional**

- No module may block the main thread long enough to trip WoW's "script ran too long"
  watchdog. The scheduler therefore refreshes at most one due module per tick, and the
  initial refresh walks one module per frame.
- Heavy work (deep scans, tooltip contents) is gated behind tooltip hover and never runs on
  the timer.
- A disabled module costs nothing beyond the memory its already-parsed file occupies.
- Upgrades are additive by default: new settings appear via a defaults merge, and only a
  *changed* default needs a schema migration step.
- No taint of secure frames, and no comparison, concatenation or table-keying of secret values.

## Constraints

- **Target:** WoW Retail, Interface `120100` (Midnight 12.1.0), single interface version.
- **No build step, no package manager, no test suite, no linter.** Pure Lua under the game's
  5.1-based interpreter. Load order is `.toc` order.
- **Verification is loading the addon in a game client**, which no agent can do. What can be
  checked statically is only that files parse, `.toc` entries resolve and no deprecated global
  is called. Three shipped defects have already been found by reading rather than by running,
  each of which produced no error and wrong data on screen. A change that has only been
  reasoned about must be reported as exactly that.
- **LDB has no unregister.** A broker cannot be withdrawn once created, which is the root
  constraint behind deferred broker creation and reload-gated toggles.
- **Module files run before saved variables exist**, so nothing can know at file-load time
  whether it is disabled.
- **12.1 traps, all three written up in the workspace `docs/DECISIONS.md`:** secret values may
  not be compared, concatenated or used as a table key (and `type()` cannot see one); where an
  API is secret-restricted, ask the matching `C_Secrets.Should*BeSecret` predicate first and
  test the result with `issecretvalue`; and `RegisterEvent` can be refused silently in a way
  `pcall` does not detect.
- **Broker names are a public interface.** The display addon persists `DDT-<Name>` in *its*
  config, so renaming a broker breaks users' bars.
- **Module saved keys are a public interface** for the same reason: renaming one orphans every
  existing user's settings for that module.
- **API facts are checked against the local `wow-ui-source` checkout**, never from memory; the
  generated documentation is incomplete.
- Distribution is GitHub plus CurseForge, driven by `RELEASE_NOTES.md` through `release.ps1`.
- Licence: all rights reserved, provided as-is for personal use.

## Open questions

- [ ] **Non-goals.** The section above is an explicit gap. Needs Rob to say what DDT
      deliberately will not do. This is card 0006's one unanswerable item.
- [ ] **The alpha modules.** Volume Control, Audio Output and the whole Professions framework
      are labelled *(alpha)* in both user-facing docs. Nothing records what would take them
      out of alpha, or whether they are meant to.
- [ ] **Scope of two proposed modules**, Achievements (card 0003) and Quest Log (card 0004),
      both gated behind the CurseForge reply on card 0002.
- [ ] **What "1.0" means.** The addon has shipped at 0.9.x for its whole life and no
      criterion for leaving 0.9 is recorded anywhere.

## Sibling docs

| Doc | Purpose |
|-----|---------|
| [HANDOVER.md](HANDOVER.md) | Current state, what is next, how to pick up. The index for this set. |
| [DATA-MODEL.md](DATA-MODEL.md) | The `DjinnisDataTextsDB` shape and its migration mechanism. |
| [README.md](../README.md) | User-facing module documentation with screenshots. |
| [CURSEFORGE.md](../CURSEFORGE.md) | Addon page copy. |
| [docs/build/task.md](build/task.md) | Historical phase tracker, phases 1 to 9. Superseded by the board. |
| `docs/DECISIONS.md` | **Missing.** No card owns it yet; card 0006 explicitly excluded it. |
