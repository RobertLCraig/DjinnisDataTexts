# The SimC export will not import into Raidbots

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
- [ ] #5 WHEN a gear slot is filled, THE COPIED STRING SHALL write it as `slot=,id=N` plus whichever
      of `bonus_id=`, `gem_id=`, `enchant_id=` and `crafted_stats=` that item carries, and SHALL NOT
      write a raw `item:` link. proves: manual
- [ ] #6 WHEN the fallback string is pasted into the Raidbots Droptimizer import box, THE SITE SHALL
      accept it and show the right spec, talents and equipped items. proves: manual - a browser
      check, and the only proof that matters
<!-- AC:END -->

## Tasks
- [x] Find the real slash key and fix the guard at `Modules/ItemLevel.lua:391`
- [ ] Capture a genuine `/simc` export from that addon and save it under `docs/spec/` as the
      reference the fallback is written against
- [ ] Rewrite the fallback header to match that reference: comment lines, quoted name, and the
      missing `region`, `role` and `professions` keys
- [ ] Add `talents=` from `C_Traits.GenerateImportString`
- [ ] Rewrite the gear loop to split the item link into id, bonus ids, gem ids and enchant id, and
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
