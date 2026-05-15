# MBLib

Shared library for MorphieBlossom's World of Warcraft addons. Bundles common building blocks (settings UI, slash commands, changelog viewer, update-notification popup, font lookup, generic utils) so each addon only ships the code unique to its own feature set.

## Loading model

MBLib is **embedded** into each consumer addon at build time — there is no global "MBLib" addon to install. The source files are dropped under `Libraries/MBLib/` inside the consumer and loaded via `MBLib.xml`.

**MBLib does not register with LibStub.** Each consumer's embedded copy attaches a private `addon.MBLib` to its own addon namespace. Different consumer addons can ship different MBLib versions side-by-side without conflict, because the two copies never share an object — each lives on its own consumer's `addon` table.

(LibStub itself is still vendored and loaded by MBLib because [Modules/Fonts.lua](src/Modules/Fonts.lua) consumes it to look up LibSharedMedia-3.0. That's a consumer-of-LibStub relationship; MBLib does not register itself with LibStub.)

## Consumer integration

In the consumer's `.toc`, load MBLib **before** any consumer file that touches `addon.MBLib`:

```toc
Libraries\MBLib\MBLib.xml
Init.lua
Modules\Settings.lua
Modules\MyFeature.lua
...
```

In the consumer's `Init.lua`:

```lua
local addonName, addon = ...

-- Configure (call before Init)
addon.MBLib:AddSlashTrigger("/hn")  -- optional; default trigger is /<addonname>
addon.MBLib:SetIcon("Interface\\AddOns\\HoverName\\Media\\hovername-icon.png")  -- optional
addon.MBLib:SetPredecessor("ncHoverName")  -- optional; renders X-PrevAuthor* line in the options panel

-- Register data (typically split across the consumer's own module files)
addon.MBLib.Settings:Add({
  { Key = "Display_FontSize", Name = "Font Size", Group = "Display", Type = "slider",
    Min = 8, Max = 30, Step = 1, Default = 12 },
  -- ...
})
addon.MBLib.Changelog:Set({
  { version = "12.0.5.1", date = "2026-04-27", notify = true,
    categories = { ["New"] = { "Added foo.", "Added bar." } } },
  -- ...
})
addon.MBLib.Commands:Add("mycmd", {
  desc = "Do my thing",
  func = function(arg) ... end,
})

-- Bootstrap once SavedVariables are available
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, _, name)
  if name == addonName then
    addon.MBLib:Init()
    self:UnregisterEvent("ADDON_LOADED")
  end
end)
```

## API surface

Everything provided by MBLib lives under `addon.MBLib`. The consumer addon's own modules can attach freely at `addon.<Whatever>` without name collisions.

| Field                          | What                                                                          |
|--------------------------------|-------------------------------------------------------------------------------|
| `addon.MBLib`                  | Library root. `AddSlashTrigger`, `GetSlashTriggers`, `SetIcon`, `GetIcon`, `SetPredecessor`, `GetPredecessor`, `Init`. |
| `addon.MBLib.Utils`            | `IsNotEmpty`, `GetTextWithColor`, `DebugLog`, `CombineText`, `CombineTables`, `GetNpcID`, `GetTooltipData`, `GetTopMouseFocusName`, `IsInTooltip`, `CreateCopyableLink`, `CreateSeparator`. |
| `addon.MBLib.Fonts`            | `GetAvailableFonts` (LSM-aware via LibStub).                                  |
| `addon.MBLib.Settings`         | `Add`, `Get`, `Set`, `ToggleDebug`. Pre-seeded with `DebugLogging`, `GetNotified`, `LastSeenVersion`. |
| `addon.MBLib.Commands`         | `Add`, `GetTriggers`, `GetFormattedCommandStr`. Pre-seeded with `help`, `debug`, `version`, `settings`. |
| `addon.MBLib.Changelog`        | `Set`, `Build`.                                                               |
| `addon.MBLib.Notifications`    | `CheckForUpdatePopup` (popup is keyed `<ADDONNAME>_RELEASE_NOTES`).            |
| `addon.MBLib.OptionsScreen`    | `Build`. Registers a Blizzard settings category and a Release Notes subcategory. |
| `addon.MBLib.COLOR_*`          | Shared color tables (`COLOR_ALLIANCE`, `COLOR_HORDE`, `COLOR_ELITE`, etc.).   |
| `addon.MBLib.ICON_*`           | `ICON_CHECKMARK`, `ICON_LIST`.                                                |

`addon.MBLib:Init()` opens SavedVariables into `MBLib._db`, runs `Settings:Init`, registers slash handlers, builds the OptionsScreen, and schedules the update popup check.

## Building & syncing

```pwsh
# Produce build/MBLib-v<version>.zip
pwsh ./build.ps1

# Also copy into a sibling consumer addon's Libraries/MBLib/ for dev iteration
pwsh ./build.ps1 -SyncTo ../wow-hovername/src
```

## Layout

- [src/MBLib.xml](src/MBLib.xml) — embed entrypoint referenced from consumer `.toc`s. Loads LibStub, [src/Init.lua](src/Init.lua), then each module in order.
- [src/MBLib.toc](src/MBLib.toc) — metadata for `build.ps1` (version, dates). Not used for runtime loading.
- [src/Init.lua](src/Init.lua) — initializes `addon.MBLib`, attaches constants, defines top-level config methods (`SetIcon`, `SetPredecessor`, `AddSlashTrigger`, `Init`).
- [src/Modules/](src/Modules/) — each file attaches one module to `addon.MBLib` directly. State lives on the module table; methods close over the file's `addon`/`addonName` upvalues, so each consumer's copy gets its own state and method bindings naturally.
- [src/Libraries/LibStub/LibStub.lua](src/Libraries/LibStub/LibStub.lua) — vendored, public-domain. Consumed by Fonts for LSM lookup.
