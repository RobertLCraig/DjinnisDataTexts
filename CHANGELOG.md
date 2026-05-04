# Changelog

All notable changes to Djinni's Data Texts will be documented in this file.

---

## [0.9.11] - 2026-05-04

### Fixed

- **`ADDON_ACTION_BLOCKED` on profession tooltip auto-hide in combat.** The Professions tooltip parents `SecureActionButtonTemplate` lure buttons; when the auto-hide timer fired during combat, `tooltipFrames[profKey]:Hide()` cascaded to the secure children and tripped `Frame:Hide()` is protected. The hide timer now checks `InCombatLockdown()` and reschedules itself until combat ends. Same combat guard applied preventatively to the matching `Show()` paths in `ShowTooltip` and `TogglePin`, and to the equivalent code in the Majestic Beast Tracker module (which parents the same secure lure / consumable buttons).
- **Guild tooltip crash on secret-tainted MOTD.** Caching `clubInfo.broadcast` into `self.motdCache` does not launder the Midnight-era taint that rides the value, so subsequent operations on the cached MOTD errored with `attempt to compare a secret string value` (the `motd ~= ""` test) and `attempt to perform arithmetic on a secret number value` (`GetStringHeight() + 4` on a fontstring whose text was set from the tainted string). There is no `C_Secrets.Should*` predicate covering guild MOTD specifically, so the entire MOTD render block (compare, SetText, GetStringHeight) is now wrapped in a single `pcall`; on failure, the MOTD line clears and hides cleanly. Matches the existing `Modules/Delve.lua` Sanctified-string pattern.


## [0.9.10] - 2026-04-28

### Fixed

- **`ADDON_ACTION_BLOCKED` on profession tooltip auto-hide in combat.** The Professions tooltip parents `SecureActionButtonTemplate` lure buttons; when the auto-hide timer fired during combat, `tooltipFrames[profKey]:Hide()` cascaded to the secure children and tripped `Frame:Hide()` is protected. The hide timer now checks `InCombatLockdown()` and reschedules itself until combat ends. Same combat guard applied preventatively to the matching `Show()` paths in `ShowTooltip` and `TogglePin`, and to the equivalent code in the Majestic Beast Tracker module (which parents the same secure lure / consumable buttons).
- **Guild tooltip crash on secret-tainted MOTD.** Caching `clubInfo.broadcast` into `self.motdCache` does not launder the Midnight-era taint that rides the value, so subsequent operations on the cached MOTD errored with `attempt to compare a secret string value` (the `motd ~= ""` test) and `attempt to perform arithmetic on a secret number value` (`GetStringHeight() + 4` on a fontstring whose text was set from the tainted string). There is no `C_Secrets.Should*` predicate covering guild MOTD specifically, so the entire MOTD render block (compare, SetText, GetStringHeight) is now wrapped in a single `pcall`; on failure, the MOTD line clears and hides cleanly. Matches the existing `Modules/Delve.lua` Sanctified-string pattern.


## [0.9.9] - 2026-04-26

### Fixed

- **"Secret number" compare crash on world-map Area POI hover.** Hovering an Area POI (such as a Delve entrance) on the main world map could throw `attempt to compare a secret number value (execution tainted by 'DjinnisDataTexts')` from `Blizzard_SharedXML/LayoutFrame.lua:491` inside `ResizeLayoutMixin:Layout`, called during `GameTooltip_ClearWidgetSet`. Root cause: DDT routed every hover tooltip (Friends / Guild / Communities row notes, ItemLevel item links, SavedInstances character info, and the Sanctified Banner map pin) through the global `GameTooltip`, which left the tooltip owned by addon-created frames. The next Blizzard `SetOwner` then fired `GameTooltip_OnHide` -> `ClearWidgetSet` -> widget-container layout in tainted execution, where `GetNumPoints` returned a secret value and the `== 0` test errored. All DDT hover sites now route through a private `DDTHoverTooltip` frame (`GameTooltipTemplate`) via the new `ns.GetHoverTooltip()` helper, so the global tooltip is never touched from insecure code.

### Added

- **Delve Sanctified Banner: The Gulf of Memory (Upper Rootway variant)** at `/way 41.32 23.74`. Listed alongside the existing Lower Rootway spawn for the delve so the in-game map pin shows whichever variant is active.


## [0.9.8] - 2026-04-25

### Fixed

- **"Script ran too long" watchdog on periodic refresh.** `RefreshAllModules()` previously called every module's `UpdateData` in a single execution block, which could trip WoW's long-running-script guard when heavy scanners (Experience walking the quest log, SavedInstances iterating characters, BagValue stepping every bag slot) all fired in the same frame. Refresh now queues the modules and processes one per frame via `C_Timer.After(0, ...)`.
- **Movement Speed crashing on secret-tainted `GetUnitSpeed` returns.** Under Midnight 12.0.5, `GetUnitSpeed("player")` can return secret number values when `C_Secrets.ShouldUnitStatsBeSecret()` is true; arithmetic on those values errored out under tainted execution and spammed `OnUpdate` with hundreds of identical errors. Speed reads are now gated by the predicate and wrapped in `pcall` as a backstop, with previously cached values preserved when a read is refused.
- **Delve Sanctified scan crashing on secret-tainted strings.** `ScanStringsForSanctified` called `:lower():find("sanctified")` directly on every string in scanned tables; if any string came from a secret-tainted source the operation would error out and abort the scan. The string check is now wrapped in `pcall` so tainted entries are skipped without breaking detection.

---

## [0.9.7] - 2026-04-23

### Changed

- **TOC Interface bumped to `120005`** for the Midnight 12.0.5 "Lingering Shadows" content update (live 2026-04-21). The addon already carries the Midnight-era safety work from 0.9.3 (`C_Secrets` predicate guards on identity/aura/cooldown reads, `pcall` backstops around `C_Club.GetClubMembers`, combat-lockdown audit on protected frame operations), so no further API migration is required for 12.0.5.

---

## [0.9.6] - 2026-04-14

### Fixed

- **Delve Sanctified Banner detection (Tier 11+)** - banner click was stuck showing "Available" even after clicking. Previous chat-event matching (0.9.4) did not work because the "Sanctified Spoils Will Manifest Upon Delve Completion" notification does not ride any `CHAT_MSG_*` or `UI_INFO_MESSAGE` channel. Detection now post-hooks `EventToastManagerFrame:DisplayToast` and reads the resolved toast from `frame.currentDisplayingToast.toastInfo.title` (matching on "Sanctified Spoils"). The legacy `BANNER_BUFF_SPELL_IDS` aura scan is retained as a fallback for older delve variants.

### Added

- **`/ddtdelve listen`** - wide-net event + EventToast diagnostic listener for future detection regressions. Logs scenario/widget/delve events and every EventToast with `displayType`, `title`, and `subtitle` so the source channel of any new notification can be identified in a single run.
- **`/ddtdelve watch`** - live player-aura diff monitor (gained/lost auras) for identifying transient buff IDs.

---

## [0.9.5] - 2026-04-11

### Fixed

- **Scrollable tooltips** (Guild, Communities, and all modules using the shared tooltip factory) - scroll position no longer resets to the top when the underlying data refreshes while the tooltip is open. `FinalizeLayout` now preserves the current scroll offset (clamped to the new content bounds) on re-populate, and only resets on a fresh show.

---

## [0.9.3] - 2026-04-11

### Major Update: ActiveActivity Aggregator, Combat and Secret Safety Pass, Delve Tier 11+ Support

This release consolidates three beta iterations (0.9.0-beta, 0.9.1-beta, 0.9.2-beta) into a single stable release.

#### ActiveActivity (New)

Unified LDB broker that routes hover, click, and label updates to whichever sub-tracker is currently engaged. Sub-trackers register via `RegisterActivityTracker` API rather than owning their own brokers.

- **Delve** and **Prey Tracker** now register as sub-trackers and notify on label change
- Idle-state click actions configurable independently of active-tracker click actions
- Single data broker replaces multiple empty brokers when no activity is active

#### Secret API Safety (Midnight hardening)

Every module that reads identity, aura, or cooldown data is now guarded against Midnight-era secret return values.

- **Guild / Communities** — `C_Club.GetClubMembers` secret-table crashes fixed. `C_Secrets.ShouldUnitIdentityBeSecret("player")` predicate fast-path plus `pcall` backstop around the member iteration (the predicate does not always pair perfectly with this API's secrecy state on tooltip-hover paths). Fallback to `GetGuildInfo("player")` for guild name.
- **Movement Speed / Delve / Professions** — Aura reads guarded with `C_Secrets.ShouldAurasBeSecret()`.
- **Pet Info / Professions** — Cooldown reads guarded with `C_Secrets.ShouldCooldownsBeSecret()`.
- **Core.ExpandTag** — `pcall` around `tostring`/`gsub` so secret label values degrade gracefully to `?` instead of erroring the entire label.

#### Combat Safety

Audit pass on protected frame operations. Protected calls (`SetAttribute`, `RegisterForClicks`) now gated behind `InCombatLockdown()` checks with `PLAYER_REGEN_ENABLED` deferral.

#### Delve

- **Tier 11+ Sanctified Banner detection** — Newer delve variants (Atal'Aman and later) grant no player aura on banner click, so detection now matches the on-screen "Sanctified Spoils Will Manifest Upon Delve Completion" notification across `UI_INFO_MESSAGE`, `CHAT_MSG_RAID_BOSS_EMOTE`, `CHAT_MSG_MONSTER_EMOTE`, `CHAT_MSG_MONSTER_YELL`, and `CHAT_MSG_SYSTEM`.
- **`/ddtdelve watch`** — New diagnostic command. Live aura-diff monitor that prints gained/lost player auras on every `UNIT_AURA` fire. Used for identifying aura signals on future delve variants.

#### Other Fixes

- **VolumeControl** — `OnMouseWheel` now hooked on the display frame in `OnEnter` (display addons like ElvUI do not wire up `dataobj.OnMouseWheel`).
- **SavedInstances / AudioOutput** — Non-ASCII glyphs replaced with ASCII equivalents so WoW's default font renders them.
- **Professions** — Catch-up currency row rendered in KP section; Wild Perception buff tracker gains `name` field.
- **ActiveActivity** — Registration key normalized from `activeactivity` to `ActiveActivity` to match the canonical module name.


## [0.9.2-beta] - 2026-04-11

### Fixed

- **ActiveActivity** — Registration key normalized from `activeactivity` to `ActiveActivity` to match the canonical module name used elsewhere in the codebase.

---

## [0.9.1-beta] - 2026-04-11

### Fixed

- **Guild / Communities** — `C_Club.GetClubMembers` can return a secret value on tooltip-hover paths even when `C_Secrets.ShouldUnitIdentityBeSecret("player")` is false. Added a `pcall` backstop around the member iteration in both modules. Previous cached state is preserved when a secret is encountered; the next refresh out of lockdown repopulates. Safe to use `pcall` here because these are pure tooltip-render paths with no downstream secure frame ops.

### Added

- **Delve** — Sanctified Banner detection now works on Tier 11+ delves (Atal'Aman and later). Newer delve variants grant no player aura on banner click, so detection now matches on the on-screen notification ("Sanctified Spoils Will Manifest Upon Delve Completion") across `UI_INFO_MESSAGE`, `CHAT_MSG_RAID_BOSS_EMOTE`, `CHAT_MSG_MONSTER_EMOTE`, `CHAT_MSG_MONSTER_YELL`, and `CHAT_MSG_SYSTEM`.
- **Delve** — New `/ddtdelve watch` command — live aura-diff monitor that prints gained/lost player auras on every `UNIT_AURA` fire. Used to identify aura signals on future delve variants.

---

## [0.9.0-beta] - 2026-04-11

### Major Update: ActiveActivity Aggregator, Combat and Secret Safety Pass

#### ActiveActivity (New)

Unified LDB broker that routes hover, click, and label updates to whichever sub-tracker is currently engaged. Sub-trackers register via `RegisterActivityTracker` API rather than owning their own brokers.

- **Delve** and **Prey Tracker** now register as sub-trackers and notify on label change
- Idle-state click actions configurable independently of active-tracker click actions
- Single data broker replaces multiple empty brokers when no activity is active

#### Secret API Safety (Midnight hardening)

Every module that reads identity, aura, or cooldown data is now guarded against Midnight-era secret return values.

- **Guild / Communities** — `C_Club.GetClubMembers` secret-table crashes fixed. Added `C_Secrets.ShouldUnitIdentityBeSecret("player")` predicate fast-path and fallback to `GetGuildInfo("player")` for guild name.
- **Movement Speed / Delve / Professions** — Aura reads guarded with `C_Secrets.ShouldAurasBeSecret()`.
- **Pet Info / Professions** — Cooldown reads guarded with `C_Secrets.ShouldCooldownsBeSecret()`.
- **Core.ExpandTag** — `pcall` around `tostring`/`gsub` so secret label values degrade gracefully to `?` instead of erroring out the entire label.

#### Combat Safety

Audit pass on protected frame operations. Protected calls (`SetAttribute`, `RegisterForClicks`) now gated behind `InCombatLockdown()` checks with `PLAYER_REGEN_ENABLED` deferral where appropriate.

#### Other Fixes

- **VolumeControl** — `OnMouseWheel` now hooked on the display frame in `OnEnter` rather than the LDB data object (display addons like ElvUI do not wire up `dataobj.OnMouseWheel`).
- **SavedInstances / AudioOutput** — Non-ASCII glyphs (arrows, ellipsis) replaced with ASCII equivalents so WoW's default font renders them.
- **Professions/Core** — Catch-up currency row now rendered inside the KP section.
- **Professions/Data_Mining** — Wild Perception buff tracker now has `name` field.

---

## [0.8.1] - 2026-04-06

### Major Update: Professions Framework, Volume Control, Audio Output

#### Professions Framework (New, Alpha)

Per-profession LDB brokers for all 11 Midnight professions with integrated knowledge point tracking, skill/concentration display, and profession-specific features.

- **Knowledge Point Tracking** — Counts earned vs. total KP from unique treasures, books, and weekly sources (Alchemy, Blacksmithing, Enchanting, Engineering, Herbalism, Inscription, Jewelcrafting, Leatherworking, Mining, Skinning, Tailoring)
- **Darkmoon Faire awareness** — Weeklies automatically exclude DMF sources during non-DMF weeks
- **Hide Known KP** — Enabled by default; hides completed treasures/books from tooltip while preserving sub-header completion counts
- **Majestic Beasts** (Skinning only) — Daily lure-based beast tracking with 5 beasts (Eversong, Zul'Aman, Harandar, Voidstorm, Grand Beast):
  - Shows lure count in bags, missing reagents (with item names), and kill status per beast
  - Talent point gating respected (beasts locked until required points earned)
  - Click rows to set waypoints
  - Visual distinction: killed beasts shown in grey, available in lure colors
- **Buffs** — Active gathering/crafting buff detection and profession-specific consumable tracking (Skinning: Sanguithorn Tea, Haranir Phial of Perception, Root Crab)
- **Timers** — Daily and weekly reset countdowns
- **MajesticBeastTracker migration** — Automatically imports lure kill history, talent points, and settings from standalone MBT addon
- **Label templates** — `<name>`, `<skill>`, `<maxskill>`, `<kp_earned>`, `<kp_total>`, `<concentration>` + Skinning-specific `<mb_kills>`, `<mb_total>`, `<mb_next>`
- **Per-profession settings** — Individual label templates, tooltip overrides, show/hide toggles, click actions (one settings section per profession, collapsed by default)

#### Volume Control (New, Alpha)

Interactive per-stream volume control with sliders and mute toggles.

- **Five streams** — Master, Music, Effects, Ambience, Dialog
- **Interactive tooltip** — Drag sliders in real-time or use checkboxes to mute individual streams
- **Mouse wheel support** — Scroll on tooltip or individual sliders to adjust volume; Shift+scroll for 1% fine control
- **LDB scroll** — Scrolling on the datatext itself adjusts master volume (respects invert setting)
- **Configurable increment** — Default 5%, adjustable 1–20% in settings
- **Invert scroll** — Toggle to reverse scroll direction (scroll up = volume down)
- **Label tags** — `<master>`, `<music>`, `<sfx>`, `<ambience>`, `<dialog>`, `<muted>`

#### Audio Output (New, Alpha)

Switch between system audio output devices from a tooltip list.

- **Device list** — Shows all available output devices with click-to-switch and scroll-to-cycle
- **Current device highlighted** — Blue background and blue text for active device
- **Label tags** — `<device>` (current device name), `<index>` (1-based device number), `<count>` (total device count)
- **Truncation** — Device names truncated to configurable length (default 24 chars) to fit DataText bar
- **Sound system restart** — Automatically handles restart delay (0.5s) and double-syncs label after completion

#### Settings Panel Fixes (Professions)

- Fixed overlapping sections issue by building all 11 profession sections upfront from `ns.PROF_DEFS` instead of dynamically rebuilding from `profState` (now deferred, settings weren't created)
- Removed `AddLabelEditBox` from per-profession sections (requires top-level panel access) — switched to `AddEditBox` + `AddDescription` showing available tags
- Each profession settings section is independent: label template, tooltip scale/width overrides, show/hide toggles, click actions

---


### Major Update: Social Module Refactor, Smart Tooltip Anchoring, Prey Tracker, Majestic Beast Enhancements

#### Social Module Consistency Refactor

- **Friends, Guild, Communities** now follow the standard module registration pattern — each has its own DEFAULTS, settingsLabel, BuildSettingsPanel, and RegisterModule call
- Settings panels moved from centralized Settings.lua into each module file
- Removed ~310 lines of hardcoded social panel code from Settings.lua

#### Smart Tooltip Anchoring

- **Auto grow direction** — tooltips now detect whether the DataText is at the top or bottom of the screen and grow in the appropriate direction (down or up) to avoid overlapping the label
- **Per-module grow direction** — each module has a new "Tooltip Grow Direction" dropdown (Auto/Up/Down) in its tooltip settings section
- **Copy From** — tooltip grow direction is included in the "Copy Tooltip Settings From" feature

#### Prey Tracker (New Module)

- **Zone mapping** — 30 prey targets mapped to their zones (Eversong Woods, Zul'Aman, Harandar, Voidstorm) sourced from Wowhead NPC spawn data
- **Active hunt tracking** — shows prey name, zone, difficulty, and progress state (Cold/Warm/Hot/Final) via UI widget scanning
- **Weekly completions** — tracks completed prey quests with zone and difficulty columns
- **Currency tracking** — displays Remnant of Anguish quantity
- **Waypoint click action** — set a waypoint to the active prey target
- **Configurable zone overrides** — per-prey zone dropdowns in settings panel; prey names are clickable Wowhead links
- **Label tags** — `<status>`, `<zone>`, `<progress>`, `<difficulty>`, `<prey>`, `<weekly>`, `<currency>`

#### Majestic Beast Tracker Enhancements

- **Beast Routes section** — per-zone clickable rows with lure icon, zone name, reagent counts, and kill status; replaces the old Daily Kills grid
- **Multi-character columns** — when multiple characters have skinning, beast route rows show checkmark/X icons per character aligned under class-colored name headers
- **Secure lure buttons** — left-click uses the lure item via SecureActionButtonTemplate (matching MBT's implementation); right-click sets waypoint
- **Row click actions** — configurable per beast row: Set Waypoint, Use Lure, Open Lure Recipe, Shop Zone Reagents, Open Map
- **Consumable Buffs section** — shows Sanguithorn Tea, Haranir Phial of Perception, and Root Crab with stock count and active buff status; left-click uses the consumable, right-click creates AH search
- **Buff Shopping List** — new click action creates an Auctionator shopping list for all three consumables
- **Per-zone reagent shopping** — right-click a beast row to create an Auctionator shopping list for just that zone's lure ingredients

#### Saved Instances

- **New label preset** — "Full": `R: <raids>  M+: <mplus>  Dv: <delves>`


## [0.8.0] - 2026-04-06

### Professions Framework, Volume Control, Audio Output

This release introduces a comprehensive per-profession framework with knowledge point tracking and profession-specific features, plus two new utility modules for system audio control.

#### Professions Framework (New)

- **Per-profession LDB brokers** — One broker per detected profession (all 11 Midnight professions supported: Alchemy, Blacksmithing, Enchanting, Engineering, Herbalism, Inscription, Jewelcrafting, Leatherworking, Mining, Skinning, Tailoring)
- **Knowledge Point tracking** — Unique treasures, books, and weekly sources with earned vs. total counts
- **Darkmoon Faire awareness** — Weekly sources skip DMF quest during non-DMF weeks
- **Hide Known KP** — Toggle to hide completed treasures/books (enabled by default)
- **Majestic Beasts** (Skinning) — 5 daily lures with lure count in bags, missing reagents (with item names), and kill status; talent point gating; click to waypoint
- **Buffs** — Active buff detection and profession-specific consumable tracking
- **Timers** — Daily and weekly reset countdowns
- **MajesticBeastTracker migration** — Auto-import lure kills, talent points, settings from standalone MBT
- **Settings** — Per-profession sections with label templates, tooltip overrides, show/hide toggles, click actions

#### Volume Control (New)

- **Per-stream sliders** — Master, Music, Effects, Ambience, Dialog with real-time drag or checkbox mute
- **Interactive tooltip** — Slider drag, checkbox clicks, and mouse wheel (Shift = 1% fine control)
- **LDB scroll** — Scroll on datatext to adjust master volume
- **Configurable increment** — 1–20%, default 5%
- **Invert scroll** — Toggle to reverse scroll direction

#### Audio Output (New)

- **Device list tooltip** — Click to switch; scroll to cycle through output devices
- **Current device highlighted** — Blue background and text
- **Auto-restart** — Handles sound system restart delay with label double-sync

#### Settings Panel Fixes

- **Professions settings** — Build all sections upfront from `ns.PROF_DEFS` instead of deferred rebuild (avoids orphaned/hidden frames and overlapping layout)
- **Per-profession label editor** — Use `AddEditBox` + description (avoid `AddLabelEditBox` which requires top-level panel)

---

## [0.7.0] - 2026-04-02

### Social Module Refactor, Smart Tooltip Anchoring, Prey Tracker, Majestic Beast Enhancements

#### Social Module Consistency Refactor

- **Friends, Guild, Communities** — Now follow standard module registration with per-module DEFAULTS, settingsLabel, BuildSettingsPanel
- **Settings panels** — Moved from centralized Settings.lua into each module (~310 lines removed from Settings.lua)

#### Smart Tooltip Anchoring

- **Auto grow direction** — Detect top/bottom screen position and grow tooltip away from label
- **Per-module grow direction** — Dropdown (Auto/Up/Down) in tooltip settings
- **Copy From** — Grow direction included in copy tooltip settings

#### Prey Tracker (New Module)

- **Active hunt tracking** — Prey name, zone, difficulty, progress (Cold/Warm/Hot/Final)
- **Weekly completions** — Track completed prey with zone/difficulty columns
- **Zone mapping** — 30 targets mapped to zones (Eversong, Zul'Aman, Harandar, Voidstorm)
- **Currency tracking** — Remnant of Anguish display
- **Waypoint action** — Click to set waypoint to active prey
- **Label tags** — `<status>`, `<zone>`, `<progress>`, `<difficulty>`, `<prey>`, `<weekly>`, `<currency>`

#### Majestic Beast Tracker Enhancements

- **Beast Routes** — Per-zone rows with lure icon, zone name, reagent counts, kill status
- **Multi-character view** — Checkmark/X icons per character when multiple have skinning
- **Secure lure buttons** — Left-click uses lure (SecureActionButtonTemplate), right-click waypoint
- **Row click actions** — Waypoint, Use Lure, Open Lure Recipe, Shop Zone Reagents, Open Map
- **Consumable Buffs** — Sanguithorn Tea, Haranir Phial of Perception, Root Crab with stock and buff status
- **Shopping Lists** — Buff list and per-zone reagent shopping via Auctionator

#### Saved Instances

- **New label preset** — "Full": `R: <raids>  M+: <mplus>  Dv: <delves>`

---

## [0.6.2] - 2026-04-02

### Bugfix Release: Settings Panel, Professions Settings, MajesticBeast Tooltip

#### Professions Module Fixes

- **Settings panel rebuild** — Removed deferred rebuild approach; all 11 profession sections now built upfront from `ns.PROF_DEFS`
- **Label template** — Switched from `AddLabelEditBox` to `AddEditBox` + description (avoids panel access requirements)
- **Settings overlap fixed** — Static section building prevents orphaned/hidden frame accumulation

#### Volume Control & Audio Output Fixes

- **AudioOutput device name** — Removed count guard; always call `GetDeviceName()` directly, use `PLAYER_ENTERING_WORLD` for reliable sound system startup
- **VolumeControl LDB scroll** — Added `OnMouseWheel` to dataobj; scrolling on datatext adjusts master volume
- **Invert scroll** — New setting to reverse scroll direction; applied across LDB button, tooltip frame, and all sliders via shared `ScrollDelta()` helper

---

## [0.6.0] - 2026-04-01

### Release v0.6.0

Initial unified release combining core DDT framework with 20+ modules covering social, character, economy, instances, time/location, and system categories.

---

## [0.5.1] - 2026-04-01

### ItemLevel: Durability Tracking + Auctionator Category Search + Bug Fixes

This release significantly expands the Item Level module with real-time durability tracking, fixes several tooltip display issues, and upgrades the Auctionator enchant search to use proper category filters.

#### Durability Tracking

- **Per-slot durability column** — Dedicated right-hand column in the tooltip showing each slot's durability percentage, color-coded: green (100%), yellow (<100%), orange (≤50%), red (≤25%)
- **Overall durability summary** — Header line showing weighted average durability across all gear with the same color coding
- **Needs Repair summary** — Lists all slots below 100% durability at the bottom of the tooltip
- **Label template tags** — `<durability>` (lowest slot %) and `<repair>` (count of slots needing repair)
- **Settings** — Toggle durability display on/off; threshold slider controls the % below which per-slot values appear
- **Live updates** — Registers `UPDATE_INVENTORY_DURABILITY` event for immediate refresh

#### Auctionator Enchant Search

- Right-clicking a slot row (default) now opens an Auctionator shopping list using the advanced category filter format:
  `;Item Enhancements/<Slot>;...;CurrentExpansion;` — no search term, just the category + current expansion filter
- Slots map correctly: Finger → Finger subcategory, Feet → Feet, Weapon → Weapon, etc.
- Gem search similarly scoped to the Gems category + current expansion
- Bulk shopping list (Ctrl+L) uses the same format for all missing enchants

#### Bug Fixes

- **Settings crash** — Fixed `AddSlider` being called with a table argument instead of positional args, which blocked the entire settings panel from loading (breaking `/ddt` and Options → Addons)
- **CopyToClipboard** — Removed call to the hardware-protected `CopyToClipboard()` global; now always shows a scrollable popup editbox (Ctrl+A, Ctrl+C, Escape)
- **SlashCmdList nil** — Added nil guard before calling `SlashCmdList["SIMULATIONCRAFT"]`
- **LDB dataobj nil** — Added `LDB:GetDataObjectByName()` fallback for when the LDB name is already registered on reload
- **Tooltip row overlap** — Label is now bounded by the status column so slot names never overlap "No Enchant" or socket warnings
- **Summary row overflow** — Missing Enchants / Missing Gems / Needs Repair summary rows now use the full row width (slot list in label, value/status cleared)
- **Frame type** — Tooltip rows now correctly created as `Button` frames (required for `OnClick` and `RegisterForClicks`)

#### Friends Module

- Fixed class color detection: removed access to undocumented `FriendInfo` fields (`classTag`, `classFileName`, `classFile`, `classToken`); now uses only `className` (localized lookup) and the documented fields
- Fixed BNet friends class detection similarly — removed nonexistent `classTag`/`classFile`/`classToken` from `BNetGameAccountInfo`

---

## [0.8.2] - 2026-04-07

### Major Update: Professions Framework, Volume Control, Audio Output

#### Professions Framework (New, Alpha)

Per-profession LDB brokers for all 11 Midnight professions with integrated knowledge point tracking, skill/concentration display, and profession-specific features.

- **Knowledge Point Tracking** — Counts earned vs. total KP from unique treasures, books, and weekly sources (Alchemy, Blacksmithing, Enchanting, Engineering, Herbalism, Inscription, Jewelcrafting, Leatherworking, Mining, Skinning, Tailoring)
- **Darkmoon Faire awareness** — Weeklies automatically exclude DMF sources during non-DMF weeks
- **Hide Known KP** — Enabled by default; hides completed treasures/books from tooltip while preserving sub-header completion counts
- **Majestic Beasts** (Skinning only) — Daily lure-based beast tracking with 5 beasts (Eversong, Zul'Aman, Harandar, Voidstorm, Grand Beast):
  - Shows lure count in bags, missing reagents (with item names), and kill status per beast
  - Talent point gating respected (beasts locked until required points earned)
  - Click rows to set waypoints
  - Visual distinction: killed beasts shown in grey, available in lure colors
- **Buffs** — Active gathering/crafting buff detection and profession-specific consumable tracking (Skinning: Sanguithorn Tea, Haranir Phial of Perception, Root Crab)
- **Timers** — Daily and weekly reset countdowns
- **MajesticBeastTracker migration** — Automatically imports lure kill history, talent points, and settings from standalone MBT addon
- **Label templates** — `<name>`, `<skill>`, `<maxskill>`, `<kp_earned>`, `<kp_total>`, `<concentration>` + Skinning-specific `<mb_kills>`, `<mb_total>`, `<mb_next>`
- **Per-profession settings** — Individual label templates, tooltip overrides, show/hide toggles, click actions (one settings section per profession, collapsed by default)

#### Volume Control (New, Alpha)

Interactive per-stream volume control with sliders and mute toggles.

- **Five streams** — Master, Music, Effects, Ambience, Dialog
- **Interactive tooltip** — Drag sliders in real-time or use checkboxes to mute individual streams
- **Mouse wheel support** — Scroll on tooltip or individual sliders to adjust volume; Shift+scroll for 1% fine control
- **LDB scroll** — Scrolling on the datatext itself adjusts master volume (respects invert setting)
- **Configurable increment** — Default 5%, adjustable 1–20% in settings
- **Invert scroll** — Toggle to reverse scroll direction (scroll up = volume down)
- **Label tags** — `<master>`, `<music>`, `<sfx>`, `<ambience>`, `<dialog>`, `<muted>`

#### Audio Output (New, Alpha)

Switch between system audio output devices from a tooltip list.

- **Device list** — Shows all available output devices with click-to-switch and scroll-to-cycle
- **Current device highlighted** — Blue background and blue text for active device
- **Label tags** — `<device>` (current device name), `<index>` (1-based device number), `<count>` (total device count)
- **Truncation** — Device names truncated to configurable length (default 24 chars) to fit DataText bar
- **Sound system restart** — Automatically handles restart delay (0.5s) and double-syncs label after completion

#### Settings Panel Fixes (Professions)

- Fixed overlapping sections issue by building all 11 profession sections upfront from `ns.PROF_DEFS` instead of dynamically rebuilding from `profState` (now deferred, settings weren't created)
- Removed `AddLabelEditBox` from per-profession sections (requires top-level panel access) — switched to `AddEditBox` + `AddDescription` showing available tags
- Each profession settings section is independent: label template, tooltip scale/width overrides, show/hide toggles, click actions

---


### Major Update: Social Module Refactor, Smart Tooltip Anchoring, Prey Tracker, Majestic Beast Enhancements

#### Social Module Consistency Refactor

- **Friends, Guild, Communities** now follow the standard module registration pattern — each has its own DEFAULTS, settingsLabel, BuildSettingsPanel, and RegisterModule call
- Settings panels moved from centralized Settings.lua into each module file
- Removed ~310 lines of hardcoded social panel code from Settings.lua

#### Smart Tooltip Anchoring

- **Auto grow direction** — tooltips now detect whether the DataText is at the top or bottom of the screen and grow in the appropriate direction (down or up) to avoid overlapping the label
- **Per-module grow direction** — each module has a new "Tooltip Grow Direction" dropdown (Auto/Up/Down) in its tooltip settings section
- **Copy From** — tooltip grow direction is included in the "Copy Tooltip Settings From" feature

#### Prey Tracker (New Module)

- **Zone mapping** — 30 prey targets mapped to their zones (Eversong Woods, Zul'Aman, Harandar, Voidstorm) sourced from Wowhead NPC spawn data
- **Active hunt tracking** — shows prey name, zone, difficulty, and progress state (Cold/Warm/Hot/Final) via UI widget scanning
- **Weekly completions** — tracks completed prey quests with zone and difficulty columns
- **Currency tracking** — displays Remnant of Anguish quantity
- **Waypoint click action** — set a waypoint to the active prey target
- **Configurable zone overrides** — per-prey zone dropdowns in settings panel; prey names are clickable Wowhead links
- **Label tags** — `<status>`, `<zone>`, `<progress>`, `<difficulty>`, `<prey>`, `<weekly>`, `<currency>`

#### Majestic Beast Tracker Enhancements

- **Beast Routes section** — per-zone clickable rows with lure icon, zone name, reagent counts, and kill status; replaces the old Daily Kills grid
- **Multi-character columns** — when multiple characters have skinning, beast route rows show checkmark/X icons per character aligned under class-colored name headers
- **Secure lure buttons** — left-click uses the lure item via SecureActionButtonTemplate (matching MBT's implementation); right-click sets waypoint
- **Row click actions** — configurable per beast row: Set Waypoint, Use Lure, Open Lure Recipe, Shop Zone Reagents, Open Map
- **Consumable Buffs section** — shows Sanguithorn Tea, Haranir Phial of Perception, and Root Crab with stock count and active buff status; left-click uses the consumable, right-click creates AH search
- **Buff Shopping List** — new click action creates an Auctionator shopping list for all three consumables
- **Per-zone reagent shopping** — right-click a beast row to create an Auctionator shopping list for just that zone's lure ingredients

#### Saved Instances

- **New label preset** — "Full": `R: <raids>  M+: <mplus>  Dv: <delves>`

---

## [0.9.4] - 2026-04-11

### Major Update: ActiveActivity Aggregator, Combat and Secret Safety Pass, Delve Tier 11+ Support

This release consolidates three beta iterations (0.9.0-beta, 0.9.1-beta, 0.9.2-beta) into a single stable release.

#### ActiveActivity (New)

Unified LDB broker that routes hover, click, and label updates to whichever sub-tracker is currently engaged. Sub-trackers register via `RegisterActivityTracker` API rather than owning their own brokers.

- **Delve** and **Prey Tracker** now register as sub-trackers and notify on label change
- Idle-state click actions configurable independently of active-tracker click actions
- Single data broker replaces multiple empty brokers when no activity is active

#### Secret API Safety (Midnight hardening)

Every module that reads identity, aura, or cooldown data is now guarded against Midnight-era secret return values.

- **Guild / Communities** — `C_Club.GetClubMembers` secret-table crashes fixed. `C_Secrets.ShouldUnitIdentityBeSecret("player")` predicate fast-path plus `pcall` backstop around the member iteration (the predicate does not always pair perfectly with this API's secrecy state on tooltip-hover paths). Fallback to `GetGuildInfo("player")` for guild name.
- **Movement Speed / Delve / Professions** — Aura reads guarded with `C_Secrets.ShouldAurasBeSecret()`.
- **Pet Info / Professions** — Cooldown reads guarded with `C_Secrets.ShouldCooldownsBeSecret()`.
- **Core.ExpandTag** — `pcall` around `tostring`/`gsub` so secret label values degrade gracefully to `?` instead of erroring the entire label.

#### Combat Safety

Audit pass on protected frame operations. Protected calls (`SetAttribute`, `RegisterForClicks`) now gated behind `InCombatLockdown()` checks with `PLAYER_REGEN_ENABLED` deferral.

#### Delve

- **Tier 11+ Sanctified Banner detection** — Newer delve variants (Atal'Aman and later) grant no player aura on banner click, so detection now matches the on-screen "Sanctified Spoils Will Manifest Upon Delve Completion" notification across `UI_INFO_MESSAGE`, `CHAT_MSG_RAID_BOSS_EMOTE`, `CHAT_MSG_MONSTER_EMOTE`, `CHAT_MSG_MONSTER_YELL`, and `CHAT_MSG_SYSTEM`.
- **`/ddtdelve watch`** — New diagnostic command. Live aura-diff monitor that prints gained/lost player auras on every `UNIT_AURA` fire. Used for identifying aura signals on future delve variants.

#### Other Fixes

- **VolumeControl** — `OnMouseWheel` now hooked on the display frame in `OnEnter` (display addons like ElvUI do not wire up `dataobj.OnMouseWheel`).
- **SavedInstances / AudioOutput** — Non-ASCII glyphs replaced with ASCII equivalents so WoW's default font renders them.
- **Professions** — Catch-up currency row rendered in KP section; Wild Perception buff tracker gains `name` field.
- **ActiveActivity** — Registration key normalized from `activeactivity` to `ActiveActivity` to match the canonical module name.
