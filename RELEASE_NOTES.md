# Release Notes

## Version: 0.9.9

### Fixed

- **"Secret number" compare crash on world-map Area POI hover.** Hovering an Area POI (such as a Delve entrance) on the main world map could throw `attempt to compare a secret number value (execution tainted by 'DjinnisDataTexts')` from `Blizzard_SharedXML/LayoutFrame.lua:491` inside `ResizeLayoutMixin:Layout`, called during `GameTooltip_ClearWidgetSet`. Root cause: DDT routed every hover tooltip (Friends / Guild / Communities row notes, ItemLevel item links, SavedInstances character info, and the Sanctified Banner map pin) through the global `GameTooltip`, which left the tooltip owned by addon-created frames. The next Blizzard `SetOwner` then fired `GameTooltip_OnHide` -> `ClearWidgetSet` -> widget-container layout in tainted execution, where `GetNumPoints` returned a secret value and the `== 0` test errored. All DDT hover sites now route through a private `DDTHoverTooltip` frame (`GameTooltipTemplate`) via the new `ns.GetHoverTooltip()` helper, so the global tooltip is never touched from insecure code.

### Added

- **Delve Sanctified Banner: The Gulf of Memory (Upper Rootway variant)** at `/way 41.32 23.74`. Listed alongside the existing Lower Rootway spawn for the delve so the in-game map pin shows whichever variant is active.
