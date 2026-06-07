local addonName, addon = ...
local MBLib = addon.MBLib

-- MacroButton
--
-- An optional icon-style button rendered on the addon's main settings page
-- (the canvas Blizzard shows when the addon's entry is selected in the
-- AddOns settings tree). Clicking or dragging the button creates a saved
-- macro (if missing) and places it on the cursor so the user can drop it
-- onto any action bar slot. The drop-target slot then becomes a one-click
-- shortcut into the addon's settings panel.
--
-- Consumer API (call once during addon load, before MBLib:Init runs the
-- options screen build):
--
--   addon.MBLib:SetMacroButton({
--     icon      = "xxx",
--     macroName = "xxx",
--     macroBody = "/<addonname> settings",
--     tooltip   = {
--       title = "xxx",
--       desc  = "xxx",
--     },
--   })
--
-- If SetMacroButton is never called, MacroButton:Build returns nil and the
-- main page renders without the button — zero footprint for addons that
-- don't want this feature.

local MacroButton = {}

local function resolveTexture(icon)
  if type(icon) == "number" then return icon end
  if type(icon) ~= "string" or icon == "" then return nil end
  if icon:find("\\") or icon:find("/") then return icon end
  return "Interface\\Icons\\" .. icon
end

local function defaultMacroBody()
  return "/" .. addonName:lower() .. " settings"
end

function MBLib:SetMacroButton(opts)
  if type(opts) ~= "table" then return end
  self._macroButton = {
    icon      = opts.icon,
    macroName = opts.macroName,
    macroBody = opts.macroBody,
    tooltip   = type(opts.tooltip) == "table" and opts.tooltip or nil,
  }
end

function MBLib:GetMacroButtonConfig()
  return self._macroButton
end

function MacroButton:Build(parent, opts)
  local cfg = MBLib._macroButton
  if not cfg then return nil end
  if not parent then return nil end
  opts = opts or {}
  local size       = tonumber(opts.size) or 40
  local showBorder = opts.showBorder ~= false

  local macroName = cfg.macroName or addonName
  local macroBody = cfg.macroBody or defaultMacroBody()
  local iconArg   = cfg.icon

  local btn = CreateFrame("Button", nil, parent)
  btn:SetSize(size, size)

  if iconArg then
    btn:SetNormalTexture(resolveTexture(iconArg))
    local nt = btn:GetNormalTexture()
    if nt then nt:SetTexCoord(0.07, 0.93, 0.07, 0.93) end
  end

  btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  btn:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")

  if showBorder then
    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    border:SetSize(size * 1.6, size * 1.6)
    border:SetPoint("CENTER")
  end

  local tooltip = cfg.tooltip or {}
  local tipTitle = tooltip.title or ("Pick up " .. macroName .. " macro")
  local tipDesc  = tooltip.desc or
    ("Picks up a |cffffff00" .. macroBody .. "|r macro onto your cursor. " ..
     "Drop it on any action bar slot to get a button that runs the macro.")
  btn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(tipTitle, 1, 1, 1)
    GameTooltip:AddLine(tipDesc, nil, nil, nil, true)
    GameTooltip:Show()
  end)
  btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
  btn:RegisterForClicks("LeftButtonUp")
  btn:RegisterForDrag("LeftButton")

  local function pickup()
    if InCombatLockdown() then
      print("|cffff8000" .. addonName .. "|r: can't manage macros during combat.")
      return
    end
    if not (GetMacroIndexByName and PickupMacro) then
      print("|cffff8000" .. addonName .. "|r: macro API unavailable on this client.")
      return
    end
    local idx = GetMacroIndexByName(macroName) or 0
    if idx == 0 then
      if not CreateMacro then return end
      local ok = pcall(CreateMacro, macroName, iconArg or "INV_Misc_QuestionMark", macroBody, false)
      if not ok then
        print("|cffff8000" .. addonName ..
          "|r: couldn't create the macro (personal macro slots may be full). Paste this on a bar slot instead: " ..
          macroBody)
        return
      end
    end
    PickupMacro(macroName)
  end

  btn:SetScript("OnClick",     pickup)
  btn:SetScript("OnDragStart", pickup)

  return btn
end

-- ===== Top-bar mount =====
-- Mounts a compact (24×24, no border) icon button into the chrome of the
-- Blizzard SettingsPanel, anchored next to the "Defaults" button. The
-- button is only visible while the consumer's settings subcategory is the
-- one currently selected — other subcategories (Release Notes, etc.) and
-- other addons' settings pages won't see it.
--
-- Top-bar parenting is mildly fragile (it depends on SettingsPanel's
-- internal frame names) so we degrade gracefully:
--   - If SettingsPanel or its containers aren't reachable, no-op silently.
--   - If the Defaults button can't be found, anchor to TOPRIGHT of the
--     settings list with a reasonable offset.
-- Show/hide is driven by hooking the panel's category-display path and
-- the panel's own OnShow/OnHide.
function MacroButton:MountInTopBar(subcategory)
  if not subcategory then return end
  if MBLib._topBarBtn then return end -- mount only once per session
  if not (SettingsPanel and SettingsPanel.Container) then return end
  local list = SettingsPanel.Container.SettingsList
  if not list then return end

  local btn = self:Build(list, { size = 24, showBorder = false })
  if not btn then return end
  btn:ClearAllPoints()
  btn:SetFrameStrata("HIGH")

  local defaultsBtn = list.DefaultsButton
    or (list.Header and list.Header.DefaultsButton)
    or (SettingsPanel.Container.SettingsList and SettingsPanel.Container.SettingsList.DefaultsButton)
  if defaultsBtn then
    btn:SetPoint("RIGHT", defaultsBtn, "LEFT", -8, 0)
  else
    btn:SetPoint("TOPRIGHT", list, "TOPRIGHT", -120, -12)
  end

  btn:Hide()
  MBLib._topBarBtn = btn

  local function updateVisibility()
    if not SettingsPanel:IsShown() then btn:Hide(); return end
    local cur = SettingsPanel.GetCurrentCategory and SettingsPanel:GetCurrentCategory()
    btn:SetShown(cur == subcategory)
  end

  SettingsPanel:HookScript("OnShow", updateVisibility)
  SettingsPanel:HookScript("OnHide", function() btn:Hide() end)

  if SettingsPanel.Container.DisplayCategory then
    hooksecurefunc(SettingsPanel.Container, "DisplayCategory", updateVisibility)
  end
  if EventRegistry and EventRegistry.RegisterCallback then
    pcall(EventRegistry.RegisterCallback, EventRegistry,
      "Settings.CategoryChanged", updateVisibility, btn)
    pcall(EventRegistry.RegisterCallback, EventRegistry,
      "SettingsCategoryFrame.SelectionChanged", updateVisibility, btn)
  end

  updateVisibility()
end

MBLib.MacroButton = MacroButton
