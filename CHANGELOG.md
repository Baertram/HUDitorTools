# Changelog

## 1.2.0 - Dakjaniels

- Per-element scale and font on the HUD Editor info box (face, size, and outline). Scale is any positive percent and changes the live control only, not the editor preview. Saved fonts reapply after reload.
- Optional LibMediaProvider (13 or newer) adds its font list. Without it, the built-in game fonts are used.
- Extra Edit HUD movers for stock frames the base editor does not own: Battleground score, Objective meter, Player interaction, Player progress, Reticle, Reticle interact, Stealth icon, Ram, and Tutorials.
- Pyramid layout for the player resource bars (health on top, magicka and stamina tucked underneath). It is separate from Combined Resources and only applies while Combined Resources is on.
- Don't expand keeps health, magicka, and stamina at their normal width when max power increases. Bars still shrink when max power drops.
- Grid overlay lines are 1px and aligned to UI units.
- Share strings are HUDT version 3 and include scale, font, pyramid, and don't-expand. Version 1 and 2 strings still import.

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
