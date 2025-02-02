local LOP = LibStub:GetLibrary("LibObjectiveProgress-1.0")

local COLOR_DEFAULT = { r = 1, g = 1, b = 1 }
local COLOR_DEAD = { r = 136 / 255, g = 136 / 255, b = 136 / 255 }
local COLOR_HOSTILE = { r = 1, g = 68 / 255, b = 68 / 255 }
local COLOR_NEUTRAL = { r = 1, g = 1, b = 68 / 255 }
local COLOR_HOSTILE_UNATTACKABLE = { r = 210 / 255, g = 76 / 255, b = 56 / 255 }
local COLOR_RARE = { r = 226 / 255, g = 228 / 255, b = 226 / 255 }
local COLOR_ELITE = { r = 213 / 255, g = 154 / 255, b = 18 / 255 }

local function GetNpcID(unit)
	local guid = UnitGUID(unit)
	local npcID = guid and select(6, strsplit("-", guid))
	if not npcID or npcID == "" then
		return nil
	else
		return tonumber(npcID)
	end
end

local function GetUnitNameColor(unittype)
	local reaction = UnitReaction(unittype, "player") or 5

	if UnitIsPlayer(unittype) then
		local _, class = UnitClass(unittype)
		return RAID_CLASS_COLORS[class]
	elseif UnitCanAttack("player", unittype) then
		if UnitIsDead(unittype) then
			return COLOR_DEAD
		else
			if reaction < 4 then
				return COLOR_HOSTILE
			elseif reaction == 4 then
				return COLOR_NEUTRAL
			end
		end
	else
		if reaction < 4 then
			return COLOR_HOSTILE_UNATTACKABLE
		else
			return COLOR_DEFAULT
		end
	end
end

local function GetTextWithColor(text, color)
	return format("|cFF%02x%02x%02x%s |r", color.r * 255, color.g * 255, color.b * 255, text)
end

local function GetLevelText()
	local level = UnitLevel("mouseover")
	if level and level > 1 then
		return GetTextWithColor(tostring(level), GetQuestDifficultyColor(level))
	else
		return ""
	end
end

local function GetTargetText()
	local target = UnitName("mouseovertarget")
	if target then
		return GetTextWithColor(">", COLOR_DEFAULT) .. GetTextWithColor(target, GetUnitNameColor("mouseovertarget"))
	else
		return ""
	end
end

local function GetStatusText(fakeAfk, fakeDnd, fakePvp)
	local afkText = ""
	local dndText = ""
	local pvpText = ""

	if (UnitIsAFK("mouseover") or fakeAfk) then afkText = GetTextWithColor("<AFK>", COLOR_DEAD) end
	if (UnitIsDND("mouseover") or fakeDnd) then dndText = GetTextWithColor("<DND>", COLOR_HOSTILE) end
	if ((UnitIsPVP("mouseover") and UnitIsPlayer("mouseover")) or fakePvp) then
		pvpText = GetTextWithColor("<PVP>",
			COLOR_HOSTILE)
	end

	return (afkText .. dndText .. pvpText)
end

local function GetClassificationText()
	local classification = UnitClassification("mouseover")
	if (classification == "worldboss") then
		return GetTextWithColor("World Boss", COLOR_ELITE)
	elseif (classification == "elite") then
		return GetTextWithColor("Elite", COLOR_ELITE)
	elseif (classification == "rareelite") then
		return GetTextWithColor("Rare Elite", COLOR_RARE)
	elseif (classification == "rare") then
		return GetTextWithColor("Rare", COLOR_RARE)
	else
		return ""
	end
end

local function GetTooltipData()
	local tooltipLines = {}

	if not UnitIsPlayer("mouseover") then
		for i = 1, GameTooltip:NumLines() do
			local line = _G["GameTooltipTextLeft" .. i]:GetText()
			if line then table.insert(tooltipLines, line)	end
		end
	end

	return tooltipLines
end

local function IsInTooltip(tooltipLines, query)
	if not tooltipLines or type(tooltipLines) ~= "table" then	return false end
	if not query or type(query) ~= "string" or query == "" then	return false end

	for _, line in ipairs(tooltipLines) do
		if string.find(string.lower(line), string.lower(query)) then return true end
	end
	return false
end

local function GetQuestText(tooltipLines)
	if UnitIsPlayer("mouseover") or not C_QuestLog.UnitIsRelatedToActiveQuest("mouseover") then
		return nil
	end

	local targetName = string.lower(UnitName("mouseover"))
	local npcID = GetNpcID("mouseover")
	local weightsTable
	if npcID then weightsTable = LOP:GetNPCWeightByCurrentQuests(npcID) end

	for i = 1, C_QuestLog.GetNumQuestLogEntries() do
		local info = C_QuestLog.GetInfo(i)
		if info and not info.isHeader then
			local objectives = C_QuestLog.GetQuestObjectives(info.questID)
			if objectives then
				for _, obj in ipairs(objectives) do
					if obj.text then
						-- Check for progress bar objectives, use the LOP for mob check
						if obj.type == "progressbar" and weightsTable then
							local npcWeight = weightsTable[info.questID]
							if npcWeight then
								return "- " .. obj.text .. string.format(" + %.1f%%", npcWeight)
							end
						end

						-- Check for "monster" kill objectives (specific NPC kills)
						if obj.type == "monster" and (string.find(string.lower(obj.text), targetName)) then
							return "- " .. obj.text
						end

						-- Alternatively, when this quest is displayed in the tooltips by any other addon,
						-- then we can use that data as well
						if IsInTooltip(tooltipLines, obj.text) then
							return "- " .. obj.text
						end
					end
				end
			end
		end
	end

	return nil
end

local function UpdateFrameContents(f)
	local foci = GetMouseFoci()
	if foci[1] and foci[1]:GetName() ~= "WorldFrame" then return end

	local unitName = UnitName("mouseover")
	if unitName == nil then return end

	local unitText = GetTextWithColor(unitName, GetUnitNameColor("mouseover"))
	local levelText = GetLevelText()
	local targetText = GetTargetText()
	local statusText = GetStatusText()
	local classText = GetClassificationText()

	local tooltips = GetTooltipData()
	local questText = GetQuestText(tooltips)


	local offset = 0
	if questText then offset = 12 end

	f.mainText:SetText(levelText .. unitText .. targetText)
	f.headerText:SetText(statusText .. classText)
	f.subText:SetText(questText)

	f:SetSize(f.mainText:GetStringWidth(), f.mainText:GetStringHeight())
	f.mainText:SetPoint("TOP", f, "TOP", 0, offset)
	f.headerText:SetPoint("TOPLEFT", f.mainText, "TOPLEFT", 0, 12)
	f.subText:SetPoint("BOTTOMLEFT", f.mainText, "BOTTOMLEFT", 12, -15)

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


local frame = CreateFrame("Frame", "MainFrame", UIParent)
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
