local addonName, addon = ...

-- MBLib (MorphieBlossom Lib)
--
-- Embedded into each consumer addon at build time. Every consumer carries its own
-- private MBLib under `addon.MBLib`; no global registration, no LibStub for MBLib
-- itself, no version racing. Different consumer addons can ship different MBLib
-- versions side-by-side without conflict.
--
-- (LibStub is still vendored under Libraries/ because MBLib's Fonts module uses it
-- to fetch LibSharedMedia. That is a consumer-of-LibStub relationship, separate
-- from MBLib's own loading model.)
--
-- Load order in the consumer's .toc must put MBLib before any consumer file that
-- references addon.MBLib, e.g.:
--   Libraries\MBLib\MBLib.xml
--   Init.lua
--   ...
--
-- Consumer usage:
--   local addonName, addon = ...
--   addon.MBLib:AddSlashTrigger("/hn")
--   addon.MBLib:SetIcon("Interface\\AddOns\\HoverName\\Media\\hovername-icon.png")
--   addon.MBLib:SetPredecessor("ncHoverName")
--
--   addon.MBLib.Settings:Add({ ... })
--   addon.MBLib.Changelog:Set({ ... })
--   addon.MBLib.Commands:Add("foo", { desc = ..., func = ... })
--
--   -- bootstrap from the consumer's ADDON_LOADED handler:
--   addon.MBLib:Init()

addon.MBLib = addon.MBLib or {}
local MBLib = addon.MBLib

MBLib._version = "1.0.4"
MBLib._addonName = addonName
MBLib._addon = addon
MBLib._slashTriggers = {}
MBLib._iconPath = nil
MBLib._predecessor = nil
MBLib._initialized = false
MBLib._db = nil
MBLib._optionsScreenID = nil
MBLib._debugEnabled = false

-- Generic "debug mode is on" toggle. Opt-modules (the icon-picker dump
-- pipeline, for instance) check this to gate their developer-facing
-- behavior. Consumer addons that ship their own debug page mirror their
-- toggle into here via MBLib:SetDebugEnabled so MBLib's internals can
-- self-gate without each opt-module having to register a callback.
function MBLib:IsDebugEnabled()
  return self._debugEnabled == true
end

function MBLib:SetDebugEnabled(on)
  self._debugEnabled = on and true or false
end

-- Shared constants (colors, icons, addon list) live in CoreModules/Constants.lua,
-- loaded immediately after this file by MBLib.xml.

-- Add an extra slash trigger to the addon. The default trigger `/<addonname>` is
-- always registered; this adds additional ones.
function MBLib:AddSlashTrigger(token)
  if type(token) ~= "string" or token == "" then return end
  for _, existing in ipairs(self._slashTriggers) do
    if existing == token then return end
  end
  table.insert(self._slashTriggers, token)
end

function MBLib:GetSlashTriggers()
  return self._slashTriggers
end

-- Optional. Texture path rendered in the OptionsScreen header. Unset = no icon.
function MBLib:SetIcon(path)
  self._iconPath = path
end

function MBLib:GetIcon()
  return self._iconPath
end

-- Optional. Names a predecessor addon to render a "continuation from <name> by <authors>"
-- line on the OptionsScreen. Authors are read from TOC fields X-PrevAuthor1..5.
function MBLib:SetPredecessor(name)
  self._predecessor = name
end

function MBLib:GetPredecessor()
  return self._predecessor
end

-- Optional. Overrides the label of the settings subcategory built by
-- OptionsScreen (the page that hosts all consumer-registered settings).
-- Defaults to "Display Settings" when not set.
function MBLib:SetSettingsSubcategoryName(name)
  if type(name) ~= "string" or name == "" then return end
  self._settingsSubcategoryName = name
end

function MBLib:GetSettingsSubcategoryName()
  -- Hard fallback "Display Settings" stays here in addition to L because
  -- GetSettingsSubcategoryName may be reached before Strings.lua loads in
  -- pathological consumer code paths.
  return self._settingsSubcategoryName or (self.L and self.L.SETTINGS_SUBCATEGORY_DEFAULT) or "Display Settings"
end

-- Bootstrap: open SavedVariables, init Settings, register slash handlers, build the
-- options screen, schedule the update popup check.
-- Call once from the consumer's ADDON_LOADED handler after registering data.
function MBLib:Init()
  if self._initialized then return end
  self._initialized = true

  local dbName = self._addonName .. "Data"
  _G[dbName] = _G[dbName] or {}
  self._db = _G[dbName]

  if self.Settings and self.Settings.Init then
    self.Settings:Init()
  end
  if self.Fonts and self.Fonts.RegisterEmbeddedFonts then
    pcall(self.Fonts.RegisterEmbeddedFonts, self.Fonts)
  end
  if self.Commands and self.Commands.RegisterSlashHandlers then
    self.Commands:RegisterSlashHandlers()
  end
  if self.OptionsScreen and self.OptionsScreen.Build then
    pcall(function() self.OptionsScreen:Build() end)
  end
  if self.Notifications and self.Notifications.CheckForUpdatePopup then
    C_Timer.After(2, function() self.Notifications:CheckForUpdatePopup() end)
  end
end
