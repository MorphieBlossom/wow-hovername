# <img src="https://raw.githubusercontent.com/MorphieBlossom/wow-hovername/refs/heads/main/media/hovername-icon.png" width="50" height="50"> HoverName

### Version 11.2.0.1 - available for World of Warcraft ![Version](https://img.shields.io/badge/version-11.2.0-blue)

👉 View the [changelog here](https://raw.githubusercontent.com/MorphieBlossom/wow-hovername/master/CHANGELOG.md)

---

### Version 5.5.0.1 - available for World of Warcraft - Mists of Pandaria Classic ![Version](https://img.shields.io/badge/version-5.5.0-blue)

👉 View the [changelog here](https://raw.githubusercontent.com/MorphieBlossom/wow-hovername/master/CHANGELOG_Mists.md)

---

_If you have questions, suggestions or encountering issues - feel free to reach out on [CurseForge](https://www.curseforge.com/wow/addons/hovername) or the [Github project](https://github.com/MorphieBlossom/wow-hovername)_

> [!NOTE]
> This is a continuation from the original addon [ncHoverName](https://www.wowinterface.com/downloads/info16012-ncHoverName.html) by Nightcracker,  
> and fan-update [ncHoverNameFU](https://www.wowinterface.com/downloads/info24902-ncHoverNameFU.html#info) by Narfi@DieAldor (EU)  
> _Credits go to them for the initial code_

---

### What this addon does?
World of Warcraft addon to show basic information about the target upon mouse hover.

<img src="https://raw.githubusercontent.com/MorphieBlossom/wow-hovername/refs/heads/main/media/hovername-player.jpg" height="300"> <img src="https://raw.githubusercontent.com/MorphieBlossom/wow-hovername/refs/heads/main/media/hovername-npcs.jpg" height="300"> <img src="https://raw.githubusercontent.com/MorphieBlossom/wow-hovername/refs/heads/main/media/hovername-quests.jpg" height="300">

---

It will display:

The target's level and name. (Level 1 and ?? are omitted)
- Name is displayed in respective class color for players.
- Name is displayed in standing state color for NPCs (dead, friendly, hostile, hostile but not attackable)

The target's target name
- Class color or default color

The target's status (afk, dnd, pvp flagged)
- Multiple are possible, each in a matching color

The target's classification (world boss, elite, rare, rare elite)
- World boss and Elite in a gold color - to match the gold dragon frame
- Rare and Rare Elite in a silver color - to match the silver dragon frame

The quest objectives related to the target (quest, daily, world quest)
- When there are multiple objectives related to the target, all of the will be shown. The objective(s) completed will stay present, until all objectives are completed. (The target will then be flagged by the API as no more relevant to active quest objectives). The list of objectives is sorted: In Progress > Done.
- Targets that are related to "Progress quests" (Those with %) will show the current % done and in addition (when known in the [LibObjectiveProgress-1.0 library](https://www.curseforge.com/wow/addons/libobjectiveprogress-1-0)) it will show how much that target will add to the %-counter when killed/looted/clicked.
