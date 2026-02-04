local addonName, addon = ...

-- Define the Popup Dialog
StaticPopupDialogs["HOVERNAME_RELEASE_NOTES"] = {
  text = "|cffffd200" .. addon.NAME .. " updated to |r" .. addon.VERSION .. "\n\n%s",
  button1 = "View Changes",
  button2 = "Close",
  OnAccept = function()
    if addon.OptionsScreenID then
      Settings.OpenToCategory(addon.OptionsScreenID)
    end
  end,
  OnCancel = function() end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
}

local Notifications = {}

function Notifications:CheckForUpdatePopup()
  if not addon.Settings or not addon.Settings.Get then return end

  local currentVersion = addon.VERSION
  local lastSeen = addon.Settings:Get("LastSeenVersion")
  local notifyEnabled = addon.Settings:Get("GetNotified")

  if lastSeen ~= currentVersion then
    addon.Settings:Set("LastSeenVersion", currentVersion)

    if notifyEnabled then
      -- Generic message instead of pulling specific changelog lines
      local summary = "|cffccccccNew features have been added in this version. Check out the release notes for what is changed.|r\n\n"
      StaticPopup_Show("HOVERNAME_RELEASE_NOTES", summary)
    end
  end
end

addon.Notifications = Notifications