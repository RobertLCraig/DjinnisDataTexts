# Changelog

All notable changes to Djinni's Data Texts will be documented in this file.

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


## [0.5.0-beta] - 2026-04-01

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

## [0.4.0-beta] - 2026-04-01

### ItemLevel Module + SavedInstances Delve Tracking & UI Enhancements

#### New Module: ItemLevel
- **Equipped item level display** with configurable label template tags (`<ilvl>`, `<overall>`, `<enchants>`, `<gems>`)
- **Per-slot breakdown** in tooltip showing item ilvl, quality colors, missing enchants/gems with warnings
- **SimC string export** — copy your SimulationCraft import string to clipboard (uses SimulationCraft addon if installed, otherwise generates basic string)
- **Missing enhancement detection** — Identifies slots with missing enchants, gems, or embellishments
- **Shopping list integration**:
  - **Auctionator** — Creates "DDT - Missing Enhancements" shopping list with one-click crafting/purchase
  - **TSM** — Copies missing item search terms to clipboard for custom price searches
- **Auction House gear upgrade search** — Finds weakest item slots and searches AH if open

#### SavedInstances Module Enhancements
- **Delve self-tracking** — Tracks individual delve completions with instance names, tier, and timestamps per week
  - Uses `SCENARIO_COMPLETED` event + zone detection + vault snapshot diffing for tier determination
  - Falls back to `C_WeeklyRewards.GetSortedProgressForActivity()` for aggregate data
  - Displays tracked run names in both full and condensed tooltip views
- **Column hover highlighting** — Vertical highlight strips appear when hovering over alt column headers for better readability
- **Column text centering** — Alt column text now properly centered

#### Core Module Enhancements
- **Centralized gold display settings** — Global `goldColorize`, `goldShowSilver`, `goldShowCopper` settings in General panel
  - `ns.FormatGold()` respects global defaults when no explicit overrides provided
  - Live gold preview in settings with custom format/color control
- **DDT:CopyToClipboard utility** — Uses `C_Clipboard.SetText()` if available, falls back to scrollable EditBox popup for SimC strings
- **Currency module UI cohesion** — Merged "Label Template" and "Gold" sections into unified "Label & Gold Display" section with live preview

#### Module Bug Fixes
- **SpecSwitch label not updating** — Added immediate `UpdateData()` call in `Init()` to ensure label is set during `ADDON_LOADED`. Separated loadout scanning into protected `UpdateLoadouts()` function to prevent API errors from killing label update. Added `TRAIT_CONFIG_CREATED` event registration.

#### Dependencies Added
- **Optional**: Auctionator (ItemLevel shopping lists), SimulationCraft (ItemLevel SimC export)


## [0.3.2] - 2026-03-31

### Separated Label & Row Click Actions, API Fixes

#### Social Module Click Actions (Friends, Guild, Communities)
- **Separate label vs row clicks** - Click actions now split into two configurable sections:
  - **Label Click Actions** (clicking the DataText) - Open respective panel list, or DDT Settings (new configurable section)
  - **Row Click Actions** (clicking a player in tooltip) - Whisper, invite, copy name, etc. (new configurable section)
- **Improved defaults** - Left-click the label now opens Friends/Guild/Communities directly (was Shift+Click only)

#### Bug Fixes
- **MovementSpeed aura scanning** - Fixed Midnight API incompatibility; switched from `C_UnitAuras.GetAuraDataByIndex` (protected spellId field) to `C_UnitAuras.GetPlayerAuraBySpellID` for known speed buffs

---

## [0.3.1-beta] - 2026-03-31

### Settings UI Refactor: Collapsible Sections & Improved Layout

Significant usability overhaul of the addon settings system: collapsible sections, two-column layouts, improved visual hierarchy, and efficient use of screen space.

#### Settings UI Improvements
- **Collapsible sections** - Organized settings into logical groups (Label Template, Display, Tooltip, Click Actions, etc.). Tooltip and Click Actions sections collapse by default to reduce clutter
- **Space-efficient two-column layouts** - Paired checkboxes and sliders now display side-by-side (e.g., "Show free slots" + "Show top items" on one row)
- **Better visual hierarchy** - Section headers with expand/collapse indicators, grouped content, improved readability
- **Dynamic section sizing** - Sections automatically adjust height as they expand/collapse; panel height recalculates in real-time
- **Improved settings panel appearance** - Leverages WoW Blizzard API for consistent look, better organized module configuration

#### Bug Fixes
- Fixed `SetBackdrop` nil errors in Currency and BagValue row frames by adding BackdropTemplate to frame creation

---

## [0.3.0] - 2026-03-31

### Click Actions, Communities Enrichment, and Bug Fixes

#### Extended Click Action System
- **9 modifier combinations** - Left, Right, Middle, Shift+Left, Shift+Right, Ctrl+Left, Ctrl+Right, Alt+Left, Alt+Right (previously 5). All modules now expose all 9 slots in settings
- **Per-row click actions** - Currency and Bag Value modules support configurable click actions on individual tooltip rows (link to chat, open currency tab, etc.)
- **New click actions across all modules**: Account Status (Warband Bank, Pet Journal), Character Info (Achievements, Spellbook, Collections), Bag Value (Sort Bags; row click), Coordinates (Share Coords, Map Pin), Currency (Copy Gold; row click), Experience (Achievements), LFG Status (Premade Groups), Mail (Copy Summary), Micro Menu (Reload UI, Addon List), Played Time (Stopwatch, Copy Session), Saved Instances (Group Finder), System Performance (Addon List, Memory Report), Time/Date (Stopwatch, Copy Time)
- **SpecSwitch unified** - All modules now use the same `DDT:ResolveClickAction` with full modifier support

#### Communities Module Enrichment
- **Role badges** - Owner `[O]`, Leader `[L]`, Moderator `[M]` indicators next to member names
- **M+ score column** - Conditional Mythic+ score display with Blizzard tier colors
- **Battle.net App indicator** - `[App]` badge and "Battle.net App" zone text for remote chat members

#### Bug Fixes
- **PlayedTime crash** - Fixed undefined `db` variable in `BuildTooltipContent`
- **Coordinates cleanup** - Removed redundant `local db` redeclaration
- **gsub pattern injection** - All `ExpandLabel` functions use safe `ns.ExpandTag()` helper
- **SpecSwitch label** - Fixed `<icon>` tag not expanding in DemoMode

---

## [0.2.0] - 2026-03-31

### Performance, Formatting, and Quality-of-Life Update

#### New Modules
- **Account Status** - Warband bank access and pet journal unlock indicators for multiboxers
- **LFG Status** - LFG queue tracking with assigned role detection, premade group applications, listed group status

#### New Features
- **Global number formatting** - 8 locale presets (US, EU, French/SI, plain, custom) with configurable thousands separator, decimal point, and abbreviation (k/m/b). Applied to gold, currency quantities, memory, XP, and all numeric displays
- **Label template presets** - Every module now shows 2-5 clickable preset suggestions below the label editor for common configurations
- **LFG assigned role tracking** - `<assigned>` tag and tooltip display showing which role you were accepted as
- **ASCII XP progress bar** - `<bar>` tag in Experience module for visual XP display in the label

#### Optimization Pass
- **SystemPerformance** - Split into lightweight label updates (FPS/latency only) and heavy path (memory/CPU scan only when tooltip visible)
- **Coordinates** - Update interval increased 5x (0.1s to 0.5s), position threshold skips redundant C_Map calls when stationary
- **MovementSpeed** - Speed polling separated from buff scanning (UNIT_AURA event only), 0.5% change threshold
- **Experience** - Dirty flag pattern: quest XP scan only runs on quest-related events

#### Improvements
- **CPU Profiler** - Rewritten to use C_AddOnProfiler API (no scriptProfile cvar needed)
- **Number formatting** - Centralized `ns.FormatNumber`, `ns.FormatGold`, `ns.FormatGoldShort`, `ns.FormatMemory`, `ns.FormatQuantity`
- **Settings UI** - Number formatting section in General panel with preset dropdown, live preview, and custom controls

---

## [0.1.1] - 2026-03-31

### Initial Release - 19-Module LDB DataText Suite

A unified LDB DataText suite for WoW Retail (Interface 120001 / Midnight).
Works with any LDB display (ElvUI, Titan Panel, Bazooka, ChocolateBar, etc.).

#### Modules
| Category | Modules |
|----------|---------|
| Social | Guild, Friends, Communities |
| Character & Stats | Account Status, Character Info, Experience, Spec Switch, Movement Speed |
| Inventory & Economy | Currency, Bag Value, Mail |
| Instances & Progress | LFG Status, Saved Instances, Pet Info |
| Time & Location | Time/Date, Coordinates |
| System & Utility | System Performance, Played Time, Micro Menu |

#### Features
- Unified DDT font system (configurable face/size in General settings)
- Configurable label templates with `<tag>` syntax for every module
- Configurable tooltip sizing (width/scale) per module
- Configurable sort orders where applicable
- Blizzard Settings API integration with per-module subcategories
- DjinnisGuildFriends → DDT automatic migration
- Consistent dark tooltip style (dark bg, gold headers, class-colored names, gray hints)

---

## [0.1.0] - 2026-03-31

### Phase Build Log

#### Phase 1: Scaffold + Social Migration
- Core scaffold with DDT namespace, module registration, DGF migration logic
- Settings framework with Blizzard Settings API, per-module subcategories
- Ported Guild, Friends, Communities modules from DjinnisGuildFriends
- DemoMode support for development outside the game client

#### Phase 2: Spec Switch + Saved Instances
- SpecSwitch: talent/loadout/loot spec switching with clickable tooltip rows
- SavedInstances: raid/dungeon lockouts, boss details, M+ runs, alt integration
- Configurable sort order for raids, dungeons, and M+ runs

#### Phase 3: Time/Date + Coordinates
- TimeDate: server/local time, daily/weekly reset countdowns
- Coordinates: player map coordinates with zone/subzone info

#### Phase 4: System + Played + Mail
- SystemPerformance: FPS, latency, top addon memory consumers
- PlayedTime: session timer, total/level /played
- Mail: unread mail indicator, mailbox contents with sender/subject/expiry

#### Phase 5: Micro Menu + XP/Rep + Time Enhancements
- MicroMenu: quick-access clickable rows for all game panels
- Experience: XP progress, XP/hr, quest XP, time-to-level, rested XP, watched rep
- TimeDate Phase 2: calendar events, holidays, configurable strftime-based datetime format

#### Phase 6: Currency + Visual Consistency
- Currency: gold, session tracking, alt totals, WoW Token, tracked currencies
- Expansion-grouped currency sub-headers, icon display, quality-colored names
- Standardized ROW_HEIGHT to 20 across all interactive modules

#### Phase 7: Character, Speed, Bags, Pets + Enhancements
- CharacterInfo: name, realm, class, race, level, ilvl, guild, shard ID (opt-in)
- MovementSpeed: current/base speed %, swim/fly/glide, active speed buffs
- BagValue: TSM-priced bag contents, vendor fallback, top items, free slots
- PetInfo: journal unlock, battle capability, collection stats
- Currency enhancements: warband bank gold, posted auctions, staleness indicator
- SavedInstances: right-click opens Great Vault (Blizzard_WeeklyRewards)
- Unified DDT font system; configurable label templates with `<tag>` syntax

---

## [0.6.2] - 2026-04-06

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


## [0.6.1] - 2026-04-06

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


## [0.6.0] - 2026-04-02

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


## [0.5.3] - 2026-04-02

### Gold Display Fixes + Settings Label Template UX Improvements + Startup Data Load

#### Gold Display

- **Colorize now applies to datatexts** — `FormatGoldShort()` now respects `goldColorize`, `goldShowSilver`, and `goldShowCopper` global settings, matching `FormatGold()` behavior; gold in all module labels (Currency, BagValue) now colors correctly
- **Gold settings changes refresh immediately** — toggling colorize/silver/copper in General settings now calls `UpdateData()` on all modules, so labels refresh without needing a mouseover
- **Number format preset change also refreshes modules** — changing the format preset now propagates to all module labels immediately

#### Settings Label Template UX

- **Label Template editor lifted out of scroll frame** — the template editbox and tag buttons now render in a fixed header above the scroll area, resolving the persistent "blank editbox on first load" issue caused by WoW's EditBox text not rendering inside scroll children
- **Editbox pre-populated on panel show** — panels now start hidden so `OnShow` fires when Blizzard Settings displays them, ensuring the refresh callback correctly populates the editbox
- **Tag insertion at cursor** — clicking a tag button now inserts at the last cursor position rather than appending to the end; cursor position is saved on focus loss (before the tag button's OnClick fires)
- **Live template updates** — `OnTextChanged` commits the value as you type; no need to press Enter

#### Startup Data Load

- **Initial data load on login/reload** — all modules now call `UpdateData()` 1 second after addon load, so datatexts are populated immediately rather than waiting for the first mouseover
- **Periodic background refresh** — all modules refresh every 3 minutes automatically, keeping labels current without user interaction

#### SpecSwitch

- **Direct spec switching via click actions** — `spec1`/`spec2`/`spec3`/`spec4` click actions added; switch to a specific spec directly from the datatext
- **Spec names in dropdown** — click action dropdown shows "Switch to Arms" instead of "Switch to Spec 1"; spec names resolved once on first data load


## [0.5.2] - 2026-04-01

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
