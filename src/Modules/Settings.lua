local addonName, addon = ...
local Settings = {}

-- Internal helper for printing setting changes or logs
local function Log(setting, value, isError)
  if setting == nil or setting.Hide then return end
  if isError == nil then isError = false end
  local prefix = string.format("|cffff8000%s|r", addonName)
  local nameText = string.format("|cff00ffff%s %s|r", setting.Group, setting.Name)
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
  {
    Key = "Display_FontSize",
    Name = "Font Size",
    Description = "Basic size of all texts displayed when hovering",
    Group = "Display",
    Type = "slider",
    Min = 8,
    Max = 30,
    Step = 1,
    Default = 12,
    OnChange = function()
      local f = addon.HoverName and addon.HoverName.UpdateFrame
      if f then pcall(f) end
    end,
  },
  {
    Key = "Display_FontType",
    Name = "Font Type",
    Description = "The font family of all texts displayed when hovering",
    Group = "Display",
    Type = "dropdown",
    Options = { "Friz Quadrata TT" },
    Default = "Friz Quadrata TT",
    OnChange = function()
      local f = addon.HoverName and addon.HoverName.UpdateFrame
      if f then pcall(f) end
    end,
  },
  {
    Key = "Player_ClassColor",
    Name = "Class Colors",
    Description = "Color a player's name by their class",
    Group = "Player",
    Type = "checkbox",
    Default = true,
  },
  {
    Key = "Player_ShowLevel",
    Name = "Show Level",
    Description = "Show a player's level",
    Group = "Player",
    Type = "checkbox",
    Default = true,
  },
  {
    Key = "Player_LevelColor",
    Name = "Level Color",
    Description = "Color a player's level in comparison to your own level",
    Group = "Player",
    Type = "checkbox",
    Default = true,
  },
  {
    Key = "Player_ShowTarget",
    Name = "Show Target",
    Description = "Show the name of a player's current target",
    Group = "Player",
    Type = "checkbox",
    Default = true,
  },
  {
    Key = "Player_ShowStatus",
    Name = "Show Status",
    Description = "Show a player's status (AFK / DND / PvP)",
    Group = "Player",
    Type = "checkbox",
    Default = true,
  },
  {
    Key = "Player_ShowGuildName",
    Name = "Show Guild name",
    Description = "Show a player's guild name",
    Group = "Player",
    Type = "checkbox",
    Default = false,
  },
  {
    Key = "Player_ShowGuildRank",
    Name = "Show Guild rank",
    Description = "Show a player's guild rank",
    Group = "Player",
    Type = "checkbox",
    Default = false,
  },
  {
    Key = "Player_ShowRace",
    Name = "Show Race",
    Description = "Show a player's race",
    Group = "Player",
    Type = "checkbox",
    Default = false,
  },
  {
    Key = "Player_ShowFaction",
    Name = "Show Faction",
    Description = "Show a player's faction",
    Group = "Player",
    Type = "checkbox",
    Default = false,
  },
  {
    Key = "NPC_ColorState",
    Name = "Standing Colors",
    Description = "Color an NPC's name by their standing towards you (dead / hostile / neutral / friendly)",
    Group = "NPC",
    Type = "checkbox",
    Default = true,
  },
  {
    Key = "NPC_ShowLevel",
    Name = "Show Level",
    Description = "Show an NPC's level",
    Group = "NPC",
    Type = "checkbox",
    Default = true,
  },
  {
    Key = "NPC_LevelColor",
    Name = "Level Color",
    Description = "Color an NPC's level in comparison to your own level",
    Group = "NPC",
    Type = "checkbox",
    Default = true,
  },
  {
    Key = "NPC_ShowTarget",
    Name = "Show Target",
    Description = "Show the name of an NPC's current target",
    Group = "NPC",
    Type = "checkbox",
    Default = true,
  },
  {
    Key = "NPC_ShowClassification",
    Name = "Show Classification",
    Description = "Show an NPC's classification (rare / elite / boss)",
    Group = "NPC",
    Type = "checkbox",
    Default = true,
  },
  {
    Key = "NPC_ShowFaction",
    Name = "Show Faction",
    Description = "Show an NPC's faction",
    Group = "NPC",
    Type = "checkbox",
    Default = false,
  },
  {
    Key = "NPC_ShowCreatureType",
    Name = "Show Creature Type",
    Description = "Show an NPC's creature type (e.g. Beast, Humanoid, Demon, etc.)",
    Group = "NPC",
    Type = "checkbox",
    Default = false,
  },
  {
    Key = "Quest_Show",
    Name = "Show Information",
    Description = "Show info below the target's name if this is needed for quests, dailies, world quests or objectives.",
    Group = "Quests / Objectives",
    Type = "checkbox",
    Default = true,
  },
  {
    Key = "Quest_ShowCompleted",
    Name = "Show Completed",
    Description = "Still show completed objectives in the hover information, until all are completed.",
    Group = "Quests / Objectives",
    Type = "checkbox",
    Default = true,
  },
  {
    Key = "Objects_ShowHoverable",
    Name = "Show Hoverable",
    Description = "Show names for hoverable objects",
    Group = "Objects",
    Type = "checkbox",
    Default = false,
    Hide = true,
  },
  {
    Key = "Integrations_Rarity",
    Name = "Rarity",
    Description = "Show information from the 'Rarity' addon when it is installed",
    Group = "Integrations",
    Type = "checkbox",
    Default = false,
    Hide = true,
  },
}

-- build helper maps
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

-- Initialize saved settings with defaults
function Settings:Init()
  addon.DB = addon.DB or {}
  addon.DB.Settings = addon.DB.Settings or {}

  -- Populate font options via Fonts module (keeps Init cleaner)
  if addon.Settings and addon.Settings.byKey and addon.Settings.byKey["Display_FontType"] and addon.Fonts and addon.Fonts.GetAvailableFonts then
    local fonts, _ = addon.Fonts:GetAvailableFonts()
    addon.Settings.byKey["Display_FontType"].Options = fonts
  end

  -- Ensure selection defaults are valid and initialize saved settings
  for _, def in ipairs(self.definitions) do
    if def.Type == "selection" and def.Options and #def.Options > 0 then
      local ok = false
      for _, opt in ipairs(def.Options) do
        if opt == def.Default then ok = true break end
      end
      if not ok then
        def.Default = def.Options[1]
      end
    end

    if addon.DB.Settings[def.Key] == nil then
      addon.DB.Settings[def.Key] = def.Default
    end
  end
end

-- Get a setting value
function Settings:Get(key)
  if not key then return nil end
  return addon.DB and addon.DB.Settings and addon.DB.Settings[key]
end

-- Set a setting with validation and logging (uses setting Name for logs)
function Settings:Set(key, value)
  local def = self.byKey[key]
  if not def then
    Log("Unknown setting", key, true)
    return false
  end
  -- ensure saved table exists
  addon.DB = addon.DB or {}
  addon.DB.Settings = addon.DB.Settings or {}

  local old = addon.DB.Settings[key]

  -- coerce/validate new value according to type
  if def.Type == "number" then
    value = tonumber(value) or def.Default
    if def.Min then value = math.max(def.Min, value) end
    if def.Max then value = math.min(def.Max, value) end
  elseif def.Type == "checkbox" then
    value = not not value
  elseif def.Type == "selection" then
    if def.Options and #def.Options > 0 then
      local ok = false
      for _, opt in ipairs(def.Options) do
        if opt == value then ok = true break end
      end
      if not ok then value = def.Default end
    end
  else
    if value ~= nil then value = tostring(value) end
  end

  -- if value unchanged, do nothing
  if old == value then
    return true
  end

  addon.DB.Settings[key] = value
  Log(def, value)

  -- Call any change callback defined on the setting def
  if def.OnChange then
    pcall(function() def.OnChange(value) end)
  end

  return true
end

-- Toggle debug helper
function Settings:ToggleDebug(state)
  if type(state) ~= "boolean" then
    Log("Error", "ToggleDebug expects a boolean (true/false)", true)
    return
  end
  self:Set("DebugLogging", state)
end


addon.Settings = Settings
return Settings