local addonName, addon = ...
local Settings = {};
local DefaultSettings = {
  DebugLogging = false,
};

-- Internal helper for printing setting changes or logs
local function Log(name, value, isError)
  if isError == nil then isError = false end

  local prefix = string.format("|cffff8000%s|r", addonName) -- Legendary
  local nameText = string.format("|cff00ffff%s|r", name)    -- Cyan
  local message

  if isError then
    -- For errors: "AddonName - Name: Message"
    message = string.format("%s - %s: %s", prefix, nameText, string.format("|cffffff00%s|r", tostring(value)))
  else
    -- For normal logs: "AddonName - Name: changed to Value"
    message = string.format("%s - %s changed to %s", prefix, nameText, string.format("|cffffff00%s|r", tostring(value)))
  end

  print(message)
end

function Settings:Init()
  addon.DB.Settings = addon.DB.Settings or {}

  for key, default in pairs(DefaultSettings) do
    if addon.DB.Settings[key] == nil then
      addon.DB.Settings[key] = default
    end

    Settings[key] = addon.DB.Settings[key]
  end
end

--- Update a named setting, syncing both saved data and in-memory cache
function Settings:Set(key, value, altValue)
  addon.DB.Settings[key] = value
  Settings[key] = value
  Log(key, altValue or value)
end

-- Toggle the debug flag on or off using a boolean value
function Settings:ToggleDebug(state)
  if type(state) ~= "boolean" then
    Log("Error", "ToggleDebug expects a boolean (true/false)", true)
    return
  end

  self:Set("DebugLogging", state, state and "ON" or "OFF")
end

-- Expose module
addon.Settings = Settings
