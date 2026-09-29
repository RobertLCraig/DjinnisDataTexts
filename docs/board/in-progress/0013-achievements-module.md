# Achievements DataText module (medium scope)

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
TESTS: +22 new, all green (`lua docs/build/check-achievements.lua`, Lua 5.4 and 5.1)
TOUCHED: Modules/Achievements.lua, docs/build/check-achievements.lua, DjinnisDataTexts.toc, README.md, RELEASE_NOTES.md, docs/HANDOVER.md (one Sibling docs row for the new check), docs/board/in-progress/0013-achievements-module.md
OUT-OF-SCOPE: none

Built the module and its check. Only #1 is ticked: it is the one criterion whose proof is the
check alone. Every other criterion needs a live client, which no session here can run, so they
stay open for the in-game check. The check was watched red first (20 of 22 failing against a stub
`[ach-helpers]` block), then green. It lifts the real block and the real `ns.ExpandTag` from
`Core.lua`, so it cannot pass around the module. **#3 is half proved**: the row formatting
(`quantity / required`, bar fill, the 0x1 flag found among other bits, the divide-by-zero case)
is tested; the bar drawing is not.

What a person needs to check in game (`deploy.ps1 -Only`, `/reload`): the label, then
`<points> (<session>)` after earning something; the recent list and its dates; a tracked
achievement's bars and done lines; the grey "No achievements tracked." line; left-click on the
DataText and on a row; right-click on both (menu only, no action); the settings panel, its poll
dropdown in Modules, and Reset to Defaults. Watch for Lua errors on hover.

Assumed, and not settled by the repository:
- **Recent count is capped at 5 in settings.** The slider runs 1 to 5 because
  `GetLatestCompletedAchievements` is believed to return five; nothing in `wow-ui-source`
  states the count. Widen the slider if the game returns more.
- **Newest first is the game's order**, not a sort of ours. Completion dates carry no time of
  day, so a sort could not order two achievements from the same day anyway.
- **"Untrack" appears only on tracked rows.** On a recently completed row it would do nothing.
- **The session baseline waits for a non-zero read**, in case the total reads 0 before the game
  has loaded it. An account with 0 points shows +0 until its first achievement.
- **Row clicks are fixed**, not configurable: the card's click-action criterion (#7) names the
  DataText's actions, and Rob's rule fixes what a row right-click does.
- **The release notes entry lands in the held 0.9.16.** The card asked for it there; that
  release is waiting on in-game checks for 0008 and 0010. If 0.9.16 should ship without this
  module until it has been in a client, move the entry to the next version.

The runner's `.\vendor\bin\pest.bat` and `pint.bat` do not exist here: this is a Lua addon with no
PHP, no `vendor/` and no Composer file, in this worktree or in the source repository. The Lua
checks are the suite. That is the project's shape, not a missing copy.
