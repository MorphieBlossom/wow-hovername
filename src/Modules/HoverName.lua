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
	CURSOR_OFFSET_VERTICAL_DEFAULT = 4, -- Fallback vertical offset from cursor when setting is unavailable.
	CURSOR_OFFSET_HORIZONTAL_DEFAULT = 0, -- Fallback horizontal offset from cursor when setting is unavailable.
	FORCES_GAP_RIGHT = 6, -- Horizontal gap between the name and the Enemy Forces text (right mode).
	FORCES_GAP_UNDER = 2, -- Vertical gap below the subtext block before the Enemy Forces line (under mode).
	COMBAT_ICON_GAP = -2, -- Horizontal gap between the combat icon and the name line (negative tucks it closer, compensating for the icon texture's transparent border).
}

-- Map a Cursor Anchor selection to the frame point that should sit at the cursor.
-- The horizontal/vertical offsets are then added on top as raw deltas.
local ANCHOR_TO_POINT = {
	TOP         = "BOTTOM",
	BOTTOM      = "TOP",
	LEFT        = "RIGHT",
	RIGHT       = "LEFT",
	TOPLEFT     = "BOTTOMRIGHT",
	TOPRIGHT    = "BOTTOMLEFT",
	BOTTOMLEFT  = "TOPRIGHT",
	BOTTOMRIGHT = "TOPLEFT",
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
	if addon and addon.MBLib.Settings and addon.MBLib.Settings.Get then
		local value = tonumber(addon.MBLib.Settings:Get("Display_BackgroundPadding"))
		if value then return math.max(0, value) end
	end
	return 0
end

local function UpdateFrameFonts(f)
	if not (addon and addon.MBLib.Settings and addon.MBLib.Settings.Get) then return end

	local fontName = addon.MBLib.Settings:Get("Display_FontType")
	local fontSize = tonumber(addon.MBLib.Settings:Get("Display_FontSize"))
	local fontOutline = addon.MBLib.Settings:Get("Display_FontOutline") or "OUTLINE"
	if fontOutline == "NONE" then fontOutline = "" end
	if not (fontName and fontSize) then return end

	local fontPath
	if addon.MBLib.Fonts then
		-- Ensure MBLib has scanned LSM at least once. GetAvailableFonts is
		-- rebuild-on-every-call (MBLib 1.0.5+), so this also picks up fonts
		-- registered by other addons after MBLib's initial load.
		if addon.MBLib.Fonts.GetAvailableFonts then
			pcall(function() addon.MBLib.Fonts:GetAvailableFonts() end)
		end
		local map = addon.MBLib.Fonts._fontMap
		if map and map[fontName] then fontPath = map[fontName] end
		if not fontPath and addon.MBLib.Fonts.LSM and addon.MBLib.Fonts.LSM.Fetch then
			local ok, path = pcall(function() return addon.MBLib.Fonts.LSM:Fetch("font", fontName) end)
			if ok and path then fontPath = path end
		end
	end

	-- Direct LSM fallback in case MBLib.Fonts hasn't loaded yet, or the consumer
	-- selected a font that LSM only knows about after a late registration.
	if not fontPath and LibStub then
		local ok, LSM = pcall(function() return LibStub("LibSharedMedia-3.0", true) end)
		if ok and LSM and LSM.Fetch then
			local fetchOk, path = pcall(function() return LSM:Fetch("font", fontName) end)
			if fetchOk and path then fontPath = path end
		end
	end

	if not fontPath then return end

	-- The Mythic+ Enemy Forces and quest lines carry their own sizes (they fall
	-- back to the base-derived sizes when unset).
	local mpSize = tonumber(addon.MBLib.Settings:Get("MythicPlus_FontSize")) or fontSize
	local questSize = tonumber(addon.MBLib.Settings:Get("Quest_FontSize")) or (fontSize - 3)

	pcall(function()
		if f.mainText then f.mainText:SetFont(fontPath, fontSize, fontOutline) end
		if f.combatIcon then f.combatIcon:SetFont(fontPath, fontSize, fontOutline) end
		if f.headerText then f.headerText:SetFont(fontPath, fontSize - 3, fontOutline) end
		if f.statusText then f.statusText:SetFont(fontPath, fontSize - 4, fontOutline) end
		if f.guildText then f.guildText:SetFont(fontPath, fontSize - 4, fontOutline) end
		if f.subText then f.subText:SetFont(fontPath, questSize, fontOutline) end
		if f.forcesText then f.forcesText:SetFont(fontPath, mpSize, fontOutline) end
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
	local enabled = addon.MBLib.Settings and addon.MBLib.Settings.Get and addon.MBLib.Settings:Get("Display_BackgroundEnabled")
	if not enabled then
		f:SetBackdropColor(0, 0, 0, 0)
		return
	end

	local colorKey = addon.MBLib.Settings and addon.MBLib.Settings.Get and addon.MBLib.Settings:Get("Display_BackgroundColor") or "BLACK"
	local alpha = addon.MBLib.Settings and addon.MBLib.Settings.Get and addon.MBLib.Settings:Get("Display_BackgroundAlpha") or 70

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

	local frameName = addon.MBLib.Utils:GetTopMouseFocusName()
	if addon.MBLib.Utils:IsNotEmpty(frameName) and frameName ~= "WorldFrame" then return end

	local unitName = UnitName("mouseover")
	if unitName == nil then return end

	local unitText = addon.MBLib.Utils:GetTextWithColor(unitName, addon.UnitInfo:GetUnitNameColor("mouseover"))

	-- In-combat crossed-swords icon (mobs only). Rendered as its own FontString
	-- anchored to the LEFT of the name line (further down) so it extends leftward
	-- instead of pushing the level / name to the right. The helper guards secret
	-- combat values itself; wrap it anyway so a failure never breaks the frame.
	local combatIcon
	pcall(function() combatIcon = addon.UnitInfo:GetCombatIcon() end)

	local level = addon.UnitInfo:GetLevelText()
	local targetName = addon.UnitInfo:GetTargetText()
	local status = addon.UnitInfo:GetStatusText()
	local classification = addon.UnitInfo:GetClassificationText()
	local guild = addon.UnitInfo:GetGuildText()
	local faction = addon.UnitInfo:GetFactionText()
	local race = addon.UnitInfo:GetRaceText()
	local creatureType = addon.UnitInfo:GetCreatureType()
	local tooltips = addon.MBLib.Utils:GetTooltipData()

	local mainText = addon.MBLib.Utils:CombineText(level, unitText, targetName)
	local statusText = status
	local headerText = addon.MBLib.Utils:CombineText(faction, classification, creatureType, race)
	local guildText = guild

	f.mainText:SetText(mainText)
	f.combatIcon:SetText(combatIcon or "")
	f.statusText:SetText(statusText)
	f.headerText:SetText(headerText)
	f.guildText:SetText(guildText)

	addon.MBLib.Utils:DebugLog(string.format("Unit: %s (%s)", mainText or "", headerText or ""))

	-- Quest / objective lines fill the subtext block directly under the name.
	local subTexts = addon.MBLib.Utils:CombineTables(
		addon.QuestInfo:GetQuestText("mouseover", tooltips)
	)
	local subCount = (subTexts and #subTexts) or 0
	if subCount > 0 then
		local joined = subTexts[1]
		for i = 2, subCount do
			joined = joined .. "\n" .. subTexts[i]
		end
		f.subText:SetText(joined)
	else
		f.subText:SetText("")
	end

	-- Mythic+ Enemy Forces line: its own FontString so it can carry a separate
	-- font size and sit either under the name or to its right. GetForcesText
	-- returns nil or a { line } table; the line itself may be a secret value, so
	-- we branch on the (non-secret) table, never compare the string.
	-- DungeonInfo is retail-only (not loaded on the Classic flavors), so guard the
	-- call; forcesArr is nil there and the whole block below stays inert.
	local forcesArr = addon.DungeonInfo and addon.DungeonInfo:GetForcesText("mouseover")
	local hasForces = forcesArr ~= nil
	local forcesRight = false
	if hasForces and addon.MBLib.Settings and addon.MBLib.Settings.Get then
		forcesRight = addon.MBLib.Settings:Get("MythicPlus_DisplayRight") and true or false
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
	local guildW = Measure(f.guildText)
	local headerW = Measure(f.headerText)
	local statusW = Measure(f.statusText)
	local subW, subH = Measure(f.subText)
	local fontSize = tonumber(addon.MBLib.Settings and addon.MBLib.Settings.Get and addon.MBLib.Settings:Get("Display_FontSize")) or Layout.MAIN_MIN_HEIGHT
	local mpFontSize = tonumber(addon.MBLib.Settings and addon.MBLib.Settings.Get and addon.MBLib.Settings:Get("MythicPlus_FontSize")) or fontSize

	-- The forces line may be a secret value whose width/height can't be measured
	-- (they come back 0). Reserve its width from a worst-case literal measured at
	-- the current font, and use the configured font size for its height.
	local forcesW, forcesH = 0, 0
	if hasForces then
		f.forcesText:SetText(addon.DungeonInfo:GetReserveText())
		forcesW = Measure(f.forcesText)
		f.forcesText:SetText(forcesArr[1])
		forcesH = mpFontSize
	else
		f.forcesText:SetText("")
	end

	mainW = math.max(mainW, 1)
	mainH = math.max(mainH, fontSize)

	local topLines = 0
	if addon.MBLib.Utils:IsNotEmpty(guildText) then topLines = topLines + 1 end
	if addon.MBLib.Utils:IsNotEmpty(headerText) then topLines = topLines + 1 end
	if addon.MBLib.Utils:IsNotEmpty(statusText) then topLines = topLines + 1 end

	local padding = GetBackgroundPadding()
	local topExtra = (topLines * Layout.LINE_STEP) + padding

	-- Build the under-name stack top-down: Enemy Forces first (when shown under
	-- the name), then the quest / objective lines. dropY tracks the distance
	-- below the name's bottom; forcesUnderY / questY are the anchor offsets.
	local dropY = 0
	local forcesUnderY, questY
	local forcesUnder = hasForces and not forcesRight

	if forcesUnder then
		dropY = dropY + Layout.FORCES_GAP_UNDER
		forcesUnderY = -dropY
		dropY = dropY + forcesH
	end

	if subCount > 0 then
		dropY = dropY + Layout.SUB_BOTTOM_OFFSET
		questY = -dropY
		-- Quest text isn't secret, so its measured height is reliable and follows
		-- the quest font size; fall back to a per-line estimate if unmeasured.
		dropY = dropY + ((subH > 0) and subH or (Layout.SUB_LINE_STEP * subCount))
	end

	local belowMain = dropY
	if belowMain > 0 then belowMain = belowMain + Layout.SUB_BOTTOM_OFFSET end -- small bottom margin

	-- Enemy Forces on the right widens the frame and may grow the name row.
	local rightExtra = 0
	if hasForces and forcesRight then
		rightExtra = Layout.FORCES_GAP_RIGHT + forcesW
		mainH = math.max(mainH, forcesH)
	end
	local forcesUnderWidth = forcesUnder and (forcesW + Layout.SUB_LEFT_INSET) or 0

	local width = math.max(mainW + rightExtra, guildW, headerW, statusW, subW + Layout.SUB_LEFT_INSET, forcesUnderWidth)
	width = math.max(Layout.FRAME_MIN_WIDTH, width + (padding * 2))

	local height = topExtra + mainH + belowMain + padding
	height = math.max(Layout.FRAME_MIN_HEIGHT, height)

	f:SetSize(width, height)
	f.mainText:ClearAllPoints()
	-- When forces sit on the right, shift the name left by half the added width
	-- so the name + forces pair stays centered in the frame.
	f.mainText:SetPoint("TOP", f, "TOP", -(rightExtra / 2), -topExtra)

	-- The combat icon hangs off the left of the name line; anchoring its RIGHT to
	-- the mainText LEFT means it grows leftward and never displaces the level.
	f.combatIcon:ClearAllPoints()
	if combatIcon then
		f.combatIcon:SetPoint("RIGHT", f.mainText, "LEFT", -Layout.COMBAT_ICON_GAP, 0)
	end

	local top = 0
	if addon.MBLib.Utils:IsNotEmpty(guildText) then top = SetAnchor(f.guildText, f.mainText, "TOPLEFT", top) end
	if addon.MBLib.Utils:IsNotEmpty(headerText) then top = SetAnchor(f.headerText, f.mainText, "TOPLEFT", top) end
	if addon.MBLib.Utils:IsNotEmpty(statusText) then top = SetAnchor(f.statusText, f.mainText, "TOPLEFT", top) end
	f.subText:ClearAllPoints()
	if subCount > 0 then
		f.subText:SetPoint("TOPLEFT", f.mainText, "BOTTOMLEFT", Layout.SUB_LEFT_INSET, questY)
	end

	f.forcesText:ClearAllPoints()
	if hasForces then
		if forcesRight then
			f.forcesText:SetPoint("LEFT", f.mainText, "RIGHT", Layout.FORCES_GAP_RIGHT, 0)
		else
			f.forcesText:SetPoint("TOPLEFT", f.mainText, "BOTTOMLEFT", Layout.SUB_LEFT_INSET, forcesUnderY)
		end
	end

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
	local anchor = (addon.MBLib.Settings and addon.MBLib.Settings.Get and addon.MBLib.Settings:Get("Display_CursorAnchor")) or "TOP"
	local point = ANCHOR_TO_POINT[anchor] or ANCHOR_TO_POINT.TOP

	local xOffset = (addon.MBLib.Settings and addon.MBLib.Settings.Get and tonumber(addon.MBLib.Settings:Get("Display_CursorOffsetHorizontal"))) or Layout.CURSOR_OFFSET_HORIZONTAL_DEFAULT
	local yOffset = (addon.MBLib.Settings and addon.MBLib.Settings.Get and tonumber(addon.MBLib.Settings:Get("Display_CursorOffsetVertical"))) or Layout.CURSOR_OFFSET_VERTICAL_DEFAULT

	f:ClearAllPoints()
	f:SetPoint(point, UIParent, "BOTTOMLEFT", (x / scale) + xOffset, (y / scale) + yOffset)
end

-- Create the main frame with backdrop support.
local frame = CreateFrame("Frame", "HoverNameFrame", UIParent, "BackdropTemplate")
frame:SetFrameStrata("TOOLTIP")
frame:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background" })
frame:SetBackdropColor(0, 0, 0, 0)

frame.mainText = frame:CreateFontString(nil, "OVERLAY", "GameTooltipText")
frame.combatIcon = frame:CreateFontString(nil, "OVERLAY", "GameTooltipText")
frame.statusText = frame:CreateFontString(nil, "OVERLAY", "GameTooltipText")
frame.headerText = frame:CreateFontString(nil, "OVERLAY", "GameTooltipText")
frame.guildText = frame:CreateFontString(nil, "OVERLAY", "GameTooltipText")
frame.subText = frame:CreateFontString(nil, "OVERLAY", "GameTooltipText")
frame.forcesText = frame:CreateFontString(nil, "OVERLAY", "GameTooltipText")

frame:SetScript("OnUpdate", function(self) UpdateFramePosition(self) end)
frame:SetScript("OnEvent", function(self) UpdateFrameContents(self) end)
frame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")


function HoverName.UpdateFrame()
	pcall(function() UpdateFrameFonts(frame) end)
	pcall(function() UpdateBackground(frame) end)
end

addon.HoverName = HoverName
return HoverName
