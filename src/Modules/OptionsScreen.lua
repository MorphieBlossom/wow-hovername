local addonName, addon = ...
local OptionsScreen = {}

local function CreateCommandList(parent, anchor, startOffsetX, startOffsetY)
  local triggers = addon.Commands:GetTriggers()
  local usageText = "Usage: " .. table.concat(triggers, " [command] or ") .. " [command]"

  local usageFS = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  usageFS:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", startOffsetX, -5)
  usageFS:SetTextColor(0.7, 0.7, 0.7)
  usageFS:SetText(usageText)

  local lastCmd = usageFS
  if addon.Commands and addon.Commands.list then
    local keys = {}
    for k in pairs(addon.Commands.list) do table.insert(keys, k) end
    table.sort(keys)

    for i, cmd in ipairs(keys) do
      local info = addon.Commands.list[cmd]
      local cmdText = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")

      if i == 1 then
        cmdText:SetPoint("TOPLEFT", lastCmd, "BOTTOMLEFT", 0, -15)
      else
        cmdText:SetPoint("TOPLEFT", lastCmd, "TOPLEFT", 0, -18)
      end

      cmdText:SetText(addon.Commands:GetFormattedCommandStr(cmd, info.desc))
      lastCmd = cmdText
    end
  end
end

local function CreateMainFrame()
  local mainFrame = CreateFrame("Frame", nil)
  mainFrame:Hide()

  local icon = mainFrame:CreateTexture(nil, "ARTWORK")
  icon:SetSize(64, 64)
  icon:SetPoint("TOPLEFT", 15, -15)
  icon:SetTexture("Interface\\AddOns\\" .. addonName .. "\\Media\\hovername-icon.png")

  local title = mainFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
  title:SetPoint("LEFT", icon, "RIGHT", 15, 10)
  title:SetText(C_AddOns.GetAddOnMetadata(addonName, "Title"))

  local description = mainFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
  description:SetText(C_AddOns.GetAddOnMetadata(addonName, "Notes"))

  local line1 = addon.Utils:CreateSeparator(mainFrame, mainFrame, 15, -100)

  local creditsData = {
    "|cffffd200Version:|r " .. C_AddOns.GetAddOnMetadata(addonName, "Version"),
    "|cffffd200Author:|r " .. C_AddOns.GetAddOnMetadata(addonName, "Author"),
    "|cffffd200Last Updated:|r " .. C_AddOns.GetAddOnMetadata(addonName, "X-Date"),
  }

  local topCredits = mainFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  topCredits:SetPoint("TOPLEFT", line1, "BOTTOMLEFT", 20, -20)
  topCredits:SetJustifyH("LEFT")
  topCredits:SetSpacing(6)
  topCredits:SetText(table.concat(creditsData, "\n"))

  local contactCTA = mainFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  contactCTA:SetPoint("TOPLEFT", topCredits, "BOTTOMLEFT", 0, -30)
  contactCTA:SetText("Questions or issues? Reach out on:")

  local posAnchor
  posAnchor = addon.Utils:CreateCopyableLink(mainFrame, "Github:", C_AddOns.GetAddOnMetadata(addonName, "X-Github"), contactCTA, 0, -10)
  posAnchor = addon.Utils:CreateCopyableLink(mainFrame, "CurseForge:", C_AddOns.GetAddOnMetadata(addonName, "X-CurseForge"), posAnchor, 0, 0)
  posAnchor = addon.Utils:CreateCopyableLink(mainFrame, "Wago.io:", C_AddOns.GetAddOnMetadata(addonName, "X-Wago"), posAnchor, 0, 0)

  local subCredits = mainFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  local prevAuthors = {
    C_AddOns.GetAddOnMetadata(addonName, "X-PrevAuthor1"),
    C_AddOns.GetAddOnMetadata(addonName, "X-PrevAuthor2")
  }

  subCredits:SetPoint("TOPLEFT", posAnchor, "BOTTOMLEFT", 0, -25)
  if #prevAuthors > 0 then
    subCredits:SetText("|cffaaaaaaThis is a continuation from the original addon|r |cffffd200ncHoverName|r |cffaaaaaaby|r " .. table.concat(prevAuthors, " |cffaaaaaa&|r "))
  end

  local line2 = addon.Utils:CreateSeparator(mainFrame, mainFrame, 15, -360)
  local cmdTitle = mainFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  cmdTitle:SetPoint("TOPLEFT", line2, "BOTTOMLEFT", 20, -20)
  cmdTitle:SetText("Available Chat Commands:")
  CreateCommandList(mainFrame, cmdTitle, 10, -10)

  return mainFrame
end


local function CreateSettingsCategory(parent)
  local category, layout = Settings.RegisterVerticalLayoutSubcategory(parent, "Display Settings")

  for _, group in ipairs(addon.Settings.groupOrder) do
    local defs = addon.Settings.byGroup[group]
    if defs and #defs > 0 then
      local visible = {}
      for _, def in ipairs(defs) do
        if not def.Hide then table.insert(visible, def) end
      end

      if #visible > 0 then
        layout:AddInitializer(Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", { name = group }))

        for _, def in ipairs(visible) do
          local variable = addonName .. "_" .. def.Key
          local setting = Settings.RegisterProxySetting(
            category,
            variable,
            type(def.Default),
            def.Name,
            def.Default,
            function() return addon.Settings:Get(def.Key) end,
            function(value) addon.Settings:Set(def.Key, value) end
          )

          if def.Type == "checkbox" then
            Settings.CreateCheckbox(category, setting, def.Description)

          elseif def.Type == "dropdown" then
            local function GetOptions()
              local container = Settings.CreateControlTextContainer()
              for _, opt in ipairs(def.Options or {}) do
                container:Add(opt, tostring(opt))
              end
              return container:GetData()
            end
            Settings.CreateDropdown(category, setting, GetOptions, def.Description)

          elseif def.Type == "slider" then
            local minValue = def.Min or 0
            local maxValue = def.Max or 100
            local step = def.Step or 1
            local options = Settings.CreateSliderOptions(minValue, maxValue, step)
            options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
            Settings.CreateSlider(category, setting, options, def.Description)
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
  local def = addon.Settings.byKey[settingKey]
  local cb = CreateFrame("CheckButton", nil, releaseFrame, "InterfaceOptionsCheckButtonTemplate")
  cb:SetPoint("BOTTOMRIGHT", releaseFrame, "TOPRIGHT", -200, -45)
  cb.Text:SetText(def.Name)
  cb:SetChecked(addon.Settings:Get(settingKey))

  cb:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(def.Name, 1, 1, 1)
    GameTooltip:AddLine(def.Description, nil, nil, nil, true)
    GameTooltip:Show()
  end)

  cb:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  cb:SetScript("OnShow", function(self)
    self:SetChecked(addon.Settings:Get(settingKey))
  end)

  cb:SetScript("OnClick", function(self)
    local isChecked = self:GetChecked()
    addon.Settings:Set(settingKey, isChecked)
  end)

  local line = addon.Utils:CreateSeparator(releaseFrame, releaseFrame, 15, -50)

  local scrollFrame = CreateFrame("ScrollFrame", nil, releaseFrame, "UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", line, "BOTTOMLEFT", 0, -10)
  scrollFrame:SetPoint("BOTTOMRIGHT", releaseFrame, "BOTTOMRIGHT", -30, 20)

  local content = CreateFrame("Frame", nil, scrollFrame)
  content:SetSize(650, 500)
  content:SetSize(650, 1) -- Height will be updated by Changelog:Build
  scrollFrame:SetScrollChild(content)
  addon.Changelog:Build(content) -- Tell Changelog to draw itself into the content frame

  Settings.RegisterCanvasLayoutSubcategory(parent, releaseFrame, "Release Notes")
end


function OptionsScreen:Build()
  if not Settings then return end

  local mainFrame = CreateMainFrame()
  local mainCategory = Settings.RegisterCanvasLayoutCategory(mainFrame, addonName)
  CreateSettingsCategory(mainCategory)
  CreateReleaseNotesCategory(mainCategory)

  Settings.RegisterAddOnCategory(mainCategory)

  addon.OptionsScreen = OptionsScreen
  addon.OptionsScreenID = mainCategory:GetID()
  return mainCategory
end

-- Auto-build on load so the Settings panel is available immediately
pcall(function() OptionsScreen:Build() end)
return OptionsScreen
