# Release Notes

## Version: 0.6.1 — 2026-04-02

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
