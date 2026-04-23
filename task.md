# DjinnisDataTexts — Task Tracker

## Project Overview
A unified LDB DataText suite for WoW Retail (Interface 120005 — Midnight 12.0.5).
Absorbs DjinnisGuildFriends and adds new DataTexts with rich Djinni-style tooltips.

## Phase 1: Scaffold + Social Module Migration — COMPLETE
- [x] Directory structure and TOC
- [x] Core.lua (DDT namespace, utilities, DGF migration logic, module registry)
- [x] Settings.lua (widget helpers, Blizzard Settings API panels, module extensibility)
- [x] Libs (LibStub, CallbackHandler-1.0, LibDataBroker-1.1)
- [x] Port Guild.lua (DGF-Guild → DDT-Guild)
- [x] Port Friends.lua (DGF-Friends → DDT-Friends)
- [x] Port Communities.lua (DGF-Communities → DDT-Communities)
- [x] Port DemoMode.lua

### Notes
- All broker files ported with namespace changes only (DGF → DDT)
- No functional changes in initial port
- Core.lua includes DjinnisGuildFriendsDB migration logic
- Core.lua includes coexistence check (warns if DGF still loaded)
- Settings.lua exposes ns.SettingsWidgets and ns.CreateScrollPanel for future modules
- Module registration system: ns:RegisterModule(key, mod, defaults)

## Phase 2: Spec Switch + Saved Instances — COMPLETE
- [x] Modules/SpecSwitch.lua
  - Talent loadout switching via C_ClassTalents
  - Loot spec selection (GetLootSpecialization/SetLootSpecialization)
  - Left-click opens PlayerSpellsFrame (talent window)
  - Tooltip: specs with role icons, loadouts with active markers, loot spec — all clickable
  - Starter build detection
  - Combat lockdown guards
  - Events: PLAYER_TALENT_UPDATE, ACTIVE_TALENT_GROUP_CHANGED, PLAYER_LOOT_SPEC_UPDATED, TRAIT_CONFIG_DELETED, TRAIT_CONFIG_UPDATED
- [x] Modules/SavedInstances.lua (Phase 1 scope)
  - Current character raid/dungeon lockouts via GetSavedInstanceInfo
  - Reset timers with smart formatting (Xd Yh / Xh Ym / Xm)
  - Boss kill status (alive/dead) with click-to-expand per instance
  - Difficulty tags with color coding (N/H/M/LFR/M+/legacy)
  - Progress display with color (green=cleared, gold=partial, gray=none)
  - Extended lockout indicator (green left bar)
  - Configurable sort order for raids/dungeons (difficulty asc/desc, name, API order)
  - Configurable sort order for M+ runs (level asc/desc, name, API order)
  - Condensed raid view (group difficulties per instance)
  - Condensed M+ view (group runs by dungeon)
  - Alt lockouts from SavedInstances addon DB (if present)
  - Alt sorting: max-level first, then alphabetical
  - Row layout: name (left ~35%), diff+progress+reset (right ~65%)
  - LDB text: "Lockouts: 2R 1D" format
  - Events: UPDATE_INSTANCE_INFO, BOSS_KILL, INSTANCE_LOCK_START/STOP

## Phase 3: Time/Date + Coordinates — COMPLETE
- [x] Modules/TimeDate.lua (Phase 1)
  - Server time, local time, daily/weekly reset countdowns
  - Date display (weekday, month, day, year)
  - 12h/24h toggle, seconds toggle, server/local toggle
  - Left-click: calendar, right-click: toggle server/local on LDB
  - OnUpdate at 1s interval
  - Events: PLAYER_ENTERING_WORLD
- [x] Modules/Coordinates.lua
  - Player map coordinates via C_Map.GetBestMapForUnit/GetPlayerMapPosition
  - Zone, subzone, map name, map ID in tooltip
  - Configurable decimal precision (default 2)
  - Optional zone name in LDB text
  - Left-click: world map, right-click: copy coords to chat
  - OnUpdate at 0.1s interval
  - Events: ZONE_CHANGED, ZONE_CHANGED_INDOORS, ZONE_CHANGED_NEW_AREA, LOADING_SCREEN_DISABLED

## Phase 4: System + Played + Mail — COMPLETE
- [x] Modules/SystemPerformance.lua
  - FPS, home/world latency, total addon memory
  - Top addon memory consumers list (configurable count, default 10)
  - Configurable sort order for addon list (memory asc/desc, name)
  - Color-coded values (green/yellow/red thresholds for FPS and latency)
  - Left-click: garbage collect, right-click: refresh memory stats
  - OnUpdate at 1s interval
  - Events: PLAYER_ENTERING_WORLD
- [x] Modules/PlayedTime.lua
  - Session timer (real-time), total /played, level /played
  - Requests TIME_PLAYED_MSG silently on login
  - Long-form duration in tooltip (days, hours, minutes)
  - Character name (class-colored) and level in tooltip
  - Left-click: refresh /played data
  - OnUpdate at 1s interval
  - Events: PLAYER_ENTERING_WORLD, TIME_PLAYED_MSG
- [x] Modules/Mail.lua
  - Unread mail indicator via HasNewMail()
  - Mailbox contents scanned on MAIL_SHOW/MAIL_INBOX_UPDATE
  - Tooltip shows sender, subject, money, attachments, expiry
  - Configurable sort order (sender, subject, expiry, unread first)
  - Icon changes based on mail status
  - Events: UPDATE_PENDING_MAIL, MAIL_SHOW, MAIL_CLOSED, MAIL_INBOX_UPDATE

## Phase 5: Micro Menu + XP/Rep + Time Enhancements — COMPLETE
- [x] Modules/MicroMenu.lua
  - Quick-access clickable rows for all game panels (character, spellbook, talents, achievements, etc.)
  - 12 menu entries with icons, click to open and auto-dismiss tooltip
  - Left-click DataText: Game Menu
- [x] Modules/Experience.lua
  - XP progress with visual bar (purple fill + blue rested overlay)
  - Rested XP display with percentage
  - XP per hour tracking (session-based, resets on login)
  - Time-to-level estimate based on current XP/hr rate
  - Quest XP: total expected XP from quests ready to turn in
  - Session stats (total XP gained, session duration)
  - Remaining XP to level
  - At max level: shows watched reputation with standing and progress bar
  - Events: PLAYER_XP_UPDATE, PLAYER_LEVEL_UP, UPDATE_EXHAUSTION, UPDATE_FACTION, QUEST_LOG_UPDATE, QUEST_TURNED_IN
- [x] TimeDate Phase 2 (calendar events, holidays)
  - Tooltip shows today's calendar events (holidays, raid resets)
  - C_Calendar.OpenCalendar() on login to populate data
  - CALENDAR_UPDATE_EVENT_LIST event registered
- [x] TimeDate Phase 2.5 (configurable datetime format)
  - strftime-based dateTimeFormat setting (default: "%A, %B %d, %Y")
  - 10 format presets dropdown (ISO, US, EU, abbreviated, etc.)
  - Custom format editbox for arbitrary strftime strings
  - Live preview in settings panel
  - Strftime token cheatsheet in settings
  - GetDateString() now uses date(fmt) directly, removed manual WEEKDAY/MONTH tables
- [ ] TimeDate Phase 3 (multi-timezone) — deferred

## Phase 6: Currency + Visual Consistency — COMPLETE
- [x] Modules/Currency.lua
  - Current character gold with colorized display (gold/silver/copper)
  - Session gold change tracking (green positive, red negative)
  - Alt character gold totals (persisted per-character in SavedVariables)
  - Total gold across all characters
  - WoW Token price via C_WowTokenPublic (polled every 60s)
  - Tracked currencies from currency tab (C_CurrencyInfo)
  - Expansion-grouped currency sub-headers (when sorted by list order)
  - Currency icons with quality-colored names
  - Configurable max currencies shown, sort order (list/name/quantity)
  - Label tags: <gold> <session> <token>
  - Left-click: Currency Tab, Right-click: Refresh
  - Events: PLAYER_MONEY, CURRENCY_DISPLAY_UPDATE, TOKEN_MARKET_PRICE_UPDATED
- [x] Visual consistency pass
  - Social modules (Guild, Friends, Communities) updated to match standard tooltip pattern:
    - Backdrop: ChatFrameBackground (was UI-Tooltip-Background)
    - Border: (0.3, 0.3, 0.3, 1) (was 0.6, 0.6, 0.6, 0.8)
    - Edge size: 14 (was 16), insets: 3 (was 4)
    - Added gold title separator line (was missing)
    - Header color: gold (1, 0.82, 0) via SetTextColor
    - Hint bar: CENTER-justified at y=8 (was LEFT at TOOLTIP_PADDING)
    - Hint bar color: (0.53, 0.53, 0.53) explicit
  - MicroMenu and SpecSwitch ROW_HEIGHT: 20 (was 22) to match all other modules

## Phase 7: Character, Speed, Bags, Pets + Currency Enhancements — COMPLETE
- [x] Modules/CharacterInfo.lua
  - Character name, realm, class (class-colored), race, level, item level
  - Faction display (Alliance blue / Horde red)
  - Guild name
  - Shard ID (best-effort via NPC GUID parsing, off by default)
  - Settings: limitations explained for shard ID, opt-in toggle
  - Label tags: <name> <realm> <class> <level> <ilvl> <race> <shard>
  - LClick: Character Panel, RClick: Copy Name-Realm to chat
  - Events: PLAYER_ENTERING_WORLD, PLAYER_LEVEL_UP, PLAYER_AVG_ITEM_LEVEL_UPDATE, UNIT_TARGET
- [x] Modules/MovementSpeed.lua
  - Current/base speed as percentage (base 7 yd/s = 100%)
  - Ground, flying, swimming, skyriding (C_PlayerInfo.GetGlidingInfo) speeds
  - Active speed buff detection from known spell list (consumables, enchants, items, class, food)
  - Common speed source reference in tooltip (potions, enchants, gunshoes, food, class abilities)
  - Configurable update interval dropdown (0.05s-1s) for CPU impact control
  - Label tags: <speed> <run> <fly> <swim> <mode>
  - Events: UNIT_AURA + OnUpdate at configurable interval
- [x] Modules/BagValue.lua
  - Total estimated bag value using TSM price source (6 sources: dbmarket, dbminbuyout, etc.)
  - Vendor value fallback when TSM not loaded
  - Top items breakdown with icons, quantities, individual values
  - Free/total bag slot display with color-coded warnings
  - Debounced scanning (0.5s) on BAG_UPDATE
  - Settings: TSM source dropdown, item count, sort order (value/name/quantity)
  - Future: Auctionator, Auctioneer, Oribos Exchange support planned
  - Label tags: <value> <vendor> <free> <total> <used>
  - LClick: Toggle Bags, RClick: Rescan
- [x] Modules/PetInfo.lua
  - Pet Journal unlock status (C_PetJournal.IsJournalUnlocked)
  - Battle capability (C_PetJournal.IsFindBattleEnabled)
  - Find Battle queue status
  - Collection stats: owned/total with %, level 25 count, rare quality count, favorites
  - Locked journal explanation for restricted accounts
  - Label tags: <status> <owned> <total> <maxlevel>
  - LClick: Open Pet Journal
  - Events: PET_JOURNAL_LIST_UPDATE, COMPANION_UPDATE, NEW_PET_ADDED
- [x] Currency module enhancements
  - Warband bank gold (C_Bank.FetchDepositedMoney, works anytime)
  - Warband access status (C_PlayerInfo.HasAccountInventoryLock / IsAccountBankEnabled)
  - Posted auctions count + value (scanned at AH, cached when away)
  - Auction post hooks (C_AuctionHouse.PostCommodity/PostItem)
  - Staleness indicator ("last scanned: 2h ago")
  - New label tags: <warbank> <auctions>
- [x] SavedInstances: RClick opens Great Vault (loads Blizzard_WeeklyRewards, toggles WeeklyRewardsFrame)

## Deprioritised
- Durability — EnhanceQoL is sufficient

## Architecture Reference
### Source / Inspirational Projects
- DjinnisGuildFriends — Original social module codebase (LDB, namespace, tooltip, settings patterns)
- ElvUI — DataText patterns, tooltip conventions, feature parity target
- Shadow & Light (ElvUI plugin) — Extended DataText ideas
- WindTools (ElvUI plugin) — Additional DataText modules
- EnhanceQoL — System/performance DataText patterns
- SavedInstances addon — Alt lockout data integration (reads SavedInstancesDB)
- TradeSkillMaster — Bag value pricing API (TSM_API)
- GoblinToolbox — Warband bank access detection patterns
- LDB prefix: DDT-
- SavedVariables: DjinnisDataTextsDB
- Slash: /ddt
- Tooltip: dark bg (0.05, 0.05, 0.05, 0.92), gold headers, class-colored names, gray hint bar
- Font system: DDTFontHeader/DDTFontNormal/DDTFontSmall (global, configurable in General settings)

## Phase 8: Configurable Click Actions + Account Status + Enhancements — COMPLETE
- [x] Configurable click actions for all 17 modules
  - Every module: OpenDDT Settings available as click action
  - Social modules: opensettings added to ns.ACTION_VALUES
  - Standalone modules: per-module CLICK_ACTIONS table + DDT:BuildHintText(actions, labels)
  - New: ns.AddModuleClickActionsSection() settings helper
- [x] SystemPerformance: CPU profiler support
  - Uses scriptProfile CVar + GetAddOnCPUUsage/ResetCPUUsage
  - Toggleable via showCpuUsage setting
  - "Enable via /console scriptProfile 1" instructions in tooltip when disabled
  - Game Menu added as click action option
- [x] BagValue enhancements
  - Added DBRecent TSM price source
  - Fixed Unicode arrow artifacts in dropdown labels (replaced with >)
- [x] PetInfo enhancements
  - 8 click actions: openjournal, randomsummon, revive, bandage, safarihat, pettreat, randomteam, opensettings
  - New label tags: <rare> <favorites> <journal> <battles>
- [x] MovementSpeed enhancements
  - Shopping click actions: enchants, food, potions, gear (Midnight-era items)
  - Auctionator shopping list creation or TSM search string copy
- [x] AccountStatus module (NEW)
  - Warband bank access indicator (feature enabled + inventory lock status)
  - Pet journal unlock + battle capability indicator
  - Designed for multibox setups (at-a-glance shared resource access)
  - Label tags: <warbank> <journal> <wbstatus> <petstatus>
- [x] Unicode arrow fix across all modules (SavedInstances, Currency, BagValue, SystemPerformance)
- [x] AddLabelEditBox widget with clickable tag-insert buttons in settings panels
- [x] Alphabetical sort for settings subcategories (social + standalone modules)
- [x] Currency: Track Currencies click action (opens backpack)
- [x] LFGStatus module (NEW)
  - Tracks LFG queue status: Dungeon Finder, Raid Finder, Scenarios
  - Premade group applications with role, group name, activity, status
  - Active listed group with applicant count
  - Live wait time / elapsed counters via OnUpdate
  - Dynamic icon based on queue state (idle/queued/proposal/applied/listed)
  - Label tags: <status> <queues> <apps> <role> <wait> <elapsed>
  - LClick: Group Finder, RClick: Open Settings
  - Events: LFG_UPDATE, LFG_QUEUE_STATUS_UPDATE, LFG_PROPOSAL_*, LFG_LIST_*
- [x] README.md with full module documentation
- [x] ARTWORK_PROMPTS.md with logo/banner generation prompts

## Phase 9: Settings UI Refactor — COMPLETE
- [x] Collapsible sections infrastructure
  - AddSection/EndSection functions with anchor-chain frame support
  - Section headers with +/- toggle indicators
  - Automatic height recalculation when sections collapse/expand
  - RecalcHeight() method on scroll panels to sum all section heights
- [x] Space-efficient widgets
  - AddCheckboxPair: Two checkboxes side-by-side (x=14, x=270)
  - AddSliderPair: Two compact sliders (155px each) with spec table API
- [x] Converted all 17 Settings.lua builder functions to section-based layout
  - General panel: 2 sections (Number Formatting collapsed, Tooltip Font expanded)
  - Friends/Guild/Communities: 6 sections (Label Template, Tooltip collapsed, Display, Grouping & Sorting, Click Actions collapsed, Social Settings collapsed)
  - Currency, BagValue, SavedInstances, etc.: 5-8 sections with paired widgets
- [x] Visual improvements
  - Organized logical groupings (Label Template, Display, Tooltip, Click Actions, etc.)
  - Collapsed tooltip and click action sections by default
  - Two-column layouts for efficient space usage
  - Better visual hierarchy with section headers
- [x] Bug fixes
  - Fixed SetBackdrop nil errors in Currency and BagValue row frames (BackdropTemplate)

## Current State
Phase 9 complete. Addon has 19 modules with refactored settings UI:
- Guild, Friends, Communities (ported from DGF, visuals standardized)
- SpecSwitch (talent/loadout/loot spec switching)
- SavedInstances (lockout summary, boss details, M+ runs, Great Vault click, alt integration)
- TimeDate (server/local time, reset countdowns, calendar events, configurable datetime format)
- Coordinates (player map coordinates with zone info)
- SystemPerformance (FPS, latency, addon memory, CPU profiler)
- PlayedTime (session timer, total/level played)
- Mail (unread mail indicator, mailbox contents)
- MicroMenu (quick-access game panel launcher)
- Experience (XP progress, XP/hr, quest XP, time-to-level, rested XP, watched reputation)
- Currency (gold, alt totals, warband bank, WoW Token, posted auctions, tracked currencies)
- CharacterInfo (name, realm, class, race, level, ilvl, shard ID)
- MovementSpeed (current/base %, swim/fly/glide, speed buffs, shopping actions)
- BagValue (TSM-priced bag contents, vendor fallback, top items, free slots)
- PetInfo (journal unlock, battle capability, collection stats, pet actions)
- AccountStatus (warband bank + pet journal access for multiboxers)
- LFGStatus (queue tracking, premade applications, roles, wait times)
All modules use unified DDT font system (configurable face/size in General settings).
All modules have configurable label templates, tooltip sizing, sort order, and settings panels.
All modules have configurable click actions with "Open DDT Settings" available everywhere.
All modules share consistent tooltip visual pattern (backdrop, border, separator, hint bar).

## Blockers
None.
