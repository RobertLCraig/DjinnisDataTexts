# Release Notes

## Version: 0.9.4

### Major Update: ActiveActivity Aggregator, Combat and Secret Safety Pass, Delve Tier 11+ Support

This release consolidates three beta iterations (0.9.0-beta, 0.9.1-beta, 0.9.2-beta) into a single stable release.

#### ActiveActivity (New)

Unified LDB broker that routes hover, click, and label updates to whichever sub-tracker is currently engaged. Sub-trackers register via `RegisterActivityTracker` API rather than owning their own brokers.

- **Delve** and **Prey Tracker** now register as sub-trackers and notify on label change
- Idle-state click actions configurable independently of active-tracker click actions
- Single data broker replaces multiple empty brokers when no activity is active

#### Secret API Safety (Midnight hardening)

Every module that reads identity, aura, or cooldown data is now guarded against Midnight-era secret return values.

- **Guild / Communities** — `C_Club.GetClubMembers` secret-table crashes fixed. `C_Secrets.ShouldUnitIdentityBeSecret("player")` predicate fast-path plus `pcall` backstop around the member iteration (the predicate does not always pair perfectly with this API's secrecy state on tooltip-hover paths). Fallback to `GetGuildInfo("player")` for guild name.
- **Movement Speed / Delve / Professions** — Aura reads guarded with `C_Secrets.ShouldAurasBeSecret()`.
- **Pet Info / Professions** — Cooldown reads guarded with `C_Secrets.ShouldCooldownsBeSecret()`.
- **Core.ExpandTag** — `pcall` around `tostring`/`gsub` so secret label values degrade gracefully to `?` instead of erroring the entire label.

#### Combat Safety

Audit pass on protected frame operations. Protected calls (`SetAttribute`, `RegisterForClicks`) now gated behind `InCombatLockdown()` checks with `PLAYER_REGEN_ENABLED` deferral.

#### Delve

- **Tier 11+ Sanctified Banner detection** — Newer delve variants (Atal'Aman and later) grant no player aura on banner click, so detection now matches the on-screen "Sanctified Spoils Will Manifest Upon Delve Completion" notification across `UI_INFO_MESSAGE`, `CHAT_MSG_RAID_BOSS_EMOTE`, `CHAT_MSG_MONSTER_EMOTE`, `CHAT_MSG_MONSTER_YELL`, and `CHAT_MSG_SYSTEM`.
- **`/ddtdelve watch`** — New diagnostic command. Live aura-diff monitor that prints gained/lost player auras on every `UNIT_AURA` fire. Used for identifying aura signals on future delve variants.

#### Other Fixes

- **VolumeControl** — `OnMouseWheel` now hooked on the display frame in `OnEnter` (display addons like ElvUI do not wire up `dataobj.OnMouseWheel`).
- **SavedInstances / AudioOutput** — Non-ASCII glyphs replaced with ASCII equivalents so WoW's default font renders them.
- **Professions** — Catch-up currency row rendered in KP section; Wild Perception buff tracker gains `name` field.
- **ActiveActivity** — Registration key normalized from `activeactivity` to `ActiveActivity` to match the canonical module name.
