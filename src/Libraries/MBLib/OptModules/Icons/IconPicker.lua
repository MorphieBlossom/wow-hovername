local _, addon = ...
local MBLib = addon.MBLib

-- ===== MBLib.IconPicker =====
-- Modal icon-picker dialog. One singleton popup; consumers call
-- ``MBLib.IconPicker:Show(opts)``.
--
-- opts = {
--   title    = "Pick an icon",   -- optional dialog title
--   current  = fileID,           -- optional, highlights this icon if visible
--   onSelect = function(fileID),  -- required, fired on Save
--   onCancel = function(),       -- optional, fired on Cancel / [X]
-- }
--
-- Search:
--   Numeric  -> treated as a FileDataID directly; preview renders that ID.
--   Text     -> tries C_Spell.GetSpellInfo / GetSpellTexture / GetItemInfo
--               to resolve "Frostbolt" or "Hearthstone" to an icon. WoW's
--               API can't search the full spellbook by name (only known
--               spells / cached items resolve), so this is best-effort —
--               the user can always paste an exact FileID as a fallback.
--
-- Catalog:
--   Macro-style icons from GetMacroIcons() + GetMacroItemIcons() form the
--   browseable grid. The grid is VIRTUALIZED — exactly VISIBLE_ROWS * COLS
--   tile frames are created once and rebound on scroll, so a 700+ entry
--   catalog doesn't hammer the texture loader.

local IconPicker = {}
addon.MBLib.IconPicker = IconPicker

-- ===== Layout =====
local COLS         = 10
local VISIBLE_ROWS = 7
local TILE_SIZE    = 36
local TILE_PAD     = 6
local ROW_HEIGHT   = TILE_SIZE + TILE_PAD
local TILE_WIDTH   = TILE_SIZE + TILE_PAD
local PREVIEW_SIZE = 64
local FALLBACK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

local SIDE_PAD     = 16
local SCROLLBAR_W  = 22
local GRID_WIDTH   = COLS * TILE_WIDTH
local GRID_HEIGHT  = VISIBLE_ROWS * ROW_HEIGHT
local FRAME_WIDTH  = GRID_WIDTH + SIDE_PAD * 2 + SCROLLBAR_W
local TOP_AREA     = 100 -- title + search row + preview
local BOTTOM_AREA  = 50  -- save/cancel row + padding
local FRAME_HEIGHT = TOP_AREA + GRID_HEIGHT + BOTTOM_AREA

-- ===== State =====
local dialog
local tiles = {}

-- Grid catalog: only the macro-eligible FileDataIDs Blizzard exposes via
-- GetMacroIcons + GetMacroItemIcons. This keeps the grid focused on
-- "real" usable icons (the same set the /macro UI shows) and excludes
-- texture tiles, glyphs, atlas slices, and other non-icon clutter that
-- live in the full listfile. Names come from MBLib.IconCatalog (the
-- bundled listfile mapping) — the macro API returns IDs only.
local catalog
local filtered

-- byID is the FULL FileDataID -> name lookup, populated from the
-- bundled listfile. Used to:
--   (1) resolve a name for the grid catalog
--   (2) name the preview when the user types an arbitrary numeric ID
--       that isn't in the macro subset
local byID

-- ===== Debug dump (internal) =====
-- The dump lives entirely inside MBLib so consumers don't have to wire
-- it up themselves. Storage path: MBLib._db._MBLib.iconDump (the
-- _MBLib bucket is MBLib's private namespace inside the consumer's
-- SavedVariables — kept separate from the consumer's own keys).

local function iconDumpStorage()
  if not (MBLib and MBLib._db) then return nil end
  MBLib._db._MBLib = MBLib._db._MBLib or {}
  return MBLib._db._MBLib
end

local function writeIconDump(payload)
  local store = iconDumpStorage()
  if not store then return end
  local ids = {}
  for _, entry in ipairs(payload.catalog or {}) do
    table.insert(ids, entry[1])
  end
  store.iconDump = {
    version   = payload.gameVersion,
    ids       = ids,
    missing   = payload.missingNames or {},
    timestamp = payload.timestamp,
  }
end

-- Completion popup shown after an auto-refresh dump finishes. The
-- dump itself is silent (no chat output); this popup is the only
-- user-visible signal that the SavedVariables file now has fresh data
-- the user can run tools/refresh-iconcatalog.ps1 against. Cached as
-- a singleton frame so repeated triggers reuse the same UI.
local refreshPopup
local function showRefreshCompletePopup(payload)
  if not refreshPopup then
    local f = CreateFrame("Frame", "MBLib_IconDumpRefreshPopup", UIParent, "BackdropTemplate")
    f:SetSize(460, 180)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:EnableMouse(true)
    f:SetBackdrop({
      bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
      edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
      tile = true, tileSize = 32, edgeSize = 32,
      insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    f:Hide()

    local title = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -18)
    title:SetText((MBLib._addonName or "MBLib") .. " — icon catalog refreshed")
    f.title = title

    -- Close button anchored first so we can pin the message's bottom to
    -- it: the message stretches from below the title down to just above
    -- the button, which means it never overlaps the button regardless
    -- of how many lines the body wraps to.
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    closeBtn:SetSize(110, 24)
    closeBtn:SetPoint("BOTTOM", 0, 16)
    closeBtn:SetText("Close")
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    local msg = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    msg:SetPoint("TOPLEFT",  f, "TOPLEFT",  20, -50)
    msg:SetPoint("TOPRIGHT", f, "TOPRIGHT", -20, -50)
    msg:SetPoint("BOTTOM",   closeBtn, "TOP", 0, 12)
    msg:SetJustifyH("CENTER")
    msg:SetJustifyV("TOP")
    msg:SetSpacing(4)
    f.msg = msg

    refreshPopup = f
  end

  -- Text varies depending on whether a previous dump existed. First
  -- dump for a fresh install reads "no previous dump"; subsequent
  -- WoW-version changes name the prior version so the user knows
  -- which patch's dump is being replaced.
  local prior = payload.previousVersion
  local body
  if prior then
    body = ("WoW version changed after last icon dump (previous version %s). "
      .. "Do a /reload to save and run the refresh tool to update the library."):format(prior)
  else
    body = "No icon dump existed yet. "
      .. "Do a /reload to save and run the refresh tool to update the library."
  end
  refreshPopup.msg:SetText(body)
  refreshPopup:Show()
end

local function ensureCatalog()
  if catalog then return end

  -- Side-index: full bundled listfile, FileDataID -> name.
  byID = {}
  for _, entry in ipairs(MBLib.IconCatalog or {}) do
    byID[entry[1]] = entry[2]
  end

  -- Grid catalog: macro-eligible IDs only. The macro APIs populate a
  -- caller-provided table with FileDataIDs.
  local macroIDs = {}
  if GetMacroIcons then pcall(GetMacroIcons, macroIDs) end
  if GetMacroItemIcons then
    local items = {}
    pcall(GetMacroItemIcons, items)
    for _, id in ipairs(items) do table.insert(macroIDs, id) end
  end

  catalog = {}
  -- Track FileDataIDs that GetMacroIcons surfaces but our bundled
  -- listfile (byID) has no name for. These are usually icons added
  -- in a WoW patch newer than the listfile snapshot — surfacing
  -- them lets the consumer's tooling notice when the bundled file
  -- needs regeneration via tools/refresh-iconnames.ps1.
  local missingNames = {}
  for _, id in ipairs(macroIDs) do
    local name = byID[id]
    table.insert(catalog, { id, name or "" })
    if not name then table.insert(missingNames, id) end
  end

  -- Sort by FileDataID — user preference: monotonic ID ordering is
  -- visually easier to scan than alphabetical by internal name.
  table.sort(catalog, function(a, b) return a[1] < b[1] end)

  filtered = catalog

  -- When MBLib's debug mode is on, snapshot the macro subset into the
  -- consumer's SavedVariables (under the MBLib-namespaced bucket so
  -- consumers don't see internal debug state polluting their own
  -- keys). The dump powers tools/refresh-iconcatalog.ps1; freshness
  -- across WoW patches is auto-handled by the PLAYER_LOGIN check at
  -- the bottom of this file.
  if MBLib and MBLib.IsDebugEnabled and MBLib:IsDebugEnabled() then
    -- Snapshot the previous dump's version BEFORE writeIconDump
    -- overwrites it — the completion popup uses it to tell the user
    -- which patch their last dump was for.
    local store = iconDumpStorage()
    local previousVersion = store and store.iconDump and store.iconDump.version
    local payload = {
      catalog         = catalog,
      missingNames    = missingNames,
      gameVersion     = (GetBuildInfo and (GetBuildInfo())) or "unknown",
      timestamp       = (time and time()) or 0,
      previousVersion = previousVersion,
    }
    writeIconDump(payload)
    if IconPicker._refreshPending then
      IconPicker._refreshPending = false
      showRefreshCompletePopup(payload)
    end
  end
end

-- Force a rebuild of the (otherwise cached) catalog, firing the
-- internal dump + popup flow when debug is on. Called automatically by
-- the PLAYER_LOGIN handler when the stored dump's WoW version differs
-- from the current client; consumers don't need to invoke this.
function IconPicker:RebuildAndDump()
  catalog  = nil
  filtered = nil
  ensureCatalog()
end

-- Substring search over lowercased names. Empty query restores the full
-- catalog. Linear scan over ~30K entries; well under a frame at modern
-- CPU speeds, so debouncing isn't needed.
local function applyFilter(query)
  if not query or query == "" then
    filtered = catalog
    return
  end
  local q = query:lower()
  filtered = {}
  for _, entry in ipairs(catalog) do
    if entry[2]:find(q, 1, true) then
      table.insert(filtered, entry)
    end
  end
end

-- ===== Search behavior =====
-- The catalog (MBLib.IconCatalog) is the source of truth. Typing text
-- filters the grid by substring match against icon names; typing a number
-- additionally sets the preview directly so the user can pick an ID that
-- isn't a substring of any catalog name. Tile clicks always pull from
-- the visible filtered set.

-- ===== Preview + name display =====
local function applySelected()
  if not dialog then return end
  local fileID = dialog._selected
  local name   = dialog._selectedName

  -- Preview swatch
  if fileID and fileID > 0 then
    dialog.previewIcon:SetTexture(fileID)
    dialog.previewIcon:Show()
  else
    dialog.previewIcon:Hide()
  end

  -- ID + name line below the search input. ID first because it's a
  -- fixed-width(ish) number; putting the variable-length name after it
  -- means the line's right edge moves but the ID stays anchored at the
  -- same column, which reads more steadily as the user scrubs through
  -- different icons.
  if fileID and fileID > 0 then
    if name and name ~= "" then
      dialog.nameLabel:SetText("|cffaaaaaa#" .. fileID .. "|r  " .. name)
    else
      dialog.nameLabel:SetText("|cffaaaaaa#" .. fileID .. "|r")
    end
  else
    dialog.nameLabel:SetText("")
  end

  -- Refresh tile highlights so the previously-selected tile dims out.
  for _, tile in ipairs(tiles) do
    if tile:IsShown() then
      local on = (tile.fileID == fileID)
      for _, edge in ipairs(tile.border) do edge:SetShown(on) end
    end
  end
end

local function selectFileID(fileID, name)
  if not dialog then return end
  dialog._selected     = fileID
  dialog._selectedName = name
  applySelected()
end

-- ===== Virtualized grid =====
local function refreshGrid()
  if not dialog then return end
  local offset   = dialog.scrollFrame:GetVerticalScroll() or 0
  local firstRow = math.floor(offset / ROW_HEIGHT)
  for r = 0, VISIBLE_ROWS - 1 do
    for c = 0, COLS - 1 do
      local idx   = (firstRow + r) * COLS + c + 1
      local entry = filtered and filtered[idx]
      local tile  = tiles[r * COLS + c + 1]
      if entry then
        tile.fileID = entry[1]
        tile.iconName = entry[2]
        tile.tex:SetTexture(entry[1])
        local on = (tile.fileID == dialog._selected)
        for _, edge in ipairs(tile.border) do edge:SetShown(on) end
        tile:Show()
      else
        tile.fileID = nil
        tile.iconName = nil
        tile:Hide()
      end
    end
  end
end

-- A yellow border on the selected tile, drawn as four edge strips. Each
-- strip extends `T` past the tile on both ends so the corner squares are
-- filled by overlap rather than left as gaps — the previous version had
-- mismatched offsets on the two anchors of each strip which produced
-- slanted edges and corner artifacts.
local function makeBorder(tile)
  local T = 2
  local r, g, b, a = 1, 0.82, 0, 1
  local edges = {}

  local function strip()
    local t = tile:CreateTexture(nil, "OVERLAY")
    t:SetColorTexture(r, g, b, a)
    t:Hide()
    return t
  end

  -- Top edge: T-tall strip sitting just above the tile, extending T to
  -- each side. Both anchors share the same outset values so the strip is
  -- rectangular (not slanted).
  local top = strip()
  top:SetHeight(T)
  top:SetPoint("TOPLEFT",  tile, "TOPLEFT",  -T,  T)
  top:SetPoint("TOPRIGHT", tile, "TOPRIGHT",  T,  T)
  table.insert(edges, top)

  local bottom = strip()
  bottom:SetHeight(T)
  bottom:SetPoint("BOTTOMLEFT",  tile, "BOTTOMLEFT",  -T, -T)
  bottom:SetPoint("BOTTOMRIGHT", tile, "BOTTOMRIGHT",  T, -T)
  table.insert(edges, bottom)

  local left = strip()
  left:SetWidth(T)
  left:SetPoint("TOPLEFT",    tile, "TOPLEFT",    -T,  T)
  left:SetPoint("BOTTOMLEFT", tile, "BOTTOMLEFT", -T, -T)
  table.insert(edges, left)

  local right = strip()
  right:SetWidth(T)
  right:SetPoint("TOPRIGHT",    tile, "TOPRIGHT",     T,  T)
  right:SetPoint("BOTTOMRIGHT", tile, "BOTTOMRIGHT",  T, -T)
  table.insert(edges, right)

  return edges
end

local function buildGrid(scrollFrame)
  for r = 0, VISIBLE_ROWS - 1 do
    for c = 0, COLS - 1 do
      local tile = CreateFrame("Button", nil, scrollFrame)
      tile:SetSize(TILE_SIZE, TILE_SIZE)
      tile:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT",
        c * TILE_WIDTH,
       -r * ROW_HEIGHT)

      local tex = tile:CreateTexture(nil, "ARTWORK")
      tex:SetAllPoints()
      tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
      tile.tex = tex

      tile.border = makeBorder(tile)

      tile:SetScript("OnEnter", function(self) self.tex:SetVertexColor(1.2, 1.2, 1.2) end)
      tile:SetScript("OnLeave", function(self) self.tex:SetVertexColor(1,    1,    1)   end)
      tile:SetScript("OnClick", function(self)
        if not self.fileID then return end
        -- Clicking a tile sets selection with the catalog name (so the
        -- preview shows the icon's file name + ID). The search text is
        -- left alone — the user might be browsing within a filter and
        -- want to keep that filter while previewing different matches.
        selectFileID(self.fileID, self.iconName)
      end)
      tile:Hide()
      tiles[r * COLS + c + 1] = tile
    end
  end
end

-- ===== Dialog =====

local function ensureDialog()
  if dialog then return dialog end

  local f = CreateFrame("Frame", "MBLib_IconPickerDialog", UIParent, "BackdropTemplate")
  f:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
  f:SetPoint("CENTER")
  f:SetFrameStrata("DIALOG")
  f:SetToplevel(true)
  f:EnableMouse(true)
  f:SetMovable(true)
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
  table.insert(UISpecialFrames, "MBLib_IconPickerDialog")

  -- Title + [X]
  local title = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  title:SetPoint("TOP", 0, -10)
  f.title = title

  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -2, -2)
  close:SetScript("OnClick", function()
    f:Hide()
    if f._onCancel then pcall(f._onCancel) end
  end)

  -- ----- Selected preview (top-right) -----
  local preview = CreateFrame("Frame", nil, f, "BackdropTemplate")
  preview:SetSize(PREVIEW_SIZE, PREVIEW_SIZE)
  preview:SetPoint("TOPRIGHT", f, "TOPRIGHT", -28, -30)
  preview:SetBackdrop({
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12,
    insets   = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  -- Dim question-mark fallback at BACKGROUND so an unset / invalid ID
  -- renders as an obvious "?" rather than the dialog backdrop tint.
  local fallback = preview:CreateTexture(nil, "BACKGROUND")
  fallback:SetPoint("TOPLEFT", 4, -4)
  fallback:SetPoint("BOTTOMRIGHT", -4, 4)
  fallback:SetTexture(FALLBACK_ICON)
  fallback:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  fallback:SetVertexColor(0.35, 0.35, 0.35)

  local previewIcon = preview:CreateTexture(nil, "ARTWORK")
  previewIcon:SetPoint("TOPLEFT", 4, -4)
  previewIcon:SetPoint("BOTTOMRIGHT", -4, 4)
  previewIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  previewIcon:Hide()
  f.previewIcon = previewIcon

  local previewLabel = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  previewLabel:SetPoint("BOTTOM", preview, "TOP", 0, 4)
  previewLabel:SetText(MBLib.L.ICON_PICKER_SELECTED_LABEL)

  -- ----- Search row + Name/ID display -----
  local searchLabel = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  searchLabel:SetPoint("TOPLEFT", SIDE_PAD, -42)
  searchLabel:SetText(MBLib.L.ICON_PICKER_SEARCH_LABEL)

  local searchBox = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
  searchBox:SetSize(150, 22)
  searchBox:SetPoint("LEFT", searchLabel, "RIGHT", 10, 0)
  searchBox:SetAutoFocus(false)
  searchBox:SetMaxLetters(64)
  -- Name + ID label between the search input and the selected preview.
  -- Updates on every search/resolution; cleared when nothing is picked.
  -- Selected ID + name line below the search input, anchored to the
  -- "Search:" label so it sits flush-left with it (not indented under
  -- the input). Spans to the preview swatch's left edge, with word-wrap
  -- as a safety net for the rare name that exceeds that width.
  local nameLabel = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  nameLabel:SetPoint("TOPLEFT", searchLabel, "BOTTOMLEFT", 0, -16)
  nameLabel:SetPoint("RIGHT", preview, "LEFT", -16, 0)
  nameLabel:SetJustifyH("LEFT")
  nameLabel:SetWordWrap(true)
  f.nameLabel = nameLabel

  searchBox:SetScript("OnTextChanged", function(self)
    if dialog._suppressSearch then return end
    local text = (self:GetText() or ""):match("^%s*(.-)%s*$") or ""
    applyFilter(text)
    -- Scroll back to top and update the scrollbar range so the user's
    -- view doesn't end up inside an empty region after a narrowing filter.
    local totalRows = math.max(1, math.ceil(#filtered / COLS))
    dialog.scrollChild:SetHeight(totalRows * ROW_HEIGHT)
    dialog.scrollFrame:SetVerticalScroll(0)
    refreshGrid()
    -- Numeric input also seeds the preview directly so a user pasting a
    -- specific FileDataID can save without it being a substring of any
    -- catalog name. Name comes from the byID side-index if available.
    local asNumber = tonumber(text)
    if asNumber and asNumber > 0 then
      selectFileID(asNumber, byID and byID[asNumber] or nil)
    elseif text == "" then
      -- Clear selection when the search box is fully blanked.
      selectFileID(nil, nil)
    end
  end)
  f.searchBox = searchBox

  -- ----- Scrollable grid -----
  local scrollFrame = CreateFrame("ScrollFrame", "MBLib_IconPickerScroll", f, "UIPanelScrollFrameTemplate")
  scrollFrame:SetSize(GRID_WIDTH, GRID_HEIGHT)
  scrollFrame:SetPoint("TOPLEFT", SIDE_PAD, -TOP_AREA)
  -- ScrollChild's height drives the scrollbar range; tiles aren't parented
  -- to it (they live on scrollFrame so they stay in the viewport while we
  -- update their content per scroll).
  local scrollChild = CreateFrame("Frame", nil, scrollFrame)
  scrollChild:SetSize(GRID_WIDTH, 1)
  scrollFrame:SetScrollChild(scrollChild)
  scrollFrame:SetScript("OnVerticalScroll", function(_, _) refreshGrid() end)
  f.scrollFrame = scrollFrame
  f.scrollChild = scrollChild

  buildGrid(scrollFrame)

  -- ----- Save + Cancel (bottom, centered) -----
  local BTN_W, BTN_GAP = 100, 10
  local pairW = BTN_W * 2 + BTN_GAP

  local save = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  save:SetSize(BTN_W, 22)
  save:SetText(MBLib.L.MOVER_SAVE_BTN)
  save:SetPoint("BOTTOMLEFT", f, "BOTTOM", -pairW / 2, 12)
  f.save = save

  local cancel = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  cancel:SetSize(BTN_W, 22)
  cancel:SetText(MBLib.L.ICON_PICKER_CANCEL_BTN)
  cancel:SetPoint("LEFT", save, "RIGHT", BTN_GAP, 0)
  cancel:SetScript("OnClick", function()
    f:Hide()
    if f._onCancel then pcall(f._onCancel) end
  end)
  f.cancel = cancel

  dialog = f
  return f
end

-- ===== Entry point =====

function IconPicker:Show(opts)
  if type(opts) ~= "table" or type(opts.onSelect) ~= "function" then return end
  ensureCatalog()
  local f = ensureDialog()

  f.title:SetText(opts.title or MBLib.L.ICON_PICKER_TITLE)
  f._onCancel = opts.onCancel

  f.save:SetScript("OnClick", function()
    f:Hide()
    pcall(opts.onSelect, f._selected)
  end)

  -- Reset state for the new session. Clear search field + restore the
  -- unfiltered catalog. Selection comes from opts.current (consumer's
  -- previously-saved icon); the side-index lets us show its file name.
  f._suppressSearch = true
  f.searchBox:SetText("")
  f._suppressSearch = false
  applyFilter("")
  selectFileID(opts.current, opts.current and byID and byID[opts.current] or nil)

  -- Scrollbar range and starting view (full catalog).
  local totalRows = math.max(1, math.ceil(#filtered / COLS))
  f.scrollChild:SetHeight(totalRows * ROW_HEIGHT)
  f.scrollFrame:SetVerticalScroll(0)
  refreshGrid()

  f:Show()
end

function IconPicker:Hide()
  if dialog then dialog:Hide() end
end

-- ===== Auto-refresh dump on WoW version change =====
-- On PLAYER_LOGIN (deferred a few seconds so macro APIs populate), if
-- debug mode is on and the stored dump's WoW version doesn't match
-- the current client, force a rebuild + dump. Setting _refreshPending
-- lets ensureCatalog know to surface the completion popup after the
-- dump finishes.
local loginFrame = CreateFrame("Frame")
loginFrame:RegisterEvent("PLAYER_LOGIN")
loginFrame:SetScript("OnEvent", function(self, event)
  if event ~= "PLAYER_LOGIN" then return end
  self:UnregisterEvent("PLAYER_LOGIN")
  self:SetScript("OnEvent", nil)
  C_Timer.After(3, function()
    if not (MBLib and MBLib.IsDebugEnabled and MBLib:IsDebugEnabled()) then return end
    local store = iconDumpStorage()
    if not store then return end
    local current = (GetBuildInfo and (GetBuildInfo())) or "unknown"
    local prior   = store.iconDump and store.iconDump.version
    if prior == current then return end  -- already fresh
    IconPicker._refreshPending = true
    IconPicker:RebuildAndDump()
  end)
end)
