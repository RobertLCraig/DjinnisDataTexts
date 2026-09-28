# Delve tracker: recognise 12.1.0 Lairs

## What I need from you

**Walk these four steps in the game and tick or report each.** This is one of the two checks
holding the 0.9.16 release.

**Not deployed yet.** The review's fix is on branch `claude/0008`, not `master`, because another
session was committing to `master` at the time. First, in `C:\Dev\WoWAddons\DjinnisDataTexts`:
`git merge claude/0008`. Then from `C:\Dev\WoWAddons`: `.\bin\deploy.ps1 -WhatIf -Only
DjinnisDataTexts`, read the plan, run it again without `-WhatIf`, and `/reload`.

1. **Outside any delve**, hover the Active Activity DataText with Delve shown.
   Expect: the idle text as before (the word "Lair" appears nowhere), tooltip header
   "Delve Tracker". No Lua error.
2. **Queue into a Lair** from the group finder and enter it. Look at the bar, then hover.
   Expect: label starts `Lair:`, tooltip header reads "Lair Tracker", and the companion XP line
   reads "This Lair:". (Ticks #1.)
3. **Enter an ordinary delve.**
   Expect: `Delve:` label, "Delve Tracker" header, "This Delve:" XP line, exactly as before 12.1.0. (Ticks #2.)
4. Open `/ddt`, then the Delve panel, and look at the label template box.
   Expect: it shows `<kind>: <progress>` if you never changed it, or your own template if you did. (Ticks #3 and #4.)

**Pass:** all four as expected, and BugSack / the error frame stays empty.

**Fail:** a Lair still reads "Delve" anywhere in the label or header, or any Lua error. Paste
the error or a screenshot into `## Comments` and move the card to `todo/`.

**Why it needs you:** only a live client can put you in a Lair. Nothing here can run the game.

## Why
Patch 12.1.0 went live on 2026-08-18 and added **Lairs**, a delve you can queue for
through the group finder. The game reports every Lair as an active delve. Blizzard says so
in its own code, `Interface/AddOns/Blizzard_FrameXML/InstanceDifficulty.lua:51`:

> `-- every lair is a delve, but not every delve is a lair.`

So our tracker fires inside a Lair and labels it "Delve". Only `C_DelvesUI.IsInLair()`,
new in 12.1.0, tells the two apart.

Checked against `C:\Dev\WoWAddons\wow-ui-source` at `12.1.0 (69382)`, diffed from the last
12.0.7 build. Nothing else in the delve UI moved that we consume: the
`ScenarioHeaderDelves` widget we read is byte-identical and was only relocated out of
`Blizzard_UIWidgets/Mainline/`, and no `C_DelvesUI` function we call was removed or changed.

## Not this card
- The new companion **Flavor** curio slot (`Enum.CompanionConfigSlotTypes.Flavor`, plus
  `GetFlavorNodeForCompanion` / `GetFlavorNodeNameForCompanion`). We show companion level
  and XP only, never curios, so there is nothing to render.
- `HasActiveLair()` and `HasActiveLFGLair()`. We need to know we are in one, not how we got
  in. `HasActiveLFGLair` only matters to the difficulty picker's queue button.
- The new `GetTieredEntranceTierInfo` fields (`queueAsLFG`, `difficultyID`,
  `overrideTooltipSpellID`). Only Blizzard's difficulty picker reads them. We do not.
- New `BANNER_LOCATIONS` entries. Whether 12.1.0 added delve maps cannot be answered from
  `wow-ui-source`, which carries no map data. An unknown delve simply shows no map pin.

## Acceptance
<!-- AC:BEGIN -->
- [ ] #1 WHEN the player is inside a Lair, THE APP SHALL show "Lair" rather than "Delve" in
      the DataText label and in the tooltip header.
- [ ] #2 WHEN the player is inside an ordinary delve, THE APP SHALL show "Delve" exactly as
      it did before 12.1.0.
- [ ] #3 WHEN a user's saved label template still equals the old default
      `Delve: <progress>`, THE APP SHALL rewrite it once to `<kind>: <progress>` on load.
- [ ] #4 IF a user typed their own label template, THEN THE APP SHALL leave it untouched.
- [ ] #5 WHEN the addon loads on a client without `C_DelvesUI.IsInLair`, THE APP SHALL fall
      back to "Delve" and raise no Lua error.
<!-- AC:END -->

## Tasks
- [x] Diff `wow-ui-source` 12.0.7 to 12.1.0 across the delve UI and API docs, and record what
      we consume against what changed.
- [x] Add an `inLair` state flag to `Modules/Delve.lua`, resolved once per `UpdateData` from
      `C_DelvesUI.IsInLair()` behind a `pcall`.
- [x] Add a `KindLabel()` helper and a `<kind>` label tag; change the default template to
      `<kind>: <progress>`.
- [x] Use it for the tooltip header and for the delve-name fallback.
- [x] List the new tag and the new default preset in the settings panel.
- [x] Add schema migration v2 in `Core.lua` for users still on the old default template.
- [x] Confirm both files parse under Lua 5.1.
- [ ] **Verify in the game client.** `pwsh -File deploy.ps1`, `/reload`, enter a Lair and an
      ordinary delve, and check acceptance #1 to #4. This is the only real check this
      project has, and none of the above has been run.

## Comments

**2026-09-29** ADVERSARIAL REVIEW (unattended, agent). Verdict: the code meets all five
criteria as far as anything outside a game client can tell; moved to `human-review/` because
#1 to #4 are only settled in the client. No criterion names a runnable test; the four steps
above are the proof.

Attacked, and held:
- **API.** `C_DelvesUI.IsInLair` checked in `wow-ui-source` (now at `12.1.0 (69933)`, newer than
  the build the card was written against): `DelvesUIDocumentation.lua:431`, returns a
  non-nilable `bool`, no `SecretReturns` or restriction flag, so the secret-value trap does not
  apply. Blizzard calls it unguarded in `InstanceDifficulty.lua:50`.
- **#3 and #4, the migration.** Lifted `SCHEMA_VERSION` through `RunSchemaMigrations` out of the
  real `Core.lua` into a throwaway Lua harness and ran five cases: old default migrates, a
  custom template is kept, a v1 database still migrates, a v2 database is not re-run, a fresh
  install with no `delve` table is untouched. All pass. Mutating the `== old` guard to `true`
  turns "custom template kept" red, so the harness can fail. Every user who ever loaded the
  addon has the old default saved (the defaults merge writes it), so the migration reaches
  everyone it should.
- **#5.** `IsInLair` is behind `C_DelvesUI and C_DelvesUI.IsInLair` and a `pcall`, and falls
  back to `false`, so `KindLabel()` returns "Delve". Moot in practice: the `.toc` is `120100`
  only.
- **Tag order.** `<kind>` expands before `<name>`, so a delve name cannot inject a tag.

Broke, and fixed in place:
- **The companion XP line still said "This Delve:" inside a Lair** (`Modules/Delve.lua`, the
  session/delve summary rows). The card's own helper comment promises "every player-facing
  place that names the content type"; that row was missed. Now `"This " .. KindLabel()`.
  Parses under `luac -p`. Step 2 above checks it.

Security (code card): **weakest point** is the one new external read, `IsInLair`, and it is a
plain bool behind a `pcall`. **Unchecked path:** none new; the template is the user's own
string, expanded only by `ns.ExpandTag` into a FontString. **Leaks:** nothing; the addon has no
network or cross-character surface here, and a failed read degrades to the old "Delve" label.

Not this card, noted: `Delve:Init` registers eleven events in a row without the
`IsEventRegistered` check the workspace 2026-08-21 decision asks for. It predates this card and
none of those events is known to be protected, so no card opened.

