local addonName, addon = ...
local MBLib = addon.MBLib

local OptionsScreen = {}

local function GetDefaultValueLabel(def)
  if not def then return "" end
  if def.Type == "dropdown" and def.Options and #def.Options > 0 then
    for _, opt in ipairs(def.Options) do
      if type(opt) == "table" and opt.value ~= nil and opt.name ~= nil then
        if opt.value == def.Default then
          return tostring(opt.name)
        end
      elseif opt == def.Default then
        return tostring(opt)
      end
    end
  end
  return tostring(def.Default)
end

local function BuildSettingDescription(def)
  local base = def.Description or ""
  local defaultLabel = GetDefaultValueLabel(def)
  local suffix = "(Default: " .. defaultLabel .. ")"
  if base == "" then return suffix end
  return base .. "\n" .. suffix
end

local function CreateCommandList(parent, anchor, startOffsetX)
  local triggers = MBLib.Commands:GetTriggers()
  local usageText = "Usage: " .. table.concat(triggers, " [command] or ") .. " [command]"

  local usageFS = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  usageFS:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", startOffsetX, -5)
  usageFS:SetTextColor(0.7, 0.7, 0.7)
  usageFS:SetText(usageText)

  local lastCmd = usageFS
  if MBLib.Commands and MBLib.Commands.list then
    local keys = {}
    for k in pairs(MBLib.Commands.list) do table.insert(keys, k) end
    table.sort(keys)

    for i, cmd in ipairs(keys) do
      local info = MBLib.Commands.list[cmd]
      local cmdText = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
      if i == 1 then
        cmdText:SetPoint("TOPLEFT", lastCmd, "BOTTOMLEFT", 0, -15)
      else
        cmdText:SetPoint("TOPLEFT", lastCmd, "TOPLEFT", 0, -18)
      end
      cmdText:SetText(MBLib.Commands:GetFormattedCommandStr(cmd, info.desc))
      lastCmd = cmdText
    end
  end
end

local function CreateMainFrame()
  local mainFrame = CreateFrame("Frame", nil)
  mainFrame:Hide()

  local iconPath = MBLib:GetIcon()
  if iconPath then
    local icon = mainFrame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(64, 64)
    icon:SetPoint("TOPLEFT", 15, -15)
    icon:SetTexture(iconPath)
  end

  local title = mainFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
  title:SetPoint("LEFT", mainFrame, "TOPLEFT", iconPath and 94 or 20, -32)
  title:SetText(C_AddOns.GetAddOnMetadata(addonName, "Title"))

  local description = mainFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
  description:SetText(C_AddOns.GetAddOnMetadata(addonName, "Notes"))

  local line1 = MBLib.Utils:CreateSeparator(mainFrame, mainFrame, 15, -100)

  local creditsData = {
    "|cffffd200Version:|r " .. (C_AddOns.GetAddOnMetadata(addonName, "Version") or ""),
    "|cffffd200Author:|r " .. (C_AddOns.GetAddOnMetadata(addonName, "Author") or ""),
    "|cffffd200Last Updated:|r " .. (C_AddOns.GetAddOnMetadata(addonName, "X-Date") or ""),
  }

  local topCredits = mainFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  topCredits:SetPoint("TOPLEFT", line1, "BOTTOMLEFT", 20, -20)
  topCredits:SetJustifyH("LEFT")
  topCredits:SetSpacing(6)
  topCredits:SetText(table.concat(creditsData, "\n"))

  local contactCTA = mainFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  contactCTA:SetPoint("TOPLEFT", topCredits, "BOTTOMLEFT", 0, -30)
  contactCTA:SetText("Questions or issues? Reach out on:")

  local posAnchor = contactCTA
  local function MaybeLink(label, field, prevAnchor, firstOffsetY)
    local value = C_AddOns.GetAddOnMetadata(addonName, field)
    if value and value ~= "" then
      return MBLib.Utils:CreateCopyableLink(mainFrame, label, value, prevAnchor, 0, prevAnchor == contactCTA and (firstOffsetY or -10) or 0)
    end
    return prevAnchor
  end
  posAnchor = MaybeLink("Github:", "X-Github", posAnchor, -10)
  posAnchor = MaybeLink("CurseForge:", "X-CurseForge", posAnchor)
  posAnchor = MaybeLink("Wago.io:", "X-Wago", posAnchor)

  local predecessor = MBLib:GetPredecessor()
  if predecessor then
    local prevAuthors = {}
    for i = 1, 5 do
      local name = C_AddOns.GetAddOnMetadata(addonName, "X-PrevAuthor" .. i)
      if name and name ~= "" then table.insert(prevAuthors, name) end
    end
    if #prevAuthors > 0 then
      local subCredits = mainFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
      subCredits:SetPoint("TOPLEFT", posAnchor, "BOTTOMLEFT", 0, -25)
      subCredits:SetText("|cffaaaaaaThis is a continuation from the original addon|r |cffffd200"
        .. predecessor .. "|r |cffaaaaaaby|r "
        .. table.concat(prevAuthors, " |cffaaaaaa&|r "))
    end
  end

  local line2 = MBLib.Utils:CreateSeparator(mainFrame, mainFrame, 15, -360)
  local cmdTitle = mainFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  cmdTitle:SetPoint("TOPLEFT", line2, "BOTTOMLEFT", 20, -20)
  cmdTitle:SetText("Available Chat Commands:")
  CreateCommandList(mainFrame, cmdTitle, 10)

  return mainFrame
end

local function CreateSettingsCategory(parent)
  local category, layout = Settings.RegisterVerticalLayoutSubcategory(parent, "Display Settings")

  for _, group in ipairs(MBLib.Settings.groupOrder) do
    local defs = MBLib.Settings.byGroup[group]
    if defs and #defs > 0 then
      local visible = {}
      for _, def in ipairs(defs) do
        if not def.Hide then table.insert(visible, def) end
      end

      if #visible > 0 then
        layout:AddInitializer(Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", { name = group }))

        for _, def in ipairs(visible) do
          local variable = addonName .. "_" .. def.Key
          local settingDescription = BuildSettingDescription(def)
          local setting = Settings.RegisterProxySetting(
            category,
            variable,
            type(def.Default),
            def.Name,
            def.Default,
            function() return MBLib.Settings:Get(def.Key) end,
            function(value) MBLib.Settings:Set(def.Key, value) end
          )

          if def.Type == "checkbox" then
            Settings.CreateCheckbox(category, setting, settingDescription)
          elseif def.Type == "dropdown" then
            local function GetOptions()
              local container = Settings.CreateControlTextContainer()
              for _, opt in ipairs(def.Options or {}) do
                if type(opt) == "table" and opt.name and opt.value then
                  container:Add(opt.value, opt.name)
                else
                  container:Add(opt, tostring(opt))
                end
              end
              return container:GetData()
            end
            Settings.CreateDropdown(category, setting, GetOptions, settingDescription)
          elseif def.Type == "slider" then
            local minValue = def.Min or 0
            local maxValue = def.Max or 100
            local step = def.Step or 1
            local options = Settings.CreateSliderOptions(minValue, maxValue, step)
            options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
            Settings.CreateSlider(category, setting, options, settingDescription)
          end
        end
      end
    end
  end
end

local function CreateReleaseNotesCategory(parent)
  local releaseFrame = CreateFrame("Frame", nil)
  releaseFrame:Hide()

  local title = releaseFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 20, -20)
  title:SetText(addonName .. " - Release Notes")

  local settingKey = "GetNotified"
  local def = MBLib.Settings.byKey[settingKey]
  if def then
    local cb = CreateFrame("CheckButton", nil, releaseFrame, "InterfaceOptionsCheckButtonTemplate")
    cb:SetPoint("BOTTOMRIGHT", releaseFrame, "TOPRIGHT", -200, -45)
    cb.Text:SetText(def.Name)
    cb:SetChecked(MBLib.Settings:Get(settingKey))

    cb:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(def.Name, 1, 1, 1)
      GameTooltip:AddLine(def.Description, nil, nil, nil, true)
      GameTooltip:Show()
    end)
    cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
    cb:SetScript("OnShow", function(self) self:SetChecked(MBLib.Settings:Get(settingKey)) end)
    cb:SetScript("OnClick", function(self) MBLib.Settings:Set(settingKey, self:GetChecked()) end)
  end

  local line = MBLib.Utils:CreateSeparator(releaseFrame, releaseFrame, 15, -50)

  local scrollFrame = CreateFrame("ScrollFrame", nil, releaseFrame, "UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", line, "BOTTOMLEFT", 0, -10)
  scrollFrame:SetPoint("BOTTOMRIGHT", releaseFrame, "BOTTOMRIGHT", -30, 20)

  local content = CreateFrame("Frame", nil, scrollFrame)
  content:SetSize(650, 1)
  scrollFrame:SetScrollChild(content)
  if MBLib.Changelog and MBLib.Changelog.Build then
    MBLib.Changelog:Build(content)
  end

  Settings.RegisterCanvasLayoutSubcategory(parent, releaseFrame, "Release Notes")
end

function OptionsScreen:Build()
  if not Settings then return end

  local mainFrame = CreateMainFrame()
  local mainCategory = Settings.RegisterCanvasLayoutCategory(mainFrame, addonName)
  CreateSettingsCategory(mainCategory)
  CreateReleaseNotesCategory(mainCategory)

  Settings.RegisterAddOnCategory(mainCategory)

  MBLib._optionsScreenID = mainCategory:GetID()
  return mainCategory
end

MBLib.OptionsScreen = OptionsScreen
