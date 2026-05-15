local addonName, addon = ...
local MBLib = addon.MBLib

local Fonts = {}

-- Return available fonts as a list of names; second return is name -> path map.
-- Uses LibSharedMedia-3.0 via LibStub when available.
function Fonts:GetAvailableFonts()
  if self._fontList then return self._fontList, self._fontMap end

  local LSM
  if type(LibStub) == "table" or type(LibStub) == "function" then
    pcall(function() LSM = LibStub("LibSharedMedia-3.0", true) end)
  end
  self.LSM = LSM

  local fonts = { "Friz Quadrata TT" }
  local fontMap = {}

  if LSM then
    local ht = LSM:HashTable("font")
    if ht then
      fonts = {}
      for name, path in pairs(ht) do
        table.insert(fonts, name)
        fontMap[name] = path
      end
      table.sort(fonts)
    end
  end

  for _, name in ipairs(fonts) do
    if not fontMap[name] and LSM then
      local ok, p = pcall(LSM.Fetch, LSM, "font", name)
      if ok and p then fontMap[name] = p end
    end
  end

  self._fontList = fonts
  self._fontMap = fontMap
  return fonts, fontMap
end

MBLib.Fonts = Fonts
