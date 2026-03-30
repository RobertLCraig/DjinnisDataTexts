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
  - Alt lockouts from SavedInstances addon DB (if present)
  - Alt sorting: max-level first, then alphabetical
  - LDB text: "Lockouts: 2R 1D" format
  - Events: UPDATE_INSTANCE_INFO, BOSS_KILL, INSTANCE_LOCK_START/STOP

## Phase 3: Time/Date + Coordinates — PENDING
- [ ] Modules/TimeDate.lua (Phase 1)
  - Server time, local time
  - Weekly reset countdown
  - Basic Djinni tooltip
- [ ] Modules/Coordinates.lua

## Phase 4: System + Played + Mail — PENDING
- [ ] Modules/SystemPerformance.lua
- [ ] Modules/PlayedTime.lua
- [ ] Modules/Mail.lua

## Phase 5: Micro Menu + XP/Rep + Time Phases 2-3 — PENDING
- [ ] Modules/MicroMenu.lua
- [ ] Modules/Experience.lua
- [ ] TimeDate Phase 2 (calendar events, holidays)
- [ ] TimeDate Phase 3 (multi-timezone)

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
Phase 2 complete. Addon has 5 modules:
- Guild, Friends, Communities (ported from DGF)
- SpecSwitch (new — talent/loadout/loot spec switching)
- SavedInstances (new — lockout summary with boss details and alt integration)
Ready to begin Phase 3 (Time/Date, Coordinates).

## Blockers
None.
