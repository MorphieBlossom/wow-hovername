local addonName, addon = ...
local MBLib = addon.MBLib

local Commands = {}
local defaultTrigger = "/" .. addonName:lower()

local function PrintCommand(cmd, message)
  print(string.format("|cffff8000%s|r [|cff00ffff%s|r] %s", addonName, cmd, message))
end

local function PrintUsage(cmd)
  local handler = Commands.list[cmd]
  if handler and handler.usage then
    PrintCommand(cmd, string.format("Usage: %s %s %s", defaultTrigger, cmd, handler.usage))
  end
end

-- Library-provided baseline. Consumer extends via Commands:Add(name, handler).
Commands.list = {
  help = {
    desc = "Show all available commands",
    func = function()
      PrintCommand("help", string.format("- Available commands (%s)", defaultTrigger))
      for cmd, info in pairs(Commands.list) do
        print(Commands:GetFormattedCommandStr(cmd, info.desc))
      end
      return true
    end,
  },
  debug = {
    desc = "Toggle debug logging on/off",
    usage = "on / off",
    func = function(arg)
      if arg == "on" then
        MBLib.Settings:ToggleDebug(true)
        return true
      elseif arg == "off" then
        MBLib.Settings:ToggleDebug(false)
        return true
      end
    end,
  },
  version = {
    desc = "Show addon version",
    func = function()
      local v = C_AddOns.GetAddOnMetadata(addonName, "Version")
      local a = C_AddOns.GetAddOnMetadata(addonName, "Author")
      PrintCommand("version", string.format("|cffffff00%s|r by %s", v or "", a or ""))
      return true
    end,
  },
  settings = {
    desc = "Open the settings window",
    func = function()
      if MBLib._optionsScreenID then
        Settings.OpenToCategory(MBLib._optionsScreenID)
      end
      return true
    end,
  },
}

-- Add or replace a slash command handler.
function Commands:Add(name, handler)
  if type(name) ~= "string" or name == "" then return end
  if type(handler) ~= "table" or type(handler.func) ~= "function" then return end
  self.list[name] = handler
end

-- Register slash triggers and the dispatcher with the game. Called by addon.MBLib:Init().
function Commands:RegisterSlashHandlers()
  if self._registered then return end
  self._registered = true

  local upper = addonName:upper()
  local triggers = MBLib:GetSlashTriggers()
  local cIdx = 0
  local defaultRegistered = false

  for _, token in ipairs(triggers) do
    cIdx = cIdx + 1
    _G["SLASH_" .. upper .. cIdx] = token
    if token == defaultTrigger then defaultRegistered = true end
  end

  if not defaultRegistered then
    cIdx = cIdx + 1
    _G["SLASH_" .. upper .. cIdx] = defaultTrigger
  end

  SlashCmdList[upper] = function(input)
    local cmd, arg = input:match("^(%S*)%s*(.-)$")
    local handler = Commands.list[cmd]
    if not handler then
      Commands.list.help.func()
    else
      if not handler.func(arg) then PrintUsage(cmd) end
    end
  end
end

function Commands:GetTriggers()
  local triggers = {}
  local prefix = "SLASH_" .. addonName:upper()
  local i = 1
  while _G[prefix .. i] do
    table.insert(triggers, _G[prefix .. i])
    i = i + 1
  end
  return triggers
end

function Commands:GetFormattedCommandStr(cmd, desc)
  return string.format("- |cff00ff00%s|r > %s", cmd, desc or "")
end

MBLib.Commands = Commands
