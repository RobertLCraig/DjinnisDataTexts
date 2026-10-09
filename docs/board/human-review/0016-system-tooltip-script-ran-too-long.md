# The System tooltip throws "script ran too long" while it is open

## What I need from you

**One check in the client, with BugSack open.** Deployed 2026-10-09. Just `/reload`.

1. Hover the System DataText (fps / latency), or pin its tooltip, and leave it open for a minute.
   Expect: the memory list fills on open and refreshes about every 10 seconds; fps, latency and
   CPU still change every second.

**Pass:** no "script ran too long" from `SystemPerformance.lua` in that minute.

**Fail:** paste the error into `## Comments` and move the card to `todo/`.

**Why it needs you:** the time limit only exists in a live client.

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
