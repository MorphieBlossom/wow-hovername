local addonName, addon = ...
local OptionsScreen = {}

-- Build a Settings panel using the Blizzard Settings API (RegisterVerticalLayoutCategory)
-- This file maps the existing addon.Settings.definitions into Settings.RegisterAddOnSetting
function OptionsScreen:Build()
  if not Settings then return end
  local category, layout = Settings.RegisterVerticalLayoutCategory(addonName)

  -- iterate groups in order and register each as a subcategory
  for _, group in ipairs(addon.Settings.groupOrder) do
    local defs = addon.Settings.byGroup[group]
    if defs and #defs > 0 then
      -- filter out hidden settings
      local visible = {}
      for _, def in ipairs(defs) do
        if not def.Hide then table.insert(visible, def) end
      end
      if #visible == 0 then
        -- skip groups that have no visible settings
      else
        -- Add a section header for this group using the built-in section header template
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

  -- show addon version + author
  pcall(function()
    layout:AddInitializer(Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", {
      name = "v" .. tostring(addon.VERSION) .. " by " .. tostring(addon.AUTHOR),
    }))
  end)

  Settings.RegisterAddOnCategory(category)
  addon.OptionsScreen = OptionsScreen
  addon.OptionsScreenID = category:GetID()
  return category, layout
end

-- Auto-build on load so the Settings panel is available immediately
pcall(function() OptionsScreen:Build() end)

return OptionsScreen
