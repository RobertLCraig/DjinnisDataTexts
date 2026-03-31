# Release Notes

## Version: 0.2.0

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
