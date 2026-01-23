local addonName, addon = ...
local ConfigScreen = {}
local configFrame

-- UI helpers
local function GetCheckbox(parent, label, initial, onChange)
  local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  cb.text:SetText(label)
  cb.text:SetFont(STANDARD_TEXT_FONT, 12)
  cb.text:SetTextColor(1, 1, 1)
  cb:SetChecked(initial)
  cb:SetScript("OnClick", function(self)
    local checked = self:GetChecked()
    if onChange then onChange(checked) end
  end)
  return cb
end

local function GetNumberInput(parent, initial, min, max, onChange)
  local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
  eb:SetSize(60, 20)
  eb:SetAutoFocus(false)
  eb:SetText(tostring(initial or ""))
  eb:SetMaxLetters(3)
  eb:SetScript("OnEnterPressed", function(self)
    local v = tonumber(self:GetText()) or 0
    if min then v = math.max(min, v) end
    if max then v = math.min(max, v) end
    self:SetText(tostring(v))
    if onChange then onChange(v) end
    self:ClearFocus()
  end)
  eb:SetScript("OnEscapePressed", function(self)
    self:SetText(tostring(initial or ""))
    self:ClearFocus()
  end)
  return eb
end

local function GetDropdown(parent, options, initial, width, onChange)
  -- Use the new Blizzard_Menu dropdown button template and generator API
  local dd = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
  if width then dd:SetWidth(width) end

  dd:SetDefaultText(tostring(initial or ""))
  dd._value = initial

  dd:SetupMenu(function(dropdown, rootDescription)
    for _, opt in ipairs(options or {}) do
      local optVal = opt
      local optText = tostring(optVal)

      local function IsSelected()
        return dropdown._value == optVal
      end

      local function SetSelected(_, value)
        dropdown._value = value
        if onChange then onChange(value) end
        if dropdown.GenerateMenu then
          dropdown:GenerateMenu()
        end
      end

      rootDescription:CreateRadio(optText, IsSelected, SetSelected, optVal)
    end
  end)

  -- Ensure the visible text matches the initial value
  if dd.OverrideText then
    dd:OverrideText(tostring(initial or ""))
  end

  return dd
end

local function CreateSection(cf, yCursor, title, defs)
  local header = cf:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  header:SetPoint("TOPLEFT", 0, yCursor)
  header:SetText(title)

  local line = cf:CreateTexture(nil, "ARTWORK")
  line:SetHeight(1)
  line:SetColorTexture(0.6, 0.6, 0.6, 0.6)
  line:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -8)
  line:SetPoint("TOPRIGHT", -10, -8)

  local entryFrame = CreateFrame("Frame", nil, cf)
  entryFrame:SetPoint("TOPLEFT", line, "BOTTOMLEFT", 0, -8)
  entryFrame:SetPoint("TOPRIGHT", cf, "TOPRIGHT", -10, -8)

  local localY = 0
  local checkboxControls = {}

  -- compute column widths based on entryFrame width (left 60% / right 40%)
  local entryW = entryFrame:GetWidth()
  if not entryW or entryW == 0 then
    entryW = cf:GetWidth() - 20
  end
  local colPadding = 10
  local leftColW = math.floor(entryW * 0.6)
  local rightColX = leftColW + colPadding
  local rightColW = math.max(60, entryW - rightColX - 6)

  for _, def in ipairs(defs) do
    local initial = addon.Settings:Get(def.Key)

    -- Left column: name + description
    local nameFS = entryFrame:CreateFontString(nil, "OVERLAY")
    nameFS:SetPoint("TOPLEFT", entryFrame, "TOPLEFT", 15, localY)
    nameFS:SetJustifyH("LEFT")
    nameFS:SetWidth(leftColW - 20)
    nameFS:SetFont(STANDARD_TEXT_FONT, 13)
    nameFS:SetTextColor(1, 0.82, 0)
    nameFS:SetText(def.Name)

    local descFS = entryFrame:CreateFontString(nil, "OVERLAY")
    descFS:SetPoint("TOPLEFT", nameFS, "BOTTOMLEFT", 0, -4)
    descFS:SetJustifyH("LEFT")
    descFS:SetWidth(leftColW - 20)
    descFS:SetFont(STANDARD_TEXT_FONT, 11)
    descFS:SetTextColor(0.8, 0.8, 0.8, 0.8)
    descFS:SetText(def.Description or "")

    -- force layout measurement
    local nameH = nameFS:GetHeight()
    local descH = descFS:GetHeight()
    local usedH = nameH + descH + 15

    -- Right column: control
    if def.Type == "checkbox" then
      local cb = GetCheckbox(entryFrame, "", initial, function(v) addon.Settings:Set(def.Key, v) end)
      cb.text:SetText("")
      cb:SetPoint("TOPLEFT", entryFrame, "TOPLEFT", rightColX, localY)
      tinsert(checkboxControls, cb)

    elseif def.Type == "number" then
      local eb = GetNumberInput(entryFrame, initial, def.Min, def.Max, function(v) addon.Settings:Set(def.Key, v) end)
      eb:SetPoint("TOPLEFT", entryFrame, "TOPLEFT", rightColX, localY)

    elseif def.Type == "selection" then
      local dd = GetDropdown(entryFrame, def.Options, initial, math.min(160, rightColW - 8),
        function(v) addon.Settings:Set(def.Key, v) end)
      dd:SetPoint("TOPLEFT", entryFrame, "TOPLEFT", rightColX, localY)

    else -- text
      local eb = CreateFrame("EditBox", nil, entryFrame, "InputBoxTemplate")
      eb:SetSize(math.max(80, rightColW - 12), 20)
      eb:SetAutoFocus(false)
      eb:SetPoint("TOPLEFT", entryFrame, "TOPLEFT", rightColX, localY)
      eb:SetText(tostring(initial or ""))
      eb:SetScript("OnEnterPressed", function(self)
        local v = self:GetText()
        addon.Settings:Set(def.Key, v)
        self:ClearFocus()
      end)
      eb:SetScript("OnEscapePressed", function(self)
        self:SetText(tostring(initial or ""))
        self:ClearFocus()
      end)
    end

    -- advance cursor by measured height
    localY = localY - (usedH + 6)
  end

  -- ensure entry frame has height
  local entryHeight = math.max(1, math.abs(localY))
  entryFrame:SetHeight(entryHeight)
  entryFrame:Show()

  local sectionBottomMargin = 30
  local newCursor = yCursor - (header:GetHeight() + math.abs(localY)) - 10 - sectionBottomMargin
  return newCursor
end

function ConfigScreen:CreateConfig()
  if configFrame then return configFrame end

  local mainWidth = 600
  local mainHeight = 500

  local mainFrame = CreateFrame("Frame", "ConfigFrame", UIParent, "BasicFrameTemplateWithInset")
  mainFrame:SetSize(mainWidth, mainHeight)
  mainFrame:SetPoint("CENTER")
  mainFrame:SetMovable(true)
  mainFrame:EnableMouse(true)
  mainFrame:RegisterForDrag("LeftButton")
  mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
  mainFrame:SetScript("OnDragStop", mainFrame.StopMovingOrSizing)
  mainFrame:Hide()

  mainFrame.TitleBg:SetHeight(30)
  mainFrame.TitleText:SetText(addon.NAME)

  local versionLabel = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  versionLabel:SetPoint("TOPRIGHT", -35, -8)
  versionLabel:SetText("v" .. addon.VERSION)
  versionLabel:SetTextColor(0.7, 0.7, 0.7)

  -- scroll frame
  local scrollFrame = CreateFrame("ScrollFrame", "ConfigScrollFrame", mainFrame, "UIPanelScrollFrameTemplate")
  local scrollFramePadding = 10
  local scrollerPadding = 35
  scrollFrame:SetPoint("TOPLEFT", mainFrame.TitleBg, "BOTTOMLEFT", scrollFramePadding, 0)
  scrollFrame:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -scrollerPadding, scrollFramePadding)
  --local scrollBg = scrollFrame:CreateTexture(nil, "BACKGROUND")
  --scrollBg:SetAllPoints(scrollFrame)
  --scrollBg:SetColorTexture(0.06, 0.06, 0.06, 0.9)

  local contentWidth = mainWidth - (scrollFramePadding * 2) - scrollerPadding
  local contentFrame = CreateFrame("Frame", nil, scrollFrame)
  contentFrame:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 5, -5)
  contentFrame:SetWidth(contentWidth)
  scrollFrame:SetScrollChild(contentFrame)
  --local contentBg = contentFrame:CreateTexture(nil, "BACKGROUND")
  --contentBg:SetAllPoints(contentFrame)
  --contentBg:SetColorTexture(0, 1, 1, 0.6)

  -- build grouped sections
  local yCursor = -10
  for _, group in ipairs(addon.Settings.groupOrder) do
    local defs = addon.Settings.byGroup[group]
    if defs and #defs > 0 then
      yCursor = CreateSection(contentFrame, yCursor, group, defs)
    end
  end

  -- set the content frame height based on accumulated yCursor so the scrollchild can be larger than the view
  contentFrame:SetHeight(math.max(1, -yCursor + 20))

  configFrame = mainFrame
  tinsert(UISpecialFrames, "ConfigFrame")
  return mainFrame
end

function ConfigScreen:ToggleView()
  if not configFrame then self:CreateConfig() end
  if configFrame:IsShown() then configFrame:Hide() else configFrame:Show() end
end

addon.ConfigScreen = ConfigScreen
return ConfigScreen
