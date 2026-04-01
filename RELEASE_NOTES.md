# Release Notes

## Version: 0.5.1 — 2026-04-01

### ItemLevel: Durability Tracking + Auctionator Category Search + Bug Fixes

This release significantly expands the Item Level module with real-time durability tracking, fixes several tooltip display issues, and upgrades the Auctionator enchant search to use proper category filters.

#### Durability Tracking

- **Per-slot durability column** — Dedicated right-hand column in the tooltip showing each slot's durability percentage, color-coded: green (100%), yellow (<100%), orange (≤50%), red (≤25%)
- **Overall durability summary** — Header line showing weighted average durability across all gear with the same color coding
- **Needs Repair summary** — Lists all slots below 100% durability at the bottom of the tooltip
- **Label template tags** — `<durability>` (lowest slot %) and `<repair>` (count of slots needing repair)
- **Settings** — Toggle durability display on/off; threshold slider controls the % below which per-slot values appear
- **Live updates** — Registers `UPDATE_INVENTORY_DURABILITY` event for immediate refresh

#### Auctionator Enchant Search

- Right-clicking a slot row (default) now opens an Auctionator shopping list using the advanced category filter format:
  `;Item Enhancements/<Slot>;...;CurrentExpansion;` — no search term, just the category + current expansion filter
- Slots map correctly: Finger → Finger subcategory, Feet → Feet, Weapon → Weapon, etc.
- Gem search similarly scoped to the Gems category + current expansion
- Bulk shopping list (Ctrl+L) uses the same format for all missing enchants

#### Bug Fixes

- **Settings crash** — Fixed `AddSlider` being called with a table argument instead of positional args, which blocked the entire settings panel from loading (breaking `/ddt` and Options → Addons)
- **CopyToClipboard** — Removed call to the hardware-protected `CopyToClipboard()` global; now always shows a scrollable popup editbox (Ctrl+A, Ctrl+C, Escape)
- **SlashCmdList nil** — Added nil guard before calling `SlashCmdList["SIMULATIONCRAFT"]`
- **LDB dataobj nil** — Added `LDB:GetDataObjectByName()` fallback for when the LDB name is already registered on reload
- **Tooltip row overlap** — Label is now bounded by the status column so slot names never overlap "No Enchant" or socket warnings
- **Summary row overflow** — Missing Enchants / Missing Gems / Needs Repair summary rows now use the full row width (slot list in label, value/status cleared)
- **Frame type** — Tooltip rows now correctly created as `Button` frames (required for `OnClick` and `RegisterForClicks`)

#### Friends Module

- Fixed class color detection: removed access to undocumented `FriendInfo` fields (`classTag`, `classFileName`, `classFile`, `classToken`); now uses only `className` (localized lookup) and the documented fields
- Fixed BNet friends class detection similarly — removed nonexistent `classTag`/`classFile`/`classToken` from `BNetGameAccountInfo`
