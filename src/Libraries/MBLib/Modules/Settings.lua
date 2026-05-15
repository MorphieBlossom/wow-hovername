local addonName, addon = ...
local MBLib = addon.MBLib

local Settings = {}
local pendingSliderLogs = {}

-- Library-provided baseline. Consumer extends via Settings:Add(...).
Settings.definitions = {
  {
    Key = "DebugLogging",
    Name = "Debug Logging",
    Description = "Enable debug logging for the addon",
    Group = "General",
    Type = "checkbox",
    Default = false,
    Hide = true,
  },
  {
    Key = "GetNotified",
    Name = "Notify me on updates",
    Description = "Enable notifications for (important) updates of newly added features",
    Group = "General",
    Type = "checkbox",
    Default = true,
    Hide = true,
  },
  {
    Key = "LastSeenVersion",
    Name = "Last seen version",
    Group = "General",
    Type = "text",
    Default = "",
    Hide = true,
  },
}

Settings.byKey = {}
Settings.byGroup = {}
Settings.groupOrder = {}

local function RebuildIndex()
  Settings.byKey = {}
  Settings.byGroup = {}
  Settings.groupOrder = {}
  for _, def in ipairs(Settings.definitions) do
    Settings.byKey[def.Key] = def
    if not Settings.byGroup[def.Group] then
      Settings.byGroup[def.Group] = {}
      table.insert(Settings.groupOrder, def.Group)
    end
    table.insert(Settings.byGroup[def.Group], def)
  end
end
RebuildIndex()

local function GetOptionLabel(setting, value)
  if not setting or not setting.Options then return value end
  for _, opt in ipairs(setting.Options) do
    if type(opt) == "table" and opt.name ~= nil and opt.value ~= nil then
      if opt.value == value then return opt.name end
    elseif opt == value then
      return tostring(opt)
    end
  end
  return value
end

local function IsDropdownValueValid(setting, value)
  if not setting or not setting.Options or #setting.Options == 0 then
    return true
  end
  for _, opt in ipairs(setting.Options) do
    if type(opt) == "table" and opt.value ~= nil then
      if opt.value == value then return true end
    elseif opt == value then
      return true
    end
  end
  return false
end

local function Log(setting, value, isError)
  if setting == nil or setting.Hide then return end
  if isError == nil then isError = false end
  local displayValue = GetOptionLabel(setting, value)
  local prefix = string.format("|cffff8000%s|r", addonName)
  local nameText = string.format("|cff00ffff%s %s|r", setting.Group, setting.Name)
  local message

  if isError then
    message = string.format("%s - %s: %s", prefix, nameText, string.format("|cffffff00%s|r", tostring(displayValue)))
  else
    message = string.format("%s - %s changed to %s", prefix, nameText, string.format("|cffffff00%s|r", tostring(displayValue)))
  end
  print(message)
end

local function DebouncedSliderLog(key, setting, value)
  local state = pendingSliderLogs[key] or { token = 0 }
  state.token = state.token + 1
  state.value = value
  pendingSliderLogs[key] = state

  local token = state.token
  C_Timer.After(1, function()
    local current = pendingSliderLogs[key]
    if not current or current.token ~= token then return end
    Log(setting, current.value)
    pendingSliderLogs[key] = nil
  end)
end

-- Append a list of setting definitions provided by the consumer.
-- Can be called multiple times; index is rebuilt each call.
-- If a definition's Key matches an existing one, it replaces it (allows overriding library defaults).
function Settings:Add(definitions)
  if type(definitions) ~= "table" then return end
  for _, def in ipairs(definitions) do
    if def and def.Key then
      if self.byKey[def.Key] then
        for i, existing in ipairs(self.definitions) do
          if existing.Key == def.Key then
            self.definitions[i] = def
            break
          end
        end
      else
        table.insert(self.definitions, def)
      end
    end
  end
  RebuildIndex()
end

-- Initialize saved settings with defaults. Called by addon.MBLib:Init().
function Settings:Init()
  MBLib._db = MBLib._db or {}
  MBLib._db.Settings = MBLib._db.Settings or {}

  -- If the consumer added Display_FontType, populate its Options from LSM (via Fonts module).
  if self.byKey["Display_FontType"] and MBLib.Fonts and MBLib.Fonts.GetAvailableFonts then
    local fonts = MBLib.Fonts:GetAvailableFonts()
    self.byKey["Display_FontType"].Options = fonts
  end
  -- If the consumer added Display_FontOutline, ensure the standard outline options are present.
  if self.byKey["Display_FontOutline"] and (not self.byKey["Display_FontOutline"].Options or #self.byKey["Display_FontOutline"].Options == 0) then
    self.byKey["Display_FontOutline"].Options = {
      { name = "None", value = "NONE" },
      { name = "Outline", value = "OUTLINE" },
      { name = "Thick Outline", value = "THICKOUTLINE" },
      { name = "Monochrome Outline", value = "MONOCHROMEOUTLINE" },
    }
  end

  for _, def in ipairs(self.definitions) do
    if def.Type == "dropdown" and def.Options and #def.Options > 0 then
      if not IsDropdownValueValid(def, def.Default) then
        local first = def.Options[1]
        if type(first) == "table" and first.value ~= nil then
          def.Default = first.value
        else
          def.Default = first
        end
      end
    end

    if MBLib._db.Settings[def.Key] == nil then
      MBLib._db.Settings[def.Key] = def.Default
    end
  end
end

function Settings:Get(key)
  if not key then return nil end
  return MBLib._db and MBLib._db.Settings and MBLib._db.Settings[key]
end

function Settings:Set(key, value)
  local def = self.byKey[key]
  if not def then
    Log({ Group = "Settings", Name = "Unknown setting" }, key, true)
    return false
  end
  MBLib._db = MBLib._db or {}
  MBLib._db.Settings = MBLib._db.Settings or {}

  local old = MBLib._db.Settings[key]

  if def.Type == "number" or def.Type == "slider" then
    value = tonumber(value) or def.Default
    if def.Min then value = math.max(def.Min, value) end
    if def.Max then value = math.min(def.Max, value) end
  elseif def.Type == "checkbox" then
    value = not not value
  elseif def.Type == "dropdown" then
    if not IsDropdownValueValid(def, value) then value = def.Default end
  else
    if value ~= nil then value = tostring(value) end
  end

  if old == value then
    return true
  end

  MBLib._db.Settings[key] = value
  if def.Type == "slider" then
    DebouncedSliderLog(key, def, value)
  else
    Log(def, value)
  end

  if def.OnChange then
    pcall(function() def.OnChange(value) end)
  end

  return true
end

function Settings:ToggleDebug(state)
  if type(state) ~= "boolean" then
    Log({ Group = "Settings", Name = "Error" }, "ToggleDebug expects a boolean (true/false)", true)
    return
  end
  self:Set("DebugLogging", state)
end

MBLib.Settings = Settings
