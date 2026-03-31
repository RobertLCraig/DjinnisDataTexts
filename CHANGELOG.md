# Changelog

All notable changes to Djinni's Data Texts will be documented in this file.

---

## [0.3.1-beta] - 2026-03-31

### Settings UI Refactor: Collapsible Sections & Improved Layout

**Beta release** with significant usability overhaul of the addon settings system.

#### Settings UI Improvements
- **Collapsible sections** - Organized settings into logical groups (Label Template, Display, Tooltip, Click Actions, etc.). Tooltip and Click Actions sections collapse by default to reduce clutter
- **Space-efficient two-column layouts** - Paired checkboxes and sliders now display side-by-side (e.g., "Show free slots" + "Show top items" on one row)
- **Better visual hierarchy** - Section headers with expand/collapse indicators, grouped content, improved readability
- **Dynamic section sizing** - Sections automatically adjust height as they expand/collapse; panel height recalculates in real-time
- **Improved settings panel appearance** - Leverages WoW Blizzard API for consistent look, better organized module configuration

#### Bug Fixes
- Fixed `SetBackdrop` nil errors in Currency and BagValue row frames by adding BackdropTemplate to frame creation

---

## [0.1.1] - 2026-03-31

### Initial Release - 17-Module LDB DataText Suite

A unified LDB DataText suite for WoW Retail (Interface 120001 / Midnight).
Works with any LDB display (ElvUI, Titan Panel, Bazooka, ChocolateBar, etc.).

#### Social (ported from DjinnisGuildFriends)
- **Guild** - Online guild roster, MOTD, rank, zone, and notes
- **Friends** - Friends list with BNet status, game info, and broadcasts
- **Communities** - WoW Communities roster with online members and streams

#### Character & Stats
- **CharacterInfo** - Name, realm, class, race, level, item level, shard ID (opt-in)
- **Experience** - XP progress, XP/hr, quest XP, time-to-level, rested XP, watched rep at max level
- **SpecSwitch** - Talent specialization, loadout switching, and loot spec selection
- **MovementSpeed** - Current/base speed %, swim/fly/glide, active speed buffs, configurable update rate

#### Inventory & Economy
- **Currency** - Gold, alt totals, warband bank, WoW Token, posted auctions, tracked currencies
- **BagValue** - TSM-priced bag contents with vendor fallback, top items, free slots
- **Mail** - Unread mail indicator, mailbox contents (sender, subject, money, attachments, expiry)

#### Instances & Progress
- **SavedInstances** - Raid/dungeon lockouts, boss details, M+ runs, Great Vault, alt integration
- **PetInfo** - Pet journal unlock, battle capability, collection stats (level 25, rare, favorites)

#### Time & Location
- **TimeDate** - Server/local time, reset countdowns, calendar events, configurable datetime format
- **Coordinates** - Player map coordinates with zone/subzone info

#### System & Utility
- **SystemPerformance** - FPS, latency, addon memory consumers
- **PlayedTime** - Session timer, total/level /played
- **MicroMenu** - Quick-access clickable rows for all game panels

#### Features
- Unified DDT font system (configurable face/size in General settings)
- Configurable label templates with `<tag>` syntax for every module
- Configurable tooltip sizing (width/scale) per module
- Configurable sort orders where applicable
- Blizzard Settings API integration with per-module subcategories
- DjinnisGuildFriends -> DDT automatic migration
- Consistent dark tooltip style (dark bg, gold headers, class-colored names, gray hints)

---

## [0.1.0] - 2026-03-31

### Added - Phase 1: Scaffold + Social Migration
- Core scaffold with DDT namespace, module registration, DGF migration logic
- Settings framework with Blizzard Settings API, per-module subcategories
- Ported Guild, Friends, Communities modules from DjinnisGuildFriends
- DemoMode support for development outside the game client
- Libraries: LibStub, CallbackHandler-1.0, LibDataBroker-1.1

### Added - Phase 2: Spec Switch + Saved Instances
- SpecSwitch: talent/loadout/loot spec switching with clickable tooltip rows
- SavedInstances: raid/dungeon lockouts, boss details, M+ runs, alt integration
- Configurable sort order for raids, dungeons, and M+ runs
- Condensed raid/M+ views, extended lockout indicator

### Added - Phase 3: Time/Date + Coordinates
- TimeDate: server/local time, daily/weekly reset countdowns
- Coordinates: player map coordinates with zone/subzone info

### Added - Phase 4: System + Played + Mail
- SystemPerformance: FPS, latency, top addon memory consumers
- PlayedTime: session timer, total/level /played
- Mail: unread mail indicator, mailbox contents with sender/subject/expiry

### Added - Phase 5: Micro Menu + XP/Rep + Time Enhancements
- MicroMenu: quick-access clickable rows for all game panels
- Experience: XP progress, XP/hr, quest XP, time-to-level, rested XP, watched rep
- TimeDate Phase 2: calendar events, holidays in tooltip
- TimeDate Phase 2.5: configurable strftime-based datetime format with presets

### Added - Phase 6: Currency + Visual Consistency
- Currency: gold, session tracking, alt totals, WoW Token, tracked currencies
- Expansion-grouped currency sub-headers, icon display, quality-colored names
- Visual consistency pass: social modules updated to match standard tooltip pattern
- Standardized ROW_HEIGHT to 20 across all interactive modules

### Added - Phase 7: Character, Speed, Bags, Pets + Enhancements
- CharacterInfo: name, realm, class, race, level, ilvl, guild, shard ID (opt-in)
- MovementSpeed: current/base speed %, swim/fly/glide, active speed buffs
- BagValue: TSM-priced bag contents, vendor fallback, top items, free slots
- PetInfo: journal unlock, battle capability, collection stats
- Currency enhancements: warband bank gold, posted auctions, staleness indicator
- SavedInstances: right-click opens Great Vault (Blizzard_WeeklyRewards)
- Unified DDT font system (configurable face/size in General settings)
- Configurable label templates with `<tag>` syntax for every module

---

## [0.3.1] [beta] - 2026-03-31

### Settings UI Refactor: Collapsible Sections & Improved Layout

**19-module LDB DataText suite for WoW Retail (Interface 120001 / Midnight).**

Significant usability overhaul of the addon settings system: collapsible sections, two-column layouts, improved visual hierarchy, and efficient use of screen space.

#### Settings UI Improvements
- **Collapsible sections** - Organized settings into logical groups (Label Template, Display, Tooltip, Click Actions, etc.). Tooltip and Click Actions sections collapse by default to reduce clutter
- **Space-efficient two-column layouts** - Paired checkboxes and sliders now display side-by-side (e.g., "Show free slots" + "Show top items" on one row)
- **Better visual hierarchy** - Section headers with expand/collapse indicators, grouped content, improved readability
- **Dynamic section sizing** - Sections automatically adjust height as they expand/collapse; panel height recalculates in real-time
- **Improved settings panel appearance** - Leverages WoW Blizzard API for consistent look, better organized module configuration

#### Bug Fixes
- Fixed `SetBackdrop` nil errors in Currency and BagValue row frames by adding BackdropTemplate to frame creation

#### Full Module List (19)
| Category | Modules |
|----------|---------|
| Social | Guild, Friends, Communities |
| Character & Stats | Account Status, Character Info, Experience, Spec Switch, Movement Speed |
| Inventory & Economy | Currency, Bag Value, Mail |
| Instances & Progress | LFG Status, Saved Instances, Pet Info |
| Time & Location | Time/Date, Coordinates |
| System & Utility | System Performance, Played Time, Micro Menu |


## [0.3.0] - 2026-03-31

### Click Actions, Communities Enrichment, and Bug Fixes

19-module LDB DataText suite for WoW Retail (Interface 120001 / Midnight).
Works with any LDB display (ElvUI, Titan Panel, Bazooka, ChocolateBar, etc.).

#### Extended Click Action System
- **9 modifier combinations** - Left, Right, Middle, Shift+Left, Shift+Right, Ctrl+Left, Ctrl+Right, Alt+Left, Alt+Right (previously 5). All modules now expose all 9 slots in settings
- **Per-row click actions** - Currency and Bag Value modules support configurable click actions on individual tooltip rows (link to chat, open currency tab, etc.)
- **New click actions across all modules**:
  - Account Status: Open Warband Bank, Open Pet Journal
  - Character Info: Achievements, Spellbook, Collections
  - Bag Value: Sort Bags; row click to link items
  - Coordinates: Share Coords in Group, Set/Clear Map Pin
  - Currency: Copy Gold to Chat; row click to link currencies
  - Experience: Achievements
  - LFG Status: Premade Groups
  - Mail: Copy Mail Summary
  - Micro Menu: Reload UI, Addon List
  - Played Time: Toggle Stopwatch, Copy Session Time
  - Saved Instances: Group Finder
  - System Performance: Addon List, Copy Memory Report
  - Time/Date: Toggle Stopwatch, Copy Time to Chat
- **SpecSwitch unified** - Merged custom click resolver back into standard system; all modules now use the same `DDT:ResolveClickAction` with full modifier support

#### Communities Module Enrichment
- **Role badges** - Owner `[O]`, Leader `[L]`, Moderator `[M]` indicators next to member names
- **M+ score column** - Conditional Mythic+ score display with Blizzard tier colors (hidden when no member has a score)
- **Battle.net App indicator** - `[App]` badge and "Battle.net App" zone text for remote chat members in BNet communities

#### Bug Fixes
- **PlayedTime crash** - Fixed undefined `db` variable used before declaration in `BuildTooltipContent`
- **Coordinates cleanup** - Removed redundant `local db` redeclaration in `BuildTooltipContent`
- **gsub pattern injection** - All 16 module `ExpandLabel` functions and Core `FormatLabel`/`GetCustomURL` now use safe `ns.ExpandTag()` helper to prevent `%` characters in replacement values from being interpreted as Lua capture references
- **SpecSwitch label** - Fixed `<icon>` tag not expanding in DemoMode by using shared `ExpandLabel` function

#### Demo Mode Updates
- Updated all demo data to Midnight expansion: level cap 90, Quel'Thalas zones (Silvermoon City, Eversong Woods, Ghostlands, The Dead Scar, etc.)
- Added 4th demo community "BNet Gaming Group" with M+ scores and App-only members
- Mix of max-level and leveling characters across demo data

#### Full Module List (19)
| Category | Modules |
|----------|---------|
| Social | Guild, Friends, Communities |
| Character & Stats | Account Status, Character Info, Experience, Spec Switch, Movement Speed |
| Inventory & Economy | Currency, Bag Value, Mail |
| Instances & Progress | LFG Status, Saved Instances, Pet Info |
| Time & Location | Time/Date, Coordinates |
| System & Utility | System Performance, Played Time, Micro Menu |


## [0.2.0] - 2026-03-31

### Performance, Formatting, and Quality-of-Life Update

19-module LDB DataText suite for WoW Retail (Interface 120001 / Midnight).
Works with any LDB display (ElvUI, Titan Panel, Bazooka, ChocolateBar, etc.).

#### New Modules
- **Account Status** - Warband bank access and pet journal unlock indicators for multiboxers
- **LFG Status** - LFG queue tracking with assigned role detection, premade group applications, listed group status

#### New Features
- **Global number formatting** - 8 locale presets (US, EU, French/SI, plain, custom) with configurable thousands separator, decimal point, and abbreviation (k/m/b). Applied to gold, currency quantities, memory, XP, and all numeric displays
- **Label template presets** - Every module now shows 2-5 clickable preset suggestions below the label editor for common configurations
- **LFG assigned role tracking** - `<assigned>` tag and tooltip display showing which role you were accepted as (via GetLFGProposal / UnitGroupRolesAssigned)
- **ASCII XP progress bar** - `<bar>` tag in Experience module for visual XP display in the label

#### Optimization Pass
- **SystemPerformance** - Split into lightweight label updates (FPS/latency only) and heavy path (memory/CPU scan only when tooltip visible). ~1,700 API calls/sec reduced to ~2 when tooltip hidden
- **Coordinates** - Update interval increased 5x (0.1s to 0.5s), position threshold skips redundant C_Map calls when stationary
- **MovementSpeed** - Speed polling separated from buff scanning (UNIT_AURA event only), 0.5% change threshold
- **Experience** - Dirty flag pattern: quest XP scan only runs on quest-related events, not every XP update

#### Improvements
- **CPU Profiler** - Rewritten to use C_AddOnProfiler API (no scriptProfile cvar needed), handles 140+ addons without script timeout
- **Number formatting** - Centralized `ns.FormatNumber`, `ns.FormatGold`, `ns.FormatGoldShort`, `ns.FormatMemory`, `ns.FormatQuantity` replace per-module formatting functions
- **Settings UI** - Number formatting section in General panel with preset dropdown, live preview, and custom separator/decimal/abbreviation controls

#### Full Module List (19)
| Category | Modules |
|----------|---------|
| Social | Guild, Friends, Communities |
| Character & Stats | Account Status, Character Info, Experience, Spec Switch, Movement Speed |
| Inventory & Economy | Currency, Bag Value, Mail |
| Instances & Progress | LFG Status, Saved Instances, Pet Info |
| Time & Location | Time/Date, Coordinates |
| System & Utility | System Performance, Played Time, Micro Menu |

---

## [0.3.2] - 2026-03-31

### Separated Label & Row Click Actions, API Fixes

#### Social Module Click Actions (Friends, Guild, Communities)
- **Separate label vs row clicks** - Click actions now split into two configurable sections:
  - **Label Click Actions** (clicking the DataText) - Open respective panel list, or DDT Settings (new configurable section)
  - **Row Click Actions** (clicking a player in tooltip) - Whisper, invite, copy name, etc. (new configurable section)
- **Improved defaults** - Left-click the label now opens Friends/Guild/Communities directly (was Shift+Click only)

#### Bug Fixes
- **MovementSpeed aura scanning** - Fixed Midnight API incompatibility by switching from `C_UnitAuras.GetAuraDataByIndex` (protected spellId field) to `C_UnitAuras.GetPlayerAuraBySpellID` for known speed buffs

---

**Previous Versions:**
See CHANGELOG.md for 0.3.1-beta and earlier releases.
