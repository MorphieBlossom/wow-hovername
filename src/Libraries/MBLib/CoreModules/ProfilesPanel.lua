local _, addon = ...

-- Profiles management canvas subcategory. Lives in MBLib so any consumer
-- that calls ``MBLib.Profiles:Enable()`` automatically gets this page in
-- their options screen — no consumer code required.
--
-- The page is pure view + glue: lists every profile, marks the active
-- one for THIS character, surfaces per-row actions (Activate / Copy /
-- Export / Delete), and provides the two top-bar buttons (New profile /
-- Import). All persistence flows through ``MBLib.Profiles`` and the
-- generic popups in ``MBLib.Dialogs``.
--
-- Profile-level Import / Export is fully MBLib-driven (no consumer
-- callback needed) because Profiles already knows how to round-trip a
-- profile through the base64 envelope. For *finer-grained* exports
-- (e.g. Meower exporting one watcher) the consumer wires its own UI
-- against ``MBLib.Dialogs`` + ``Profiles:WrapForExport`` /
-- ``Profiles:UnwrapImport``.

local L = addon.MBLib.L

local Panel = {}

local CONTENT_WIDTH = 660
local INNER_WIDTH   = 560
local LEFT_MARGIN   = 16
local TOP_PAD       = 20
-- Row height grows with the character list (one line per bound char,
-- plus the profile name line). Constants below define the per-line
-- heights; the actual row height is computed in rowAt() at refresh.
local ROW_NAME_LINE_H = 18
local ROW_CHAR_LINE_H = 13
local ROW_TOP_PAD     = 6
local ROW_BOT_PAD     = 6
local ROW_GAP         = 4 -- vertical gap between profile rows

local COLOR_ACTIVE  = { r = 0.3, g = 1.0,  b = 0.3 }
local COLOR_SOFT    = { r = 0.7, g = 0.7,  b = 0.7 }

local function makeLabel(parent, text, fontObject)
  local fs = parent:CreateFontString(nil, "ARTWORK", fontObject or "GameFontNormal")
  fs:SetText(text)
  return fs
end

local function setTooltip(frame, title, desc)
  frame:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(title or "", 1, 1, 1)
    if desc and desc ~= "" then GameTooltip:AddLine(desc, nil, nil, nil, true) end
    GameTooltip:Show()
  end)
  frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- ===== Row pool =====
-- Visual style mirrors the Watchers list: plain frame (no backdrop /
-- border), a small "active" dot to the left of the name, then the
-- character list stacked vertically below. A thin horizontal separator
-- sits at the bottom of every row.
--
-- Each row reuses a pool of per-character FontStrings (`charLines`) so a
-- profile bound to many characters doesn't churn FontString allocation
-- on every refresh.
Panel._rowPool = {}

local function ensureCharLine(row, idx)
  row.charLines = row.charLines or {}
  if row.charLines[idx] then return row.charLines[idx] end
  local line = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  line:SetTextColor(COLOR_SOFT.r, COLOR_SOFT.g, COLOR_SOFT.b)
  line:SetJustifyH("LEFT")
  row.charLines[idx] = line
  return line
end

local function rowAt(idx)
  if Panel._rowPool[idx] then return Panel._rowPool[idx] end

  local content = Panel._content
  local row = CreateFrame("Frame", nil, content)

  -- Active-profile indicator. Uses the same green orb texture the
  -- Watchers list uses for its row status dot, so "active" reads the
  -- same way across both pages.
  local dot = row:CreateTexture(nil, "ARTWORK")
  dot:SetSize(14, 14)
  dot:SetPoint("TOPLEFT", 2, -7)
  dot:SetTexture("Interface\\COMMON\\Indicator-Green")
  row.dot = dot

  local nameLabel = makeLabel(row, "", "GameFontNormalLarge")
  nameLabel:SetPoint("TOPLEFT", 22, -ROW_TOP_PAD)
  row.nameLabel = nameLabel

  -- Bottom-of-row horizontal divider. Width follows the row so it spans
  -- the whole list column edge-to-edge — same look as the Watchers
  -- list's row separators.
  local sep = row:CreateTexture(nil, "ARTWORK")
  sep:SetHeight(1)
  sep:SetPoint("BOTTOMLEFT", 0, 0)
  sep:SetPoint("BOTTOMRIGHT", 0, 0)
  sep:SetColorTexture(1, 1, 1, 0.2)
  row.sep = sep

  -- Tighter button width so the 5-button chain fits the row even on
  -- the narrower options-canvas widths some clients use.
  local function btn(parent, label, w)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w or 62, 22)
    b:SetText(label)
    return b
  end

  row.renameBtn   = btn(row, L.PROFILES_ROW_RENAME_BTN,   64)
  row.copyBtn     = btn(row, L.PROFILES_ROW_COPY_BTN,     54)
  row.exportBtn   = btn(row, L.PROFILES_ROW_EXPORT_BTN,   62)
  row.deleteBtn   = btn(row, L.PROFILES_ROW_DELETE_BTN,   58)

  -- Buttons anchor to the top-right corner of the row (top line) so
  -- they don't shift as the row grows to fit a multi-character list.
  -- Chain right-to-left so Delete sits flush against the row edge.
  -- Activate is gone: the dropdown at the top of the page handles
  -- profile activation now, freeing up horizontal room for the row.
  row.deleteBtn:SetPoint("TOPRIGHT", row, "TOPRIGHT", -4, -ROW_TOP_PAD + 2)
  row.exportBtn:SetPoint("RIGHT", row.deleteBtn,   "LEFT", -4, 0)
  row.copyBtn:SetPoint(  "RIGHT", row.exportBtn,   "LEFT", -4, 0)
  row.renameBtn:SetPoint("RIGHT", row.copyBtn,     "LEFT", -4, 0)

  Panel._rowPool[idx] = row
  return row
end

-- ===== Refresh =====
local function refresh()
  if not Panel._content then return end
  local P = addon.MBLib.Profiles
  if not (P and P.IsEnabled and P:IsEnabled()) then return end
  local D = addon.MBLib.Dialogs

  local names = P:Names()
  local activeName = P:GetActiveName()
  local content = Panel._content

  -- Push the active profile name into the dropdown label so the user
  -- sees what's currently bound. When nothing's bound (the character
  -- is profile-less after a delete) show the localized placeholder so
  -- the dropdown doesn't look broken — the user can pick any existing
  -- profile from the menu to recover.
  if Panel._activeDd then
    if Panel._activeDd.OverrideText then
      Panel._activeDd:OverrideText(activeName or L.PROFILES_ACTIVE_NONE)
    end
    if Panel._activeDd.GenerateMenu then
      Panel._activeDd:GenerateMenu()
    end
  end

  local prev
  for i, name in ipairs(names) do
    local row = rowAt(i)
    row:Show()
    row:ClearAllPoints()
    -- Anchor rows to the SCROLL frame's right edge (with a -8 margin to
    -- clear the inner scrollbar gutter) rather than to content's right.
    -- The scroll child (content) has a fixed CONTENT_WIDTH that exceeds
    -- the visible viewport on narrow canvas pages, so anything anchored
    -- to content.RIGHT ends up off-screen even though the row itself is
    -- inside `content`. Using scroll.RIGHT pegs the right edge to what
    -- the user actually sees.
    if prev then
      row:SetPoint("TOPLEFT",  prev, "BOTTOMLEFT", 0, -ROW_GAP)
    else
      row:SetPoint("TOPLEFT",  content, "TOPLEFT", 0, -4)
    end
    row:SetPoint("RIGHT", Panel._scroll, "RIGHT", -8, 0)

    local isActive = (name == activeName)
    row.dot:SetShown(isActive)
    row.nameLabel:SetText(name)
    if isActive then
      row.nameLabel:SetTextColor(COLOR_ACTIVE.r, COLOR_ACTIVE.g, COLOR_ACTIVE.b)
    else
      row.nameLabel:SetTextColor(1, 0.82, 0)
    end

    -- Stack character names vertically below the profile name (one per
    -- line, no "Used by" prefix). Empty list collapses to a single
    -- muted "Not used by any character" line so the row still has
    -- visible content.
    local chars = P:CharactersFor(name)
    local lineAnchor = row.nameLabel
    local lineCount  = 0
    if #chars == 0 then
      local line = ensureCharLine(row, 1)
      line:Show()
      line:ClearAllPoints()
      line:SetPoint("TOPLEFT", lineAnchor, "BOTTOMLEFT", 0, -2)
      line:SetText(L.PROFILES_ROW_CHARS_NONE)
      lineCount = 1
    else
      for ci, charName in ipairs(chars) do
        local line = ensureCharLine(row, ci)
        line:Show()
        line:ClearAllPoints()
        line:SetPoint("TOPLEFT", lineAnchor, "BOTTOMLEFT", 0, ci == 1 and -2 or 0)
        line:SetText(charName)
        lineAnchor = line
      end
      lineCount = #chars
    end
    -- Hide any leftover lines from a previous (longer) bind list so
    -- they don't ghost-render under the row separator.
    if row.charLines then
      for ci = lineCount + 1, #row.charLines do
        row.charLines[ci]:Hide()
      end
    end

    -- Compute the row's final height from the contents.
    local contentH = ROW_TOP_PAD + ROW_NAME_LINE_H + (lineCount * ROW_CHAR_LINE_H) + ROW_BOT_PAD
    row:SetHeight(contentH)

    row.renameBtn:SetScript("OnClick", function()
      D:ShowNameInput({
        title   = L.PROFILES_RENAME_TITLE,
        prompt  = string.format(L.PROFILES_RENAME_PROMPT_FMT, name),
        prefill = name,
        accept  = function(input)
          if input == name then return nil end
          local ok, err = P:Rename(name, input)
          if not ok then
            if err == "exists" then return L.PROFILES_ERR_NAME_IN_USE end
            return string.format(L.PROFILES_ERR_GENERIC, tostring(err or "?"))
          end
          refresh()
          return nil
        end,
      })
    end)

    row.copyBtn:SetScript("OnClick", function()
      D:ShowNameInput({
        title   = L.PROFILES_COPY_TITLE,
        prompt  = string.format(L.PROFILES_COPY_PROMPT_FMT, name),
        prefill = name .. " (copy)",
        accept  = function(input)
          local ok, err = P:Copy(name, input)
          if not ok then
            if err == "dst exists" then return L.PROFILES_ERR_NAME_IN_USE end
            return string.format(L.PROFILES_ERR_GENERIC, tostring(err or "?"))
          end
          refresh()
          return nil
        end,
      })
    end)

    row.exportBtn:SetScript("OnClick", function()
      local payload, err = P:Export(name)
      if not payload then
        pcall(print, string.format(L.PROFILES_ERR_GENERIC, tostring(err or "?")))
        return
      end
      D:ShowExport({
        title   = string.format(L.PROFILES_EXPORT_TITLE_FMT, name),
        prompt  = L.PROFILES_EXPORT_PROMPT,
        payload = payload,
      })
    end)

    -- Delete is always allowed now. When characters are still bound,
    -- the confirm popup warns about it — the deletion still goes
    -- through and those characters become profile-less.
    local boundCount = #chars
    setTooltip(row.deleteBtn, L.PROFILES_ROW_DELETE_BTN, L.PROFILES_ROW_DELETE_TOOLTIP_DESC)
    row.deleteBtn:SetScript("OnClick", function()
      local body
      if boundCount > 0 then
        body = string.format(L.PROFILES_DELETE_BODY_BOUND_FMT, name, boundCount)
      else
        body = string.format(L.PROFILES_DELETE_BODY_FMT, name)
      end
      D:ShowConfirm({
        title       = L.PROFILES_DELETE_TITLE,
        body        = body,
        confirmText = L.PROFILES_DELETE_CONFIRM_BTN,
        onConfirm   = function()
          P:Delete(name)
          refresh()
        end,
      })
    end)

    prev = row
  end

  for i = #names + 1, #Panel._rowPool do
    Panel._rowPool[i]:Hide()
  end

  C_Timer.After(0, function()
    if not Panel._content then return end
    local last = Panel._rowPool[#names]
    if not last then
      Panel._content:SetHeight(80)
      return
    end
    local cTop = Panel._content:GetTop()
    local bBot = last:GetBottom()
    if cTop and bBot then
      local used = (cTop - bBot) + 20
      if used < 80 then used = 80 end
      Panel._content:SetHeight(used)
    end
  end)
end
Panel.refresh = refresh

-- ===== Panel build =====
local function buildPanel()
  local frame = CreateFrame("Frame")

  local title = makeLabel(frame, L.PROFILES_TITLE, "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", LEFT_MARGIN + 4, -TOP_PAD)

  local desc = makeLabel(frame, L.PROFILES_DESC, "GameFontHighlight")
  desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
  desc:SetWidth(INNER_WIDTH + 80)
  desc:SetJustifyH("LEFT")

  -- Active-profile dropdown sits on the LEFT of the action row.
  -- Selection drives MBLib.Profiles:Activate so the user can flip the
  -- current character to a different profile from one place — no
  -- per-row Activate button needed. The dropdown's options + selected
  -- value are rebuilt by refresh() so any rename / create / delete /
  -- import elsewhere is reflected on the next refresh tick.
  local activeLabel = makeLabel(frame, L.PROFILES_ACTIVE_LABEL, "GameFontHighlight")
  activeLabel:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -20)
  Panel._activeLabel = activeLabel

  local activeDd = CreateFrame("DropdownButton", nil, frame, "WowStyle1DropdownTemplate")
  activeDd:SetWidth(220)
  activeDd:SetPoint("LEFT", activeLabel, "RIGHT", 8, 0)
  activeDd:SetDefaultText("")
  activeDd:SetupMenu(function(_, rootDescription)
    if rootDescription.SetScrollMode then
      rootDescription:SetScrollMode(10 * 20)
    end
    local P = addon.MBLib.Profiles
    if not P then return end
    local current = P:GetActiveName()
    for _, optName in ipairs(P:Names()) do
      local n = optName
      rootDescription:CreateRadio(n,
        function() return current == n end,
        function()
          P:Activate(n)
          refresh()
        end, n)
    end
  end)
  Panel._activeDd = activeDd

  -- New / Import buttons. Their right edge is pinned to the page's
  -- right edge so the column lines up with the Delete button on each
  -- row below. Row buttons live at scroll.RIGHT - 8 (where scroll =
  -- frame.RIGHT - 30), and the row's Delete button adds another -4
  -- inset — so Import sits at frame.RIGHT - 42 to match. New profile
  -- chains to Import's left.
  local newBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  newBtn:SetSize(120, 24)
  newBtn:SetText(L.PROFILES_NEW_BTN)
  newBtn:SetScript("OnClick", function()
    local P = addon.MBLib.Profiles
    local D = addon.MBLib.Dialogs
    D:ShowNameInput({
      title  = L.PROFILES_NEW_TITLE,
      prompt = L.PROFILES_NEW_PROMPT,
      accept = function(input)
        local ok, err = P:Create(input)
        if not ok then
          if err == "exists" then return L.PROFILES_ERR_NAME_IN_USE end
          return string.format(L.PROFILES_ERR_GENERIC, tostring(err or "?"))
        end
        refresh()
        return nil
      end,
    })
  end)

  local importBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  importBtn:SetSize(120, 24)
  importBtn:SetPoint("TOP",   activeDd, "TOP", 0, 0)
  importBtn:SetPoint("RIGHT", frame,    "RIGHT", -42, 0)
  newBtn:SetPoint("TOP",   activeDd,  "TOP",  0, 0)
  newBtn:SetPoint("RIGHT", importBtn, "LEFT", -8, 0)
  importBtn:SetText(L.PROFILES_IMPORT_BTN)
  importBtn:SetScript("OnClick", function()
    local P = addon.MBLib.Profiles
    local D = addon.MBLib.Dialogs
    D:ShowImport({
      title  = L.PROFILES_IMPORT_TITLE,
      prompt = L.PROFILES_IMPORT_PROMPT,
      -- Two-step import: validate the paste, then ask for a destination
      -- name (so the user can rename on import to avoid collisions).
      -- The Import dialog stays open on the first step's error result;
      -- on success we hide it and chain into the name-input dialog.
      accept = function(raw)
        local envelope, err = P:UnwrapImport(raw)
        if not envelope then
          return string.format(L.PROFILES_ERR_INVALID, tostring(err or "?"))
        end
        if envelope.kind ~= "MBLibProfile" then
          return L.PROFILES_ERR_NOT_PROFILE
        end
        D:HideImport()
        D:ShowNameInput({
          title   = L.PROFILES_IMPORT_NAME_TITLE,
          prompt  = L.PROFILES_IMPORT_NAME_PROMPT,
          prefill = envelope.name or "",
          accept  = function(input)
            local ok2, ierr = P:Import(raw, input, false)
            if not ok2 then
              if ierr == "exists" then return L.PROFILES_ERR_NAME_IN_USE end
              return string.format(L.PROFILES_ERR_GENERIC, tostring(ierr or "?"))
            end
            refresh()
            return nil
          end,
        })
        return nil
      end,
    })
  end)

  -- Anchor the scroll's TOPLEFT to the page's description, not to the
  -- action row — that way the list's left edge stays put even if the
  -- buttons / dropdown above it get rearranged. (Previously the scroll
  -- chased newBtn's left edge, so when we swapped the dropdown in
  -- front of New / Import the whole list visibly slid to the right.)
  local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -50)
  scroll:SetPoint("BOTTOMRIGHT", -30, 10)

  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(CONTENT_WIDTH, 200)
  scroll:SetScrollChild(content)

  Panel._frame   = frame
  Panel._scroll  = scroll
  Panel._content = content
  return frame
end

-- ===== Subcategory registration =====
-- Called from MBLib.OptionsScreen's PLAYER_LOGIN late-registration step,
-- between MoversPanel and Release Notes, so the final left-rail order is:
--     Settings -> <consumer subcategories> -> Movers -> Profiles -> Release Notes.
-- Building from there (instead of an independent PLAYER_LOGIN handler in
-- this file) is the only reliable way to land in that slot — the Settings
-- API has no reorder primitive, registration order is the only lever.
function Panel:Build(parentCategory)
  if self._built then return end
  if not (Settings and Settings.RegisterCanvasLayoutSubcategory) then return end
  if not parentCategory then return end
  local P = addon.MBLib.Profiles
  if not (P and P.IsEnabled and P:IsEnabled()) then return end
  self._built = true

  local frame = buildPanel()
  frame:SetScript("OnShow", refresh)

  Settings.RegisterCanvasLayoutSubcategory(parentCategory, frame, L.PROFILES_SUBCATEGORY_NAME)

  if P.OnActivated then P:OnActivated(function() pcall(refresh) end) end
  if P.OnProfileChanged then P:OnProfileChanged(function() pcall(refresh) end) end

  C_Timer.After(0, function() pcall(refresh) end)
end

addon.MBLib.ProfilesPanel = Panel
