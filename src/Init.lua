local addonName, addon = ...
local LOP = LibStub:GetLibrary("LibObjectiveProgress-1.0")

-- SavedVariables must be declared in .toc:
local dbName = addonName .. "Data"
addon.DB_Name = dbName

-- Expose libraries
addon.LOP = LOP

-- Constant values
addon.COLOR_DEFAULT = { r = 1, g = 1, b = 1 }
addon.COLOR_DEAD = { r = 136 / 255, g = 136 / 255, b = 136 / 255 }
addon.COLOR_HOSTILE = { r = 1, g = 68 / 255, b = 68 / 255 }
addon.COLOR_NEUTRAL = { r = 1, g = 1, b = 68 / 255 }
addon.COLOR_HOSTILE_UNATTACKABLE = { r = 210 / 255, g = 76 / 255, b = 56 / 255 }
addon.COLOR_RARE = { r = 226 / 255, g = 228 / 255, b = 226 / 255 }
addon.COLOR_ELITE = { r = 213 / 255, g = 154 / 255, b = 18 / 255 }
addon.COLOR_COMPLETE = { r = 136 / 255, g = 136 / 255, b = 136 / 255 }
addon.ICON_CHECKMARK = "|TInterface\\RaidFrame\\ReadyCheck-Ready:11|t"
addon.ICON_LIST = "- "

-- Define additional configurable slash commands here; /addonName is always registered
addon.COMMANDS_TRIGGERLIST = { "/hn" }


-- Create a temporary frame to register for the ADDON_LOADED event
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(self, event, name)
  if name == addonName then
    _G[dbName] = _G[dbName] or {}
    addon.DB = _G[dbName]
    addon.Settings:Init()

    -- Clean up the temporary frame
    self:UnregisterEvent("ADDON_LOADED")
    self:SetScript("OnEvent", nil)
  end
end)
