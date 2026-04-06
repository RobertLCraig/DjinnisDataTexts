# Release Notes

## Version: 0.8.1 — 2026-04-06

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

## Version: 0.8.1 — 2026-04-02

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
