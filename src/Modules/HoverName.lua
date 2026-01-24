local _, addon = ...

local function UpdateFrameContents(f)
	local frameName = addon.Utils:GetTopMouseFocusName()
	if frameName ~= nil and frameName ~= "" and frameName ~= "WorldFrame" then return end

	local unitName = UnitName("mouseover")
	if unitName == nil then return end

	local unitText = addon.Utils:GetTextWithColor(unitName, addon.UnitInfo:GetUnitNameColor("mouseover"))
	local levelText = addon.UnitInfo:GetLevelText()
	local targetText = addon.UnitInfo:GetTargetText()
	local statusText = addon.UnitInfo:GetStatusText()
	local classText = addon.UnitInfo:GetClassificationText()
	local tooltips = addon.Utils:GetTooltipData()

	local mainText = levelText .. unitText .. targetText
	local headerText = statusText .. classText
	f.mainText:SetText(mainText)
	f.headerText:SetText(headerText)

	addon.Utils:DebugLog(string.format("Unit: %s (%s)", mainText, headerText))

	local offset = 0
	local subTexts = addon.Utils:CombineTables(addon.QuestInfo:GetQuestText("mouseover", tooltips))
	if subTexts and #subTexts > 0 then
		offset = 12 * #subTexts
		f.subText:SetText(table.concat(subTexts, "\n"))
	else
		f.subText:SetText("")
	end

	local width, height
	local mainTextValue = f.mainText:GetText()
	if mainTextValue and not issecretvalue(mainTextValue) then
		local okW, w = pcall(f.mainText.GetStringWidth, f.mainText)
		local okH, h = pcall(f.mainText.GetStringHeight, f.mainText)
		if okW and not issecretvalue(w) and type(w) == "number" then width = w end
		if okH and not issecretvalue(h) and type(h) == "number" then height = h end
	end

	width = width or 100
	height = height or 14

	local subCount = (subTexts and #subTexts) or 0
	width = math.max(1, width + 16)
	height = math.max(1, height + (12 * subCount))
	f:SetSize(width, height)
	f.mainText:SetPoint("TOP", f, "TOP", 0, offset)
	f.headerText:SetPoint("TOPLEFT", f.mainText, "TOPLEFT", 0, 12)
	f.subText:SetPoint("BOTTOMLEFT", f.mainText, "BOTTOMLEFT", 12, -1 + (-12 * subCount))

	f:Show()
end

local function UpdateFramePosition(f)
	if not UnitExists("mouseover") then
		f:Hide()
		return
	end

	local x, y = GetCursorPosition()
	local scale = UIParent:GetEffectiveScale()
	f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale + 15)
end


local frame = CreateFrame("Frame", "HoverNameFrame", UIParent)
frame:SetFrameStrata("TOOLTIP")
--frame.texture = frame:CreateTexture()
--frame.texture:SetAllPoints(frame)
--frame.texture:SetTexture("Interface/BUTTONS/WHITE8X8")
frame.mainText = frame:CreateFontString(nil, "OVERLAY", "GameTooltipText")
frame.mainText:SetFont("Interface\\AddOns\\HoverName\\Fonts\\Expressway.ttf", 14, "OUTLINE")
frame.headerText = frame:CreateFontString(nil, "OVERLAY", "GameTooltipText")
frame.headerText:SetFont("Interface\\AddOns\\HoverName\\Fonts\\Expressway.ttf", 11, "OUTLINE")
frame.subText = frame:CreateFontString(nil, "OVERLAY", "GameTooltipText")
frame.subText:SetFont("Interface\\AddOns\\HoverName\\Fonts\\Expressway.ttf", 11, "OUTLINE")

frame:SetScript("OnUpdate", function(self) UpdateFramePosition(self) end)
frame:SetScript("OnEvent", function(self) UpdateFrameContents(self) end)
frame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
