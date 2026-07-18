A unified LDB DataText suite for World of Warcraft: Midnight. Works with ElvUI, Titan Panel, Bazooka, ChocolateBar, and any other LDB display addon.

---

## What it is

Djinni's Data Texts (DDT) packs 24+ information-rich modules into a single addon. Each module appears as a DataText on your bar with a detailed tooltip and configurable click actions. Everything is configured through the standard Blizzard Settings interface.

* **24+ modules** | Social, character, economy, instances, time, system, professions, audio
* **Label templates** | `<tag>` syntax with clickable tag-insert buttons and preset suggestions per module
* **Click actions** | 9 modifier combinations per module (Left, Right, Middle, Shift, Ctrl, Alt variants)
* **Tooltip sizing** | Width and scale configurable per module, up to 2000px wide
* **Sort orders** | Configurable on all list-based modules
* **Number formatting** | 8 locale presets or fully custom separators, decimals, and abbreviation
* **Font system** | Global font face and size setting applied across all module tooltips
* **Reset to Defaults** | One-click settings reset per module from the settings panel

---

## Modules

### Social

| Module | Description |
|--------|-------------|
| **Guild** | Online roster with MOTD, rank, zone, and notes. Group by rank, class, or zone. Officer notes column. Click rows to whisper, invite, or open armory. |
| **Friends** | Character and Battle.net friends with game info, status, and broadcasts. Filterable by type (WoW / BNet / offline). |
| **Communities** | WoW Communities roster with online members, role badges, and BNet App status. |

### Character

| Module | Description |
|--------|-------------|
| **Character Info** | Name, realm, class, race, level, and item level. |
| **Experience** | XP bar with rested overlay, XP/hour rate, quest XP ready to hand in, and time-to-level estimate. Shows watched reputation at max level. |
| **Item Level** | Equipped and overall item level with per-slot breakdown, quality colors, durability column, and missing enchant/gem warnings. Auctionator category-filtered shopping lists. SimulationCraft string export. AH upgrade search. |
| **Spec Switch** | Active spec display with talent loadout switching and loot spec selection. All specs shown with role icons. |
| **Movement Speed** | Current and base speed as a percentage. Ground, fly, swim, and skyriding breakdowns. Active speed buff detection. |
| **Account Status** | Warband bank access and pet journal unlock status at a glance. |

### Inventory and Economy

| Module | Description |
|--------|-------------|
| **Currency** | Character gold, alt gold totals, warband bank gold, WoW Token price, posted auction value, and expansion-grouped tracked currencies with icons. |
| **Bag Value** | Total bag value via TSM price sources (six sources) with vendor fallback. Top items breakdown and bag space display. |
| **Mail** | Unread mail count with full mailbox scan: sender, subject, money, attachments, and expiry countdown. |

### Instances and Progress

| Module | Description |
|--------|-------------|
| **Saved Instances** | Raid and dungeon lockouts with boss kill status, M+ weekly runs, and delve tracking. Difficulty color-coding, extended lockout markers, condensed views. Alt lockout columns via the SavedInstances addon. Great Vault progress on right-click. |
| **LFG Status** | Live Dungeon Finder and Raid Finder queue tracking. Queue name, elapsed time, and estimated wait on separate rows. Premade group applications with role and status. Assigned role shown when accepted. |
| **Prey Tracker** | Active Midnight prey hunt tracking - current target, zone, difficulty, and progress state (Cold/Warm/Hot/Final). Weekly completion history and Remnant of Anguish currency. |
| **Delve** | Live delve progress: tier, step criteria, companion level and XP, Sanctified Banner state, and active modifiers. |
| **Active Activity** | Aggregator that routes the DataText label and click actions to whichever sub-tracker (Delve, Prey Tracker) is currently active. One broker instead of several empty ones when idle. |
| **Pet Info** | Pet journal collection stats: owned, level 25, rare quality, favorites. Click actions for revive, bandage, safari hat, treats, and random summon. |

### Time and Location

| Module | Description |
|--------|-------------|
| **Time / Date** | Server and local time with 12h/24h toggle. Daily and weekly reset countdowns. Calendar events and holidays. Configurable date format with presets. |
| **Coordinates** | Player map coordinates via C_Map. Zone, subzone, and map ID in tooltip. Click to copy coords, open maps, or paste a TomTom waypoint. |

### System

| Module | Description |
|--------|-------------|
| **System Performance** | FPS, home and world latency, addon memory with top consumers list. CPU profiling via C_AddOnProfiler - no scriptProfile cvar needed. |
| **Played Time** | Session timer, total /played, and level /played. Class-colored character display. |
| **Micro Menu** | Quick-access launcher for all game panels: character, spellbook, talents, achievements, collections, and more. |

### Audio *(alpha)*

| Module | Description |
|--------|-------------|
| **Volume Control** | Per-stream volume sliders and mute toggles for Master, Music, Effects, Ambience, and Dialog. Drag sliders or use the scroll wheel to adjust live. |
| **Audio Output** | Switch between system audio output devices from a tooltip list. Click to switch, scroll to cycle. |

### Professions *(alpha)*

One LDB broker per detected profession. Covers all 11 Midnight professions: Alchemy, Blacksmithing, Enchanting, Engineering, Herbalism, Inscription, Jewelcrafting, Leatherworking, Mining, Skinning, Tailoring.

| Feature | Description |
|---------|-------------|
| **Knowledge Points** | Earned vs total KP from treasures, books, and weekly sources. Darkmoon Faire aware. Hides completed sources by default. |
| **Skill and Concentration** | Current skill level and available concentration currency. |
| **Majestic Beasts** *(Skinning)* | Daily lure beast tracking: lure counts in bags, missing reagents, and kill status per beast. Talent point gating respected. Click rows to set waypoints or use lures directly. |
| **Buffs** | Active gathering and crafting buff detection with profession-specific consumable tracking. |
| **Timers** | Daily and weekly reset countdowns. |

---

## Configuration

Open **Game Menu > Options > AddOns > Djinni's Data Texts**, or type `/ddt`.

| Setting | What it controls |
|---------|-----------------|
| **General - Font** | Font face and size applied across all module tooltips |
| **General - Number Format** | Locale preset or custom thousands separator, decimal, and abbreviation (K/M/B) |
| **Per-module - Label Template** | DataText label using `<tag>` syntax, with clickable tag buttons and presets |
| **Per-module - Tooltip** | Width (up to 2000px), scale, and grow direction |
| **Per-module - Click Actions** | What each of the 9 modifier combos does |
| **Per-module - Reset to Defaults** | Wipes and re-applies the module's registered defaults |

---

## Optional integrations

| Addon | Used for |
|-------|----------|
| ElvUI | LDB display (works without it) |
| TradeSkillMaster | Bag value pricing and TSM shopping lists |
| Auctionator | Category-filtered enhancement and gem shopping lists |
| SavedInstances | Alt character lockout columns in Saved Instances |
| SimulationCraft | SimC string export from Item Level |
| TomTom | Waypoint paste from Coordinates and Prey Tracker |
| MajesticBeastTracker | Auto-imports kill history and settings on first load |

---

## Migrating from DjinnisGuildFriends

DDT absorbs and replaces DjinnisGuildFriends. Settings are imported automatically on first load - no manual steps needed.
