# Achievements DataText module (medium scope)

## What I need from you

**Walk acceptance #2 to #7 in game.** No agent can run a client.

1. `.\bin\deploy.ps1 -WhatIf -Only DjinnisDataTexts`, then without `-WhatIf`; `/reload`; add
   DDT-Achievements to a display.
2. Track two achievements, one with a counted criterion, and hover: recent list newest first with
   dates, tracked list with bars and "q / r" or Done / Not done. Untrack both and hover again for
   the grey "No achievements tracked." line.
3. Left-click the DataText and a row; right-click both (menu only, no action); from a row menu use
   Untrack and Link in chat. Earn something and watch `<session>`. Try Reset to Defaults and the
   poll dropdown.

**Pass:**
- every step above behaves as the acceptance line says
- no Lua error (BugSack or `/console scriptErrors 1`)

**Fail:** note the step and the error text in `## Comments`; the card goes back to `todo/`.

**Why it needs you:** the in-game surface is a step only a person can take. The code passed the
adversarial review below.

## Why
There is no Achievements DataText. To see your points, what you finished recently, or how far
along a tracked achievement is, you open the full achievement window. A CurseForge user said
this and a Quest Log module are the two things keeping Broker Everything installed next to
Data Texts. Rob chose the medium scope on 2026-09-29 (card `0003`, option 2).

## Links

**Relates to**
- `0003` - the scoping decision this card builds; its options explain why the full browser was
  ruled out.
- `0014` - the Quest Log module from the same user request, built to the same pattern.

## Not this card
- A category tree, search or per-achievement drill-down (option 3 on `0003`, ruled out).
- Per-category progress rows for every top-level category. Broker Everything has them; they
  were not in the chosen scope. A later card if asked for.
- Statistics or Feats of Strength handling beyond what the three sections below need.

## Acceptance
<!-- AC:BEGIN -->
- [x] #1 WHEN the DataText is shown, THE APP SHALL show total achievement points in the label,
      through a label template with at least `<points>` and `<session>` (points gained since
      login). proves: `docs/build/check-achievements.lua` (template expansion and session delta)
- [ ] #2 WHEN the tooltip opens, THE APP SHALL list the most recently completed achievements,
      newest first, each with its completion date, up to a configurable count (default 5).
      proves: manual
- [ ] #3 WHEN achievements are tracked, THE APP SHALL list each with its criteria: a progress bar
      and "quantity / required" for quantity criteria, done or not done for the rest.
      proves: `docs/build/check-achievements.lua` (criteria row formatting) and manual
- [ ] #4 WHEN nothing is tracked, THE APP SHALL say so in one grey line rather than show an empty
      section. proves: manual
- [ ] #5 WHEN the DataText is left-clicked, THE APP SHALL open the achievement window; WHEN a
      tooltip row is left-clicked, THE APP SHALL open the window at that achievement.
      proves: manual
- [ ] #6 WHEN the DataText or a row is right-clicked, THE APP SHALL open a menu and SHALL NOT act
      on the click itself (Rob's rule). Row menu: open, untrack, link in chat. proves: manual
- [ ] #7 THE APP SHALL register as a normal module: enable toggle, poll interval, label
      template, tooltip size, click actions and Reset to Defaults, like every other module.
      proves: manual
<!-- AC:END -->

## Tasks
- [x] Write `docs/build/check-achievements.lua` first, lifting pure helpers out of the module
      between markers, as `docs/build/check-club-sort.lua` does.
- [x] `Modules/Achievements.lua`, registered as `achievements`, broker `DDT-Achievements`.
- [x] Add it to `DjinnisDataTexts.toc`, `README.md` and `RELEASE_NOTES.md`.
- [ ] In-game check.

## Plan
**Where to stand:** `C:\Dev\WoWAddons\DjinnisDataTexts`, a branch of its own. Read
`docs/HANDOVER.md` and `docs/DATA-MODEL.md` first. Copy the shape of a small module such as
`Modules/Mail.lua`: `DEFAULTS`, `ns:NewBroker`, `ns:RegisterModule`, `BuildSettingsPanel`.

**APIs, checked in `wow-ui-source` (12.1.0, 69933).** The achievement globals are not in the
generated docs but are live: `Blizzard_AchievementUI/Mainline/Blizzard_AchievementUI.lua` calls
`GetTotalAchievementPoints`, `GetLatestCompletedAchievements`, `GetAchievementInfo`,
`GetAchievementNumCriteria` and `GetAchievementCriteriaInfo`, and none is only in a
`Blizzard_Deprecated*` shim. Tracked achievements come from
`C_ContentTracking.GetTrackedIDs(Enum.ContentTrackingType.Achievement)` (enum value 2,
`ContentTrackingTypesDocumentation.lua`). Re-check each before use; the workspace
`docs/DECISIONS.md` 12.1 entries apply to any string the game hands back.

**What Broker Everything shows, so parity is measured** (its `modules/achievements.lua`, GitHub
`HizurosWoWAddOns/Broker_Everything` at `349fa55`): label is points plus "+N" earned this
session; tooltip has Latest (name and date), per-category progress with bars, and a watch list
of tracked achievements with criteria bars or done/not-done lines. Left-click opens the
achievement window, right-click a menu. Its rows have no click actions. This card matches it
except the category rows, and adds row clicks.

**Refresh:** event-driven (`ACHIEVEMENT_EARNED`, `CRITERIA_UPDATE`, tracking changes), with the
heavy criteria walk only on tooltip hover. Register each event singly and confirm with
`IsEventRegistered`, per the workspace decision of 2026-08-21.

## Comments

**2026-09-29** Written from Rob's answer on `0003` ("medium", option 2). Not started.

**2026-09-29** RESULT: partial
TESTS: +1 new, all green (`docs/build/check-achievements.lua`, 19 checks, Lua 5.4 and 5.1)
TOUCHED: Modules/Achievements.lua, docs/build/check-achievements.lua, DjinnisDataTexts.toc, README.md, RELEASE_NOTES.md, docs/HANDOVER.md, docs/board/in-progress/0013-achievements-module.md
OUT-OF-SCOPE: none

Built the module to the card. Only #1 is ticked, because it is the only criterion fully proved
here. #2 to #7 are written but have never run in a game client, so they stay open for the
in-game check. #3's row formatting is tested; its drawing is not.

The check lifts the `[ach-helpers]` block and Core's real `ns.ExpandTag`. It was watched red
first against stub helpers (13 of 19 failing on behaviour). It covers the label template, the
session delta (the baseline is the first non-zero read, since the game can answer 0 before
achievement data loads), criteria rows (flag bit 1 is `EVALUATION_TREE_FLAG_PROGRESS_BAR`; the
game's `quantityString` wins over "q / r" when present; the bar clamps at full), and a secret
criteria string passing through without concatenation.

Assumed, not settled from the repository:
- `GetLatestCompletedAchievements()` returns newest first and may return fewer than 10. The
  count slider (1 to 10, default 5) only trims what the game gives. How many it returns is a
  C-side answer the UI source does not show.
- Right-click on the DataText defaults to the "menu" click action. Click actions are
  configurable, so a user can reassign it; Rob's rule holds for the defaults. Row clicks are
  fixed (left opens, right menus) and not configurable, since the card specifies them.
- The tooltip stays up while any context menu is open (`Menu.GetManager():GetOpenMenu()`),
  because a Blizzard context menu closes when its owner row hides.
- Label points are a plain number, not run through the global number format. The tooltip uses
  `BreakUpLargeNumbers`.

The session instruction to run `.\vendor\bin\pest.bat` and `pint.bat` does not apply here: this
is a Lua addon with no PHP, no `vendor/` and no Pest. The suite is the three regression scripts in
`docs/build/` (achievements, club-sort, timezones), and all three pass under Lua 5.1.
`check-alt-prune.lua` is a one-off that needs a real SavedVariables file and was not run.

In-game check owed: `deploy.ps1`, `/reload`, add DDT-Achievements to a display, then walk #2
to #7. Track two achievements, one with a counted criterion. Untrack and link in chat from the
row menu. Earn something and watch `<session>`. Try Reset to Defaults, and the poll dropdown in
the Modules panel.

**2026-10-04** REVIEW (adversarial, separate agent)
VERDICT: pass to human-review. No non-trivial finding; one test gap and one stale comment fixed in `90d7151`.

Attacked, against `wow-ui-source` 12.1.0 (69933), not memory:
- `GetAchievementInfo` order (id, name, points, completed, month, day, year): the recent and tracked reads match `Blizzard_AchievementUI/Mainline`.
- `GetAchievementCriteriaInfo` order (string, type, completed, quantity, reqQuantity, charName, flags, assetID, quantityString): matches Mainline line 1952 and the objective tracker.
- `C_ContentTracking.GetTrackedIDs(type)` and `StopTracking(type, id, stopType)`, `Enum.ContentTrackingType.Achievement` (2) and `Enum.ContentTrackingStopType.Manual` (2): match the generated docs and Blizzard's own untrack calls.
- `ToggleAchievementFrame` and `ShowAchievementFrameForAchievement` live in `Blizzard_AchievementUI_Bootstrap.lua`, which is not load-on-demand and loads the UI itself. `GetAchievementLink`, `ChatFrameUtil.InsertLink` (returns false with no edit box, so the `OpenChat` fallback is right), `FormatShortDate(day, month, year)`, `BreakUpLargeNumbers` and `Menu.GetManager():GetOpenMenu()` all exist outside `Blizzard_Deprecated*`.
- All five events exist in the generated docs; registered singly after `SetScript`, each confirmed with `IsEventRegistered`.
- Settings widget calls match the `Settings.lua` signatures; Reset to Defaults and the poll dropdown come from the shared panel.
- Right-click: the DataText defaults to the menu, and rows open a menu and never act. Rob's rule holds for the defaults.
- Secrets: no achievement API carries a secret annotation and there is no `C_Secrets` predicate for achievements, so `pts .. " pts"` and `"+" .. gained` on plain numbers hold. Criterion text is never concatenated.

Mutation run on a temp copy (arg 1): no clamp, empty quantityString winning and a zero baseline all went red. Broke:
- Treating any non-zero criteria flag as a bar passed all 19 checks; only flags 0 and 1 were fed. Fixed: flags 2 (`EVALUATION_TREE_FLAG_DO_NOT_DISPLAY`) and 3 added, the mutation now fails, 21 pass.
- The line 154 comment said `CRITERIA_UPDATE` only redoes the label; it also rebuilds the tooltip while shown. Comment corrected.

Left open, low, not fixed:
- The check cannot see call-site wiring: swapping month and day, shifting the criteria returns, or passing 0 for `gained` in `UpdateData` all stay green. Those were verified by reading against source above, and are manual by design.
- The fake secret only traps concatenation. `quantityString ~= ""` compares a game string; harmless unless 12.1 makes criteria strings secret, which nothing in the source says.
- A rebuild runs on every `CRITERIA_UPDATE` while hovered, and every criterion is listed, completed ones included, with no cap (the objective tracker caps and hides completed ones). A tracked meta with dozens of criteria gives a long tooltip; it scrolls.
- A tracked achievement with zero criteria shows its name and nothing under it; the objective tracker shows the description instead.
- The broker menu's "Open achievement window" toggles, so it closes the window if it is already open.

Security: (1) Weakest point: nothing reachable by another party. The only input is the user's own label template, run through `ns.ExpandTag` with a literal tag pattern inside pcall. (2) Unchecked: the event handler reads no payload, achievement ids come from the game, and the row menu captures its id when it opens. No network, and nothing read from SavedVariables beyond the module's own settings. (3) Leaks: nothing; a link in chat is the user's explicit choice, and errors stay in the local client.

The in-game surface was not looked at: no client. Ask: walk #2 to #7 per `## What I need from you`.
