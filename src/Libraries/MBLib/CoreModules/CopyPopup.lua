local _, addon = ...
local MBLib = addon.MBLib

-- Standalone copy-to-clipboard dialog.
--
-- Built on a custom Frame (not StaticPopupDialogs) because StaticPopup uses a
-- shared pool of frames whose EditBox is reused for protected confirmations
-- (revive/release prompts, duel/trade, etc.). Mutating the pooled EditBox here
-- (SetText/HighlightText/SetFocus) taints that slot and causes
-- ADDON_ACTION_FORBIDDEN the next time Blizzard reuses it for a secure call.
-- Owning our own frame avoids the shared pool entirely.

local CopyPopup = {}
MBLib.CopyPopup = CopyPopup

local popup

local function build()
  local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
  f:SetSize(360, 150)
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

  local title = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  title:SetPoint("TOP", 0, -16)
  f.title = title

  local description = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  description:SetPoint("TOP", title, "BOTTOM", 0, -8)
  description:SetPoint("LEFT", 16, 0)
  description:SetPoint("RIGHT", -16, 0)
  description:SetJustifyH("CENTER")
  description:SetTextColor(0.8, 0.8, 0.8)
  f.description = description

  local editBox = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
  editBox:SetSize(300, 24)
  editBox:SetPoint("BOTTOM", 0, 50)
  editBox:SetAutoFocus(false)
  editBox:SetFontObject(ChatFontNormal)
  editBox:SetScript("OnEnterPressed",  function() f:Hide() end)
  editBox:SetScript("OnEscapePressed", function() f:Hide() end)
  editBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
  -- Restore the original text on any keypress so the user can't mangle the
  -- value before copying. They can still select + Ctrl+C as normal.
  editBox:SetScript("OnChar", function(self) self:SetText(f._text or "") end)
  f.editBox = editBox

  local closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  closeBtn:SetSize(96, 22)
  closeBtn:SetPoint("BOTTOM", 0, 14)
  closeBtn:SetText(CLOSE or "Close")
  closeBtn:SetScript("OnClick", function() f:Hide() end)
  f.closeBtn = closeBtn

  return f
end

-- Show a copyable dialog. opts:
--   title       (string, required) header text
--   description (string, optional) grey instructional line below the title
--   text        (string, required) pre-filled copyable text
function CopyPopup:Show(opts)
  if type(opts) ~= "table" then return end
  popup = popup or build()

  popup.title:SetText(opts.title or "")

  if opts.description and opts.description ~= "" then
    popup.description:SetText(opts.description)
    popup.description:Show()
  else
    popup.description:Hide()
  end

  popup._text = opts.text or ""
  popup.editBox:SetText(popup._text)
  popup:Show()
  popup.editBox:HighlightText()
  popup.editBox:SetFocus()
end

function CopyPopup:Hide()
  if popup then popup:Hide() end
end
