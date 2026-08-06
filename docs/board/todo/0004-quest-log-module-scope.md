---
needs: 0002
---
# Scope for a Quest Log DataText module

## Why
Requested on CurseForge alongside Achievements (see 0002), specifically "on par with Broker
Everything". No Quest Log module exists. There is existing quest-log code to build on:
[Experience.lua](../../../Modules/Experience.lua) already walks
`C_QuestLog.GetNumQuestLogEntries` / `GetInfo` / `ReadyForTurnIn` to total up quest XP, so
the scan pattern and its cost are known.

"Parity with Broker Everything" is the user's phrasing, not a specification, and the gap
between a quest counter and a full quest browser is where all the effort sits. Blocked on
0002.

## Options
1. **Counter and turn-ins.** Label shows quests held out of the cap and how many are ready
   to hand in; tooltip lists the ready ones, click to open the quest log. Cost: small, and
   most of the scan already exists in Experience. Covers the single most useful thing a
   quest DataText does, which is telling you that you are carrying finished quests.
2. **Grouped log with click actions.** The above, plus all quests grouped by zone or
   campaign, per-quest progress text, daily and weekly counts, and per-row clicks to
   select, track, or abandon. Cost: substantial. The tooltip becomes one of the largest in
   the addon, per-row click actions need the same treatment Currency and BagValue got, and
   quest state changes fire often enough that the refresh path needs care.
3. **Counter only.** Label and no meaningful tooltip. Cost: trivial. Rejected as not worth
   a module; the tooltip is the reason people use DDT.

## Recommendation
Option 1 first, shipped on its own, with option 2 as a follow-up if the module gets used.
Quest data changes constantly and the scan is not free, so a large always-grouped tooltip is
the version most likely to cause performance complaints, which is a poor trade given card
0001 exists precisely because a user objected to unnecessary refreshing. Shipping option 1
also gets something in front of the requester quickly rather than holding everything behind
the big version.

Split into a feature card with acceptance criteria once scoped. Check what Broker
Everything's quest module actually displays before committing to "parity".

## Decided
