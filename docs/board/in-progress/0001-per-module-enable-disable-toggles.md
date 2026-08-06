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
- [x] `Core.lua`: `ns.db.modules = { [key] = { enabled, poll } }`, stored outside per-module
      settings so resets cannot clear it. Helpers `ns:IsModuleEnabled(key)` (default true)
      and `ns:GetModulePoll(key)` (default 180).
- [x] `Core.lua`: `ns:NewBroker(key, name, spec)` queues `{key, name, spec}` on
      `ns.pendingBrokers` and returns `spec` unchanged, so each module's `dataobj` upvalue
      keeps working. The plan verified identity is preserved: `LDB:NewDataObject` mutates
      and returns that same table.
- [x] `Core.lua`: in `ADDON_LOADED`, after the db is ready and before Init, create brokers
      for enabled modules only. Gate the Init loop on `ns:IsModuleEnabled(key)`.
- [x] `Core.lua`: replace `C_Timer.NewTicker(180, RefreshAllModules)` with a 1s driver that
      refreshes at most one due module per tick, honouring each module's interval.
- [x] ~23 module files: swap `LDB:NewDataObject("DDT-X", {...})` for
      `ns:NewBroker("xkey", "DDT-X", {...})`. Mechanical, one line each.
- [x] ActiveActivity / PreyTracker / Delve: inspect rather than mechanically edit. The two
      feeders push a plain-table dataobj into the aggregator's combined broker; confirm a
      disabled feeder or aggregator no-ops instead of erroring, and add guards if not.
- [x] Professions: no broker line to change (brokers are created in Init). One toggle,
      handled by gating Init and refresh.
- [x] `Settings.lua`: a "Modules" panel registered before the alphabetical loop so it sits
      first. Scrollable list, per row an Enabled checkbox and a poll dropdown
      (180s default / 30s / 60s / 5m / 10m / Events only). Top note that changes apply
      after a reload, a Reload UI button, Enable All / Disable All, pending indicator.
- [~] CHANGELOG and CURSEFORGE entries written. **`.toc` and RELEASE_NOTES left
      alone deliberately**: `release.ps1` derives the `.toc` version from the
      `## Version:` line in RELEASE_NOTES.md and auto-corrects any mismatch, so
      hand-bumping the `.toc` to 0.10.0 while RELEASE_NOTES still reads 0.9.12
      would be silently reverted at release time. RELEASE_NOTES is also still
      holding the already-shipped 0.9.12 notes, and composing the next release
      (which version, and whether the unreleased 12.1 work ships with it) is
      Rob's call, not this card's. Notes are in CHANGELOG `[Unreleased]`.
- [ ] **Not done: verify in game.** `deploy.ps1`, `/reload`, disable a module and
      confirm the broker is gone from the display addon's list and stops
      refreshing; set another to Events only and confirm hover still shows live
      data; re-enable and confirm it returns. This is the acceptance evidence
      that cannot be produced outside the game client.

## Verification so far

- `luac -p` parses every Lua file in the addon cleanly. Note this is Lua 5.4 and
  WoW runs 5.1, so it proves syntax, not runtime compatibility.
- A throwaway harness loaded the real `Core.lua` against a stubbed WoW API and
  ran 30 checks, all passing, covering acceptance 1 to 7: no broker and no
  `Init` for a disabled module, per-module intervals honoured, "Events only"
  never polling, at most one refresh per tick, defaults preserved on upgrade,
  both resets leaving toggles alone, and a re-enabled module getting its broker
  and its saved settings back. The harness is not committed; it stubs enough of
  the WoW API to load one file and is not a test suite.
- Acceptance 8 (aggregator trio) was verified by reading rather than running:
  `RegisterActivityTracker` and `NotifyActivityChange` are both defined at file
  scope in ActiveActivity.lua, so they exist even when that module is disabled,
  both feeder call sites are guarded with `if ns.X then`, and both bodies are
  gated on `_initialized`, which only `Init` sets.
- **Nothing has been run in the game client.** The Settings panel is entirely
  unexercised: no frame in it has ever been constructed. Treat the whole
  Modules panel as unverified until someone loads it.

## Direction
**2026-06-23** Scope locked to toggles plus poll control, applied on reload rather than live.
Matches the existing edit-the-toc-and-reload workflow users already have.
