local _, addon = ...

-- ===== MBLib.Dialogs =====
-- Reusable popup dialogs shared across MBLib and any consumer that needs
-- the same name-input / paste-base64 / show-base64 / confirm-action UX.
-- Each dialog type is lazy-built and recycled — opening the same dialog
-- twice in a row reuses the same frame and only updates the labels /
-- callbacks. None of the popups touch SavedVariables; persistence is the
-- caller's job via the accept callback.
--
-- Visual language: BackdropTemplate (NOT StaticPopup) so we don't drag
-- Blizzard's popup styling chrome along with us. Standard color palette
-- mirrors the rest of MBLib's UI.

local Dialogs = {}

local COLOR_HEADING = { r = 1.0, g = 0.82, b = 0.0 }
local COLOR_SOFT    = { r = 0.7, g = 0.7,  b = 0.7 }
local COLOR_ERROR   = { r = 1.0, g = 0.5,  b = 0.5 }

local function makeLabel(parent, text, fontObject)
  local fs = parent:CreateFontString(nil, "ARTWORK", fontObject or "GameFontNormal")
  fs:SetText(text or "")
  return fs
end

local function makeMutedLabel(parent, text)
  local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  fs:SetText(text or "")
  fs:SetTextColor(COLOR_SOFT.r, COLOR_SOFT.g, COLOR_SOFT.b)
  return fs
end

local function newDialog(width, height)
  local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
  f:SetSize(width, height)
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
  -- Force the backdrop color to fully opaque so the canvas page
  -- underneath doesn't bleed through. Some Blizzard UI scales render
  -- the default tint with effective alpha < 1.
  f:SetBackdropColor(0, 0, 0, 1)
  f:SetBackdropBorderColor(1, 1, 1, 1)
  f:Hide()
  return f
end

-- Selects every character in an editbox AFTER the dialog is shown.
-- Selection doesn't render until the frame is on screen, so we defer
-- one frame and (for the read-only export case) drive focus too.
local function autoSelect(edit)
  if not edit then return end
  C_Timer.After(0, function()
    if edit:IsVisible() then
      edit:SetFocus()
      edit:HighlightText()
    end
  end)
end

-- ===== Name input =====
-- opts:
--   title    : header text
--   prompt   : muted body text above the input
--   prefill  : starting text (selected for easy overwrite)
--   accept   : function(name) -> nil on success, "error string" on failure
--              (returning a string keeps the dialog open and displays it
--               as inline validation — useful for "name already in use")
local nameDialog
function Dialogs:ShowNameInput(opts)
  opts = opts or {}
  if not nameDialog then
    nameDialog = newDialog(360, 150)
    nameDialog.title = makeLabel(nameDialog, "", "GameFontNormalLarge")
    nameDialog.title:SetPoint("TOP", 0, -14)
    nameDialog.title:SetTextColor(COLOR_HEADING.r, COLOR_HEADING.g, COLOR_HEADING.b)

    nameDialog.prompt = makeMutedLabel(nameDialog, "")
    nameDialog.prompt:SetPoint("TOPLEFT", 16, -40)
    nameDialog.prompt:SetPoint("TOPRIGHT", -16, -40)
    nameDialog.prompt:SetJustifyH("LEFT")

    local edit = CreateFrame("EditBox", nil, nameDialog, "InputBoxTemplate")
    edit:SetAutoFocus(true)
    edit:SetSize(310, 22)
    edit:SetPoint("TOPLEFT", 22, -72)
    edit:SetMaxLetters(60)
    nameDialog.edit = edit

    local ok = CreateFrame("Button", nil, nameDialog, "UIPanelButtonTemplate")
    ok:SetSize(110, 24)
    ok:SetPoint("BOTTOMRIGHT", -16, 14)
    nameDialog.ok = ok

    local cancel = CreateFrame("Button", nil, nameDialog, "UIPanelButtonTemplate")
    cancel:SetSize(110, 24)
    cancel:SetPoint("RIGHT", ok, "LEFT", -8, 0)
    cancel:SetScript("OnClick", function() nameDialog:Hide() end)
    nameDialog.cancel = cancel

    nameDialog.err = makeMutedLabel(nameDialog, "")
    nameDialog.err:SetTextColor(COLOR_ERROR.r, COLOR_ERROR.g, COLOR_ERROR.b)
    nameDialog.err:SetPoint("BOTTOMLEFT", 16, 44)
    nameDialog.err:SetPoint("BOTTOMRIGHT", -16, 44)
    nameDialog.err:SetJustifyH("LEFT")
  end

  local L = addon.MBLib.L
  nameDialog.title:SetText(opts.title or "")
  nameDialog.prompt:SetText(opts.prompt or "")
  nameDialog.edit:SetText(opts.prefill or "")
  autoSelect(nameDialog.edit)
  nameDialog.err:SetText("")
  nameDialog.ok:SetText(opts.okText or L.PROFILES_POPUP_OK_BTN)
  nameDialog.cancel:SetText(opts.cancelText or L.PROFILES_POPUP_CANCEL_BTN)

  local function attempt()
    local input = (nameDialog.edit:GetText() or ""):match("^%s*(.-)%s*$") or ""
    if input == "" then
      nameDialog.err:SetText(L.PROFILES_ERR_EMPTY_NAME)
      return
    end
    local err = opts.accept and opts.accept(input)
    if err then
      nameDialog.err:SetText(err)
    else
      nameDialog:Hide()
    end
  end
  nameDialog.ok:SetScript("OnClick", attempt)
  nameDialog.edit:SetScript("OnEnterPressed", attempt)
  nameDialog.edit:SetScript("OnEscapePressed", function() nameDialog:Hide() end)
  nameDialog:Show()
end

-- ===== Export (read-only base64) =====
-- opts:
--   title    : header text
--   prompt   : muted body text above the box
--   payload  : the base64 string to display (pre-selected for Ctrl+C)
local exportDialog
function Dialogs:ShowExport(opts)
  opts = opts or {}
  if not exportDialog then
    exportDialog = newDialog(520, 380)
    exportDialog.title = makeLabel(exportDialog, "", "GameFontNormalLarge")
    exportDialog.title:SetPoint("TOP", 0, -14)
    exportDialog.title:SetTextColor(COLOR_HEADING.r, COLOR_HEADING.g, COLOR_HEADING.b)

    exportDialog.prompt = makeMutedLabel(exportDialog, "")
    exportDialog.prompt:SetPoint("TOPLEFT", 16, -42)
    exportDialog.prompt:SetPoint("TOPRIGHT", -16, -42)
    exportDialog.prompt:SetJustifyH("LEFT")

    local scroll = CreateFrame("ScrollFrame", nil, exportDialog, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 16, -76)
    scroll:SetPoint("BOTTOMRIGHT", -36, 50)
    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetFontObject("ChatFontSmall")
    edit:SetWidth(450)
    edit:SetAutoFocus(false)
    -- Read-only: any text-change attempt snaps back to the original
    -- payload. Selection / Ctrl+C still works independently.
    edit:SetScript("OnTextChanged", function(self) self:SetText(self._payload or "") end)
    scroll:SetScrollChild(edit)
    exportDialog.edit = edit

    local close = CreateFrame("Button", nil, exportDialog, "UIPanelButtonTemplate")
    close:SetSize(110, 24)
    close:SetPoint("BOTTOMRIGHT", -16, 14)
    close:SetScript("OnClick", function() exportDialog:Hide() end)
    exportDialog.close = close
  end

  local L = addon.MBLib.L
  exportDialog.title:SetText(opts.title or "")
  exportDialog.prompt:SetText(opts.prompt or L.PROFILES_EXPORT_PROMPT)
  exportDialog.close:SetText(opts.closeText or L.PROFILES_POPUP_CLOSE_BTN)
  -- Sanitize payload so CTRL+A in the editbox doesn't sweep in any
  -- stray leading / trailing whitespace (the base64 alphabet doesn't
  -- include whitespace so there's nothing legitimate to preserve at
  -- the edges).
  local payload = opts.payload or ""
  payload = payload:gsub("^%s+", ""):gsub("%s+$", "")
  exportDialog.edit._payload = payload
  exportDialog.edit:SetText(payload)
  exportDialog:Show()
  autoSelect(exportDialog.edit)
end

-- ===== Import (paste base64 + validate + accept) =====
-- opts:
--   title    : header text
--   prompt   : muted body text above the box
--   accept   : function(rawBase64) -> nil on success, "error string" on
--              failure (failure keeps the dialog open with the error
--              shown inline). The accept callback is responsible for
--              decoding/validating the payload — `MBLib.Profiles:UnwrapImport`
--              is the typical helper.
local importDialog
function Dialogs:ShowImport(opts)
  opts = opts or {}
  if not importDialog then
    importDialog = newDialog(520, 380)
    importDialog.title = makeLabel(importDialog, "", "GameFontNormalLarge")
    importDialog.title:SetPoint("TOP", 0, -14)
    importDialog.title:SetTextColor(COLOR_HEADING.r, COLOR_HEADING.g, COLOR_HEADING.b)

    importDialog.prompt = makeMutedLabel(importDialog, "")
    importDialog.prompt:SetPoint("TOPLEFT", 16, -42)
    importDialog.prompt:SetPoint("TOPRIGHT", -16, -42)
    importDialog.prompt:SetJustifyH("LEFT")

    local scroll = CreateFrame("ScrollFrame", nil, importDialog, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 16, -76)
    scroll:SetPoint("BOTTOMRIGHT", -36, 76)
    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetFontObject("ChatFontSmall")
    edit:SetWidth(450)
    edit:SetAutoFocus(true)
    scroll:SetScrollChild(edit)
    importDialog.edit = edit

    importDialog.err = makeMutedLabel(importDialog, "")
    importDialog.err:SetTextColor(COLOR_ERROR.r, COLOR_ERROR.g, COLOR_ERROR.b)
    importDialog.err:SetPoint("BOTTOMLEFT", 16, 44)
    importDialog.err:SetPoint("BOTTOMRIGHT", -16, 44)
    importDialog.err:SetJustifyH("LEFT")

    local ok = CreateFrame("Button", nil, importDialog, "UIPanelButtonTemplate")
    ok:SetSize(110, 24)
    ok:SetPoint("BOTTOMRIGHT", -16, 14)
    importDialog.ok = ok

    local cancel = CreateFrame("Button", nil, importDialog, "UIPanelButtonTemplate")
    cancel:SetSize(110, 24)
    cancel:SetPoint("RIGHT", ok, "LEFT", -8, 0)
    cancel:SetScript("OnClick", function() importDialog:Hide() end)
    importDialog.cancel = cancel
  end

  local L = addon.MBLib.L
  importDialog.title:SetText(opts.title or "")
  importDialog.prompt:SetText(opts.prompt or L.PROFILES_IMPORT_PROMPT)
  importDialog.ok:SetText(opts.okText or L.PROFILES_IMPORT_BTN)
  importDialog.cancel:SetText(opts.cancelText or L.PROFILES_POPUP_CANCEL_BTN)
  importDialog.err:SetText("")
  importDialog.edit:SetText("")
  importDialog.ok:SetScript("OnClick", function()
    -- Trim leading / trailing whitespace from the paste so the user
    -- can copy-paste casually (Discord, email, etc. often surround
    -- the payload with newlines or trailing spaces).
    local raw = (importDialog.edit:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local err = opts.accept and opts.accept(raw)
    if err then
      importDialog.err:SetText(err)
    else
      importDialog:Hide()
    end
  end)
  importDialog:Show()
  importDialog.edit:SetFocus()

  -- Allow callers to programmatically close (e.g. after chaining into a
  -- name-input dialog) by returning a handle.
  return importDialog
end

function Dialogs:HideImport()
  if importDialog then importDialog:Hide() end
end

-- ===== Confirm (yes/no, with optional onCancel) =====
-- opts:
--   title         : header text
--   body          : main body text
--   confirmText   : OK button text (defaults to localized "OK")
--   cancelText    : Cancel button text
--   onConfirm     : function() — fires on OK click
--   onCancel      : function() — OPTIONAL; fires on Cancel click. When
--                   set, Cancel is treated as an alternative action
--                   rather than a "back out" — useful for two-option
--                   prompts ("Add to Global" vs "Add to Profile") that
--                   don't have a third no-op state. Esc / closing the
--                   dialog without clicking still fires nothing.
local confirmDialog
function Dialogs:ShowConfirm(opts)
  opts = opts or {}
  if not confirmDialog then
    confirmDialog = newDialog(380, 150)
    confirmDialog.title = makeLabel(confirmDialog, "", "GameFontNormalLarge")
    confirmDialog.title:SetPoint("TOP", 0, -14)
    confirmDialog.title:SetTextColor(COLOR_HEADING.r, COLOR_HEADING.g, COLOR_HEADING.b)

    confirmDialog.body = makeLabel(confirmDialog, "", "GameFontHighlight")
    confirmDialog.body:SetPoint("TOPLEFT", 16, -42)
    confirmDialog.body:SetPoint("TOPRIGHT", -16, -42)
    confirmDialog.body:SetJustifyH("LEFT")
    confirmDialog.body:SetSpacing(4)

    local ok = CreateFrame("Button", nil, confirmDialog, "UIPanelButtonTemplate")
    ok:SetSize(110, 24)
    ok:SetPoint("BOTTOMRIGHT", -16, 14)
    confirmDialog.ok = ok

    local cancel = CreateFrame("Button", nil, confirmDialog, "UIPanelButtonTemplate")
    cancel:SetSize(110, 24)
    cancel:SetPoint("RIGHT", ok, "LEFT", -8, 0)
    confirmDialog.cancel = cancel
  end

  local L = addon.MBLib.L
  confirmDialog.title:SetText(opts.title or "")
  confirmDialog.body:SetText(opts.body or "")
  confirmDialog.ok:SetText(opts.confirmText or L.PROFILES_POPUP_OK_BTN)
  confirmDialog.cancel:SetText(opts.cancelText or L.PROFILES_POPUP_CANCEL_BTN)
  confirmDialog.ok:SetScript("OnClick", function()
    confirmDialog:Hide()
    if opts.onConfirm then opts.onConfirm() end
  end)
  confirmDialog.cancel:SetScript("OnClick", function()
    confirmDialog:Hide()
    if opts.onCancel then opts.onCancel() end
  end)
  -- Auto-size buttons to fit longer labels (e.g. "Add to Profile" doesn't
  -- fit in the default 110-wide cell). Both buttons get the wider of
  -- the two so the row stays visually balanced.
  local fs1, fs2 = confirmDialog.ok:GetFontString(), confirmDialog.cancel:GetFontString()
  local w1 = fs1 and fs1:GetStringWidth() or 0
  local w2 = fs2 and fs2:GetStringWidth() or 0
  local w  = math.max(110, math.ceil(math.max(w1, w2)) + 30)
  confirmDialog.ok:SetWidth(w)
  confirmDialog.cancel:SetWidth(w)
  confirmDialog:Show()
end

addon.MBLib.Dialogs = Dialogs
