local addonName, addon = ...
local MBLib = addon.MBLib

local Notifications = {}
local popupKey = addonName:upper() .. "_RELEASE_NOTES"

StaticPopupDialogs[popupKey] = {
  text = "|cffffd200" .. (C_AddOns.GetAddOnMetadata(addonName, "Title") or addonName)
    .. " updated to |r" .. (C_AddOns.GetAddOnMetadata(addonName, "Version") or "") .. "\n\n%s",
  button1 = "View Changes",
  button2 = "Close",
  OnAccept = function()
    if MBLib._optionsScreenID then
      Settings.OpenToCategory(MBLib._optionsScreenID)
    end
  end,
  OnCancel = function() end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
}

function Notifications:CheckForUpdatePopup()
  if not MBLib.Settings or not MBLib.Settings.Get then return end

  local currentVersion = C_AddOns.GetAddOnMetadata(addonName, "Version")
  local lastSeen = MBLib.Settings:Get("LastSeenVersion")
  local notifyEnabled = MBLib.Settings:Get("GetNotified")

  if lastSeen ~= currentVersion then
    MBLib.Settings:Set("LastSeenVersion", currentVersion)

    if notifyEnabled then
      local changelist = (MBLib.Changelog and MBLib.Changelog.list) or {}
      local shouldNotify = false

      for _, entry in ipairs(changelist) do
        if lastSeen == nil or lastSeen == "" then
          if entry.notify then shouldNotify = true; break end
        else
          if entry.version == lastSeen then break end
          if entry.notify then shouldNotify = true; break end
        end
      end

      if shouldNotify then
        local summary = "|cffccccccNew features have been added in this version. Check out the release notes for what is changed.|r\n\n"
        StaticPopup_Show(popupKey, summary)
      end
    end
  end
end

MBLib.Notifications = Notifications
