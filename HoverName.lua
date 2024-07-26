local function getcolor()
	local reaction = UnitReaction("mouseover", "player") or 5
	
	if UnitIsPlayer("mouseover") then
		local _, class = UnitClass("mouseover")
		local color = RAID_CLASS_COLORS[class]
		return color.r, color.g, color.b
	elseif UnitCanAttack("player", "mouseover") then
		if UnitIsDead("mouseover") then
			return 136/255, 136/255, 136/255
		else
			if reaction<4 then
				return 1, 68/255, 68/255
			elseif reaction==4 then
				return 1, 1, 68/255
			end
		end
	else
		if reaction<4 then
			return 48/255, 113/255, 191/255
		else
			return 1, 1, 1
		end
	end
end

local f = CreateFrame("Frame")
f:SetFrameStrata("TOOLTIP")
f.text = f:CreateFontString(nil, "OVERLAY")
f.text:SetFont("Interface\\AddOns\\HoverName\\Expressway.ttf", 9, "OUTLINE")

f:SetScript("OnUpdate", function(self)
	if not UnitExists("mouseover") then self:Hide() return end
	local x, y = GetCursorPosition()
	local scale = UIParent:GetEffectiveScale()
	self.text:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y+15)
end)

f:SetScript("OnEvent", function(self)
	local foci = GetMouseFoci()
	if foci[1] and foci[1]:GetName()~="WorldFrame" then return end

	local name = UnitName("mouseover")
	local level = UnitLevel("mouseover")
	local target = UnitName("mouseovertarget")
	local AFK = UnitIsAFK("mouseover")
	local DND = UnitIsDND("mouseover")
	local levelprefix = ""
	local statusprefix = ""

	if level and level > 1 then
		local difficulty = GetQuestDifficultyColor(level)
		levelprefix = format("|cFF%02x%02x%02x%s |r", difficulty.r*255, difficulty.g*255, difficulty.b*255, tostring(level))
	end

	if AFK then statusprefix = "<AFK> " end
	if DND then statusprefix = "<DND> " end

	self.text:SetTextColor(getcolor())

	if target then
		local r, g, b = getcolor()
		self.text:SetText(statusprefix..levelprefix..name..(("|cFFFFFFFF > |cFF%02x%02x%02x"):format(r*255, g*255, b*255))..target)
	else
		self.text:SetText(statusprefix..levelprefix..name)
	end

	self:Show()
end)

f:RegisterEvent("UPDATE_MOUSEOVER_UNIT")