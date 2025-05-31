local addonName, addon = ...

Utils = {}

function Utils:GetTextWithColor(text, color)
	return format("|cFF%02x%02x%02x%s |r", color.r * 255, color.g * 255, color.b * 255, text)
end

function Utils:DebugLog(logText)
  if not addon.Settings or not addon.Settings.DebugLogging then return end
  if type(logText) ~= "string" then
    logText = tostring(logText)
  end

  print(string.format("|cffff8000%s|r |cff00ffff[Debug]|r: %s", addonName, logText))
end

function Utils:CombineTables(table1, table2)
	if not table1 or type(table1) ~= "table" then table1 = {} end
	if not table2 or type(table2) ~= "table" then return table1 end
	for _, value in ipairs(table2) do table.insert(table1, value) end
	return table1
end

function Utils:GetNpcID(unit)
	local guid = UnitGUID(unit)
	local npcID = guid and select(6, strsplit("-", guid))
	if not npcID or npcID == "" then
		return nil
	else
		return tonumber(npcID)
	end
end

function Utils:GetTooltipData()
  local tooltipLines = {}
  if not UnitIsPlayer("mouseover") then
    for i = 1, GameTooltip:NumLines() do
      local line = _G["GameTooltipTextLeft" .. i]:GetText()
      if line then table.insert(tooltipLines, line) end
    end
  end
  return tooltipLines
end

function Utils:IsInTooltip(tooltipLines, query)
	if not tooltipLines or type(tooltipLines) ~= "table" then return false end
	if not query or type(query) ~= "string" or query == "" then return false end

	for _, line in ipairs(tooltipLines) do
		if string.find(string.lower(line), string.lower(query)) then return true end
	end
	return false
end

-- Expose module
addon.Utils = Utils