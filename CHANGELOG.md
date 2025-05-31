# Changelog
All notable changes to this project will be documented in this file.

---
### `11.1.7.0` (2025-05-31)
**Version update**
- Updated to game version 11.1.7

**Improvements**
- Changed some underlying structure to now also include slash commands and able to store settings.

**Fixes**
- Improved some check to catch 'exceptional' cases from other AddOns making "bad" frames, such as OPie having a nameless overlay frame, that causes HoverName to no longer trigger.

---
### `11.1.5.0` (2025-04-22)
**Version update**
- Updated to game version 11.1.5

---
### `11.1.0.0` (2025-02-20)
**Version update**
- Updated to game version 11.1.0

---
### `11.0.7.2` (2025-02-03)
**Improvements**
- For targets that are counting to multiple objectives it will now show all of them.
Sorted based on completion; once all objectives are complete the displayed objectives will be hidden again.

---
### `11.0.7.1` (2025-02-02)
**New things**
- Targets that are part of an active (world) quest will now have that quest objective displayed.
Those that are part of a "progress" quest will also display the amount of percentage they will yield
towards the total progress (thanks to the ObjectiveProgress library).

---
### `11.0.7.0` (2024-12-20)
**Version update**
- Updated to game version 11.0.7

---
### `11.0.5.0` (2024-10-23)
**Version update**
- Updated to game version 11.0.5

---
### `11.0.0.4` (2024-08-02)
**Fixes**
- Fixed issue that caused in some cases the text to never be displayed at all. But somehow not everyone was affected by it.

---
### `11.0.0.3` (2024-08-02)
**New things**
- Added now also display text for unit classification - e.g. World Boss, Elite, Rare and Rare Elite. These are displayed above the level and name.
- Added a new status "pvp" - which will be displayed if a player has pvp enabled.

**Improvements**
- Moved the status display (Afk, Dnd) of the target above the level and name display so that not everything is on one line; reduced the font-size of it a little.
- Changed some of the colors used to match them more with the standard used colors.
- Took some time to clean up the original code; added bit more structure and improved reusability of code.

**Fixes**
- The target's target name will now also be properly displayed in the correct class color.

---
### `11.0.0.2` (2024-07-27)
**Improvements**
- Updated addon version to match WoW version, this will make it easier to see if the version is suitable for the current patch. Formatted as: `[warcraft version].[addon build]`

**Fixes**
- Fixed issue that could cause Lua error when there is no UnitName.

---
### `1.1` (2024-07-26)
Re-created the project.

**Fixes**
- Fixed issues caused by the WoW API changes for game version 11.0.0.
