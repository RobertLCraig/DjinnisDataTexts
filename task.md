# DjinnisDataTexts — Task Tracker

## Project Overview
A unified LDB DataText suite for WoW Retail (Interface 120001).
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
  - Icon changes based on mail status
  - Events: UPDATE_PENDING_MAIL, MAIL_SHOW, MAIL_CLOSED, MAIL_INBOX_UPDATE

## Phase 5: Micro Menu + XP/Rep + Time Enhancements — COMPLETE
- [x] Modules/MicroMenu.lua
  - Quick-access clickable rows for all game panels (character, spellbook, talents, achievements, etc.)
  - 12 menu entries with icons, click to open and auto-dismiss tooltip
  - Left-click DataText: Game Menu
- [x] Modules/Experience.lua
  - XP progress with visual bar (purple fill + blue rested overlay)
  - Rested XP display
  - Remaining XP to level
  - At max level: shows watched reputation with standing and progress bar
  - Events: PLAYER_XP_UPDATE, PLAYER_LEVEL_UP, UPDATE_EXHAUSTION, UPDATE_FACTION
- [x] TimeDate Phase 2 (calendar events, holidays)
  - Tooltip shows today's calendar events (holidays, raid resets)
  - C_Calendar.OpenCalendar() on login to populate data
  - CALENDAR_UPDATE_EVENT_LIST event registered
- [ ] TimeDate Phase 3 (multi-timezone) — deferred

## Deprioritised
- Currency/Gold — EnhanceQoL is sufficient; implement later with guild bank, token price, alt gold, expansion-grouped currencies
- Bags/Durability — EnhanceQoL is sufficient

## Architecture Reference
- Primary: DjinnisGuildFriends (LDB, namespace, tooltip, settings patterns)
- Secondary: ElvUI, Shadow & Light, WindTools, EnhanceQoL, SavedInstances
- LDB prefix: DDT-
- SavedVariables: DjinnisDataTextsDB
- Slash: /ddt
- Tooltip: dark bg (0.05, 0.05, 0.05, 0.92), gold headers, class-colored names, gray hint bar

## Current State
Phase 5 complete. Addon has 12 modules:
- Guild, Friends, Communities (ported from DGF)
- SpecSwitch (talent/loadout/loot spec switching)
- SavedInstances (lockout summary with boss details, M+ runs, condensed views, configurable sort order, alt integration)
- TimeDate (server/local time, reset countdowns, calendar events/holidays)
- Coordinates (player map coordinates with zone info)
- SystemPerformance (FPS, latency, addon memory)
- PlayedTime (session timer, total/level played)
- Mail (unread mail indicator, mailbox contents)
- MicroMenu (quick-access game panel launcher)
- Experience (XP progress, rested XP, watched reputation)
All modules have configurable label templates, tooltip sizing, and settings panels.

## Blockers
None.
