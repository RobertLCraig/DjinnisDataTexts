# Changelog

All notable changes to Djinni's Data Texts will be documented in this file.

---

## [0.1.0] — 2026-03-31

### Added — Phase 1: Scaffold + Social Migration
- Core scaffold with DDT namespace, module registration, DGF migration logic
- Settings framework with Blizzard Settings API, per-module subcategories
- Ported Guild, Friends, Communities modules from DjinnisGuildFriends
- DemoMode support for development outside the game client
- Libraries: LibStub, CallbackHandler-1.0, LibDataBroker-1.1

### Added — Phase 2: Spec Switch + Saved Instances
- SpecSwitch: talent/loadout/loot spec switching with clickable tooltip rows
- SavedInstances: raid/dungeon lockouts, boss details, M+ runs, alt integration
- Configurable sort order for raids, dungeons, and M+ runs
- Condensed raid/M+ views, extended lockout indicator

### Added — Phase 3: Time/Date + Coordinates
- TimeDate: server/local time, daily/weekly reset countdowns
- Coordinates: player map coordinates with zone/subzone info

### Added — Phase 4: System + Played + Mail
- SystemPerformance: FPS, latency, top addon memory consumers
- PlayedTime: session timer, total/level /played
- Mail: unread mail indicator, mailbox contents with sender/subject/expiry

### Added — Phase 5: Micro Menu + XP/Rep + Time Enhancements
- MicroMenu: quick-access clickable rows for all game panels
- Experience: XP progress, XP/hr, quest XP, time-to-level, rested XP, watched rep
- TimeDate Phase 2: calendar events, holidays in tooltip
- TimeDate Phase 2.5: configurable strftime-based datetime format with presets

### Added — Phase 6: Currency + Visual Consistency
- Currency: gold, session tracking, alt totals, WoW Token, tracked currencies
- Expansion-grouped currency sub-headers, icon display, quality-colored names
- Visual consistency pass: social modules updated to match standard tooltip pattern
- Standardized ROW_HEIGHT to 20 across all interactive modules

### Added — Phase 7: Character, Speed, Bags, Pets + Enhancements
- CharacterInfo: name, realm, class, race, level, ilvl, guild, shard ID (opt-in)
- MovementSpeed: current/base speed %, swim/fly/glide, active speed buffs
- BagValue: TSM-priced bag contents, vendor fallback, top items, free slots
- PetInfo: journal unlock, battle capability, collection stats
- Currency enhancements: warband bank gold, posted auctions, staleness indicator
- SavedInstances: right-click opens Great Vault (Blizzard_WeeklyRewards)
- Unified DDT font system (configurable face/size in General settings)
- Configurable label templates with `<tag>` syntax for every module
