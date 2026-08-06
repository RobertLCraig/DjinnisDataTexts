# How to answer the CurseForge comment about module toggles

## What I need from you
Pick one of the three reply options below and say whether the Achievements and Quest Log
modules get a public commitment or a soft "noted". A draft reply is ready for each option;
choosing one means the reply can be posted without another round. An agent cannot settle
this: it commits you publicly to a scope and a rough timeframe, and getting it wrong costs
either goodwill or a promise you did not want to make.

The comment is on the DDT CurseForge page. Nothing is posted until you answer.

## Why
A user asked for per-module enable/disable toggles, noted correctly that everything
refreshes on the 180s ticker whether displayed or not, and said they are currently
commenting modules out of the `.toc` by hand. They also said that with a good Achievements
module and a Quest Log module on par with Broker Everything they would drop that addon
entirely, and that they prefer DDT's tooltips and customisation.

The toggle work is already planned and is card 0001, so the substance of the reply is
settled. What is not settled is how much to promise and when.

Their technical claim was checked and is accurate: [Core.lua:1536](../../../Core.lua#L1536)
tickers `RefreshAllModules` over every module carrying an `UpdateData`. Two mitigations they
would not have seen: refreshes are spread one module per frame, and the expensive work
(tooltip building, deep scans) is hover-gated. Worth saying, because it is the difference
between "the addon is wasteful" and "the addon polls more than it needs to".

## Options
1. **Name a version, commit to both modules.** Say toggles land in 0.10.0 and that
   Achievements and Quest Log are on the roadmap. Cost: strongest goodwill, and it is the
   answer most likely to keep the user. But it commits you to two unscoped modules while
   0001 is still unbuilt, and Broker Everything parity on Quest Log is a genuinely large
   surface. A missed promise on a public comment is visible to everyone reading the page.
2. **Name a version for toggles only, soften the modules.** Toggles in 0.10.0; the two
   modules "noted, no timing promised, and I would rather do them properly than thinly".
   Cost: slightly less exciting, but it is true on the day it is written and stays true.
   The user still learns their main request is actually happening.
3. **Confirm the direction, promise no version.** Toggles are coming and their `.toc`
   workaround is fine meanwhile; both modules noted. Cost: safest, and the least useful to
   someone deciding whether to keep waiting. Given 0001 is fully planned rather than merely
   wished for, this undersells where things actually stand.

## Recommendation
Option 2. The toggle work is planned in enough detail that naming 0.10.0 is a statement of
fact rather than a hope, so there is little downside to saying it. The two new modules are
in the opposite position: no scope, no acceptance criteria, and Quest Log parity with Broker
Everything is a much bigger job than it sounds. Promising those by name and then shipping a
thin version is worse than not promising. Confirming their read of the refresh loop is worth
doing either way; they read the code and were right, and saying so plainly earns more trust
than a generic thanks.

Cards 0003 and 0004 hold the scope decisions for the two modules and are waiting on this.

## Decided
