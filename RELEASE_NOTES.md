# Release Notes

## Version: 0.3.1

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
