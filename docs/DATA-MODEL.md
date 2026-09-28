# Data model: Djinni's Data Texts (DDT)

_Last updated: 2026-08-29_

The single source of truth for this project's data shape. `Core.lua` implements it; this
document describes it. Anywhere the code and this doc disagree, the code is right and this doc
is the bug. But see [Known divergences](#known-divergences) for the places where the code is
knowingly inconsistent with itself.

There is exactly one saved variable, declared in `DjinnisDataTexts.toc`:

```
## SavedVariables: DjinnisDataTextsDB
```

It is **account-wide and flat**. There are no profiles, no per-character database and no
per-spec layer. Anything that needs to be per-character is a table keyed by a character key
*inside* the one database (see [Character-keyed tables](#character-keyed-tables)).

## Top-level shape

```lua
DjinnisDataTextsDB = {
    global        = { ... },   -- cross-module settings (fonts, numbers, gold, URLs)
    modules       = { ... },   -- per-module enable flag and poll interval
    [moduleKey]   = { ... },   -- one table per registered module, keyed by registration key
    altLockouts   = { ... },   -- SavedInstances: one entry per character ever seen
    delveHistory  = { ... },   -- SavedInstances: this week's delve runs, per character
    _migratedFromDGF = bool,   -- set once, after DjinnisGuildFriends settings are pulled in
    _schemaVersion   = int,    -- migration stamp; a fresh DB starts at 0
}
```

Three of those tables come from three different places, and the difference matters:

| Table | Created by | Reset by "Reset to Defaults"? |
|-------|-----------|-------------------------------|
| `global`, `[moduleKey]` | `MergeDefaults` from `ns.defaults` at `ADDON_LOADED` | Yes, per key |
| `modules` | On demand by `ModuleState()` ([Core.lua:247](../Core.lua#L247)) | **No, deliberately** |
| `altLockouts`, `delveHistory` | On demand by `Modules/SavedInstances.lua` | No: nothing declares them as defaults |

### `global`

Cross-module settings. Declared in `ns.defaults.global` ([Core.lua:38](../Core.lua#L38)).

| Field | Type | Default | Notes |
|-------|------|---------|-------|
| `tooltipFont` | string | `Fonts\FRIZQT__.TTF` | Font file path, applied to all three shared font objects |
| `tooltipFontSize` | number | `12` | Points; header and small sizes derive from it |
| `customUrl1` | string | `""` | User URL template for the "Copy Custom URL 1" click action |
| `customUrl2` | string | `""` | As above, slot 2 |
| `tagSeparator` | string | `"#"` | Character that marks a `#tag` inside a friend / guild note |
| `noteShowInAllGroups` | boolean | `true` | Whether a tagged member appears under every tag group |
| `numberFormat` | string | `"us_short"` | Locale preset id; `"custom"` means use the three fields below |
| `numberSep` | string | `","` | Thousands separator |
| `numberDec` | string | `"."` | Decimal point |
| `numberAbbr` | boolean | `true` | Abbreviate to k / m / b rather than printing in full |
| `goldColorize` | boolean | `true` | Colour gold / silver / copper amounts |
| `goldShowSilver` | boolean | `true` | Include the silver component |
| `goldShowCopper` | boolean | `true` | Include the copper component |

### `modules`

`DjinnisDataTextsDB.modules[moduleKey] = { enabled = bool, poll = number|false }`

| Field | Type | Nullable | Notes |
|-------|------|----------|-------|
| `enabled` | boolean | yes | Absent means **on**. The check is `enabled ~= false`, so upgrading from a version without toggles leaves every module where the user had it. |
| `poll` | number \| `false` | yes | Seconds between periodic refreshes. Absent means `ns.DEFAULT_POLL` = **180**. `false` means "events only", no timed refresh at all. Offered values: 30, 60, 180, 300, 600, `false`. |

**This table sits outside each module's own settings table on purpose.** Neither the
per-module nor the global "Reset to Defaults" can reach it, so a reset cannot silently
re-enable a module the user turned off or change how often it polls
([Core.lua:217](../Core.lua#L217)). `modules` is safe as a sibling of the per-module tables
only because no module registers under that key.

### Per-module tables

One table per module, keyed by the key that module passed to
`ns:RegisterModule(key, mod, defaults)` ([Core.lua:210](../Core.lua#L210)). The module's
`DEFAULTS` table becomes `ns.defaults[key]`, and `MergeDefaults` copies anything missing from
it into `DjinnisDataTextsDB[key]` at load.

Field names vary by module, but nearly every module shares this core:

| Field | Type | Notes |
|-------|------|-------|
| `labelTemplate` | string | The DataText label, in `<tag>` syntax. Tags are module-specific. |
| `tooltipWidth` | number | Pixels, up to 2000 |
| `tooltipScale` | number | Multiplier, typically `1.0` |
| `tooltipMaxHeight` | number | Pixels; above this the tooltip scrolls |
| `sortBy` / `sortAscending` | string / boolean | List-based modules only; keys into `ns.SORT_FUNCTIONS` |
| `clickActions` | table | Nine fixed slots: `leftClick`, `rightClick`, `middleClick`, `shiftLeftClick`, `shiftRightClick`, `ctrlLeftClick`, `ctrlRightClick`, `altLeftClick`, `altRightClick`. Values are action ids, `"none"` for unbound. |

### Module key map

The registration key is what names the saved table, so **a key is a public interface**:
renaming one orphans every existing user's settings for that module. The broker name is a
*second, separate* public interface, because the display addon persists it in its own config.

| Registration key | Source file | Saved table | Broker |
|------------------|-------------|-------------|--------|
| `accountstatus` | `Modules/AccountStatus.lua` | `.accountstatus` | `DDT-AccountStatus` |
| **`ActiveActivity`** | `Modules/ActiveActivity.lua` | **`.ActiveActivity`** | `DDT-ActiveActivity` |
| `audiooutput` | `Modules/AudioOutput.lua` | `.audiooutput` | `DDT-AudioOutput` |
| `bagvalue` | `Modules/BagValue.lua` | `.bagvalue` | `DDT-BagValue` |
| `characterinfo` | `Modules/CharacterInfo.lua` | `.characterinfo` | `DDT-CharacterInfo` |
| `communities` | `Modules/Communities.lua` | `.communities` | `DDT-Communities` |
| `coordinates` | `Modules/Coordinates.lua` | `.coordinates` | `DDT-Coordinates` |
| `currency` | `Modules/Currency.lua` | `.currency` | `DDT-Currency` |
| `delve` | `Modules/Delve.lua` | `.delve` | none: sub-tracker, feeds `ActiveActivity` |
| `experience` | `Modules/Experience.lua` | `.experience` | `DDT-Experience` |
| `friends` | `Modules/Friends.lua` | `.friends` | `DDT-Friends` |
| `guild` | `Modules/Guild.lua` | `.guild` | `DDT-Guild` |
| `itemlevel` | `Modules/ItemLevel.lua` | `.itemlevel` | `DDT-ItemLevel` |
| `lfgstatus` | `Modules/LFGStatus.lua` | `.lfgstatus` | `DDT-LFGStatus` |
| `mail` | `Modules/Mail.lua` | `.mail` | `DDT-Mail` |
| `micromenu` | `Modules/MicroMenu.lua` | `.micromenu` | `DDT-MicroMenu` |
| `movementspeed` | `Modules/MovementSpeed.lua` | `.movementspeed` | `DDT-MovementSpeed` |
| `petinfo` | `Modules/PetInfo.lua` | `.petinfo` | `DDT-PetInfo` |
| `playedtime` | `Modules/PlayedTime.lua` | `.playedtime` | `DDT-PlayedTime` |
| `preytracker` | `Modules/PreyTracker.lua` | `.preytracker` | none: sub-tracker, feeds `ActiveActivity` |
| `professions` | `Modules/Professions/Core.lua` | `.professions` | many, `DDT-Prof-<Name>`, created in `Init` |
| `savedinstances` | `Modules/SavedInstances.lua` | `.savedinstances` | `DDT-SavedInstances` |
| `specswitch` | `Modules/SpecSwitch.lua` | `.specswitch` | `DDT-SpecSwitch` |
| `systemperformance` | `Modules/SystemPerformance.lua` | `.systemperformance` | `DDT-SystemPerformance` |
| `timedate` | `Modules/TimeDate.lua` | `.timedate` | `DDT-TimeDate` |
| `volumecontrol` | `Modules/VolumeControl.lua` | `.volumecontrol` | `DDT-VolumeControl` |
| `majesticbeast` | `Modules/MajesticBeast.lua` | `.majesticbeast` | **retired**: file is commented out of the `.toc`, so it never registers |

`majesticbeast` is listed because its saved table still exists in the databases of anyone who
ran an older build, and `Modules/Professions/Core.lua` still reads it as a migration source.
Nothing writes it any more.

### Character-keyed tables

Per-character data lives in tables keyed by a character key inside the one account-wide
database.

**`altLockouts[key]`**: written by `SavedInst:SaveCurrentCharData()`, one entry per character
that has logged in with DDT installed. Key format: `"Name - Realm"` (spaces around the dash).

| Field | Type | Notes |
|-------|------|-------|
| `name`, `realm` | string | As reported by `UnitName` / `GetRealmName` |
| `class` | string | Upper-case class file token |
| `level` | number | |
| `specName`, `role` | string | `role` is `TANK` / `HEALER` / `DAMAGER`, `""` if unknown |
| `lastSeen` | number | Unix time of the last save. Drives the stale-alt prune. |
| `lockouts` | array | `{ name, difficultyTag, progress, total, reset, isRaid, extended }`, a deliberately lightweight summary, no per-boss detail, to keep SavedVariables small |
| `hasRaids` | boolean | |
| `mythicPlusRuns` | array | `{ name, level, completed }` |
| `mythicPlusCount` | number | |
| `delveRuns` | array | `{ tier, count }` |
| `delveCount` | number | |
| `delveTrackedRuns` | array | Copy of this character's tracked runs |
| `mythicPlusLastActive` | number | Unix time, updated only when M+ runs exist; drives the mplus30/60/90/180 filters |

Entries are pruned by `PruneStaleAltData()`: any character not seen within `altPruneWeeks`
weekly resets is forgotten (setting range 0 to 26, default **3**, `0` = never). A character
still holding an unexpired *extended* raid lockout is kept whatever the setting, and nothing
is pruned at all if the reset time cannot be read. Counted in resets rather than rolling days,
so the cutoff does not drift with the hour the addon happens to run.

**`delveHistory[key]`**: `{ weekStart = number, runs = { { name, tier, timestamp }, ... } }`,
also keyed `"Name - Realm"`. Cleared for the character when `weekStart` falls behind the
current weekly reset.

**`currency._altGold[key]`**: `{ gold = number, class = string, lastSeen = number }`, keyed
`"Name-Realm"` (**no spaces**, see [Known divergences](#known-divergences)).

**`professions.chars[key][profKey][expansion]`**: per-character, per-profession,
per-expansion working data, created lazily. Key format `"Name-Realm"`. Per-profession
*settings* live separately in `professions.perProf[profKey]`, also created lazily, because
most characters have only two professions and pre-creating all eleven would pollute saved
variables for nothing.

### Underscore keys

Two conventions, and they are different things:

- **At the top level**, an underscore key is migration metadata: `_migratedFromDGF` and
  `_schemaVersion`. Nothing else lives there.
- **Inside a module table**, an underscore key is cached runtime data rather than a setting:
  `currency._altGold` and `currency._postedAuctions`
  (`{ count, value, lastScan }`). They are not in `ns.defaults`, so a defaults merge never
  creates them, but a per-module **Reset to Defaults** *does* wipe them, because
  `ResetModuleDefaults` clears every key in the target table before re-merging
  ([Core.lua:391](../Core.lua#L391)).

## Canonical representation

### Load order at `ADDON_LOADED`

The order is load-bearing and is set in `Core.lua`'s init frame
([Core.lua:1591](../Core.lua#L1591)):

1. **Create the DB if absent.** `DjinnisDataTextsDB = {}`.
2. **`MigrateFromDGF()`** ([Core.lua:405](../Core.lua#L405)). If `DjinnisGuildFriendsDB` exists
   and `_migratedFromDGF` is not already set, deep-copy its `friends`, `guild`, `communities`
   and `global` sections across, then set `_migratedFromDGF = true`. Runs once, ever.
3. **`RunSchemaMigrations()`** ([Core.lua:467](../Core.lua#L467)). **Before** the defaults
   merge, so a migration step sees only genuinely saved values and cannot mistake a
   just-merged default for a user's choice.
4. **`MergeDefaults(DjinnisDataTextsDB, ns.defaults)`** ([Core.lua:376](../Core.lua#L376)).
5. `ns.db = DjinnisDataTextsDB`, then fonts, then brokers for enabled modules, then
   `SetupOptions`, then each enabled module's `Init`.

### Defaults merge

`MergeDefaults` is a one-pass recursive merge that **only fills missing keys**. A table in the
defaults recurses; a scalar is written only where `target[k] == nil`. It was chosen over
`CopyTable` + `rawset` because it preserves user-modified values with no diff step.

The rule that falls out of this, and the one to remember:

> **Adding a default needs no migration. Changing a default does.**

A new key is absent from every existing database, so the merge supplies it on next login. An
existing key already has a value, so the merge leaves it alone, including a value the user
never chose, which is why a changed default needs a migration step to move anyone still
sitting on the old one.

### Schema migrations

`SCHEMA_VERSION` ([Core.lua:442](../Core.lua#L442)) is the stamp, stored at
`DjinnisDataTextsDB._schemaVersion`. A fresh database starts at 0, runs every step once, and
is then stamped to the current version and never revisited. **Bump the constant whenever a
step is added.**

It is currently at **2**:

| Version | Date | What it does |
|---------|------|--------------|
| 1 | unrecorded | Raises a saved `tooltipWidth` that still equals the old default to the new one, for `petinfo` (300 → 340), `playedtime` (280 → 340) and `movementspeed` (320 → 380) |
| 2 | 2026-08-20 | Moves `delve.labelTemplate` from `"Delve: <progress>"` to `"<kind>: <progress>"`, because 12.1.0's Lairs report as active delves and the hard-coded prefix mislabelled them |

**Both steps share one shape, and step three should copy it:** rewrite a saved value *only*
when it still equals the known old default. A user who customised the setting keeps their
value; a fresh install carries the new default already, so the `== old` test is a no-op. The
one accepted side effect is that a user who deliberately typed the old value is
indistinguishable from one who never touched it and gets moved too, recoverable through the
per-module Reset to Defaults button.

## Known divergences

Three, and none of them should be "tidied" without reading why first.

1. **`ActiveActivity` is registered CamelCase; every other module key is lowercase.**
   Its saved table is therefore `DjinnisDataTextsDB.ActiveActivity`, not `.activeactivity`.
   **This is a divergence, not the convention**: the convention is lowercase, and this one
   module breaks it.

   Do not rename it without a migration step: the key names the saved table, so renaming it
   orphans every existing user's settings for that module.

   **It has already caused one live bug.** `GetDB()` in `Modules/ActiveActivity.lua` read
   `ns.db.activeactivity`, which is not the key `MergeDefaults` creates, so the lookup always
   missed and fell through to the shared `DEFAULTS` table. Reads therefore ignored saved
   values and writes landed on an in-memory defaults table that is never persisted, which made
   the idle click actions silently unconfigurable and the tracker toggles unsaveable. Fixed in
   0.9.14; the comment above `GetDB` now says to keep the case in step with the registration.

   The whole-codebase check, if a fourth module is ever registered CamelCase: compare each
   file's `RegisterModule("…")` key against the `ns.db.<key>` its `GetDB()` reads.

2. **Two character-key formats coexist.** `SavedInstances` uses `"Name - Realm"` (spaces
   around the dash) for both `altLockouts` and `delveHistory`; `Currency._altGold` and
   `Professions.chars` use `"Name-Realm"` (no spaces). Nothing joins across the two, so
   nothing is currently broken by it, but any future feature that wants to match a character
   across those tables has to normalise first. Neither format is escaped, and realm names can
   contain spaces (`"Djinni - EU Mythic Dungeons"` is a real key from a now-deleted tournament
   realm), so `"Name - Realm"` cannot be split reliably on the dash.

3. **`altLockouts` and `delveHistory` are top-level siblings that no module declares.** They
   are created on demand by `Modules/SavedInstances.lua`, not by `ns.defaults`, so the
   defaults merge never touches them and `ResetModuleDefaults("savedinstances")` does not
   clear them. They are data rather than settings, which is arguably correct, but it means
   "Reset to Defaults" on Saved Instances does less than a user might expect.
