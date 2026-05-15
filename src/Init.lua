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

-- Bootstrap MBLib once SavedVariables are available
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(self, _, name)
  if name == addonName then
    addon.MBLib:Init()
    self:UnregisterEvent("ADDON_LOADED")
    self:SetScript("OnEvent", nil)
  end
end)
