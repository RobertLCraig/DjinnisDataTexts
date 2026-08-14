# Release Notes

<!--
  This file is the pending release. The version heading below is what release.ps1
  reads to name the tag and rewrite the .toc, and everything under it is copied
  verbatim into CHANGELOG.md when the release runs.

  AFTER RELEASING: clear the body and set the next version. Skipping that step is
  what left 0.9.12's notes sitting here through the whole 0.9.13 cycle.

  Do NOT write a version heading inside a comment like this one. release.ps1 reads
  the version with a plain regex BEFORE it strips comments, so the first match in
  the file wins even when it is commented out, and the release takes its name from
  whatever that match captures.

  Comments are stripped from the published notes, so prose here is otherwise safe.
-->

## Version: 0.9.13

### Added

- **Per-module enable/disable toggles.** A new **Modules** panel, first in the DDT settings list, has an Enabled checkbox for every module plus Enable All / Disable All. A disabled module registers no LDB DataText at all, so it disappears from your display addon's list entirely and runs no code: no `Init`, no event registrations, no refreshes. This is the same effect as commenting a module out of the `.toc`, without editing files after every update. Enabling or disabling takes effect on UI reload; the panel shows a "changes pending" note and a Reload UI button. Every module defaults to enabled, so upgrading changes nothing.
- **Per-module refresh intervals.** Each module that refreshes on a timer can be set to 30 seconds, 1 minute, 3 minutes (the previous fixed value, still the default), 5 minutes, 10 minutes, or **Events only**. "Events only" stops timed refreshes completely: the module still updates when the game reports a change, and its tooltip is always built fresh on hover. Interval changes apply immediately, without a reload. Modules that keep their own clock (Time / Date, Coordinates, Played Time) or are purely event-driven are shown as "updates on its own" rather than being offered an interval they never used.
- **World of Warcraft 12.1.0 support.** The `## Interface:` line declares `120100`, so the addon loads without an "out of date" flag on 12.1.0. A full audit of the addon's API surface against the 12.1.0 client source found nothing it calls was removed or resignatured.
- **Pet Info Safari Hat "Equipped" state.** The Equip Safari Hat action now detects the Safari Hat buff (spell 158486) via `C_UnitAuras.GetPlayerAuraBySpellID` and shows a green "Equipped" status with a desaturated icon while the hat is active. Guarded by `C_Secrets.ShouldAurasBeSecret`; the row still re-applies the toy/bag item on click.

### Fixed

- **Pet Info Revive Battle Pets / Equip Safari Hat / consumable buttons did nothing for players with "cast on key down" enabled.** The secure action buttons registered only `"AnyUp"`, but Blizzard's `SecureActionButton_OnClick` performs the protected action on just one click edge chosen by the `ActionButtonUseKeyDown` CVar — so with cast-on-key-down on, an up-only registration never fired (the non-secure Open Journal / Summon buttons kept working because they bypass the secure handler). Secure buttons now register both `"AnyUp"` and `"AnyDown"`, matching the working Professions / Majestic Beast lure buttons; Blizzard's own `clickAction` gate guarantees exactly one edge fires, so there is no double-cast. Non-secure buttons stay `"AnyUp"`-only.
- **Four latent crashes in the Professions tooltip.** Four spell-icon lookups read `C_Spell.GetSpellTexture(id) or GetSpellTexture(id)`, with a comment calling the fallback dead. It was not: the bare `GetSpellTexture` global was removed in 11.0 and never shimmed, so any spell that returned no texture would have called a nil value and thrown. The fallbacks are gone and the lookups go straight to `C_Spell`. `C_SpellBook.IsSpellKnown` now gets its documented `spellBank` argument at both call sites, which is what the removed fallback had been supplying.

### Changed

- **The download no longer contains files the addon does not use.** `CURSEFORGE.md`, `.gitattributes`, the demo-data injector and the retired Majestic Beast module were being packaged despite none of them being loaded by the `.toc`. The addon now ships as 54 files: the `.toc`, `Core.lua`, `Settings.lua`, the fonts, the vendored libraries and the modules. Nothing that loads has been removed.
- **Deprecated Blizzard globals migrated to their `C_` namespaces.** `BNInviteFriend`, `SendChatMessage`, `IsEquippedItem`, `GetSpecialization` and `GetSpecializationInfo` now go through `C_BattleNet.InviteFriend`, `C_ChatInfo.SendChatMessage`, `C_Item.IsEquippedItem` and `C_SpecializationInfo.*`. Blizzard still defines the old names, but only inside deprecation shims gated behind the `loadDeprecationFallbacks` CVar, so they are nil for anyone who has that setting off — the Battle.net invite, the coordinates chat announce, the Safari Hat equipped check and the SimC export string were all one CVar away from erroring.
- **Refresh scheduling now spreads modules out instead of bursting.** The single 180-second ticker that refreshed every module in one pass has been replaced by a 1-second driver that refreshes at most one due module per tick, honouring each module's own interval. Modules that fall due together are served one per second and then re-scheduled from when they actually ran, so they spread out on their own; the longest-overdue module always goes first, so none can be starved. This removes the periodic spike where every module's `UpdateData` landed on the same frame.
- **Wider default tooltip widths** so English content no longer collides with the right-aligned values: Pet Info 300→340, Played Time 280→340, Movement Speed 320→380. A one-time, version-gated saved-variables migration raises any saved width still sitting at the old default to the new value; widths the user has customized are left untouched.
