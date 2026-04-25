# Release Notes

## Version: 0.9.8

### Changed

- **TOC Interface bumped to `120005`** for the Midnight 12.0.5 "Lingering Shadows" content update (live 2026-04-21). The addon already carries the Midnight-era safety work from 0.9.3 (`C_Secrets` predicate guards on identity/aura/cooldown reads, `pcall` backstops around `C_Club.GetClubMembers`, combat-lockdown audit on protected frame operations), so no further API migration was required for 12.0.5 itself.

### Fixed

- **"Script ran too long" watchdog on periodic refresh.** `RefreshAllModules()` previously called every module's `UpdateData` in a single execution block, which could trip WoW's long-running-script guard when heavy scanners (Experience walking the quest log, SavedInstances iterating characters, BagValue stepping every bag slot) all fired in the same frame. Refresh now queues the modules and processes one per frame via `C_Timer.After(0, ...)`.
- **Movement Speed crashing on secret-tainted `GetUnitSpeed` returns.** Under Midnight 12.0.5, `GetUnitSpeed("player")` can return secret number values when `C_Secrets.ShouldUnitStatsBeSecret()` is true; arithmetic on those values errored out under tainted execution and spammed `OnUpdate` with hundreds of identical errors. Speed reads are now gated by the predicate and wrapped in `pcall` as a backstop, with previously cached values preserved when a read is refused.
- **Delve Sanctified scan crashing on secret-tainted strings.** `ScanStringsForSanctified` called `:lower():find("sanctified")` directly on every string in scanned tables; if any string came from a secret-tainted source the operation would error out and abort the scan. The string check is now wrapped in `pcall` so tainted entries are skipped without breaking detection.
