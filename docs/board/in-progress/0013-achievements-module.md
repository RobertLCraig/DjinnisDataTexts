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
- [ ] #1 WHEN the DataText is shown, THE APP SHALL show total achievement points in the label,
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
- [ ] Write `docs/build/check-achievements.lua` first, lifting pure helpers out of the module
      between markers, as `docs/build/check-club-sort.lua` does.
- [ ] `Modules/Achievements.lua`, registered as `achievements`, broker `DDT-Achievements`.
- [ ] Add it to `DjinnisDataTexts.toc`, `README.md` and `RELEASE_NOTES.md`.
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
