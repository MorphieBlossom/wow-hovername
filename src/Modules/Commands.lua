local addonName, addon = ...

local cIdx = 0
local cDefRegistered = false
local cDef = "/" .. addonName:lower()

local function PrintCommand(cmd, message)
  print(string.format("|cffff8000%s|r [|cff00ffff%s|r] %s", addonName, cmd, message))
end

local function PrintUsage(cmd)
  local handler = addon.Commands.list[cmd]
  if handler and handler.usage then
    PrintCommand(cmd, string.format("Usage: %s %s %s", cDef, cmd, handler.usage))
  end
end

-- Table holding all slash-command handlers
local Commands = {}
Commands.list = {
  help = {
    desc = "Show all available commands",
    func = function()
      PrintCommand("help", string.format("- Available commands (%s)", cDef))
      for cmd, info in pairs(Commands.list) do
        print(string.format("- |cff00ff00%s|r > %s", cmd, info.desc))
      end
      return true
    end,
  },
  debug = {
    desc = "Toggle debug logging on/off",
    usage = "on / off",
    func = function(arg)
      if arg == "on" then
        addon.Settings:ToggleDebug(true)
        return true
      elseif arg == "off" then
        addon.Settings:ToggleDebug(false)
        return true
      end
    end,
  },
  version = {
    desc = "Show addon version",
    func = function()
      PrintCommand("version", string.format("|cffffff00%s|r by %s", C_AddOns.GetAddOnMetadata(addonName, "Version"), C_AddOns.GetAddOnMetadata(addonName, "Author")))
      return true
    end,
  },
}



-- Register the slash commands
for _, token in ipairs(addon.COMMANDS_TRIGGERLIST or {}) do
  cIdx = cIdx + 1
  _G["SLASH_" .. addonName:upper() .. cIdx] = token
  if token == cDef then cDefRegistered = true end
end

-- Make sure the default command is registered if not already
if not cDefRegistered then
  _G["SLASH_" .. addonName:upper() .. (cIdx + 1)] = cDef
end

-- Dispatch function for slash commands
SlashCmdList[addonName:upper()] = function(input)
  local cmd, arg = input:match("^(%S*)%s*(.-)$")
  local handler = addon.Commands.list[cmd]
  if not handler then
    addon.Commands.list.help.func()
  else
    if not handler.func(arg) then PrintUsage(cmd) end
  end
end

-- Expose module
addon.Commands = Commands
