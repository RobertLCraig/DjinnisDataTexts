# Release Notes

## Version: 0.5.3 — 2026-04-02

### Gold Display Fixes + Settings Label Template UX Improvements + Startup Data Load

#### Gold Display

- **Colorize now applies to datatexts** — `FormatGoldShort()` now respects `goldColorize`, `goldShowSilver`, and `goldShowCopper` global settings, matching `FormatGold()` behavior; gold in all module labels (Currency, BagValue) now colors correctly
- **Gold settings changes refresh immediately** — toggling colorize/silver/copper in General settings now calls `UpdateData()` on all modules, so labels refresh without needing a mouseover
- **Number format preset change also refreshes modules** — changing the format preset now propagates to all module labels immediately

#### Settings Label Template UX

- **Label Template editor lifted out of scroll frame** — the template editbox and tag buttons now render in a fixed header above the scroll area, resolving the persistent "blank editbox on first load" issue caused by WoW's EditBox text not rendering inside scroll children
- **Editbox pre-populated on panel show** — panels now start hidden so `OnShow` fires when Blizzard Settings displays them, ensuring the refresh callback correctly populates the editbox
- **Tag insertion at cursor** — clicking a tag button now inserts at the last cursor position rather than appending to the end; cursor position is saved on focus loss (before the tag button's OnClick fires)
- **Live template updates** — `OnTextChanged` commits the value as you type; no need to press Enter

#### Startup Data Load

- **Initial data load on login/reload** — all modules now call `UpdateData()` 1 second after addon load, so datatexts are populated immediately rather than waiting for the first mouseover
- **Periodic background refresh** — all modules refresh every 3 minutes automatically, keeping labels current without user interaction

#### SpecSwitch

- **Direct spec switching via click actions** — `spec1`/`spec2`/`spec3`/`spec4` click actions added; switch to a specific spec directly from the datatext
- **Spec names in dropdown** — click action dropdown shows "Switch to Arms" instead of "Switch to Spec 1"; spec names resolved once on first data load
