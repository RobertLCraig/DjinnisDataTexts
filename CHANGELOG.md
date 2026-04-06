# Changelog

All notable changes to Djinni's Data Texts will be documented in this file.

---

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
