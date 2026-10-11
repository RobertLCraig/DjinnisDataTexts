# The System tooltip throws "script ran too long" while it is open

## What I need from you

**One check in the client, with BugSack open.** Deployed 2026-10-09. Just `/reload`.

1. Hover the System DataText (fps / latency), or pin its tooltip, and leave it open for a minute.
   Expect: the memory list fills on open and refreshes about every 10 seconds; fps, latency and
   CPU still change every second.

2. Queue for a group finder activity. Expect: no `LFGStatus.lua` error (#3).
3. Watch the Guild, Friends, Currency and Delve labels for a few minutes. Expect: they still
   update within a few seconds of a change, no new errors (#4).
4. Note the frame rate with the System tooltip open after a `/reload`. Expect: near your usual
   120+, not the 40 fps of 2026-10-09; if not, write down the top CPU addons the tooltip lists (#5).

**Pass:** no "script ran too long" from `SystemPerformance.lua` in that minute, and steps 2 to 4
as expected.

**Fail:** paste the error into `## Comments` and move the card to `todo/`.

**Why it needs you:** the time limit only exists in a live client.

## Acceptance
<!-- AC:BEGIN -->
- [x] #1 WHILE the System tooltip is shown, THE APP SHALL call `UpdateAddOnMemoryUsage` only on open,
      on the gc and refresh click actions, and at most every 10 seconds otherwise.
      (proved by code read: `MEMORY_INTERVAL` gate in `Modules/SystemPerformance.lua`)
- [ ] #2 WHEN the System tooltip is left open for a minute, THE APP SHALL raise no "script ran too
      long" from `SystemPerformance.lua`. proves: manual
- [ ] #3 WHEN the player queues for a group, THE APP SHALL raise no `LFGStatus.lua` error on a
      secret `C_LFGList.GetApplications()` (94b2b79). proves: manual
- [ ] #4 WHEN guild, friends, currency or delve data changes, THE APP SHALL update those labels
      within a few seconds despite the coalesced events, with no new error. proves: manual
- [ ] #5 WHEN the System tooltip is open after a `/reload`, THE frame rate SHALL be near the usual
      120+, not the 40 fps reported on 2026-10-09 (AchievementTodo 0001); if it is not, the
      tooltip's top CPU addons name the cause. proves: manual
<!-- AC:END -->

## Ask

Rob, 2026-10-09, a BugSack screenshot:
`SystemPerformance.lua:165: script ran too long`, in `CollectCPU` called from `UpdateData`.

## Direction

`UpdateData` ran `UpdateAddOnMemoryUsage()` every second while the tooltip was shown. That call
walks every addon's Lua heap, so its cost grows with the addons installed, and the CPU loop after
it in the same call took the blame. It now runs on open, on the gc and refresh click actions, and
at most every 10 seconds otherwise (`MEMORY_INTERVAL`).

## Comments

**2026-10-09, agent:** the same BugSack pass found `LFGStatus.lua:211` x2591, `ipairs` on a secret
`C_LFGList.GetApplications()`. Fixed in 94b2b79 (skip when `issecretvalue`). Only
`SystemPerformance.lua` and `LFGStatus.lua` were copied to the game folder, not a full deploy
(the 0013 and 0014 modules would come with it). Both commits are local; Rob has not OK'd a push.
Check in game: no LFGStatus errors after queueing for a group; fps with the System tooltip open.

**2026-10-09, agent, fps pass:** DDT holds 40-52 MB after a forced `collectgarbage`, so it is
retained, not churn; what holds it is still unknown (next: `/reload`, gc click at once, read it).
Separately cut per-event rebuilds: `ns.Coalesce` in Core.lua; Delve ignores `UNIT_AURA` outside a
delve and batches the rest (0.5 s); Guild, Communities, Friends (2 s) and Currency (1 s) batch
bursts; CharacterInfo reacts to target/mouseover only for a new shard, guards secret GUIDs and
stops re-sending `iconCoords`; `ns.ExpandTag` skips tags absent from the template. Those 7 files
were copied to the game folder. Check in game: guild/friends/currency/delve labels still update
within a few seconds; no new errors.

**2026-10-09, agent, second pass:** batched PetInfo (2 s), Experience (0.5 s), PreyTracker currency
label (0.5 s), Mail inbox (0.2 s), ItemLevel gear swaps (0.3 s) and LFGStatus events (0.3 s);
LFGStatus's 1 s queue tick now only redraws and re-collects every 10 s; BagValue listens to
`BAG_UPDATE_DELAYED` only; Professions `UNIT_AURA` is player-only. Copied to the game folder.
Not done, smaller: `DDT:GetOrCreateGroupHeader` keeps one FontString per name forever (pool by
position as Professions does); SystemPerformance `CollectCPU` builds a table per addon per second
while shown; TimeDate/PlayedTime rebuild an unchanged label each second; Achievements and QuestLog
(0013, 0014) need `ns.Coalesce` on `CRITERIA_UPDATE` and in `QLH.NewThrottle` before they deploy.

**2026-10-11** Clear-down (attended, agent). The card had no Acceptance block, so the product list could not see its looks. Added one from the checks the comments above already ask for: #1 ticked on a code read, #2 to #5 open as `proves: manual`. #5 is the open "40 fps, normally 120+" note moved here from DjinnisAchievementTodo 0001, since the System tooltip is how it gets traced. Per the board README rule "A look waits on the product", moved to `ai-review/`: no adversarial review has run on this card. Everything here is deployed (today's DataTexts dry run: 57 unchanged).
