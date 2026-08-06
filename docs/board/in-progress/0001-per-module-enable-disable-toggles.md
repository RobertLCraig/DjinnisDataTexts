# Per-module enable/disable toggles and per-module refresh control

## Why
Every module creates its LDB broker at file load and every module with an `UpdateData`
method is refreshed by the single 180s ticker in `Core.lua`, whether or not any display
is showing it. Users who run a handful of modules are paying for all of them. At least
one has resorted to commenting modules out of the `.toc` by hand and re-doing it after
every update.

The full design is already worked out and the scope is locked:
[docs/build/PLAN-module-toggles.md](../../build/PLAN-module-toggles.md). Read it before
starting; it records why brokers must be deferred (LDB has no unregister, and a module
cannot know it is disabled at file-load time because saved variables do not exist yet).

## Not this card
- Live enable/disable without a reload. Changes apply on `/reload`, as the plan locked.
- Per-profession toggles. Professions gets one toggle covering the framework.
- Mirroring the Enabled checkbox onto each module's own settings subcategory.
- Any attempt to detect whether a broker is actually visible in the display addon.
  LDB exposes no such signal and it is not derivable; the poll setting is the approximation.
- New modules (Achievements, Quest Log) are cards 0003 and 0004, not this one.

## Acceptance
<!-- AC:BEGIN -->
- [ ] #1 WHEN a module is disabled and the UI is reloaded, THE APP SHALL NOT register that
      module's LDB broker, so it disappears from the display addon's picker entirely.
- [ ] #2 WHEN a module is disabled, THE APP SHALL NOT call its `Init` or `UpdateData`,
      so it performs no periodic work.
- [ ] #3 WHEN a module's poll interval is set to "Events only", THE APP SHALL exclude it
      from the periodic scheduler while leaving its event registrations and its
      on-hover tooltip data intact.
- [ ] #4 WHEN a user upgrades from a version without this feature, THE APP SHALL treat
      every module as enabled at the default 180s interval, so nothing disappears.
- [ ] #5 WHEN a module's or the global "Reset to Defaults" is used, THE APP SHALL leave
      enable state and poll intervals untouched.
- [ ] #6 WHEN a disabled module is re-enabled and the UI reloaded, THE APP SHALL restore
      its broker and its previously saved settings.
- [ ] #7 WHEN the periodic scheduler runs, THE APP SHALL refresh at most one due module
      per tick rather than queueing every module in one burst.
- [ ] #8 IF a feeder module (PreyTracker, Delve) or the ActiveActivity aggregator is
      disabled while the other is enabled, THEN THE APP SHALL degrade quietly and raise
      no Lua error.
<!-- AC:END -->

## Tasks
- [ ] `Core.lua`: `ns.db.modules = { [key] = { enabled, poll } }`, stored outside per-module
      settings so resets cannot clear it. Helpers `ns:IsModuleEnabled(key)` (default true)
      and `ns:GetModulePoll(key)` (default 180).
- [ ] `Core.lua`: `ns:NewBroker(key, name, spec)` queues `{key, name, spec}` on
      `ns.pendingBrokers` and returns `spec` unchanged, so each module's `dataobj` upvalue
      keeps working. The plan verified identity is preserved: `LDB:NewDataObject` mutates
      and returns that same table.
- [ ] `Core.lua`: in `ADDON_LOADED`, after the db is ready and before Init, create brokers
      for enabled modules only. Gate the Init loop on `ns:IsModuleEnabled(key)`.
- [ ] `Core.lua`: replace `C_Timer.NewTicker(180, RefreshAllModules)` with a 1s driver that
      refreshes at most one due module per tick, honouring each module's interval.
- [ ] ~23 module files: swap `LDB:NewDataObject("DDT-X", {...})` for
      `ns:NewBroker("xkey", "DDT-X", {...})`. Mechanical, one line each.
- [ ] ActiveActivity / PreyTracker / Delve: inspect rather than mechanically edit. The two
      feeders push a plain-table dataobj into the aggregator's combined broker; confirm a
      disabled feeder or aggregator no-ops instead of erroring, and add guards if not.
- [ ] Professions: no broker line to change (brokers are created in Init). One toggle,
      handled by gating Init and refresh.
- [ ] `Settings.lua`: a "Modules" panel registered before the alphabetical loop so it sits
      first. Scrollable list, per row an Enabled checkbox and a poll dropdown
      (180s default / 30s / 60s / 5m / 10m / Events only). Top note that changes apply
      after a reload, a Reload UI button, Enable All / Disable All, pending indicator.
- [ ] Bump `.toc` to 0.10.0 and write CHANGELOG / RELEASE_NOTES / CURSEFORGE entries.
      Rob drives the actual release.
- [ ] Verify in game: `deploy.ps1`, `/reload`, disable a module and confirm the broker is
      gone from the display addon's list and stops refreshing; set another to Events only
      and confirm hover still shows live data; re-enable and confirm it returns.

## Direction
**2026-06-23** Scope locked to toggles plus poll control, applied on reload rather than live.
Matches the existing edit-the-toc-and-reload workflow users already have.
