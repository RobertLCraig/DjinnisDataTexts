# Release Notes

## Version: 0.9.11

### Fixed

- **`ADDON_ACTION_BLOCKED` on profession tooltip auto-hide in combat.** The Professions tooltip parents `SecureActionButtonTemplate` lure buttons; when the auto-hide timer fired during combat, `tooltipFrames[profKey]:Hide()` cascaded to the secure children and tripped `Frame:Hide()` is protected. The hide timer now checks `InCombatLockdown()` and reschedules itself until combat ends. Same combat guard applied preventatively to the matching `Show()` paths in `ShowTooltip` and `TogglePin`, and to the equivalent code in the Majestic Beast Tracker module (which parents the same secure lure / consumable buttons).
- **Guild tooltip crash on secret-tainted MOTD.** Caching `clubInfo.broadcast` into `self.motdCache` does not launder the Midnight-era taint that rides the value, so subsequent operations on the cached MOTD errored with `attempt to compare a secret string value` (the `motd ~= ""` test) and `attempt to perform arithmetic on a secret number value` (`GetStringHeight() + 4` on a fontstring whose text was set from the tainted string). There is no `C_Secrets.Should*` predicate covering guild MOTD specifically, so the entire MOTD render block (compare, SetText, GetStringHeight) is now wrapped in a single `pcall`; on failure, the MOTD line clears and hides cleanly. Matches the existing `Modules/Delve.lua` Sanctified-string pattern.
