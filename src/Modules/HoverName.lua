local _, addon = ...
local HoverName = {}
HoverName.init = false

local Layout = {
	LINE_STEP = 13, -- Vertical spacing between stacked top labels (guild/header/status).
	LINE_OFFSET = 2, -- Small extra offset added after each top label anchor step.
	MAIN_MIN_HEIGHT = 14, -- Fallback minimum height reserved for mainText line.
	SUB_BOTTOM_OFFSET = 1, -- Bottom offset used for subText anchoring and height math.
	SUB_LINE_STEP = 12, -- Per-line vertical step used by the subText block.
	SUB_LEFT_INSET = 12, -- Horizontal inset of subText relative to mainText.
	FRAME_MIN_WIDTH = 1, -- Keep >0 to avoid invalid size, but do not add visual padding.
	FRAME_MIN_HEIGHT = 1, -- Keep >0 to avoid invalid size, but do not add visual padding.
	CURSOR_DISTANCE_DEFAULT = 4, -- Fallback distance from cursor when setting is unavailable.
}

local BACKGROUND_COLORS = {
	BLACK = { r = 0, g = 0, b = 0 },
	WHITE = { r = 1, g = 1, b = 1 },
	RED = { r = 1, g = 0, b = 0 },
	BLUE = { r = 0, g = 0, b = 1 },
	GREEN = { r = 0, g = 1, b = 0 },
	YELLOW = { r = 1, g = 1, b = 0 },
	PURPLE = { r = 0.5, g = 0, b = 0.5 },
	ORANGE = { r = 1, g = 0.65, b = 0 },
	BROWN = { r = 0.545, g = 0.27, b = 0.075 },
}

local function GetBackgroundPadding()
	if addon and addon.Settings and addon.Settings.Get then
		local value = tonumber(addon.Settings:Get("Display_BackgroundPadding"))
		if value then return math.max(0, value) end
	end
	return 0
end

local function UpdateFrameFonts(f)
	if not (addon and addon.Settings and addon.Settings.Get) then return end

	local fontName = addon.Settings:Get("Display_FontType")
	local fontSize = tonumber(addon.Settings:Get("Display_FontSize"))
	local fontOutline = addon.Settings:Get("Display_FontOutline") or "OUTLINE"
	if fontOutline == "NONE" then fontOutline = "" end
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
		if f.mainText then f.mainText:SetFont(fontPath, fontSize, fontOutline) end
		if f.headerText then f.headerText:SetFont(fontPath, fontSize - 3, fontOutline) end
		if f.statusText then f.statusText:SetFont(fontPath, fontSize - 4, fontOutline) end
		if f.guildText then f.guildText:SetFont(fontPath, fontSize - 4, fontOutline) end
		if f.subText then f.subText:SetFont(fontPath, fontSize - 3, fontOutline) end
	end)
end

local function SetAnchor(element, anchor, position, top)
	local margin = Layout.LINE_STEP
	margin = (top or 0) + margin
	top = margin + Layout.LINE_OFFSET

	element:SetPoint(position, anchor, position, 0, margin)
	return top
end

local function UpdateBackground(f)
	local enabled = addon.Settings and addon.Settings.Get and addon.Settings:Get("Display_BackgroundEnabled")
	if not enabled then
		f:SetBackdropColor(0, 0, 0, 0)
		return
	end

	local colorKey = addon.Settings and addon.Settings.Get and addon.Settings:Get("Display_BackgroundColor") or "BLACK"
	local alpha = addon.Settings and addon.Settings.Get and addon.Settings:Get("Display_BackgroundAlpha") or 70

	alpha = tonumber(alpha) or 70
	if alpha > 1 then
		alpha = alpha / 100
	end

	local color = BACKGROUND_COLORS[colorKey] or BACKGROUND_COLORS.BLACK
	local r = color.r
	local g = color.g
	local b = color.b
	f:SetBackdropColor(r, g, b, alpha)
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

	addon.Utils:DebugLog(string.format("Unit: %s (%s)", mainText or "", headerText or ""))

	local subTexts = addon.Utils:CombineTables(addon.QuestInfo:GetQuestText("mouseover", tooltips))
	local subCount = (subTexts and #subTexts) or 0
	if subCount > 0 then
		f.subText:SetText(table.concat(subTexts, "\n"))
	else
		f.subText:SetText("")
	end

	local function Measure(fs)
		local w, h = 0, 0
		local okW, rw = pcall(fs.GetStringWidth, fs)
		local okH, rh = pcall(fs.GetStringHeight, fs)
		if okW and type(rw) == "number" and not issecretvalue(rw) then w = rw end
		if okH and type(rh) == "number" and not issecretvalue(rh) then h = rh end
		return w, h
	end

	local mainW, mainH = Measure(f.mainText)
	local guildW, guildH = Measure(f.guildText)
	local headerW, headerH = Measure(f.headerText)
	local statusW, statusH = Measure(f.statusText)
	local subW, subH = Measure(f.subText)
	local fontSize = tonumber(addon.Settings and addon.Settings.Get and addon.Settings:Get("Display_FontSize")) or Layout.MAIN_MIN_HEIGHT

	mainW = math.max(mainW, 1)
	mainH = math.max(mainH, fontSize)

	local topLines = 0
	if addon.Utils:IsNotEmpty(guildText) then topLines = topLines + 1 end
	if addon.Utils:IsNotEmpty(headerText) then topLines = topLines + 1 end
	if addon.Utils:IsNotEmpty(statusText) then topLines = topLines + 1 end

	local padding = GetBackgroundPadding()
	local topExtra = (topLines * Layout.LINE_STEP) + padding
	local subExtra = 0
	if subCount > 0 then
		subExtra = subH + Layout.SUB_BOTTOM_OFFSET + (Layout.SUB_LINE_STEP * subCount)
	end

	local width = math.max(mainW, guildW, headerW, statusW, subW + Layout.SUB_LEFT_INSET)
	width = math.max(Layout.FRAME_MIN_WIDTH, width + (padding * 2))

	local height = topExtra + mainH + subExtra + padding
	height = math.max(Layout.FRAME_MIN_HEIGHT, height)

	f:SetSize(width, height)
	f.mainText:ClearAllPoints()
	f.mainText:SetPoint("TOP", f, "TOP", 0, -topExtra)

	local top = 0
	if addon.Utils:IsNotEmpty(guildText) then top = SetAnchor(f.guildText, f.mainText, "TOPLEFT", top) end
	if addon.Utils:IsNotEmpty(headerText) then top = SetAnchor(f.headerText, f.mainText, "TOPLEFT", top) end
	if addon.Utils:IsNotEmpty(statusText) then top = SetAnchor(f.statusText, f.mainText, "TOPLEFT", top) end
	f.subText:SetPoint("BOTTOMLEFT", f.mainText, "BOTTOMLEFT", Layout.SUB_LEFT_INSET, -Layout.SUB_BOTTOM_OFFSET + (-Layout.SUB_LINE_STEP * subCount))

	UpdateBackground(f)
	f:Show()
end

local function UpdateFramePosition(f)
	if not UnitExists("mouseover") then
		f:Hide()
		return
	end

	local x, y = GetCursorPosition()
	local scale = UIParent:GetEffectiveScale()
	local anchor = addon.Settings and addon.Settings.Get and addon.Settings:Get("Display_CursorAnchor") or "TOP"
	local distance = addon.Settings and addon.Settings.Get and tonumber(addon.Settings:Get("Display_CursorDistance")) or Layout.CURSOR_DISTANCE_DEFAULT
	local point, xOffset, yOffset = "BOTTOM", 0, distance

	if anchor == "BOTTOM" then
		point = "TOP"
		xOffset = 0
		yOffset = -distance
	elseif anchor == "LEFT" then
		point = "RIGHT"
		xOffset = -distance
		yOffset = 0
	elseif anchor == "RIGHT" then
		point = "LEFT"
		xOffset = distance
		yOffset = 0
	end

	f:ClearAllPoints()
	f:SetPoint(point, UIParent, "BOTTOMLEFT", (x / scale) + xOffset, (y / scale) + yOffset)
end

-- Create the main frame with backdrop support.
local frame = CreateFrame("Frame", "HoverNameFrame", UIParent, "BackdropTemplate")
frame:SetFrameStrata("TOOLTIP")
frame:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background" })
frame:SetBackdropColor(0, 0, 0, 0)

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
	pcall(function() UpdateBackground(frame) end)
end

addon.HoverName = HoverName
return HoverName
