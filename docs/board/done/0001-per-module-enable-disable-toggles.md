# Per-module enable/disable toggles and per-module refresh control

## What I need from you

**One session in game, walking three checks. Everything else on this card is done and released.**

1. Disable a module, `/reload`, and confirm it is gone from your display addon's picker.
2. Re-enable it, `/reload`, and confirm it comes back with its old settings.
3. Disable **Active Activity** while leaving Delve enabled, `/reload`, and watch for a Lua error.

---

**On 1 and 2.** This is acceptance 1, 2 and 6, and it is the core promise of the whole card:
a disabled module registers no broker, runs no code, and loses nothing when it comes back.
Pick a module with visible output, Bag Value or Item Level, so the picker change is obvious.

Pass is all four of:
- the DataText disappears from your display addon's list, not merely showing blank
- no Lua error on the reload
- re-enabling brings it back
- its label template, tooltip width and click actions are as you left them

**On 3.** This is acceptance 8, the only one never exercised even in the harness, and it is
the case 0.9.14 changed. Delve and Prey Tracker feed Active Activity rather than owning a
DataText, so their switches now live in Active Activity's panel. You can still turn the
aggregator off while a feeder is on, which is the combination worth poking: the feeder's
`Init` runs and pushes labels at an aggregator that never initialised.

Pass is no Lua error and no stuck DataText. Fail is any error mentioning `ActiveActivity`.

**Why it needs you.** There is no automated verification of behaviour in this project at all,
and the parts a harness can reach were already checked. What is left is frames and reloads,
which only a running client has. The one in-game look so far, at the settings panel on
2026-08-15, found three bugs including a saved-variables key read with the wrong case that
had been shipping silently. These three checks cover code that no static check can reach.

**Fail on any of them:** paste the error here. Everything is released, so a fix is a 0.9.16,
not a revert.

## Why
Every module creates its LDB broker at file load and every module with an `UpdateData`
method is refreshed by the single 180s ticker in `Core.lua`, whether or not any display
is showing it. Users who run a handful of modules are paying for all of them. At least
one has resorted to commenting modules out of the `.toc` by hand and re-doing it after
every update.

## Links

**Relates to**
- `0003` - the Achievements module the same CurseForge user asked for. It is a new
  DataText, so it is out of scope here and scoped on its own card.
- `0004` - the Quest Log module from the same request, out of scope here for the same
  reason as 0003.

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
      module's LDB broker, so it disappears from the display addon's picker entirely. proves: manual
- [x] #2 WHEN a module is disabled, THE APP SHALL NOT call its `Init` or `UpdateData`,
      so it performs no periodic work. (proved offline: the 30-check harness under Verification so far, not committed)
- [x] #3 WHEN a module's poll interval is set to "Events only", THE APP SHALL exclude it
      from the periodic scheduler while leaving its event registrations and its
      on-hover tooltip data intact. (proved offline: the 30-check harness under Verification so far, not committed)
- [x] #4 WHEN a user upgrades from a version without this feature, THE APP SHALL treat
      every module as enabled at the default 180s interval, so nothing disappears. (proved offline: the 30-check harness under Verification so far, not committed)
- [x] #5 WHEN a module's or the global "Reset to Defaults" is used, THE APP SHALL leave
      enable state and poll intervals untouched. (proved offline: the 30-check harness under Verification so far, not committed)
- [ ] #6 WHEN a disabled module is re-enabled and the UI reloaded, THE APP SHALL restore
      its broker and its previously saved settings. proves: manual
- [x] #7 WHEN the periodic scheduler runs, THE APP SHALL refresh at most one due module
      per tick rather than queueing every module in one burst. (proved offline: the 30-check harness under Verification so far, not committed)
- [ ] #8 IF a feeder module (PreyTracker, Delve) or the ActiveActivity aggregator is
      disabled while the other is enabled, THEN THE APP SHALL degrade quietly and raise
      no Lua error. proves: manual
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

## Plan
**Where to stand.** `C:\Dev\WoWAddons\DjinnisDataTexts`, on `master`. The build is shipped in
v0.9.13 and v0.9.14, so nothing here is unbuilt; what a session picks this card up for is a
failed check above.

**The full design is already worked out and the scope is locked:**
[docs/build/PLAN-module-toggles.md](../../build/PLAN-module-toggles.md). Read it before
changing anything; it records why brokers must be deferred (LDB has no unregister, and a
module cannot know it is disabled at file-load time because saved variables do not exist yet).

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

**2026-08-15** The adversarial pass happened, so this card moves to `human-review/`: what is left
is a person in a game client, which no agent can do.

The review was a screenshot of the Modules panel plus an audit of what that panel lists against
what actually owns a broker. It found three bugs, all fixed and released in v0.9.14:

- The panel's two description paragraphs overlapped each other and the button row, because
  `AddDescription` measured wrapped height before the FontString had a width.
- `ActiveActivity` read its saved settings under `activeactivity`, which is not the key it
  registers, so it always fell through to the defaults table. Its idle click actions were saved
  and never read, and its tracker toggles could not persist. **This had been shipping silently.**
- Delve and Prey Tracker were listed here as though disabling them removed a DataText. They own
  no broker. They had a second, separate switch in Active Activity's panel that did something
  different, and the two could disagree into a tracker that scanned and polled while its output
  was discarded.

The last of those changes what acceptance 8 means. Delve and Prey Tracker can no longer be
disabled independently from this panel, so the feeder-off case is gone; the aggregator-off case
remains and is check 3 above.

Also worth recording against the "verification so far" note: this card shipped. v0.9.13 and
v0.9.14 are on CurseForge, so the unverified settings panel is in other people's game folders
rather than only this one. That raises the value of the three checks rather than lowering it.

## Comments

**2026-10-11** Clear-down (attended, agent). Ticked #2, #3, #4, #5 and #7: the 30-check harness recorded under Verification so far proved them offline, and a re-read of `Core.lua` today agrees (Init and the broker queue are gated on `ns:IsModuleEnabled`, the 1 s driver refreshes one due module, `GetModulePoll` returns nil for Events only). #1, #6 and #8 are the in-game looks in `## What I need from you`, now marked `proves: manual`. Per the board README rule "A look waits on the product", moved to `ai-review/` with those looks left open: the 2026-08-15 review was followed by three fixes nobody re-reviewed.

### 2026-10-17 review (v20261017044019-3760)

**suite**

No suite this job could find in WoWAddons:DjinnisDataTexts, so none ran. That is not a pass.

**acceptance: sound**

**What I did:** I checked each acceptance criterion against the code. I tried to break each one. I could not.

- **#1 and #6 (manual).** In `Core.lua`, `ns:NewBroker` holds each broker in a queue. The `ADDON_LOADED` handler then makes a broker only when `ns:IsModuleEnabled(key)` is true. Saved settings sit in each module's own table, and enable state is never written there. So a module that comes back has its old settings. Nothing in the code stops these two checks from passing.
- **#2.** The `Init` loop and the first refresh loop in the `ADDON_LOADED` handler both check `IsModuleEnabled`. The 1-second ticker checks it too.
- **#3.** `ns:GetModulePoll` gives back nil for "Events only", so the ticker skips that module. The module's event registrations and tooltip code are not changed.
- **#4.** `IsModuleEnabled` defaults to true. `GetModulePoll` defaults to `ns.DEFAULT_POLL` (180 seconds).
- **#5.** Enable and poll state live in `ns.db.modules`. That is outside every module's own settings table, so a reset does not touch it.
- **#7.** The ticker in `ADDON_LOADED` picks only the module that is most overdue. It calls `UpdateData` once per tick.
- **#8 (manual).** `ns:NotifyActivityChange` and `ns:RegisterActivityTracker` exist at file scope in `ActiveActivity.lua`. Both do their work only after `_initialized` is set. The calls in `Delve.lua` and `PreyTracker.lua` are guarded. The feeders never touch the aggregator's broker directly. So check 3 should pass.

No criterion is disproved. Only the manual in-game checks are still open. Those are yours to do.

**What you do now:** Nothing from this review. Do the three in-game checks on the card when you have a session in the game.

VERDICT: sound

**scope: sound**

I checked what this change did that the card did not ask for. I found nothing over the fence and nothing half done.

**Scope findings:**

- **The diff is bigger than this card.** It also carries work from other cards: Achievements (0013), Quest Log (0014), TimeDate (0007), the Delve Lair change (0008), the club sort fix (0012) and the `ns.Coalesce` change. Each of those has its own card. So none of it is scope creep on this card.
- **The Delve and Prey Tracker switches sit in Active Activity's panel.** The fence forbids a copy of a Modules-panel checkbox on a module's own page. This is a move, not a copy:
  - In `Settings.lua`, the Modules panel list builder skips any key in `ns.subTrackerModules`. So each tracker has one switch only.
  - `ActiveActivity:BuildSettingsPanel` uses the same `AddModuleRow` widget.
  - The card's `## Direction` entry for 2026-08-15 records this choice.
- **Enable All and Disable All also skip sub-trackers** (`Settings.lua`, the Modules panel button handlers). So the Modules panel cannot change a tracker behind Active Activity's back.
- **Nothing is half done.**
  - Every Tasks item is done, except the in-game check.
  - The `[~]` item is the deliberate `.toc` / RELEASE_NOTES hold. Later releases (0.9.13 to 0.9.16) settled it.
  - The open criteria #1, #6 and #8 are all `proves: manual`. Under the review rules, an open manual criterion is not a finding.

I wrote no UNMET lines, because no criterion is disproved.

VERDICT: sound

**breakage: sound**

I tried to break this card's code. I could not.

**What I checked:**

- **Aggregator off, feeder on (acceptance #8).** `ns:NotifyActivityChange` and `ns:RegisterActivityTracker` sit at file level in `Modules/ActiveActivity.lua`. So they exist even when Active Activity is off. Both only update the label after `ActiveActivity:Init` sets `_initialized`. Delve and Prey Tracker check that each function exists before they call it. Result: no Lua error.
- **Feeder switches.** `DDT:SetupOptions` in `Settings.lua` builds every module's panel, even for a disabled module. So the Delve and Prey switches stay in Active Activity's panel when Active Activity is off.
- **Broker deferral.** `ns:NewBroker` in `Core.lua` gives back the same table. Every module keeps its `dataobj` and works as before.

**One small cost, not a defect.** "Disable All" leaves Delve and Prey Tracker on. If Active Activity is off, those two still poll, but nobody sees their output. Nothing breaks, and no criterion fails. If you want to change it, tell me and I will add a card.

**What you do now:** nothing for this review. The three in-game checks (#1, #6, #8) are still yours to try.

VERDICT: sound

