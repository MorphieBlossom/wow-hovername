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

MBLib._version = "1.0.0"
MBLib._addonName = addonName
MBLib._addon = addon
MBLib._slashTriggers = {}
MBLib._iconPath = nil
MBLib._predecessor = nil
MBLib._initialized = false
MBLib._db = nil
MBLib._optionsScreenID = nil

-- Shared color/icon constants
MBLib.COLOR_ALLIANCE = { r = 0 / 255, g = 112 / 255, b = 221 / 255 }
MBLib.COLOR_COMPLETE = { r = 136 / 255, g = 136 / 255, b = 136 / 255 }
MBLib.COLOR_DEAD = { r = 136 / 255, g = 136 / 255, b = 136 / 255 }
MBLib.COLOR_DEFAULT = { r = 1, g = 1, b = 1 }
MBLib.COLOR_ELITE = { r = 213 / 255, g = 154 / 255, b = 18 / 255 }
MBLib.COLOR_GUILD = { r = 24 / 255, g = 222 / 255, b = 0 }
MBLib.COLOR_HORDE = { r = 1, g = 0, b = 0 }
MBLib.COLOR_HOSTILE = { r = 1, g = 68 / 255, b = 68 / 255 }
MBLib.COLOR_HOSTILE_UNATTACKABLE = { r = 210 / 255, g = 76 / 255, b = 56 / 255 }
MBLib.COLOR_NEUTRAL = { r = 1, g = 1, b = 68 / 255 }
MBLib.COLOR_RARE = { r = 226 / 255, g = 228 / 255, b = 226 / 255 }
MBLib.ICON_CHECKMARK = "|TInterface\\RaidFrame\\ReadyCheck-Ready:11|t"
MBLib.ICON_LIST = "- "

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
