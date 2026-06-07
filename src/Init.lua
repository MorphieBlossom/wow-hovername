local addonName, addon = ...

-- LibObjectiveProgress is HoverName-specific (used by QuestInfo); kept on addon directly.
-- Not available on Mists Classic.
addon.LOP = nil
if type(LibStub) == "table" and type(LibStub.GetLibrary) == "function" then
  addon.LOP = LibStub:GetLibrary("LibObjectiveProgress-1.0", true)
end

-- Configure MBLib (loaded by Libraries\Load_Libraries.xml before this file)
addon.MBLib:AddSlashTrigger("/hn")
addon.MBLib:SetIcon("Interface\\AddOns\\" .. addonName .. "\\Media\\hovername-icon.png")
addon.MBLib:SetPredecessor("ncHoverName")

-- One-shot migration of the pre-12.0.5.4 cursor positioning settings
-- (Display_CursorDistance + Display_CursorAltDistance, interpreted relative
-- to the anchor) into the new raw-offset model (Display_CursorOffsetHorizontal
-- + Display_CursorOffsetVertical). Runs after MBLib:Init has populated the
-- new keys with defaults; the translated values overwrite those defaults.
local function MigrateLegacyCursorOffsets()
  local store = addon.MBLib._db and addon.MBLib._db.Settings
  if not store then return end

  local oldDist = store.Display_CursorDistance
  local oldAlt = store.Display_CursorAltDistance
  if oldDist == nil and oldAlt == nil then return end

  local anchor = store.Display_CursorAnchor or "TOP"
  local dist = tonumber(oldDist) or 0
  local alt = tonumber(oldAlt) or 0

  local h, v
  if anchor == "BOTTOM" or anchor == "BOTTOMLEFT" or anchor == "BOTTOMRIGHT" then
    h, v = alt, -dist
  elseif anchor == "LEFT" then
    h, v = -dist, alt
  elseif anchor == "RIGHT" then
    h, v = dist, alt
  else -- TOP / TOPLEFT / TOPRIGHT / unknown
    h, v = alt, dist
  end

  store.Display_CursorOffsetHorizontal = h
  store.Display_CursorOffsetVertical = v
  store.Display_CursorDistance = nil
  store.Display_CursorAltDistance = nil
end

-- Bootstrap MBLib once SavedVariables are available
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(self, _, name)
  if name == addonName then
    addon.MBLib:Init()
    MigrateLegacyCursorOffsets()
    self:UnregisterEvent("ADDON_LOADED")
    self:SetScript("OnEvent", nil)
  end
end)
