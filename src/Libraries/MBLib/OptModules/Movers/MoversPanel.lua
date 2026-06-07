local _, addon = ...
local MBLib = addon.MBLib

-- ===== MBLib.MoversPanel =====
-- Renders the "Movers" subcategory inside the consumer addon's Settings
-- page. Visual layout mirrors a typical "list with header + actions" page
-- (à la the Watchers screen): title, one-line description, top action
-- button ("Show movers"), then one row per registered mover with a per-row
-- Show action.
--
-- Two ways to enter mover mode from here:
--   - Top "Show movers" button -> MBLib.Movers:ShowAll() (bulk edit, every
--     registered frame draggable, one floating controller with Save/Revert).
--   - Per-row "Show" button   -> MBLib.Mover:Begin() on just that frame, with
--     the small accessory popup anchored to the frame (and the consumer's
--     optional size slider, if its spec declared one).
--
-- Build() is called from OptionsScreen:Build after the main category has
-- been registered, so we can attach this subcategory to it.

local MoversPanel = {}
addon.MBLib.MoversPanel = MoversPanel

-- Row geometry — kept in module constants so a width tweak doesn't require
-- chasing per-row anchor offsets.
local ROW_WIDTH        = 640
local ROW_HEIGHT       = 22
local ROW_GAP          = 6
local ROW_DOT_SIZE     = 8
local ROW_SHOW_BTN_W   = 70

MoversPanel._rows = {}
MoversPanel._rowShowBtns = {}  -- per-row Show buttons, toggled on bulk active

-- ===== Single-frame Show =====
-- Begins a MBLib.Mover session for one registered frame. Settings panel is
-- intentionally left open: the Mover accessory is DIALOG strata so it sits
-- on top, and closing Settings on every Show click would force the user
-- back into the world map just to click a button.

local function showSingle(spec)
  if not (MBLib.Mover and spec and spec.frame) then return end
  MBLib.Mover:Begin(spec.frame, {
    title       = spec.displayName or "Drag to position",
    sizeSlider  = spec.sizeSlider,  -- optional; consumers attach when they want a size control
    -- Hand MoverController our subcategory so Save / Revert reopens
    -- Settings to this Movers page, not the generic Game settings.
    settingsCategoryID = MoversPanel._categoryID,
    onConfirm   = function(pos)
      if type(spec.onSave) == "function" then pcall(spec.onSave, pos) end
    end,
    onCancel    = function()
      if type(spec.onCancel) == "function" then pcall(spec.onCancel) end
    end,
  })
end

-- ===== Row rebuilding =====
-- Rows are recreated on every OnShow rather than reused — handful of movers
-- per addon, so churn isn't worth caching. Rebuild is also the moment we
-- refresh per-row enabled state against current bulk-active status.

local function clearRows()
  for _, row in ipairs(MoversPanel._rows) do
    row:Hide(); row:SetParent(nil)
  end
  MoversPanel._rows = {}
  MoversPanel._rowShowBtns = {}
end

local function buildRows(canvas, anchor)
  clearRows()
  local entries = MBLib.Movers and MBLib.Movers:GetAll() or {}
  local prev = anchor

  if #entries == 0 then
    local empty = canvas:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    empty:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -8)
    empty:SetText(MBLib.L.MOVERS_PANEL_EMPTY)
    table.insert(MoversPanel._rows, empty)
    return
  end

  local bulkActive = MBLib.Movers and MBLib.Movers:IsBulkActive() or false

  for i, entry in ipairs(entries) do
    local row = CreateFrame("Frame", nil, canvas)
    row:SetSize(ROW_WIDTH, ROW_HEIGHT)
    if i == 1 then
      row:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -10)
    else
      row:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -ROW_GAP)
    end

    -- Per-row preview: when the consumer's spec provides a previewIcon
    -- FileDataID, render that as the row's leading thumbnail (so the
    -- list reads as "which icon does this mover position?" rather than
    -- a generic green status dot). Falls back to the dot when no icon
    -- is configured — same width either way so names align across rows.
    local previewID = entry.spec.previewIcon
    if previewID then
      local tex = row:CreateTexture(nil, "ARTWORK")
      tex:SetSize(ROW_HEIGHT - 4, ROW_HEIGHT - 4)
      tex:SetPoint("LEFT", 0, 0)
      tex:SetTexture(previewID)
      -- Crop the 1px border baked into Blizzard icon textures.
      tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    else
      local dot = row:CreateTexture(nil, "ARTWORK")
      dot:SetSize(ROW_DOT_SIZE, ROW_DOT_SIZE)
      dot:SetPoint("LEFT", 0, 0)
      dot:SetColorTexture(0.4, 0.9, 0.4, 0.9)
    end

    -- Name label anchors at a fixed x so it lines up across rows whether
    -- they show the dot or the icon thumbnail.
    local name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    name:SetPoint("LEFT", row, "LEFT", ROW_HEIGHT + 8, 0)
    name:SetText(entry.spec.displayName or entry.id)

    local showBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    showBtn:SetSize(ROW_SHOW_BTN_W, ROW_HEIGHT)
    showBtn:SetText(MBLib.L.MOVERS_PANEL_ROW_SHOW_BTN)
    showBtn:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    showBtn:SetEnabled(not bulkActive)
    showBtn:SetScript("OnClick", function()
      showSingle(entry.spec)
    end)

    table.insert(MoversPanel._rows, row)
    table.insert(MoversPanel._rowShowBtns, showBtn)
    prev = row
  end
end

-- ===== Bulk-active state ↔ buttons =====
-- When bulk mode is on, the top "Show movers" button reads as "Hide movers"
-- and disables the per-row Show buttons (no nesting modes). When bulk ends
-- from the floating controller's Save / Revert, the buttons sync back.

local function applyBulkState(canvas)
  if not canvas then return end
  local bulkActive = MBLib.Movers and MBLib.Movers:IsBulkActive() or false
  if canvas._topShowBtn then
    canvas._topShowBtn:SetText(bulkActive and MBLib.L.MOVERS_PANEL_HIDE_BTN or MBLib.L.MOVERS_PANEL_SHOW_BTN)
  end
  for _, btn in ipairs(MoversPanel._rowShowBtns) do
    btn:SetEnabled(not bulkActive)
  end
end

-- ===== Canvas builder =====

local function buildCanvas()
  local f = CreateFrame("Frame", nil, UIParent)
  f:Hide()
  f:SetSize(700, 500)

  local title = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText(MBLib.L.MOVERS_PANEL_TITLE)

  local desc = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
  desc:SetWidth(ROW_WIDTH)
  desc:SetJustifyH("LEFT")
  desc:SetTextColor(0.8, 0.8, 0.8)
  desc:SetText(MBLib.L.MOVERS_PANEL_DESC)

  local topShow = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  topShow:SetSize(120, 22)
  topShow:SetText(MBLib.L.MOVERS_PANEL_SHOW_BTN)
  topShow:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -12)
  topShow:SetScript("OnClick", function()
    if not MBLib.Movers then return end
    if MBLib.Movers:IsBulkActive() then
      MBLib.Movers:HideAll(false)
    else
      -- Pass our subcategory ID so MoverController re-opens Settings
      -- back to this Movers page on Save / Revert (rather than the
      -- generic Game settings default).
      MBLib.Movers:ShowAll({ settingsCategoryID = MoversPanel._categoryID })
    end
  end)
  f._topShowBtn = topShow

  -- Thin divider so the action button + description visually separate from
  -- the list below — matches the visual rhythm of the Watchers screen.
  local sep = f:CreateTexture(nil, "ARTWORK")
  sep:SetHeight(1)
  sep:SetPoint("TOPLEFT", topShow, "BOTTOMLEFT", 0, -10)
  sep:SetPoint("RIGHT", f, "RIGHT", -16, 0)
  sep:SetColorTexture(1, 1, 1, 0.15)

  f._listAnchor = sep

  -- Sync the top button + per-row buttons whenever bulk mode ends (Save or
  -- Revert from the controller) — the page may still be open in the
  -- background and would otherwise show stale enabled state.
  if MBLib.Movers and MBLib.Movers.SetOnHideAll then
    MBLib.Movers:SetOnHideAll(function() applyBulkState(f) end)
  end
  if MBLib.Movers and MBLib.Movers.SetOnShowAll then
    MBLib.Movers:SetOnShowAll(function() applyBulkState(f) end)
  end

  f:SetScript("OnShow", function()
    buildRows(f, f._listAnchor)
    applyBulkState(f)
  end)

  return f
end

-- ===== Entry point =====

function MoversPanel:Build(parentCategory)
  if not Settings or not parentCategory then return end
  local canvas = buildCanvas()
  -- Capture the subcategory so the bulk button + per-row Show button
  -- can hand the ID to MoverController, which uses it to reopen
  -- Settings to this exact page after the user finishes positioning.
  local category = Settings.RegisterCanvasLayoutSubcategory(parentCategory, canvas, MBLib.L.MOVERS_PANEL_TITLE)
  self._categoryID = category and category.GetID and category:GetID() or nil
  self._canvas = canvas
end
