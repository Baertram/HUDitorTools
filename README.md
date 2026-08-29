# HUDitor Tools

Extra tools for the base-game HUD editor added in Update 51.

[ESOUI](https://www.esoui.com/downloads/info4750) · Authors: [@dack_janiels](https://github.com/DakJaniels), [Baertram](https://github.com/Baertram)

## Compatibility

Only for API version 101051 - eso.rc.12.1.0.3285845 +

## Dependencies

- [LibAddonMenu-2.0](https://www.esoui.com/downloads/info7-LibAddonMenu-2.0.html)
- [LibScrollableMenu](https://www.esoui.com/downloads/info3546-LibScrollableMenu.html)

## Features

### HUD layouts

Named snapshots of the live HUD (`HUD_MANAGER` profile 1). Save, switch, rename, and delete them from the HUD Editor Info Box (below Reset All), the Info Box settings gear, or `/hudis`.

- Account layouts are shared by every character.
- Character layouts are stored per character. The base-game HUD is still account-wide, so the last character layout you used is reapplied when that character logs in (and overwrites the shared live HUD for that session).
- First load creates an account layout named **Default** from whatever HUD you already have. It is not reapplied.
- Cap: 20 account layouts and 20 character layouts.
- Unsaved changes (live HUD differs from the selected layout) mark the dropdown name with `*` and ask before switching.
- Import pastes a `HUDT` share string, asks for a **new name**, and applies the layout. Export shows the string and selects it so you can press **Ctrl+C**. Addons cannot write the clipboard.
- Addon-registered HUD elements (same `RegisterKeyboardElement` API) are included. A layout that does not mention an addon control **clears** that control's saved row, so it jumps back to its default until you save again. Imported rows for addons that are not loaded this session stay in SavedVars and apply when that addon loads.

### HUD Editor

- Customizable grid (color, alpha, size)
- Snap elements to the grid
- Right-click context menu on HUD elements:
  - Hide / show elements **in the HUD editor** (not on the live HUD) so you can find and move things more easily
  - Reset position
- Border / fill color for HUD-hidden elements (default red). This is the element's own Visible checkbox on the live HUD, not the editor hide above.
- Live color picker for grid, selected, unselected, and hidden element colors. Changes apply immediately. The picker is movable and remembers its position. Reset restores the active slot.

### Info Box (selected element)

- Layout dropdown (account and character), Save / New / Import / Export / Rename / Delete. These stay on the Info Box even when the settings gear is enabled.
- Search the elements dropdown by display name / control name (collapsible search header)
- Right-click context menu to hide / show elements in the HUD editor
- User-hidden entries are marked with `-` around the name and colored with the hidden-element color
- Settings button (gear, top left) when enabled in LAM:
  - Always show element names (not only on mouse over or selection)
  - Hide names with a width `<= n` (slider)
  - Show Grid
  - Grid Snap
  - Grid size
  - Show color picker
  - Colors submenu (Grid / Selected / Unselected / Hidden)
  - HUD layouts (Save / New / Import / Export / Rename / Delete)
- If the settings button is disabled, grid options and the color-picker toggle stay on the Info Box options section

Configure settings in the LibAddonMenu panel (`/hudis`). Some options only appear on the Info Box when the settings context menu is enabled in LAM.

-Jabba the HUD, approved-

See [CHANGELOG.md](CHANGELOG.md) for release history.

## License / terms

This Add-on is not created by, affiliated with or sponsored by ZeniMax Media Inc. or its affiliates. The Elder Scrolls® and related logos are registered trademarks or trademarks of ZeniMax Media Inc. in the United States and/or other countries. All rights reserved.

You can read the full terms at <https://account.elderscrollsonline.com/add-on-terms>
