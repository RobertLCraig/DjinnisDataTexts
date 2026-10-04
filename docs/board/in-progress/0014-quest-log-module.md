# Quest Log DataText module (grouped log with click actions)

## Why
There is no Quest Log DataText. You cannot see at a glance how full your quest log is, which
quests are ready to hand in, or what is still outstanding, without opening the log. A
CurseForge user named this, "on par with Broker Everything", as one of two things keeping that
addon installed. Rob said "medium" on 2026-09-29; card `0004` records how that was read.

## Links

**Relates to**
- `0004` - the scoping decision this card builds, including why "medium" was read as option 2
  and what to do if Rob meant option 1.
- `0013` - the Achievements module from the same user request, built to the same pattern.
- `0001` - the per-module toggles exist because a user objected to modules refreshing when
  nothing shows them; this module's refresh path is the one most at risk of that complaint.

## Not this card
- A quest detail pane, map, or quest text in the tooltip beyond one progress line per quest.
- Sharing quests to the group and wowhead links (Broker Everything has both; not in scope).
- World quests and bonus objectives, which are not in the quest log proper.

## Acceptance
<!-- AC:BEGIN -->
- [ ] #1 WHEN the DataText is shown, THE APP SHALL show quests held out of the cap and how many
      are ready to hand in, through a label template (`<count>`, `<max>`, `<ready>`).
      proves: `docs/build/check-questlog.lua` (template expansion)
- [ ] #2 WHEN the tooltip opens, THE APP SHALL list every quest grouped by zone or campaign
      header (a setting), with ready-to-hand-in quests marked and each quest's progress text.
      proves: `docs/build/check-questlog.lua` (grouping and ordering of a fixture log) and manual
- [ ] #3 THE APP SHALL show daily and weekly quest counts in the tooltip. proves: manual
- [ ] #4 WHEN a quest row is left-clicked, THE APP SHALL open the quest log at that quest.
      proves: manual
- [ ] #5 WHEN a quest row is right-clicked, THE APP SHALL open a menu (track or untrack, open,
      abandon) and SHALL NOT act on the click itself. proves: manual
- [ ] #6 WHEN "Abandon" is chosen from that menu, THE APP SHALL ask for confirmation through
      Blizzard's own abandon dialog before anything is abandoned. proves: manual
- [ ] #7 WHEN quest events fire in bursts, THE APP SHALL rebuild at most once per throttle
      window, and SHALL walk the log for the tooltip only while it is shown.
      proves: `docs/build/check-questlog.lua` (throttle) and manual
- [ ] #8 THE APP SHALL register as a normal module: enable toggle, poll interval, label
      template, tooltip size, click actions and Reset to Defaults. proves: manual
<!-- AC:END -->

## Tasks
- [ ] Write `docs/build/check-questlog.lua` first, lifting pure helpers out between markers, as
      `docs/build/check-club-sort.lua` does.
- [ ] `Modules/QuestLog.lua`, registered as `questlog`, broker `DDT-QuestLog`.
- [ ] Add it to `DjinnisDataTexts.toc`, `README.md` and `RELEASE_NOTES.md`.
- [ ] In-game check.

## Plan
**Where to stand:** `C:\Dev\WoWAddons\DjinnisDataTexts`, a branch of its own. Read
`docs/HANDOVER.md` and `docs/DATA-MODEL.md`. The quest walk already exists in
`Modules/Experience.lua` (`C_QuestLog.GetNumQuestLogEntries`, `GetInfo`, `ReadyForTurnIn`);
reuse its pattern. Per-row click handling: copy what Currency and BagValue do.

**APIs, checked in `wow-ui-source` (12.1.0, 69933),** all in
`Blizzard_APIDocumentationGenerated/QuestLogDocumentation.lua`: `GetNumQuestLogEntries`,
`GetInfo`, `GetQuestIDForLogIndex`, `ReadyForTurnIn`, `GetMaxNumQuestsCanAccept`,
`GetQuestObjectives`, `GetQuestWatchType`, `AddQuestWatch`, `RemoveQuestWatch`,
`SetSelectedQuest`, `SetAbandonQuest`, `AbandonQuest`. Several carry
`SecretArguments = "AllowedWhenUntainted"`; read the workspace `docs/DECISIONS.md` 12.1 entries
before passing any game-returned value back in.

**Abandon, the one destructive action.** Do not call `C_QuestLog.AbandonQuest` from the menu.
Call Blizzard's `QuestMapQuestOptions_AbandonQuest(questID)`
(`Blizzard_UIPanels_Game/Mainline/QuestMapFrame.lua:1413`), which selects the quest and shows
the `ABANDON_QUEST` or `ABANDON_QUEST_WITH_ITEMS` confirmation; only its OnAccept abandons
(`Blizzard_StaticPopup_Game/Mainline/GameDialogDefs.lua:732`). Build the menu with
`MenuUtil.CreateContextMenu`.

**What Broker Everything shows, so parity is measured** (`modules/questlog.lua`, GitHub
`HizurosWoWAddOns/Broker_Everything` at `349fa55`): label is failed / complete / held of max;
tooltip rows carry level, tags, title, zone and quest id, grouped by status, header or zone; a
hover shows quest text. Row click opens the map at the quest. Per-row cells track, share, copy a
URL, and abandon on a second click with no dialog. This card matches the grouping, counts and
track/abandon, and replaces its double-click abandon with Blizzard's confirmation.

## Comments

**2026-09-29** Written from Rob's answer on `0004`, read as option 2. Not started.
