# Release Notes

## Version: 0.3.2

### Separated Label & Row Click Actions, API Fixes

#### Social Module Click Actions (Friends, Guild, Communities)
- **Separate label vs row clicks** - Click actions now split into two configurable sections:
  - **Label Click Actions** (clicking the DataText) - Open respective panel list, or DDT Settings (new configurable section)
  - **Row Click Actions** (clicking a player in tooltip) - Whisper, invite, copy name, etc. (new configurable section)
- **Improved defaults** - Left-click the label now opens Friends/Guild/Communities directly (was Shift+Click only)

#### Bug Fixes
- **MovementSpeed aura scanning** - Fixed Midnight API incompatibility by switching from `C_UnitAuras.GetAuraDataByIndex` (protected spellId field) to `C_UnitAuras.GetPlayerAuraBySpellID` for known speed buffs

---

**Previous Versions:**
See CHANGELOG.md for 0.3.1-beta and earlier releases.
