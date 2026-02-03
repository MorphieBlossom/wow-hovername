local _, addon = ...
local HoverName = {}
HoverName.init = false

local function UpdateFrameFonts(f)
	if not (addon and addon.Settings and addon.Settings.Get) then return end

	local fontName = addon.Settings:Get("Display_FontType")
	local fontSize = tonumber(addon.Settings:Get("Display_FontSize"))
	if not (fontName and fontSize) then return end

	local fontPath
	if addon.Fonts then
		local map = addon.Fonts._fontMap
		if map and map[fontName] then fontPath = map[fontName] end
		if not fontPath and addon.Fonts.LSM and addon.Fonts.LSM.Fetch then
			local ok, path = pcall(function() return addon.Fonts.LSM:Fetch("font", fontName) end)
			if ok and path then fontPath = path end
		end
	end

	if not fontPath then return end

	pcall(function()
		if f.mainText then f.mainText:SetFont(fontPath, fontSize, "OUTLINE") end
		if f.headerText then f.headerText:SetFont(fontPath, fontSize - 3, "OUTLINE") end
		if f.statusText then f.statusText:SetFont(fontPath, fontSize - 4, "OUTLINE") end
		if f.guildText then f.guildText:SetFont(fontPath, fontSize - 4, "OUTLINE") end
		if f.subText then f.subText:SetFont(fontPath, fontSize - 3, "OUTLINE") end
	end)
end

local function SetAnchor(element, anchor, position, top)
	local margin = 13
	margin = (top or 0) + margin
	top = margin + 2

	element:SetPoint(position, anchor, position, 0, margin)
	return top
end

local function UpdateFrameContents(f)
	if HoverName.init == false then
		HoverName.init = true
		pcall(function() UpdateFrameFonts(f) end)
	end

	local frameName = addon.Utils:GetTopMouseFocusName()
	if addon.Utils:IsNotEmpty(frameName) and frameName ~= "WorldFrame" then return end

	local unitName = UnitName("mouseover")
	if unitName == nil then return end

	local unitText = addon.Utils:GetTextWithColor(unitName, addon.UnitInfo:GetUnitNameColor("mouseover"))
	local level = addon.UnitInfo:GetLevelText()
	local targetName = addon.UnitInfo:GetTargetText()
	local status = addon.UnitInfo:GetStatusText()
	local classification = addon.UnitInfo:GetClassificationText()
	local guild = addon.UnitInfo:GetGuildText()
	local faction = addon.UnitInfo:GetFactionText()
	local race = addon.UnitInfo:GetRaceText()
	local creatureType = addon.UnitInfo:GetCreatureType()
	local tooltips = addon.Utils:GetTooltipData()

	local mainText = addon.Utils:CombineText(level, unitText, targetName)
	local statusText = status
	local headerText = addon.Utils:CombineText(faction, classification, creatureType, race)
	local guildText = guild

	f.mainText:SetText(mainText)
	f.statusText:SetText(statusText)
	f.headerText:SetText(headerText)
	f.guildText:SetText(guildText)

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

	local top = 0
	if addon.Utils:IsNotEmpty(guildText) then top = SetAnchor(f.guildText, f.mainText, "TOPLEFT", top) end
	if addon.Utils:IsNotEmpty(headerText) then top = SetAnchor(f.headerText, f.mainText, "TOPLEFT", top) end
	if addon.Utils:IsNotEmpty(statusText) then top = SetAnchor(f.statusText, f.mainText, "TOPLEFT", top) end
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
frame.statusText = frame:CreateFontString(nil, "OVERLAY", "GameTooltipText")
frame.headerText = frame:CreateFontString(nil, "OVERLAY", "GameTooltipText")
frame.guildText = frame:CreateFontString(nil, "OVERLAY", "GameTooltipText")
frame.subText = frame:CreateFontString(nil, "OVERLAY", "GameTooltipText")

frame:SetScript("OnUpdate", function(self) UpdateFramePosition(self) end)
frame:SetScript("OnEvent", function(self) UpdateFrameContents(self) end)
frame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")


function HoverName.UpdateFrame()
	pcall(function() UpdateFrameFonts(frame) end)
end

addon.HoverName = HoverName
return HoverName