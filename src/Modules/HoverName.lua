local _, addon = ...

local function GetUnitNameColor(unittype)
	local reaction = UnitReaction(unittype, "player") or 5

	if UnitIsPlayer(unittype) then
		local _, class = UnitClass(unittype)
		return RAID_CLASS_COLORS[class]
	elseif UnitCanAttack("player", unittype) then
		if UnitIsDead(unittype) then
			return addon.COLOR_DEAD
		else
			if reaction < 4 then
				return addon.COLOR_HOSTILE
			elseif reaction == 4 then
				return addon.COLOR_NEUTRAL
			end
		end
	else
		if reaction < 4 then
			return addon.COLOR_HOSTILE_UNATTACKABLE
		else
			return addon.COLOR_DEFAULT
		end
	end
end

local function GetLevelText()
	local level = UnitLevel("mouseover")
	if level and level > 1 then
		return addon.Utils:GetTextWithColor(tostring(level), GetQuestDifficultyColor(level))
	else
		return ""
	end
end

local function GetTargetText()
	local target = UnitName("mouseovertarget")
	if target then
		return addon.Utils:GetTextWithColor(">", addon.COLOR_DEFAULT) ..
				addon.Utils:GetTextWithColor(target, GetUnitNameColor("mouseovertarget"))
	else
		return ""
	end
end

local function GetStatusText(fakeAfk, fakeDnd, fakePvp)
	local afkText = ""
	local dndText = ""
	local pvpText = ""

	if (UnitIsAFK("mouseover") or fakeAfk) then afkText = addon.Utils:GetTextWithColor("<AFK>", addon.COLOR_DEAD) end
	if (UnitIsDND("mouseover") or fakeDnd) then dndText = addon.Utils:GetTextWithColor("<DND>", addon.COLOR_HOSTILE) end
	if ((UnitIsPVP("mouseover") and UnitIsPlayer("mouseover")) or fakePvp) then
		pvpText = addon.Utils:GetTextWithColor("<PVP>",
			addon.COLOR_HOSTILE)
	end

	return (afkText .. dndText .. pvpText)
end

local function GetClassificationText()
	local classification = UnitClassification("mouseover")
	if (classification == "worldboss") then
		return addon.Utils:GetTextWithColor("World Boss", addon.COLOR_ELITE)
	elseif (classification == "elite") then
		return addon.Utils:GetTextWithColor("Elite", addon.COLOR_ELITE)
	elseif (classification == "rareelite") then
		return addon.Utils:GetTextWithColor("Rare Elite", addon.COLOR_RARE)
	elseif (classification == "rare") then
		return addon.Utils:GetTextWithColor("Rare", addon.COLOR_RARE)
	else
		return ""
	end
end

local function GetQuestText(tooltipLines)
	if UnitIsPlayer("mouseover") or not C_QuestLog.UnitIsRelatedToActiveQuest("mouseover") then
		return nil
	end

	local questTexts = {}
	local targetName = string.lower(UnitName("mouseover"))
	local npcID = addon.Utils:GetNpcID("mouseover")
	local weightsTable
	if npcID then weightsTable = addon.LOP:GetNPCWeightByCurrentQuests(npcID) end

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
								table.insert(questTexts,
									{ text = obj.text .. string.format(" + %.1f%%", npcWeight), finished = obj.finished })
								break
							end
						end

						-- Check for "monster" kill objectives (specific NPC kills)
						if obj.type == "monster" and (string.find(string.lower(obj.text), targetName)) then
							table.insert(questTexts, { text = obj.text, finished = obj.finished })
							break
						end

						-- Alternatively, when this quest is displayed in the tooltips by any other addon,
						-- then we can use that data as well
						if addon.Utils:IsInTooltip(tooltipLines, obj.text) then
							table.insert(questTexts, { text = obj.text, finished = obj.finished })
							break
						end
					end
				end
			end
		end
	end

	-- Sort unfinished objectives first, completed ones below
	table.sort(questTexts, function(a, b) return not a.finished and b.finished end)

	-- Convert sorted table to a final list of text entries
	local sortedQuestTexts = {}
	for _, entry in ipairs(questTexts) do
		local color = entry.finished and addon.COLOR_COMPLETE or addon.COLOR_DEFAULT
		local listIcon = entry.finished and addon.ICON_CHECKMARK or addon.ICON_LIST
		table.insert(sortedQuestTexts, addon.Utils:GetTextWithColor(listIcon .. entry.text, color))
	end

	return #sortedQuestTexts > 0 and sortedQuestTexts or nil
end

local function UpdateFrameContents(f)
	local foci = GetMouseFoci()
	local frameName = foci[1] and foci[1]:GetName() or nil
	if frameName ~= nil and frameName ~= "" and frameName ~= "WorldFrame" then return end

	local unitName = UnitName("mouseover")
	if unitName == nil then return end

	local unitText = addon.Utils:GetTextWithColor(unitName, GetUnitNameColor("mouseover"))
	local levelText = GetLevelText()
	local targetText = GetTargetText()
	local statusText = GetStatusText()
	local classText = GetClassificationText()
	local tooltips = addon.Utils:GetTooltipData()

	local mainText = levelText .. unitText .. targetText
	local headerText = statusText .. classText
	f.mainText:SetText(mainText)
	f.headerText:SetText(headerText)

	addon.Utils:DebugLog(string.format("Unit: %s (%s)", mainText, headerText))

	local offset = 0
	local subTexts = addon.Utils:CombineTables(GetQuestText(tooltips))
	if subTexts and #subTexts > 0 then
		offset = 12 * #subTexts
		f.subText:SetText(table.concat(subTexts, "\n"))
	else
		f.subText:SetText("")
	end

	f:SetSize(f.mainText:GetStringWidth(), f.mainText:GetStringHeight())
	f.mainText:SetPoint("TOP", f, "TOP", 0, offset)
	f.headerText:SetPoint("TOPLEFT", f.mainText, "TOPLEFT", 0, 12)
	f.subText:SetPoint("BOTTOMLEFT", f.mainText, "BOTTOMLEFT", 12, -1 + (-12 * #subTexts))

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
