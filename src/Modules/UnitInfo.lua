local _, addon = ...
UnitInfo = {}

function UnitInfo:GetUnitNameColor(unittype)
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

function UnitInfo:GetLevelText()
	local level = UnitLevel("mouseover")
	if level and level > 1 then
		return addon.Utils:GetTextWithColor(tostring(level), GetQuestDifficultyColor(level))
	else
		return ""
	end
end

function UnitInfo:GetTargetText()
	local target = UnitName("mouseovertarget")
	if target then
		return addon.Utils:GetTextWithColor(">", addon.COLOR_DEFAULT) ..
				addon.Utils:GetTextWithColor(target, UnitInfo:GetUnitNameColor("mouseovertarget"))
	else
		return ""
	end
end

function UnitInfo:GetStatusText(fakeAfk, fakeDnd, fakePvp)
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

function UnitInfo:GetClassificationText()
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

-- Expose module
addon.UnitInfo = UnitInfo