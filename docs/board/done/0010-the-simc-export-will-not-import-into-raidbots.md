---
not_for_the_loop: criterion #6 is a paste into raidbots.com in a browser, and every other open criterion needs a right-click in a running game client
---
# The SimC export will not import into Raidbots

## What I need from you

**Does right-clicking the item level DataText now give an export that Raidbots accepts, both with the SimulationCraft addon on and with it off?**

The fixed code is already in your game folder: a dry run on 2026-09-29 found all 54 files the same
as source. This check is also what holds up the 0.9.16 release, together with card 0008.

1. With the SimulationCraft addon enabled, `/reload`, hover the item level DataText and right-click
   it. **Expected:** SimulationCraft's own export window opens (criterion #1).
2. Disable SimulationCraft in the AddOns list, `/reload`, and right-click again. **Expected:** this
   addon's copy box opens. The text starts with `#` comment lines naming your character, spec and
   date. It has a `talents=` line. Gear lines read like `head=,id=212066,bonus_id=...`, never
   `item:...` (criteria #2 to #5).
3. Paste the text from step 2 into <https://www.raidbots.com/simbot/droptimizer>. **Expected:** it is
   accepted and shows your spec, talents and equipped items (criterion #6).

**Pass:** all three steps match. Say so here and the card moves on.
**Fail:** say which step failed, and paste Raidbots' error or the wrong field. The card goes back to
`todo/` for that criterion only. A healer showing `role=attack` is a known limit and not a fail.

**Why it needs you:** every step needs a running game client or a browser, and no agent has either.

Paste-ready: `**2026-09-29** **Decided:** steps 1 to 3 all passed.`

## Why
Right-clicking the item level DataText is meant to hand you a character export you paste into
Raidbots or SimulationCraft to find out what your gear is worth. **The string it copies is rejected
or imported wrong.** You get a character with no talents and gear the site cannot read, so any
number that comes back is about somebody else's character.

Two separate faults produce that.

**It never hands the job to the real Simulationcraft addon.** `Modules/ItemLevel.lua:391` looked for
the slash handler under the key `SIMULATIONCRAFT`, which nothing ever registers, so the lookup
missed on every machine and the home-made fallback always ran.
`DjinnisDataTexts.toc` already names SimulationCraft in `## OptionalDeps`, so deferring to it was
always the intent. **Fixed 2026-08-24, see `## Direction`.**

**The fallback string is not the format SimC produces.** `Modules/ItemLevel.lua:396-444` writes five
header lines plus one line per equipped item. Against real `/simc` output it is missing `talents=`
(the loadout export string, and the single thing Raidbots most needs), `region=`, `role=` and
`professions=`. It does not quote the character name. And each gear line pastes the raw `item:...`
link string, where SimC writes a keyed line: `head=,id=212066,bonus_id=1520/10356,gem_id=213743`.
A parser expecting keys does not get them.

**What it costs.** The tooltip at `Modules/ItemLevel.lua:1054` advertises this to everyone who
installs the addon, and it works for nobody. Anyone who trusts the output sims a character with no
talents and draws a wrong conclusion, which is worse than an error message. The addon is on
CurseForge, so this ships to other people's game folders and not only yours.

**How it came to be this way.** The delegation branch and the fallback were written together from
memory of the format, and neither was ever pasted into Raidbots to see what came back.

## Not this card
**Do not reimplement the SimulationCraft addon.** When it is present, call it and stop. The fallback
exists only for people who do not have it, and it stays a best-effort export.

**Do not add bag gear, bank gear, saved sets or the weekly reward section.** Real `/simc` emits
those as commented extras. Equipped gear plus a correct header is the whole scope.

**Do not touch the Auctionator or TSM shopping-list code** further down the same file. It shares
`GEAR_SLOTS` and nothing else. **No settings and no new saved variable**, so `SCHEMA_VERSION` in
`Core.lua` does not move.

## Acceptance
<!-- AC:BEGIN -->
- [ ] #1 WHEN the SimulationCraft addon is installed and enabled, THE APP SHALL open that addon's
      own export window and SHALL NOT copy a string of its own. proves: manual - needs the addon
      installed and a right-click in a live client
- [ ] #2 WHEN the SimulationCraft addon is absent, THE COPIED STRING SHALL begin with a `#` comment
      header naming the character, spec and date, in the shape `/simc` writes. proves: manual
- [ ] #3 WHEN the SimulationCraft addon is absent, THE COPIED STRING SHALL carry a `talents=` line
      holding the current loadout export string. proves: manual
- [ ] #4 WHEN the SimulationCraft addon is absent, THE COPIED STRING SHALL carry `level=`, `race=`,
      `spec=`, `region=`, `server=`, `role=` and `professions=` lines. proves: manual
- [x] #5 WHEN a gear slot is filled, THE COPIED STRING SHALL write it as `slot=,id=N` plus whichever
      of `bonus_id=`, `gem_id=`, `enchant_id=` and `crafted_stats=` that item carries, and SHALL NOT
      write a raw `item:` link. proves: `docs/spec/test-simc-item-line.lua` (eight item strings asserted against the real addon's gear lines)
- [ ] #6 WHEN the fallback string is pasted into the Raidbots Droptimizer import box, THE SITE SHALL
      accept it and show the right spec, talents and equipped items. proves: manual - a browser
      check, and the only proof that matters
<!-- AC:END -->

## Tasks
- [x] Find the real slash key and fix the guard at `Modules/ItemLevel.lua:391`
- [x] Capture a genuine `/simc` export and save it as `docs/spec/simc-export-example.txt`
- [x] Rewrite the fallback header to match that reference: comment lines, quoted name, and the
      missing `region`, `role` and `professions` keys
- [x] Add `talents=` from `C_Traits.GenerateImportString`
- [x] Rewrite the gear loop to split the item link into id, bonus ids, gem ids and enchant id, and
      emit the keyed form
- [ ] Paste both outputs into Raidbots and record what each one did in `## Direction`

## Plan
**Where to stand.** `C:\Dev\WoWAddons\DjinnisDataTexts`, on a branch off `master`. One file changes:
`Modules/ItemLevel.lua`, the function `ItemLevel:CopySimCString` at line 389 and nothing else in it.
Read `CLAUDE.md` in this directory first for the addon's conventions.

**The reference output is the specification.** Do not write the format from memory. That is what
produced this card. Get one real `/simc` export first, keep it in the repo, and diff against it.

**The item link is the whole parsing job.** `GetInventoryItemLink` returns
`item:ID:enchant:gem1:gem2:gem3:gem4:suffix:unique:level:specID:modifiers:numBonusIDs:bonusID1:...`.
Split on `:` and take the pieces by position. No Blizzard helper hands this back already broken up,
so it is a loop of about fifteen lines.

**To see it work.** Deploy with `C:\Dev\WoWAddons\bin\deploy.ps1 -WhatIf -Only DjinnisDataTexts`,
then again without `-WhatIf`. Log in, hover the item level DataText, right-click. With
Simulationcraft enabled you should get its window; with it disabled you should get this addon's own
copy box. `/reload` between changes. **There is no test suite here**, which is why every criterion
says `manual`; the real check is a paste into <https://www.raidbots.com/simbot/droptimizer>.

## Direction
**2026-08-24** The slash key is fixed, and it is neither name this card first guessed. The addon is
installed at `C:\Games\World of Warcraft\_retail_\Interface\AddOns\Simulationcraft`, and
`core.lua:132` registers its command through AceConsole rather than by hand:

    Simulationcraft:RegisterChatCommand('simc', 'HandleChatCommand')

`AceConsole-3.0.lua:85` builds the key as `"ACECONSOLE_" .. command:upper()`, so **the real key is
`ACECONSOLE_SIMC`**. `SIMULATIONCRAFT` was wrong, and the plain `SIMC` this card originally proposed
would have been wrong too. Every addon using AceConsole is keyed this way, which is worth knowing
before guessing at another one.

The `C_AddOns.IsAddOnLoaded` half of the guard is gone rather than corrected. The handler existing
is already proof the addon loaded, and the old check matched on a folder name (`SimulationCraft`
against the real `Simulationcraft`) that a rename would break silently.

Empty input is the right argument. `HandleChatCommand` at `core.lua:167` splits it, matches none of
`debug`, `nobag`, `merchant` or `minimap`, and falls through to
`PrintSimcProfile(false, false, false)`, which is what the addon's own minimap button calls.

**What has been checked: `luac -p Modules/ItemLevel.lua` parses under Lua 5.1, and nothing else.**
Criterion #1 still needs the right-click in a live client. Criteria #2 to #6 are untouched by this
change and the fallback is still wrong.

**2026-08-26** The fallback is rewritten, against a real export Rob captured rather than from
memory. It is saved as `docs/spec/simc-export-example.txt` and `pkgmeta.yaml` already ignores
`docs`, so it does not ship.

The gear line builder is a port of the Simulationcraft addon's own
`GetItemStringFromItemLink`, keeping its offset names so the two can be diffed when a patch moves
the item string again. It emits `id`, `enchant_id`, `gem_id`, `bonus_id`, `drop_level`,
`content_tuning`, `crafted_stats`, `redirected_base_stats`, `gem_bonus_id` and `crafting_quality`.
Its 11.1.7 titan-disc belt case is left out on purpose: four hardcoded item ids that matter to one
belt. The header now carries the four comment lines, the quoted name, and `region`, `server`,
`role`, `professions` and `spec`, plus `talents=` from `C_Traits.GenerateImportString`.

**There is now a runnable check**, which is new for this repository:

    lua docs/spec/test-simc-item-line.lua

Eight cases, each a hand-built item string asserted against the exact line the real addon emitted
for that item. It loads only the block between the `[simc-parser:begin]` and `[simc-parser:end]`
markers in `ItemLevel.lua`, which is pure Lua and needs no WoW state. **It was mutation-checked**:
changing `SIMC_OFFSET_BONUS_ID` from 13 to 12 fails six of the eight, so it is a check rather than a
sentence. All eight pass on the committed code, and `luac -p` parses the whole file.

**Three known ceilings, all marked `ponytail:` in the source.** Profession and spec names are read
localised, where the real addon looks them up by id, so a non-English client emits translated
tokens. `role=` uses a caster-spec set rather than the addon's full per-spec table, so healers
report `attack`. And `omnium_talents=`, the 12.1 trait system line, is not emitted at all.

**Still unrun in a game client.** Nothing above proves the header fields are right, only the gear
lines. Criteria #1 to #6 are all still open.

## Comments
<!-- The card's thread, appended by ProgressBoard. Append-only: entries are added, never edited or removed. An entry beginning **Decided:** is an answer, and that is what a decision card exits on. -->

**2026-08-29** The loop moved this card from todo/ to human-review/ WITHOUT trying it. All 6 of its open acceptance criteria say proves: manual, so there is nothing left an unattended session could close and starting one would change nothing. Each open criterion names what to look at and what a pass is: tick what passes and move the card on, or say what failed and move it back to todo/.

### 2026-10-04 manager (m20261004153552-2be7)

**outcome: rob**

The code work looks done, and only a check in the running game and the Raidbots site can close the criteria.

**what the session said**

I checked `Modules/ItemLevel.lua`. All the fixes the card describes are there:

- `ItemLevel:CopySimCString` now looks for `ACECONSOLE_SIMC`, which is the right name for the SimulationCraft handler.
- The gear lines come from the parser between the `[simc-parser:begin]` and `[simc-parser:end]` markers. It writes keyed lines like `head=,id=...`, not raw `item:` links.
- A `talents=` line now comes from `C_Traits.GenerateImportString`.

No review findings disprove any criterion. None of the 6 is ticked, and all 6 need a person:

1. Right-click the item level DataText with SimulationCraft on, then again with it off.
2. Paste the second output into <https://www.raidbots.com/simbot/droptimizer>.

The card's "What I need from you" section gives these steps and says what a pass looks like. Sending the card back to the builder would not change anything.

WHY: The code work looks done, and only a check in the running game and the Raidbots site can close the criteria.

OUTCOME: rob

**2026-10-11** Clear-down (attended, agent). Ticked #5: `lua docs/spec/test-simc-item-line.lua` passes all eight cases today, and it was mutation-checked on 2026-08-26. #1 to #4 and #6 stay open as the looks in `## What I need from you`. Per the board README rule "A look waits on the product", moved to `ai-review/`: the 2026-10-04 pass was a manager pass, not an adversarial review. Deployed: today's dry run shows the game folder matches source.

### 2026-10-17 review (v20261017112304-5d63)

**suite**

No suite this job could find in WoWAddons:DjinnisDataTexts, so none ran. That is not a pass.

**acceptance: sound**

I tried to break the export code and could not. Every criterion leads to real code in `Modules/ItemLevel.lua`.

- **#1:** `ItemLevel:CopySimCString` looks for the handler `SlashCmdList["ACECONSOLE_SIMC"]`. If it finds it, it calls it with empty input and returns. It copies nothing of its own. AceConsole builds that key from `/simc`, as the card's Direction section says.
- **#2:** In the fallback, the `lines` table in `CopySimCString` starts with `#` comment lines. The first one holds the name, spec, date and region/realm.
- **#3:** `CopySimCString` gets the active config from `C_ClassTalents.GetActiveConfigID` and passes it to `C_Traits.GenerateImportString`. The result goes on a `talents=` line. If the client has no talent data yet, it writes a comment line in its place. That is a fair best-effort behaviour, not a fault.
- **#4:** `CopySimCString` writes `level=`, `race=`, `region=`, `server=`, `role=`, `professions=` and `spec=`. It leaves out `professions=` when the character has no primary profession, which is what SimC does too.
- **#5:** `SimCItemLine` takes each piece of the item string by its position and writes `slot=,id=N` plus the keyed fields. It never writes a raw `item:` link. `docs/spec/test-simc-item-line.lua` already proves this.
- **#6:** This one needs a paste into Raidbots in a browser. It is only open, and nothing in the code shows it cannot pass.

Only manual criteria are still open, so I wrote no `UNMET:` lines.

VERDICT: sound

**scope: sound**

I tried to find work that went outside this card, or work left half done. I found none.

**What I checked**

- I ran `git log -S` to find which commits added the `ItemLevel.lua` changes.
- Commit `d09ee88` changed `ItemLevel:CopySimCString`. Now it calls the SimulationCraft addon through `ACECONSOLE_SIMC`.
- Commit `ceef38c` changed the fallback export and added the parser block. It also added `SIMC_SLOT_NAMES`, `SIMC_SPELL_SPECS` and `SimCToken` above that function. These only support the export, so they are inside the card's purpose.
- The `ns.Coalesce` change in `ItemLevel:Init` comes from commit `641916b`, which is a separate performance commit. It is not this card's work. The other changed files in the diff also belong to other cards.

**The fence ("Not this card")**

- The export does not add bag gear, bank gear, saved sets or the weekly reward section. It writes equipped gear only.
- No settings and no new saved variable. `SCHEMA_VERSION` in `Core.lua` did not change.
- The Auctionator and TSM shopping-list code did not change.

**Half done?**

- The gear lines also write `drop_level`, `content_tuning`, `gem_bonus_id` and `crafting_quality`. These are extra keys, but they copy what the real addon writes, so they are not scope growth.
- The open criteria (#1 to #4 and #6) are all `proves: manual`. They wait for you in the game and on Raidbots. That is not a defect.
- These known limits are in the source and on the card: healers get `role=attack`, names come out in the client language, and there is no `omnium_talents=` line.

**What you do now:** the steps in the card's "What I need from you" section. Try the right-click with SimulationCraft on, then off. Then paste the second export into Raidbots.

VERDICT: sound

**breakage: sound**

I tried to break the SimC fix (the code that makes a gear export for Raidbots). I did not find a fault.

What I checked:

- **The hand-off to SimulationCraft.** `ItemLevel:CopySimCString` now reads `SlashCmdList["ACECONSOLE_SIMC"]`. If that is there, it calls it and stops. If it is not there, the code goes to the home-made export. It does not crash.
- **The helper calls.** `SafeGetSlotInfo` (in `Modules/ItemLevel.lua`) always gives back a name and a number. So the `"# %s (%d)"` comment line above each gear line cannot crash on a missing value.
- **The copy box.** `DDT:CopyToClipboard` in `Core.lua` still takes the same two inputs as before.
- **The gear list.** `GEAR_SLOTS` lists the same 16 slots as `SIMC_SLOT_NAMES`, so no slot is dropped.
- **Shared code.** The Auctionator and TSM code still uses `GEAR_SLOTS`. That list did not change, so that code is safe.
- **Game API (the functions the game gives addons).** `C_Traits.GenerateImportString` and `GetCurrentRegionName` are both in the local Blizzard API docs.
- **The test file.** `docs/spec/test-simc-item-line.lua` loads only the code between the `[simc-parser:begin]` and `[simc-parser:end]` markers in `ItemLevel.lua`. That code reads `C_TradeSkillUI` only behind a check that it exists, so the test runs outside the game. I did not run the test today. The card says all eight cases passed on 2026-10-11.

The criteria still open (#1, #2, #3, #4, #6) all need a person in the game or on the Raidbots site. They are not faults. The code shows no reason that any of them cannot pass.

What you do now: nothing for this review. Do the three steps on the card when you can.

VERDICT: sound

