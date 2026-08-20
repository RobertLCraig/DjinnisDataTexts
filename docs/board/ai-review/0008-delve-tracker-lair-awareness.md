# Delve tracker: recognise 12.1.0 Lairs

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
