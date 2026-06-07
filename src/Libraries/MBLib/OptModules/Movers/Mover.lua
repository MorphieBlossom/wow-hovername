local _, addon = ...
local MBLib = addon.MBLib

-- ===== MBLib.Mover =====
-- "Position this one frame" helper. Mover arms a single frame for mouse
-- dragging, snapshots its prior input/visibility state plus its starting
-- position, and delegates the on-screen UI (Save / Revert / [X]) to the
-- shared MBLib.MoverController. Same controller frame and same code as
-- MBLib.Movers bulk mode uses — single-frame mode just additionally
-- passes a `description` line identifying which frame is being moved.
--
-- Only one Mover:Begin() session can be active at a time. Calling Begin()
-- again while another session is open silently ends the previous one with
-- Cancel.
--
-- opts shape:
--   {
--     onConfirm   = function(pos) end,           -- required; pos = {point, relativePoint, xOfs, yOfs, size?}
--     onCancel    = function() end,              -- optional
--     title       = "Drag the icon",             -- optional; rendered as the
--                                                -- controller's description line
--                                                -- (the title itself is always
--                                                -- "<AddonName> Movers")
--     hideWhileMoving = aFrame,                  -- optional; hidden during the
--                                                -- session, re-shown on
--                                                -- Confirm/Cancel
--     sizeSlider  = {min, max, step, get, set},  -- optional; routed verbatim
--                                                -- to MoverController
--   }

local Mover = {}
addon.MBLib.Mover = Mover

-- Module state: only one mover can be active at a time. Tracks the frame
-- being moved, the snapshot of its prior state, and the consumer callbacks.
local active = nil

-- ===== Helpers =====

local function snapshotPosition(frame)
  local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint()
  return { point = point, relativeTo = relativeTo, relativePoint = relativePoint,
           xOfs = xOfs, yOfs = yOfs }
end

local function applyPosition(frame, pos)
  if not pos or not pos.point then return end
  frame:ClearAllPoints()
  -- SetPoint accepts nil relativeTo (defaults to parent), so the captured
  -- tuple round-trips cleanly even when the consumer originally anchored
  -- to UIParent implicitly.
  frame:SetPoint(pos.point, pos.relativeTo, pos.relativePoint, pos.xOfs, pos.yOfs)
end

-- Restore the frame to its start-of-session position WITHOUT ending the
-- session. Wired to the controller's Revert button.
local function revertInPlace()
  if not active then return end
  applyPosition(active.frame, active.position)
end

-- ===== Begin / End =====

local function endActive(confirmed)
  if not active then return end
  local a = active
  active = nil

  -- Resolve the final position. For confirmed, read the live anchor now —
  -- that's where the user dragged the frame to. For cancelled, revert
  -- first so the consumer's frame ends up at the original position and
  -- prevShown restoration logic below doesn't fight with stale drags.
  local pos
  if confirmed then
    local point, _, relativePoint, xOfs, yOfs = a.frame:GetPoint()
    pos = { point = point, relativePoint = relativePoint, xOfs = xOfs, yOfs = yOfs,
            size = a.sliderGet and a.sliderGet() or nil }
  else
    applyPosition(a.frame, a.position)
  end

  -- Restore frame interactivity to whatever it was before Begin().
  a.frame:SetMovable(a.prevMovable)
  a.frame:EnableMouse(a.prevEnableMouse)
  a.frame:SetClampedToScreen(a.prevClamped)
  a.frame:SetScript("OnDragStart", a.prevOnDragStart)
  a.frame:SetScript("OnDragStop",  a.prevOnDragStop)
  -- We registered the drag — unregister. There's no read-side API for "is
  -- X registered", so we always unregister on End. Harmless if the consumer
  -- hadn't registered it either.
  a.frame:RegisterForDrag()

  MBLib.MoverController:Hide()

  if a.hideWhileMoving and a.hideWhileMovingWasShown then
    a.hideWhileMoving:Show()
  end

  -- If the frame was hidden at Begin time (normally-hidden notification
  -- icon), hide it again. Otherwise leave it visible — the consumer was
  -- already showing it (e.g. Mover.Begin from an edit form previewing
  -- the icon next to the form).
  if not a.prevShown then
    a.frame:Hide()
  end

  if confirmed then
    if a.onConfirm then pcall(a.onConfirm, pos) end
  else
    if a.onCancel then pcall(a.onCancel) end
  end
end

function Mover:Begin(frame, opts)
  if type(frame) ~= "table" or type(opts) ~= "table" then return end
  if type(opts.onConfirm) ~= "function" then return end

  -- Cancel any in-flight session first.
  if active then endActive(false) end

  -- Snapshot prior state so endActive() can restore — including IsShown
  -- so a normally-hidden frame returns to hidden after the session, and
  -- the position so Revert can roll back without saving.
  active = {
    frame                   = frame,
    onConfirm               = opts.onConfirm,
    onCancel                = opts.onCancel,
    hideWhileMoving         = opts.hideWhileMoving,
    hideWhileMovingWasShown = opts.hideWhileMoving and opts.hideWhileMoving:IsShown() or false,
    prevMovable             = frame:IsMovable(),
    prevEnableMouse         = frame:IsMouseEnabled(),
    prevClamped             = frame:IsClampedToScreen(),
    prevOnDragStart         = frame:GetScript("OnDragStart"),
    prevOnDragStop          = frame:GetScript("OnDragStop"),
    prevShown               = frame:IsShown(),
    position                = snapshotPosition(frame),
    sliderGet               = opts.sizeSlider and opts.sizeSlider.get or nil,
  }

  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:SetClampedToScreen(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
  frame:SetScript("OnDragStop",  function(self)
    self:StopMovingOrSizing()
    -- The controller is pinned to this frame via stickToFrame, so it
    -- needs a nudge to re-evaluate "above or below?" after the frame
    -- has moved to a new position.
    MBLib.MoverController:Reanchor()
  end)

  -- Force-show: the frame might be normally hidden (notification icon
  -- that only surfaces on a watcher trigger). prevShown above ensures
  -- endActive will hide it again.
  frame:Show()
  if opts.hideWhileMoving and opts.hideWhileMoving:IsShown() then
    opts.hideWhileMoving:Hide()
  end

  MBLib.MoverController:Show({
    title        = MBLib.L.MOVERS_CONTROLLER_TITLE_FMT:format(MBLib._addonName or ""):gsub("^%s+", ""),
    description  = opts.title or MBLib.L.MOVER_DEFAULT_TITLE,
    sizeSlider   = opts.sizeSlider,
    -- Stick the controller to the frame being moved so it follows the
    -- icon/chat-frame around the screen instead of staying parked at
    -- the top. Bulk mode (Movers:ShowAll) deliberately leaves this off
    -- since there's no single target to follow.
    stickToFrame = frame,
    -- Forwarded so MoverController can restore the Settings panel to
    -- the consumer's subcategory after Save / Revert. When omitted,
    -- MoverController falls back to probing Blizzard's current category.
    settingsCategoryID = opts.settingsCategoryID,
    onSave       = function() endActive(true) end,
    onRevert     = revertInPlace,
    onClose      = function() endActive(false) end,
  })
end

function Mover:Cancel()
  endActive(false)
end

function Mover:IsActive()
  return active ~= nil
end
