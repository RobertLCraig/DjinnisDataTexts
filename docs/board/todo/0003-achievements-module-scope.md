---
needs: 0002
---
# Scope for an Achievements DataText module

## Why
Requested on CurseForge by a user who would drop Broker Everything if DDT covered
Achievements and Quest Log, and who prefers DDT's tooltip style and customisation. No
Achievements module exists today: the only achievement code in the addon is the
`ToggleAchievementFrame()` click action shared by CharacterInfo and Experience.

Scope has to be decided before this is buildable, because "an Achievements module" spans
anything from a points counter to a progress browser, and the tooltip work scales with it.
Blocked on 0002, which decides whether the module is publicly promised at all.

## Options
1. **Points and recent.** Label shows total achievement points; tooltip lists the most
   recent completions with dates, plus click to open the achievement frame. Cost: small,
   maybe a day. Uses `GetTotalAchievementPoints` and `GetLatestCompletedAchievements`.
   Honest but thin, and probably does not beat Broker Everything on its own.
2. **Points, recent, and tracked progress.** The above, plus the currently tracked
   achievements with their criteria progress, and statistics for the nearest incomplete
   ones. Cost: moderate. Criteria enumeration via `GetAchievementNumCriteria` /
   `GetAchievementCriteriaInfo` is fiddly per achievement type, and progress bars in a
   tooltip need layout work. This is the version that would actually replace something.
3. **Full browser.** Category tree, search, per-achievement drill-down in the tooltip.
   Cost: large, and it duplicates the Blizzard achievement UI in a tooltip, which is the
   wrong shape for a DataText. Not recommended, listed so it is ruled out on the record.

## Recommendation
Option 2, if 0002 lands as a commitment to build it. Option 1 is cheap enough to be
tempting but would not move anybody off Broker Everything, which is the stated reason the
request exists. Option 2 should be split into its own feature card with acceptance criteria
once the scope is chosen; do not start building from this card.

Worth checking before scoping: what Broker Everything's achievement module actually shows,
so parity is measured rather than assumed.

## Decided
