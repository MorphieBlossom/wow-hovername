local addonName, addon = ...
local Fonts = {}

-- Return available fonts as a list of names and store LSM/font map on the module.
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

  -- Ensure the fontMap has fallback entries for built-ins
  for _, name in ipairs(fonts) do
    if not fontMap[name] then
      if LSM then
        local ok, p = pcall(LSM.Fetch, LSM, "font", name)
        if ok and p then fontMap[name] = p end
      end
    end
  end

  self._fontList = fonts
  self._fontMap = fontMap
  return fonts, fontMap
end

addon.Fonts = Fonts
return Fonts
