local _, addon = ...
UnitInfo = {}

local function IsActive(setting)
	if not (addon and addon.MBLib.Settings and addon.MBLib.Settings.Get) then return true end
	local value = addon.MBLib.Settings:Get(setting)
	if value == nil then return true end
	return value
end

local function IsPlayer(unittype)
	return UnitIsPlayer(unittype or "mouseover")
end

function UnitInfo:GetUnitNameColor(unittype)
	local reaction = UnitReaction(unittype, "player") or 5

	if IsPlayer(unittype) then
		if IsActive("Player_ClassColor") then
			local _, class = UnitClass(unittype)
			return RAID_CLASS_COLORS[class]
		else return addon.MBLib.COLOR_DEFAULT end

	elseif not IsActive("NPC_ColorState") then
		return addon.MBLib.COLOR_DEFAULT

	elseif UnitCanAttack("player", unittype) then
		if UnitIsDead(unittype) then
			return addon.MBLib.COLOR_DEAD
		else
			if reaction < 4 then
				return addon.MBLib.COLOR_HOSTILE
			elseif reaction == 4 then
				return addon.MBLib.COLOR_NEUTRAL
			end
		end

	else
		if reaction < 4 then
			return addon.MBLib.COLOR_HOSTILE_UNATTACKABLE
		else
			return addon.MBLib.COLOR_DEFAULT
		end
	end
end

function UnitInfo:GetLevelText()
	local isPlayer = IsPlayer()
	if isPlayer and not IsActive("Player_ShowLevel") then return "" end
	if not isPlayer and not IsActive("NPC_ShowLevel") then return "" end

	local level = UnitLevel("mouseover")
	if level and level > 1 then
		local levelString = tostring(level)
		if (isPlayer and not IsActive("Player_LevelColor")) or (not isPlayer and not IsActive("NPC_LevelColor")) then
			return levelString
		end
		return addon.MBLib.Utils:GetTextWithColor(levelString, GetQuestDifficultyColor(level))
	else
		return ""
	end
end

function UnitInfo:GetTargetText()
	local isPlayer = IsPlayer()
	if isPlayer and not IsActive("Player_ShowTarget") then return "" end
	if not isPlayer and not IsActive("NPC_ShowTarget") then return "" end

	local target = UnitName("mouseovertarget")
	if target then
		return addon.MBLib.Utils:GetTextWithColor("> ", addon.MBLib.COLOR_DEFAULT) ..
				addon.MBLib.Utils:GetTextWithColor(target, UnitInfo:GetUnitNameColor("mouseovertarget"))
	else
		return ""
	end
end

function UnitInfo:GetStatusText()
	if not IsPlayer() or not IsActive("Player_ShowStatus") then return nil end

	local afkText = nil
	local dndText = nil
	local pvpText = nil
	local isAfk = UnitIsAFK("mouseover")
	local isDnd = UnitIsDND("mouseover")
	local isPvp = UnitIsPVP("mouseover")

	if (not issecretvalue(isAfk) and isAfk) then afkText = addon.MBLib.Utils:GetTextWithColor("<AFK>", addon.MBLib.COLOR_DEAD) end
	if (not issecretvalue(isDnd) and isDnd) then dndText = addon.MBLib.Utils:GetTextWithColor("<DND>", addon.MBLib.COLOR_HOSTILE) end
	if (not issecretvalue(isPvp) and isPvp and UnitIsPlayer("mouseover")) then
		pvpText = addon.MBLib.Utils:GetTextWithColor("<PVP>",	addon.MBLib.COLOR_HOSTILE)
	end

	return addon.MBLib.Utils:CombineText(afkText, dndText, pvpText)
end

function UnitInfo:GetClassificationText()
	if IsPlayer() or not IsActive("NPC_ShowClassification") then return nil end

	local classification = UnitClassification("mouseover")
	if (classification == "worldboss") then
		return addon.MBLib.Utils:GetTextWithColor("World Boss", addon.MBLib.COLOR_ELITE)
	elseif (classification == "elite") then
		return addon.MBLib.Utils:GetTextWithColor("Elite", addon.MBLib.COLOR_ELITE)
	elseif (classification == "rareelite") then
		return addon.MBLib.Utils:GetTextWithColor("Rare Elite", addon.MBLib.COLOR_RARE)
	elseif (classification == "rare") then
		return addon.MBLib.Utils:GetTextWithColor("Rare", addon.MBLib.COLOR_RARE)
	else
		return nil
	end
end

function UnitInfo:GetGuildText()
	if not IsPlayer() then return nil end
	if not IsActive("Player_ShowGuildName") and not IsActive("Player_ShowGuildRank") then return nil end

	local guildName, guildRank = GetGuildInfo("mouseover")
	if not guildName then return nil end

	local text = ""
	if IsActive("Player_ShowGuildName") then
		text = text .. "<" .. addon.MBLib.Utils:GetTextWithColor(guildName, addon.MBLib.COLOR_GUILD) .. ">"
	end
	if IsActive("Player_ShowGuildRank") and guildRank and guildRank ~= "" then
		if text ~= "" then text = text .. " " end
		text = text .. "[" ..  addon.MBLib.Utils:GetTextWithColor(guildRank, addon.MBLib.COLOR_GUILD) .. "]"
	end

	if (text == "") then return nil end
	return text
end

function UnitInfo:GetFactionText()
	local isPlayer = IsPlayer()
	if isPlayer and not IsActive("Player_ShowFaction") then return nil end
	if not isPlayer and not IsActive("NPC_ShowFaction") then return nil end

	local factionLabel, faction = UnitFactionGroup("mouseover")
	if factionLabel then
		if faction == "Horde" then
			return addon.MBLib.Utils:GetTextWithColor(factionLabel, addon.MBLib.COLOR_HORDE)
		elseif faction == "Alliance" then
			return addon.MBLib.Utils:GetTextWithColor(factionLabel, addon.MBLib.COLOR_ALLIANCE)
		else
			return addon.MBLib.Utils:GetTextWithColor(factionLabel, addon.MBLib.COLOR_NEUTRAL)
		end
	else
		return nil
	end
end

function UnitInfo:GetRaceText()
	if not IsPlayer() or not IsActive("Player_ShowRace") then return nil end

	local race = UnitRace("mouseover")
	if race then
		return addon.MBLib.Utils:GetTextWithColor(race, addon.MBLib.COLOR_DEFAULT)
	else
		return nil
	end
end

function UnitInfo:GetCreatureType()
	if IsPlayer() or not IsActive("NPC_ShowCreatureType") then return nil end

	local t = UnitCreatureType("mouseover")
	if t and not issecretvalue(t) and t ~= "Not specified" then
		return addon.MBLib.Utils:GetTextWithColor(t, addon.MBLib.COLOR_DEFAULT)
	else
		return nil
	end
end

-- Expose module
addon.UnitInfo = UnitInfo