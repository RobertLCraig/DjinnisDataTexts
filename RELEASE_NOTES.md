# Release Notes

## Version: 0.1.1

### Initial Release â€” 17-Module LDB DataText Suite

A unified LDB DataText suite for WoW Retail (Interface 120001 / Midnight).
Works with any LDB display (ElvUI, Titan Panel, Bazooka, ChocolateBar, etc.).

#### Social (ported from DjinnisGuildFriends)
- **Guild** â€” Online guild roster, MOTD, rank, zone, and notes
- **Friends** â€” Friends list with BNet status, game info, and broadcasts
- **Communities** â€” WoW Communities roster with online members and streams

#### Character & Stats
- **CharacterInfo** â€” Name, realm, class, race, level, item level, shard ID (opt-in)
- **Experience** â€” XP progress, XP/hr, quest XP, time-to-level, rested XP, watched rep at max level
- **SpecSwitch** â€” Talent specialization, loadout switching, and loot spec selection
- **MovementSpeed** â€” Current/base speed %, swim/fly/glide, active speed buffs, configurable update rate

#### Inventory & Economy
- **Currency** â€” Gold, alt totals, warband bank, WoW Token, posted auctions, tracked currencies
- **BagValue** â€” TSM-priced bag contents with vendor fallback, top items, free slots
- **Mail** â€” Unread mail indicator, mailbox contents (sender, subject, money, attachments, expiry)

#### Instances & Progress
- **SavedInstances** â€” Raid/dungeon lockouts, boss details, M+ runs, Great Vault, alt integration
- **PetInfo** â€” Pet journal unlock, battle capability, collection stats (level 25, rare, favorites)

#### Time & Location
- **TimeDate** â€” Server/local time, reset countdowns, calendar events, configurable datetime format
- **Coordinates** â€” Player map coordinates with zone/subzone info

#### System & Utility
- **SystemPerformance** â€” FPS, latency, addon memory consumers
- **PlayedTime** â€” Session timer, total/level /played
- **MicroMenu** â€” Quick-access clickable rows for all game panels

#### Features
- Unified DDT font system (configurable face/size in General settings)
- Configurable label templates with `<tag>` syntax for every module
- Configurable tooltip sizing (width/scale) per module
- Configurable sort orders where applicable
- Blizzard Settings API integration with per-module subcategories
- DjinnisGuildFriends â†’ DDT automatic migration
- Consistent dark tooltip style (dark bg, gold headers, class-colored names, gray hints)

#### Inspirations & References
- [DjinnisGuildFriends](https://github.com/Djinni-WoW/DjinnisGuildFriends) â€” Original social module codebase
- [ElvUI](https://github.com/tukui-org/ElvUI) â€” DataText patterns, tooltip conventions
- [Shadow & Light (ElvUI plugin)](https://www.tukui.org/addons.php?id=38) â€” Extended DataText ideas
- [WindTools (ElvUI plugin)](https://github.com/wind-addons/ElvUI_WindTools) â€” Additional DataText modules
- [EnhanceQoL](https://www.curseforge.com/wow/addons/enhanceqol) â€” System/performance DataText patterns
- [SavedInstances](https://www.curseforge.com/wow/addons/saved_instances) â€” Alt lockout data integration
- [TradeSkillMaster](https://www.tradeskillmaster.com/) â€” Bag value pricing API
- [GoblinToolbox](https://github.com/user/GoblinToolbox) â€” Warband bank access patterns
