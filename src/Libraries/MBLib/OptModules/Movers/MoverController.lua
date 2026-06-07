local _, addon = ...
local MBLib = addon.MBLib

-- ===== MBLib.MoverController =====
-- The single floating controller frame used by *both* MBLib.Mover
-- (single-frame mode) and MBLib.Movers (bulk mode). One frame, one piece
-- of code — the two modes just call Show(opts) with different option
-- shapes and the controller adapts.
--
-- Visual contract:
--   Top:       title (always shown; both modes pass "<AddonName> Movers")
--   [X]:       top-right corner; reverts + closes via opts.onClose
--   Optional:  description line under title (single mode passes the name
--              of the frame being positioned; bulk mode leaves nil)
--   Optional:  size slider (single mode passes when the spec carries one)
--   Bottom:    centered Save / Revert pair, equal width
--
-- The frame is draggable but its position is NOT persisted — every Show()
-- centers it at the top of the screen, by design.
--
-- Behavioral contract (callbacks):
--   onSave   -> "Save" button clicked. Consumer persists + tears down.
--   onRevert -> "Revert" button clicked. Consumer reverts in place; the
--               controller STAYS OPEN so the user can keep dragging.
--   onClose  -> [X] clicked. Consumer reverts AND tears down.

local MoverController = {}
addon.MBLib.MoverController = MoverController

-- Singleton frame; lazily created on first Show. Lives at module-scope so
-- both Mover.lua and Movers.lua reach the same instance through Show/Hide.
local f

-- Layout constants. PAIR_W is the width of the Save+Revert button pair
-- with their internal gap — used by ensure() to center them as one unit.
local BTN_W, BTN_GAP, BTN_H = 100, 10, 22
local PAIR_W = BTN_W * 2 + BTN_GAP
local FRAME_WIDTH = 300

local function ensure()
  if f then return f end

  f = CreateFrame("Frame", "MBLib_MoverController", UIParent, "BackdropTemplate")
  f:SetSize(FRAME_WIDTH, 90)  -- height adjusted per Show(); width is fixed
  f:SetFrameStrata("DIALOG")
  f:SetToplevel(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:SetClampedToScreen(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop",  f.StopMovingOrSizing)
  f:SetBackdrop({
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  f:Hide()

  -- ----- Title (always shown) -----
  local title = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  title:SetPoint("TOP", 0, -12)
  f.title = title

  -- ----- Description (hidden unless opts.description is provided) -----
  -- Word-wrap is on so a long frame name doesn't overflow horizontally —
  -- ensure() reserves vertical space for it and Show() bumps frame height
  -- when this fontstring's text is set.
  local desc = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  desc:SetPoint("TOPLEFT",  12, -32)
  desc:SetPoint("TOPRIGHT", -12, -32)
  desc:SetJustifyH("CENTER")
  desc:SetJustifyV("TOP")
  desc:SetWordWrap(true)
  desc:SetTextColor(0.85, 0.85, 0.85)
  desc:Hide()
  f.desc = desc

  -- ----- Close [X] (top-right, reverts + closes via onClose) -----
  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2)
  close:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText(MBLib.L.MOVERS_CLOSE_TOOLTIP_TITLE, 1, 1, 1)
    GameTooltip:AddLine(MBLib.L.MOVERS_CLOSE_TOOLTIP_DESC, 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
  end)
  close:SetScript("OnLeave", function() GameTooltip:Hide() end)
  f.close = close

  -- ----- Size input row (hidden unless opts.sizeSlider is provided) -----
  -- Numeric edit box matching the watcher edit form's size input, so the
  -- same control style is used everywhere a "size" value is configured.
  -- Wrapped in a row Frame so the input + label can be anchored as a unit
  -- (centered under the title or description).
  local sizeRow = CreateFrame("Frame", nil, f)
  sizeRow:SetSize(170, 22)
  sizeRow:Hide()
  f.sizeRow = sizeRow

  local sizeBox = CreateFrame("EditBox", nil, sizeRow, "InputBoxTemplate")
  sizeBox:SetSize(60, 22)
  sizeBox:SetPoint("LEFT", sizeRow, "LEFT", 0, 0)
  sizeBox:SetAutoFocus(false)
  sizeBox:SetNumeric(true)
  sizeBox:SetMaxLetters(5)
  f.sizeBox = sizeBox

  local sizeLabel = sizeRow:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  sizeLabel:SetPoint("LEFT", sizeBox, "RIGHT", 10, 0)
  f.sizeLabel = sizeLabel

  -- ----- Save + Revert (centered pair, equal width) -----
  local save = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  save:SetSize(BTN_W, BTN_H)
  save:SetText(MBLib.L.MOVER_SAVE_BTN)
  save:SetPoint("BOTTOMLEFT", f, "BOTTOM", -PAIR_W / 2, 10)
  f.save = save

  local revert = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  revert:SetSize(BTN_W, BTN_H)
  revert:SetText(MBLib.L.MOVER_REVERT_BTN)
  revert:SetPoint("BOTTOMLEFT", save, "BOTTOMRIGHT", BTN_GAP, 0)
  revert:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(MBLib.L.MOVER_REVERT_TOOLTIP_TITLE, 1, 1, 1)
    GameTooltip:AddLine(MBLib.L.MOVERS_REVERT_TOOLTIP_DESC, 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
  end)
  revert:SetScript("OnLeave", function() GameTooltip:Hide() end)
  f.revert = revert

  return f
end

-- Probe the active Settings subcategory ID via every API path Blizzard
-- has used across retail patches. Returns nil if none of them yield an
-- ID — Hide() then falls back to a plain ShowUIPanel.
--
-- The "right" API has moved repeatedly:
--   - older retail: SettingsPanel.currentCategory (field)
--   - mid-DF:       SettingsPanel:GetCurrentCategory() (method)
--   - newer:        SettingsPanel:GetCategoryList():GetCurrentCategory()
--   - top-level:    Settings.GetCurrentCategory()
-- Try each in order; first non-nil ID wins.
local function captureSettingsCategoryID()
  if not SettingsPanel then return nil end

  local function fromCategory(cat)
    if cat and cat.GetID then
      local ok, id = pcall(cat.GetID, cat)
      if ok and id then return id end
    end
    return nil
  end

  -- 1) SettingsPanel:GetCurrentCategory()
  if SettingsPanel.GetCurrentCategory then
    local ok, cat = pcall(SettingsPanel.GetCurrentCategory, SettingsPanel)
    if ok then
      local id = fromCategory(cat)
      if id then return id end
    end
  end

  -- 2) Direct field access
  local id = fromCategory(SettingsPanel.currentCategory)
            or fromCategory(SettingsPanel.activeCategory)
  if id then return id end

  -- 3) CategoryList path
  if SettingsPanel.GetCategoryList then
    local ok, list = pcall(SettingsPanel.GetCategoryList, SettingsPanel)
    if ok and list then
      if list.GetCurrentCategory then
        local catOk, cat = pcall(list.GetCurrentCategory, list)
        if catOk then
          local cid = fromCategory(cat)
          if cid then return cid end
        end
      end
      local fid = fromCategory(list.selectedCategory) or fromCategory(list.currentCategory)
      if fid then return fid end
    end
  end

  -- 4) Settings global helper
  if Settings and Settings.GetCurrentCategory then
    local ok, cat = pcall(Settings.GetCurrentCategory)
    if ok then
      local cid = fromCategory(cat)
      if cid then return cid end
    end
  end

  return nil
end

-- Open the controller at center-top of the screen. Position is reset every
-- Show — by user spec, the controller's own position is not persisted.
local function placeAtCenter()
  if not f then return end
  f:ClearAllPoints()
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
end

-- Anchor the controller above or below the given frame, picking the side
-- that grows away from the nearest screen edge (UIParent is bottom-up:
-- centerY > screenHeight/2 means the frame sits in the upper half, so the
-- controller should hang underneath; otherwise it floats above). Used when
-- opts.stickToFrame is set so the controller follows the frame being
-- positioned around the screen.
local function placeAtFrame(target)
  if not f or not target then return end
  f:ClearAllPoints()
  local centerY = select(2, target:GetCenter()) or 0
  local screenH = UIParent:GetHeight()
  if centerY > (screenH / 2) then
    f:SetPoint("TOP", target, "BOTTOM", 0, -8)
  else
    f:SetPoint("BOTTOM", target, "TOP", 0, 8)
  end
end

-- Tracks the current stick-target so Reanchor() doesn't need it re-passed.
-- Lives at module scope rather than on `f` so the lookup survives the
-- frame's lazy creation.
local stickTarget

-- opts = {
--   title        = string,        -- required; both modes pass "<AddonName> Movers"
--   description  = string?,       -- optional; single-frame mode passes the
--                                 -- name of the frame being positioned
--   sizeSlider   = {min, max, step, get, set}?, -- optional; only single-frame
--                                 -- mode usually passes this
--   stickToFrame = aFrame?,       -- optional; when set, the controller
--                                 -- anchors above/below this frame
--                                 -- instead of centering. The consumer
--                                 -- must call MoverController:Reanchor()
--                                 -- after every drag stop so the
--                                 -- controller follows the frame. The
--                                 -- controller itself becomes non-
--                                 -- draggable while sticking — it's
--                                 -- pinned to the target.
--   onSave       = function(),    -- "Save" clicked
--   onRevert     = function(),    -- "Revert" clicked (controller stays open)
--   onClose      = function(),    -- [X] clicked (revert + close, consumer-side)
-- }
function MoverController:Show(opts)
  if type(opts) ~= "table" then return end
  ensure()

  f.title:SetText(opts.title or "")

  local hasDesc = opts.description and opts.description ~= ""
  if hasDesc then
    f.desc:SetText(opts.description)
    f.desc:Show()
  else
    f.desc:Hide()
  end

  local hasSizer = opts.sizeSlider
               and type(opts.sizeSlider.set) == "function"
               and type(opts.sizeSlider.get) == "function"
  if hasSizer then
    local s    = opts.sizeSlider
    local minV = s.min or 10
    local maxV = s.max or 200
    local cur  = tonumber(s.get()) or minV
    f.sizeBox:SetNumber(cur)
    f.sizeLabel:SetText(MBLib.L.MOVER_SIZE_LABEL .. "  (" .. minV .. "-" .. maxV .. ")")
    -- Commit on enter / focus loss with min/max clamp. Same shape as the
    -- watcher edit form's numeric inputs — same control everywhere a
    -- size is edited.
    local function commit()
      local n = f.sizeBox:GetNumber() or minV
      if n < minV then n = minV end
      if n > maxV then n = maxV end
      f.sizeBox:SetNumber(n)
      pcall(s.set, n)
    end
    f.sizeBox:SetScript("OnEnterPressed",  function(self) self:ClearFocus() end)
    f.sizeBox:SetScript("OnEditFocusLost", commit)
    f.sizeRow:ClearAllPoints()
    if hasDesc then
      f.sizeRow:SetPoint("TOP", f.desc, "BOTTOM", 0, -10)
    else
      f.sizeRow:SetPoint("TOP", f.title, "BOTTOM", 0, -14)
    end
    f.sizeRow:Show()
  else
    f.sizeRow:Hide()
  end

  -- Dynamic height: title slot is always there; description + size input
  -- each add a slice when shown. Bottom slice covers the Save/Revert
  -- buttons. Numbers tuned against the static anchor points above.
  local h = 30                       -- top padding + title
  if hasDesc  then h = h + 22 end    -- description line(s); SetWordWrap can grow, eyeballed
  if hasSizer then h = h + 30 end    -- size input row
  h = h + 38                         -- Save/Revert buttons + bottom padding
  f:SetHeight(h)

  -- Wire button click handlers fresh per Show() — the callbacks differ per
  -- session (single mode -> Mover.lua's endActive; bulk mode -> Movers.lua's
  -- SaveAll/RevertInPlace/HideAll). Wrapped in pcall so a consumer
  -- exception doesn't break the controller's tear-down.
  f.save:SetScript("OnClick",   function() if opts.onSave   then pcall(opts.onSave)   end end)
  f.revert:SetScript("OnClick", function() if opts.onRevert then pcall(opts.onRevert) end end)
  f.close:SetScript("OnClick",  function() if opts.onClose  then pcall(opts.onClose)  end end)

  -- Placement: stick to a target frame when the caller asked for it,
  -- otherwise float at center. Sticking also disables the controller's
  -- own drag-to-move (it's pinned to the target) by unregistering its
  -- drag button; centered mode re-registers so the controller stays
  -- movable on its own.
  if opts.stickToFrame then
    stickTarget = opts.stickToFrame
    f:RegisterForDrag()             -- no buttons = unregister
    placeAtFrame(stickTarget)
  else
    stickTarget = nil
    f:RegisterForDrag("LeftButton")
    placeAtCenter()
  end

  -- Close Blizzard's Settings panel for the duration of the session and
  -- restore it on Hide. Done here (not in each consumer) so every flow
  -- that uses the controller gets the same UX — single-frame Mover from
  -- a watcher edit form, bulk Movers:ShowAll, per-row Show from the
  -- Movers settings panel.
  --
  -- We snapshot the currently-active subcategory ID so Hide can re-open
  -- Settings exactly where the user was. Without the snapshot,
  -- ShowUIPanel(SettingsPanel) lands on whatever Blizzard treats as the
  -- default category (Game settings), not the addon page the user came
  -- from. opts.settingsCategoryID overrides the autodetected value when
  -- the consumer knows its own category ID up front (more reliable than
  -- probing Blizzard's internals, which have moved across patches).
  if SettingsPanel and SettingsPanel:IsShown() then
    f._settingsWasShown   = true
    f._settingsCategoryID = opts.settingsCategoryID or captureSettingsCategoryID()
    HideUIPanel(SettingsPanel)
  else
    f._settingsWasShown   = false
    f._settingsCategoryID = nil
  end

  f:Show()
end

-- Re-run the placement logic. Single-frame consumers call this from their
-- OnDragStop handler so the controller follows the moved frame around the
-- screen. When the controller isn't currently sticking, Reanchor is a
-- no-op — the centered position doesn't need to track anything.
function MoverController:Reanchor()
  if not f or not f:IsShown() or not stickTarget then return end
  placeAtFrame(stickTarget)
end

function MoverController:Hide()
  if not f then return end
  local restore     = f._settingsWasShown
  local restoreID   = f._settingsCategoryID
  f._settingsWasShown   = false
  f._settingsCategoryID = nil
  f:Hide()
  stickTarget = nil
  -- Restore Settings panel if Show closed it. Settings.OpenToCategory
  -- navigates the panel back to the exact subcategory the user was on
  -- (e.g. Meower -> Watchers); ShowUIPanel alone lands on Blizzard's
  -- default category. Deferred by one frame so the controller's own
  -- Hide / disarm logic completes before the Settings panel re-shows.
  if restore then
    C_Timer.After(0, function()
      if restoreID and Settings and Settings.OpenToCategory then
        pcall(Settings.OpenToCategory, restoreID)
      elseif ShowUIPanel and SettingsPanel then
        pcall(ShowUIPanel, SettingsPanel)
      end
    end)
  end
end

function MoverController:IsShown()
  return f and f:IsShown() or false
end
