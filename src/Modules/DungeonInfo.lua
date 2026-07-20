local _, addon = ...
DungeonInfo = {}

-- ===== Mythic+ Enemy Forces =====
-- Shows how much a hovered enemy contributes to the dungeon's Enemy Forces
-- requirement, and optionally the overall pull progress. Only active during a
-- live keystone run.
--
-- SECRET VALUES: In an active keystone the mouseover unit's identity is a
-- "secret value", so C_ScenarioInfo.GetUnitCriteriaProgressValues returns
-- secret numbers/strings. Blizzard forbids comparison, arithmetic, boolean
-- tests and indexing on secret values in tainted execution, but ALLOWS
-- concatenation, string.format and passing them to FontString:SetText. So this
-- module is display-only: it never does math on the returned values. Any
-- comparison is gated behind issecretvalue() so it only runs on plain values.
-- Consequence: a "projected" figure (current + this mob) is impossible, since
-- that would be arithmetic on a secret value.

local CONTRIBUTION_COLOR = addon.MBLib.COLOR_DEFAULT       -- white: the mob's own value
local CONTEXT_COLOR      = { r = 0.7, g = 0.7, b = 0.7 }   -- light gray: pull progress

local function IsActive(setting)
  if not (addon and addon.MBLib.Settings and addon.MBLib.Settings.Get) then return true end
  local value = addon.MBLib.Settings:Get(setting)
  if value == nil then return true end
  return value
end

local function S(key)
  return addon.MBLib.Settings and addon.MBLib.Settings.Get and addon.MBLib.Settings:Get(key)
end

local function InMythicPlus()
  if not (C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive) then return false end
  local ok, active = pcall(C_ChallengeMode.IsChallengeModeActive)
  return ok and active == true
end

-- True when v holds something displayable. Safe on secret values: issecretvalue
-- short-circuits before any comparison touches a secret.
local function Present(v)
  if issecretvalue(v) then return true end
  return v ~= nil and v ~= ""
end

-- Raw-count display. Concatenation with a secret number is allowed, so this
-- works whether v is secret or plain.
local function NumberStr(v)
  if not Present(v) then return nil end
  return "" .. v
end

-- Combine a raw + percent into one part per the chosen mode.
-- percentStr / numberStr may be nil; falls back to whatever is available.
local function Compose(mode, numberStr, percentStr)
  if mode == "NUMBER" then
    return numberStr or percentStr
  elseif mode == "BOTH" then
    if numberStr and percentStr then return numberStr .. " (" .. percentStr .. ")" end
    return numberStr or percentStr
  end
  return percentStr or numberStr -- default: PERCENT
end

-- Scan the current scenario step for the Enemy Forces (weighted-progress)
-- criterion. Returns quantity (current, 0-100 percent) and totalQuantity
-- (total raw count) as-is (either may be secret), or nil,nil.
local function GetForcesCriteria()
  if not (C_Scenario and C_Scenario.GetStepInfo and C_ScenarioInfo and C_ScenarioInfo.GetCriteriaInfo) then
    return nil
  end

  local _, _, numCriteria = C_Scenario.GetStepInfo()
  if not numCriteria or issecretvalue(numCriteria) or numCriteria <= 0 then return nil end

  for i = 1, numCriteria do
    local info = C_ScenarioInfo.GetCriteriaInfo(i)
    if info and info.isWeightedProgress then
      return info.quantity, info.totalQuantity
    end
  end

  return nil
end

local function Build(unit)
  if not IsActive("MythicPlus_ShowForces") then return nil end
  if UnitIsPlayer(unit) then return nil end
  if not InMythicPlus() then return nil end
  if not (C_ScenarioInfo and C_ScenarioInfo.GetUnitCriteriaProgressValues) then return nil end

  -- actualValue = raw count (int), percentValueString = preformatted percent.
  -- percentValue (the float) is intentionally ignored: using it requires math.
  local actualValue, _, percentValueString = C_ScenarioInfo.GetUnitCriteriaProgressValues(unit)

  -- Bail only when we can *safely* prove there is nothing to show. When the
  -- value is secret it is present by definition, so we display it.
  if not issecretvalue(actualValue) then
    local n = tonumber(actualValue)
    if not n or n <= 0 then return nil end
  end

  local mode = S("MythicPlus_ContributionFormat") or "PERCENT"
  -- The API's percentValueString has no "%" sign, so append one (concatenation
  -- is allowed on secret values). Falls back to nil when the string is absent.
  local pctPart = Present(percentValueString) and (percentValueString .. "%") or nil
  local contrib = Compose(mode, NumberStr(actualValue), pctPart)
  if not contrib then return nil end

  local line = addon.MBLib.Utils:GetTextWithColor("+" .. contrib, CONTRIBUTION_COLOR)

  if IsActive("MythicPlus_ShowProgress") then
    local currentQ, totalQ = GetForcesCriteria()
    if Present(currentQ) then
      local pMode = S("MythicPlus_ProgressFormat") or "PERCENT"

      -- current: percent is always available; the raw count needs
      -- currentPct/100 * total, which is only legal when both are plain.
      local curNum
      if not issecretvalue(currentQ) and not issecretvalue(totalQ) then
        local cp, tr = tonumber(currentQ), tonumber(totalQ)
        if cp and tr then curNum = tostring(math.floor((cp / 100) * tr + 0.5)) end
      end
      -- Current value shows as a bare number (no "%"); only the total carries
      -- the "%" sign, e.g. "(20 / 100%)".
      local currentStr = Compose(pMode, curNum, NumberStr(currentQ))

      -- total: 100% and (if present) the raw total count.
      local totalStr = Compose(pMode, NumberStr(totalQ), "100%")

      if currentStr and totalStr then
        local ctx = "(" .. currentStr .. " / " .. totalStr .. ")"
        line = line .. " " .. addon.MBLib.Utils:GetTextWithColor(ctx, CONTEXT_COLOR)
      end
    end
  end

  return { line }
end

-- Worst-case literal used to reserve display width, since the real line may be
-- a secret value that can't be measured. Mirrors the chosen format with its
-- widest tokens ("999" counts, "100%").
function DungeonInfo:GetReserveText()
  local mode = S("MythicPlus_ContributionFormat") or "PERCENT"
  local reserve
  if mode == "NUMBER" then
    reserve = "+999"
  elseif mode == "BOTH" then
    reserve = "+999 (100%)"
  else
    reserve = "+100%"
  end

  if IsActive("MythicPlus_ShowProgress") then
    local pMode = S("MythicPlus_ProgressFormat") or "PERCENT"
    local ctx
    if pMode == "NUMBER" then
      ctx = "(999 / 999)"
    elseif pMode == "BOTH" then
      ctx = "(999 (100%) / 999 (100%))"
    else
      ctx = "(999 / 100%)"
    end
    reserve = reserve .. " " .. ctx
  end

  return reserve
end

-- Public: array of colored strings (one line) for the given unit, or nil.
function DungeonInfo:GetForcesText(unit)
  local ok, result = pcall(Build, unit)
  if ok then return result end
  return nil
end

addon.DungeonInfo = DungeonInfo
return DungeonInfo
