# Changelog

All notable changes to Djinni's Data Texts will be documented in this file.

---

## [0.1.0] Ã¢â‚¬â€ 2026-03-31

### Added Ã¢â‚¬â€ Phase 1: Scaffold + Social Migration
- Core scaffold with DDT namespace, module registration, DGF migration logic
- Settings framework with Blizzard Settings API, per-module subcategories
- Ported Guild, Friends, Communities modules from DjinnisGuildFriends
- DemoMode support for development outside the game client
- Libraries: LibStub, CallbackHandler-1.0, LibDataBroker-1.1

### Added Ã¢â‚¬â€ Phase 2: Spec Switch + Saved Instances
- SpecSwitch: talent/loadout/loot spec switching with clickable tooltip rows
- SavedInstances: raid/dungeon lockouts, boss details, M+ runs, alt integration
- Configurable sort order for raids, dungeons, and M+ runs
- Condensed raid/M+ views, extended lockout indicator

### Added Ã¢â‚¬â€ Phase 3: Time/Date + Coordinates
- TimeDate: server/local time, daily/weekly reset countdowns
- Coordinates: player map coordinates with zone/subzone info

### Added Ã¢â‚¬â€ Phase 4: System + Played + Mail
- SystemPerformance: FPS, latency, top addon memory consumers
- PlayedTime: session timer, total/level /played
- Mail: unread mail indicator, mailbox contents with sender/subject/expiry

### Added Ã¢â‚¬â€ Phase 5: Micro Menu + XP/Rep + Time Enhancements
- MicroMenu: quick-access clickable rows for all game panels
- Experience: XP progress, XP/hr, quest XP, time-to-level, rested XP, watched rep
- TimeDate Phase 2: calendar events, holidays in tooltip
- TimeDate Phase 2.5: configurable strftime-based datetime format with presets

### Added Ã¢â‚¬â€ Phase 6: Currency + Visual Consistency
- Currency: gold, session tracking, alt totals, WoW Token, tracked currencies
- Expansion-grouped currency sub-headers, icon display, quality-colored names
- Visual consistency pass: social modules updated to match standard tooltip pattern
- Standardized ROW_HEIGHT to 20 across all interactive modules

### Added Ã¢â‚¬â€ Phase 7: Character, Speed, Bags, Pets + Enhancements
- CharacterInfo: name, realm, class, race, level, ilvl, guild, shard ID (opt-in)
- MovementSpeed: current/base speed %, swim/fly/glide, active speed buffs
- BagValue: TSM-priced bag contents, vendor fallback, top items, free slots
- PetInfo: journal unlock, battle capability, collection stats
- Currency enhancements: warband bank gold, posted auctions, staleness indicator
- SavedInstances: right-click opens Great Vault (Blizzard_WeeklyRewards)
- Unified DDT font system (configurable face/size in General settings)
- Configurable label templates with `<tag>` syntax for every module

---

## [0.1.1] - 2026-03-31

### Initial Release Ã¢â‚¬â€ 17-Module LDB DataText Suite

A unified LDB DataText suite for WoW Retail (Interface 120001 / Midnight).
Works with any LDB display (ElvUI, Titan Panel, Bazooka, ChocolateBar, etc.).

#### Social (ported from DjinnisGuildFriends)
- **Guild** Ã¢â‚¬â€ Online guild roster, MOTD, rank, zone, and notes
- **Friends** Ã¢â‚¬â€ Friends list with BNet status, game info, and broadcasts
- **Communities** Ã¢â‚¬â€ WoW Communities roster with online members and streams

#### Character & Stats
- **CharacterInfo** Ã¢â‚¬â€ Name, realm, class, race, level, item level, shard ID (opt-in)
- **Experience** Ã¢â‚¬â€ XP progress, XP/hr, quest XP, time-to-level, rested XP, watched rep at max level
- **SpecSwitch** Ã¢â‚¬â€ Talent specialization, loadout switching, and loot spec selection
- **MovementSpeed** Ã¢â‚¬â€ Current/base speed %, swim/fly/glide, active speed buffs, configurable update rate

#### Inventory & Economy
- **Currency** Ã¢â‚¬â€ Gold, alt totals, warband bank, WoW Token, posted auctions, tracked currencies
- **BagValue** Ã¢â‚¬â€ TSM-priced bag contents with vendor fallback, top items, free slots
- **Mail** Ã¢â‚¬â€ Unread mail indicator, mailbox contents (sender, subject, money, attachments, expiry)

#### Instances & Progress
- **SavedInstances** Ã¢â‚¬â€ Raid/dungeon lockouts, boss details, M+ runs, Great Vault, alt integration
- **PetInfo** Ã¢â‚¬â€ Pet journal unlock, battle capability, collection stats (level 25, rare, favorites)

#### Time & Location
- **TimeDate** Ã¢â‚¬â€ Server/local time, reset countdowns, calendar events, configurable datetime format
- **Coordinates** Ã¢â‚¬â€ Player map coordinates with zone/subzone info

#### System & Utility
- **SystemPerformance** Ã¢â‚¬â€ FPS, latency, addon memory consumers
- **PlayedTime** Ã¢â‚¬â€ Session timer, total/level /played
- **MicroMenu** Ã¢â‚¬â€ Quick-access clickable rows for all game panels

#### Features
- Unified DDT font system (configurable face/size in General settings)
- Configurable label templates with `<tag>` syntax for every module
- Configurable tooltip sizing (width/scale) per module
- Configurable sort orders where applicable
- Blizzard Settings API integration with per-module subcategories
- DjinnisGuildFriends Ã¢â€ â€™ DDT automatic migration
- Consistent dark tooltip style (dark bg, gold headers, class-colored names, gray hints)

#### Inspirations & References
- [DjinnisGuildFriends](https://github.com/Djinni-WoW/DjinnisGuildFriends) Ã¢â‚¬â€ Original social module codebase
- [ElvUI](https://github.com/tukui-org/ElvUI) Ã¢â‚¬â€ DataText patterns, tooltip conventions
- [Shadow & Light (ElvUI plugin)](https://www.tukui.org/addons.php?id=38) Ã¢â‚¬â€ Extended DataText ideas
- [WindTools (ElvUI plugin)](https://github.com/wind-addons/ElvUI_WindTools) Ã¢â‚¬â€ Additional DataText modules
- [EnhanceQoL](https://www.curseforge.com/wow/addons/enhanceqol) Ã¢â‚¬â€ System/performance DataText patterns
- [SavedInstances](https://www.curseforge.com/wow/addons/saved_instances) Ã¢â‚¬â€ Alt lockout data integration
- [TradeSkillMaster](https://www.tradeskillmaster.com/) Ã¢â‚¬â€ Bag value pricing API
- [GoblinToolbox](https://github.com/user/GoblinToolbox) Ã¢â‚¬â€ Warband bank access patterns


## [0.1.0] - 2026-03-31

### Initial Release Ã¢â‚¬â€ 17-Module LDB DataText Suite

A unified LDB DataText suite for WoW Retail (Interface 120001 / Midnight).
Works with any LDB display (ElvUI, Titan Panel, Bazooka, ChocolateBar, etc.).

#### Social (ported from DjinnisGuildFriends)
- **Guild** Ã¢â‚¬â€ Online guild roster, MOTD, rank, zone, and notes
- **Friends** Ã¢â‚¬â€ Friends list with BNet status, game info, and broadcasts
- **Communities** Ã¢â‚¬â€ WoW Communities roster with online members and streams

#### Character & Stats
- **CharacterInfo** Ã¢â‚¬â€ Name, realm, class, race, level, item level, shard ID (opt-in)
- **Experience** Ã¢â‚¬â€ XP progress, XP/hr, quest XP, time-to-level, rested XP, watched rep at max level
- **SpecSwitch** Ã¢â‚¬â€ Talent specialization, loadout switching, and loot spec selection
- **MovementSpeed** Ã¢â‚¬â€ Current/base speed %, swim/fly/glide, active speed buffs, configurable update rate

#### Inventory & Economy
- **Currency** Ã¢â‚¬â€ Gold, alt totals, warband bank, WoW Token, posted auctions, tracked currencies
- **BagValue** Ã¢â‚¬â€ TSM-priced bag contents with vendor fallback, top items, free slots
- **Mail** Ã¢â‚¬â€ Unread mail indicator, mailbox contents (sender, subject, money, attachments, expiry)

#### Instances & Progress
- **SavedInstances** Ã¢â‚¬â€ Raid/dungeon lockouts, boss details, M+ runs, Great Vault, alt integration
- **PetInfo** Ã¢â‚¬â€ Pet journal unlock, battle capability, collection stats (level 25, rare, favorites)

#### Time & Location
- **TimeDate** Ã¢â‚¬â€ Server/local time, reset countdowns, calendar events, configurable datetime format
- **Coordinates** Ã¢â‚¬â€ Player map coordinates with zone/subzone info

#### System & Utility
- **SystemPerformance** Ã¢â‚¬â€ FPS, latency, addon memory consumers
- **PlayedTime** Ã¢â‚¬â€ Session timer, total/level /played
- **MicroMenu** Ã¢â‚¬â€ Quick-access clickable rows for all game panels

#### Features
- Unified DDT font system (configurable face/size in General settings)
- Configurable label templates with `<tag>` syntax for every module
- Configurable tooltip sizing (width/scale) per module
- Configurable sort orders where applicable
- Blizzard Settings API integration with per-module subcategories
- DjinnisGuildFriends Ã¢â€ â€™ DDT automatic migration
- Consistent dark tooltip style (dark bg, gold headers, class-colored names, gray hints)

#### Inspirations & References
- [DjinnisGuildFriends](https://github.com/Djinni-WoW/DjinnisGuildFriends) Ã¢â‚¬â€ Original social module codebase
- [ElvUI](https://github.com/tukui-org/ElvUI) Ã¢â‚¬â€ DataText patterns, tooltip conventions
- [Shadow & Light (ElvUI plugin)](https://www.tukui.org/addons.php?id=38) Ã¢â‚¬â€ Extended DataText ideas
- [WindTools (ElvUI plugin)](https://github.com/wind-addons/ElvUI_WindTools) Ã¢â‚¬â€ Additional DataText modules
- [EnhanceQoL](https://www.curseforge.com/wow/addons/enhanceqol) Ã¢â‚¬â€ System/performance DataText patterns
- [SavedInstances](https://www.curseforge.com/wow/addons/saved_instances) Ã¢â‚¬â€ Alt lockout data integration
- [TradeSkillMaster](https://www.tradeskillmaster.com/) Ã¢â‚¬â€ Bag value pricing API
- [GoblinToolbox](https://github.com/user/GoblinToolbox) Ã¢â‚¬â€ Warband bank access patterns
