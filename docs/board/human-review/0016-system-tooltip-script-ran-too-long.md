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
