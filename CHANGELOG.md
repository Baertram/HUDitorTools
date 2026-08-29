# Changelog

## 1.1.0 - Dakjaniels

- Named HUD layouts (20 per account, 20 per character). Khajiit is impressed you have this many characters. Khajiit is also concerned. Features Save / New / Rename / Delete.
- Import and export via compact `HUDT` share strings (Ctrl+C in the export dialog; addons cannot write the clipboard)
- Layout controls on the HUD Editor Info Box, plus the settings gear menu and `/hudis`
- Switching a character layout reapplies it on login because the base-game HUD is account-wide
- A layout that omits an addon HUD element clears that element's saved position (it returns to default)
- Fix `/hudis` LAM crash: Active layout dropdown now uses tables plus `UpdateChoices` (LAM does not accept functions for `choices`)
- Optional chat messages (off by default): layout apply details and HUD editor hide/show notices

## 1.0.2 - Dakjaniels

- Added live color picker in the HUD editor (grid, selected, unselected, and hidden element colors)
- Color changes apply immediately while editing; reset per color; picker is movable and remembers its position
- Toggle the picker from the InfoBox, the settings context menu, or the Colors submenu
- HUD element colors now include fill (not just the border)
- Grid overlay optimizations

## 1.0.1 - Baertram

- Renamed addon
- Added new features

## 1.0 - Dakjaniels

- Initial release as HUDGridSnap
- HUD grid with grid snap and customizable grid size
