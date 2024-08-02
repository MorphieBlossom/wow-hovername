# Changelog
All notable changes to this project will be documented in this file.

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
- Fixed issues caused by the WoW API changes for version 11.0.0.
