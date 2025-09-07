local addonName, addon = ...
Utils = {}

local function clamp255(x)
  if type(x) ~= "number" then return 255 end
  if x < 0 then return 0 end
  if x > 1 then x = 1 end
  return math.floor(x * 255 + 0.5)
end

function Utils:GetTextWithColor(text, color)
	local r = clamp255(color and color.r or 1)
  local g = clamp255(color and color.g or 1)
  local b = clamp255(color and color.b or 1)
  return string.format("|cFF%02x%02x%02x%s |r", r, g, b, text)
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
      local fs = _G["GameTooltipTextLeft" .. i]
      if fs and fs.GetText then
        local line = fs:GetText()
        if line then table.insert(tooltipLines, line) end
      end
    end
  end
  return tooltipLines
end

function Utils:GetTopMouseFocusName()
	-- Retail
  if type(GetMouseFoci) == "function" then
    local foci = GetMouseFoci()
    if foci and foci[1] and foci[1].GetName then
      return foci[1]:GetName()
    end
  end
	-- Legacy
  if type(GetMouseFocus) == "function" then
    local f = GetMouseFocus()
    if f and f.GetName then
      return f:GetName()
    end
  end
  return nil
end

function Utils:IsInTooltip(tooltipLines, query)
  if not tooltipLines or type(tooltipLines) ~= "table" then return false end
  if not query or type(query) ~= "string" or query == "" then return false end
  local q = string.lower(query)
  for _, line in ipairs(tooltipLines) do
    if string.find(string.lower(line or ""), q, 1, true) then return true end
  end
  return false
end

-- Expose module
addon.Utils = Utils