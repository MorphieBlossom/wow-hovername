local _, addon = ...
UnitInfo = {}

local function IsActive(setting)
	if not (addon and addon.Settings and addon.Settings.Get) then return true end
	local value = addon.Settings:Get(setting)
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
		else return addon.COLOR_DEFAULT end

	elseif not IsActive("NPC_ColorState") then
		return addon.COLOR_DEFAULT

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
		return addon.Utils:GetTextWithColor(levelString, GetQuestDifficultyColor(level))
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
		return addon.Utils:GetTextWithColor("> ", addon.COLOR_DEFAULT) ..
				addon.Utils:GetTextWithColor(target, UnitInfo:GetUnitNameColor("mouseovertarget"))
	else
		return ""
	end
end

function UnitInfo:GetStatusText(fakeAfk, fakeDnd, fakePvp)
	if not IsPlayer() or not IsActive("Player_ShowStatus") then return nil end

	local afkText = nil
	local dndText = nil
	local pvpText = nil

	if (UnitIsAFK("mouseover") or fakeAfk) then afkText = addon.Utils:GetTextWithColor("<AFK>", addon.COLOR_DEAD) end
	if (UnitIsDND("mouseover") or fakeDnd) then dndText = addon.Utils:GetTextWithColor("<DND>", addon.COLOR_HOSTILE) end
	if ((UnitIsPVP("mouseover") and UnitIsPlayer("mouseover")) or fakePvp) then
		pvpText = addon.Utils:GetTextWithColor("<PVP>",	addon.COLOR_HOSTILE)
	end

	return addon.Utils:CombineText(afkText, dndText, pvpText)
end

function UnitInfo:GetClassificationText()
	if IsPlayer() or not IsActive("NPC_ShowClassification") then return nil end

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
		text = text .. "<" .. addon.Utils:GetTextWithColor(guildName, addon.COLOR_GUILD) .. ">"
	end
	if IsActive("Player_ShowGuildRank") and guildRank and guildRank ~= "" then
		if text ~= "" then text = text .. " " end
		text = text .. "[" ..  addon.Utils:GetTextWithColor(guildRank, addon.COLOR_GUILD) .. "]"
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
			return addon.Utils:GetTextWithColor(factionLabel, addon.COLOR_HORDE)
		elseif faction == "Alliance" then
			return addon.Utils:GetTextWithColor(factionLabel, addon.COLOR_ALLIANCE)
		else
			return addon.Utils:GetTextWithColor(factionLabel, addon.COLOR_NEUTRAL)
		end
	else
		return nil
	end
end

function UnitInfo:GetRaceText()
	if not IsPlayer() or not IsActive("Player_ShowRace") then return nil end

	local race = UnitRace("mouseover")
	if race then
		return addon.Utils:GetTextWithColor(race, addon.COLOR_DEFAULT)
	else
		return nil
	end
end

function UnitInfo:GetCreatureType()
	if IsPlayer() or not IsActive("NPC_ShowCreatureType") then return nil end

	local t = UnitCreatureType("mouseover")
	if t and not issecretvalue(t) and t ~= "Not specified" then
		return addon.Utils:GetTextWithColor(t, addon.COLOR_DEFAULT)
	else
		return nil
	end
end

-- Expose module
addon.UnitInfo = UnitInfo