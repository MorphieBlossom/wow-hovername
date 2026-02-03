local _, addon = ...
QuestInfo = {}

local function IsActive(setting)
	if not (addon and addon.Settings and addon.Settings.Get) then return true end
	local value = addon.Settings:Get(setting)
	if value == nil then return true end
	return value
end

local function GetActiveQuests()
  local results = {}

  -- Retail
  if C_QuestLog and C_QuestLog.GetNumQuestLogEntries then
    local num = C_QuestLog.GetNumQuestLogEntries()
    for i = 1, num do
      local info = C_QuestLog.GetInfo(i)
      if info and not info.isHeader then
        local objectives = {}
        local objs = C_QuestLog.GetQuestObjectives(info.questID) or {}
        for _, o in ipairs(objs) do
          table.insert(objectives, {
            text = o.text,
            type = o.type,
            finished = (o.finished == true),
          })
        end
        table.insert(results, { questID = info.questID, isHeader = false, objectives = objectives })
      end
    end
    return results
  end

  -- Legacy option (no C_QuestLog.GetNumQuestLogEntries)
  local numEntries = GetNumQuestLogEntries() or 0
  for i = 1, numEntries do
    local title, _, _, isHeader, _, _, _, questID = GetQuestLogTitle(i)
    if title and not isHeader then
      local objectives = {}
      local numObj = GetNumQuestLeaderBoards(i) or 0
      for j = 1, numObj do
        local text, typ, finished = GetQuestLogLeaderBoard(j, i)
        if text then
          table.insert(objectives, {
            text = text,
            type = typ, -- often "monster", "item", "object", sometimes nil
            finished = (finished == 1 or finished == true),
          })
        end
      end
      table.insert(results, { questID = questID, isHeader = false, objectives = objectives })
    end
  end

  return results
end

local function UnitIsRelatedToActiveQuest(unit)
  if C_QuestLog and C_QuestLog.UnitIsRelatedToActiveQuest then
    return C_QuestLog.UnitIsRelatedToActiveQuest(unit)
  end
  -- Classic fallback: always true, so quest checks continue
  return true
end

local function StripQuestCount(text)
  if not text then return "" end
  local s = string.lower(text)
  s = s:gsub("%s*:?%s*%d+/%d+", "") -- remove " : X/Y"
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- --- Public: build formatted quest lines for a given unit (e.g., "mouseover") ---
-- Returns: array of colored strings (or nil) you can \n-concat directly under your header.
function QuestInfo:GetQuestText(unit, tooltipLines)
  if UnitIsPlayer(unit) or not UnitIsRelatedToActiveQuest(unit) or not IsActive("Quest_Show") then
		return nil
	end

  local unitName = UnitName(unit)
  if not unitName or unitName == "" then return nil end

  local questTexts = {}
	local targetName = string.lower(unitName)
  tooltipLines = tooltipLines or {}

  local weightsTable
  local npcID = addon.Utils:GetNpcID(unit)
  if npcID and addon.LOP and addon.LOP.GetNPCWeightByCurrentQuests then
    weightsTable = addon.LOP:GetNPCWeightByCurrentQuests(npcID)
  end

	for _, info in ipairs(GetActiveQuests()) do
		if info and not info.isHeader then
			local objectives = info.objectives
			if objectives then
				for _, obj in ipairs(objectives) do
					if obj.text then
						-- Check for progress bar objectives, use the LOP for mob check
						if obj.type == "progressbar" and weightsTable then
							local npcWeight = weightsTable[info.questID]
							if npcWeight then
								table.insert(questTexts, { text = obj.text .. string.format(" + %.1f%%", npcWeight), finished = obj.finished })
								break
							end
						end

						-- Check for "monster" kill objectives (specific NPC kills)
						if obj.type == "monster" and string.find(string.lower(obj.text), targetName, 1, true) then
							table.insert(questTexts, { text = obj.text, finished = obj.finished })
							break
						end

						-- Alternatively, when this quest is displayed in the tooltips by any other addon,
						-- then we can use that data as well
						if addon.Utils:IsInTooltip(tooltipLines, obj.text) or addon.Utils:IsInTooltip(tooltipLines, StripQuestCount(obj.text)) then
							table.insert(questTexts, { text = obj.text, finished = obj.finished })
							break
						end
					end
				end
			end
		end
	end

  -- Filter out finished objectives if the setting is disabled
  if not IsActive("Quest_ShowCompleted") then
    local filtered = {}
    for _, entry in ipairs(questTexts) do
      if not entry.finished then
        table.insert(filtered, entry)
      end
    end
    questTexts = filtered
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

addon.QuestInfo = QuestInfo
return QuestInfo