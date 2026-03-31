# Release Notes

## Version: 0.3.0

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
