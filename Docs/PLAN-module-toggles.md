# Plan: Per-module enable/disable toggles + per-module refresh control

Status: **APPROVED SCOPE, NOT YET IMPLEMENTED** (saved 2026-06-23)
Origin: addon-page comment requesting per-module on/off toggles; user follow-up
asking to also refresh only what's needed.

## Scope decisions (locked)
- **Toggles + poll control** — per-module enable/disable AND a per-module
  periodic-refresh setting.
- **Apply on /reload** — checkbox saves instantly; a "Reload UI" button applies
  pending changes. Matches the current .toc-edit-then-reload workflow.

## The core constraint (why it's built this way)
Every module creates its LDB broker at **file-load time**, which runs *before*
saved variables exist — so a module can't know if it's disabled when it
registers its broker. And **LDB has no unregister**: once a broker exists it
can't be removed. Therefore the only way to make a disabled module truly vanish
(like commenting it out of the .toc) is to **defer broker creation** until after
settings load, then skip it for disabled modules.

On "only refresh what's displayed": LDB exposes no "is this broker visible"
signal — that state lives inside the display addon (Titan/ElvUI/etc.) with no
universal API. Approximated correctly: disabled modules do zero work, the
expensive work (tooltips, deep scans) already only runs on hover, and the
per-module poll control can drop the periodic label-refresh ticker to
"Events only" for anything kept enabled.

## 1. Core.lua — deferred brokers, gating, scheduler
- New saved state `ns.db.modules = { [key] = { enabled, poll } }`. Helpers
  `ns:IsModuleEnabled(key)` (default **true** → existing users unaffected) and
  `ns:GetModulePoll(key)` (default **180**). Stored separately from per-module
  settings so module/global "Reset to Defaults" never touches enable state.
- Deferred broker helper `ns:NewBroker(key, name, spec)` pushes `{key,name,spec}`
  to `ns.pendingBrokers` and returns `spec` immediately (keeps each module's
  `dataobj` upvalue working). Verified safe vs LDB internals: `NewDataObject`
  mutates and returns that *same* table, so identity is preserved when
  registered later.
- In `ADDON_LOADED`, after db ready and before Init: create brokers only for
  enabled modules.
- Init loop gated with `if ns:IsModuleEnabled(key) and mod.Init`.
- Keep the one-shot 1s initial refresh (enabled modules only). Replace the
  single aligned `NewTicker(180, RefreshAllModules)` with a **1s driver
  scheduler** that refreshes at most one due module per tick, honoring each
  module's poll interval ("Events only" = not scheduled). Improves on today's
  burst-all-in-one-frame behavior.

## 2. Module files (~23) — one-line change each
`local dataobj = LDB:NewDataObject("DDT-X", {…})` →
`local dataobj = ns:NewBroker("xkey", "DDT-X", {…})`.
Applies to: AccountStatus, ActiveActivity, AudioOutput, BagValue,
CharacterInfo, Communities, Coordinates, Currency, Experience, Friends, Guild,
ItemLevel, LFGStatus, Mail, MicroMenu, MovementSpeed, PetInfo, PlayedTime,
SavedInstances, SpecSwitch, SystemPerformance, TimeDate, VolumeControl.
- **Professions:** no broker-line change — creates brokers dynamically in Init;
  single "Professions" toggle handled by Init/refresh gating.
- **Aggregator trio (ActiveActivity / PreyTracker / Delve):** PreyTracker & Delve
  feed a plain-table dataobj into ActiveActivity's combined broker. Verify the
  wiring is **disable-safe** (disabled feeder or aggregator must no-op, not
  error); add guards if needed. The one spot needing inspection vs mechanical edit.
- MajesticBeast retired/not loaded — untouched.

## 3. Settings.lua — new "Modules" panel (first subcategory)
- Scrollable list of every registered module (sorted by label); per row an
  **Enabled** checkbox + a poll-interval dropdown
  (Default 180s / 30s / 60s / 5m / 10m / **Events only**).
- Top note "Changes apply after a UI reload" + **Reload UI** button +
  **Enable All / Disable All**; "changes pending" indicator.
- Disabled modules keep their own settings subcategory visible.
- Registered before the alphabetical module loop so it appears at top.

## 4. Versioning & docs
- Bump `.toc` version (→ 0.10.0) + CHANGELOG.md / RELEASE_NOTES.md /
  CURSEFORGE.md entry. User drives the actual release.

## Verification (manual, in-game)
`/reload`; disable a module → broker disappears + stops refreshing; set another
to "Events only" → no periodic poll but hover shows live data; re-enable + reload
→ returns; watch for Lua errors.

## Out of scope / follow-ups
- Live enable/disable without reload.
- Per-profession toggles.
- Per-module Enabled checkbox mirrored onto each module's own settings page.
