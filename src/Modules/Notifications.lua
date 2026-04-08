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
      -- Only show popup when there are unseen changelog entries that have notify = true
      local changelist = (addon.Changelog and addon.Changelog.list) or {}
      local shouldNotify = false

      for i, entry in ipairs(changelist) do
        if lastSeen == nil then
          if entry.notify then shouldNotify = true; break end
        else
          if entry.version == lastSeen then break end
          if entry.notify then shouldNotify = true; break end
        end
      end

      if shouldNotify then
        local summary = "|cffccccccNew features have been added in this version. Check out the release notes for what is changed.|r\n\n"
        StaticPopup_Show("HOVERNAME_RELEASE_NOTES", summary)
      end
    end
  end
end

addon.Notifications = Notifications