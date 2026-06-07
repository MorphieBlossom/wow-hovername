local _, addon = ...
local MBLib = addon.MBLib

-- ===== MBLib.Movers =====
-- Registry of movable display frames + bulk-edit mode. Consumers register
-- each frame they want to expose in the Settings → Movers panel via
-- MBLib.Movers:Register(id, spec); ShowAll() then puts every registered
-- frame into mover mode at once and floats a single "Save all" controller.
--
-- ShowAll vs. MBLib.Mover:Begin:
--   Mover:Begin   -> one frame, with optional size slider, Confirm/Cancel
--                    accessory panel anchored to the frame. Used from a
--                    watcher's edit form ("Mover" button) to position a
--                    single icon / chat frame.
--   Movers:ShowAll-> every registered frame becomes draggable simultaneously,
--                    a single "Save all positions" / "Cancel" panel floats
--                    freely on top. Used from Settings → Movers when the
--                    user ticks "Show all movers".
--
-- spec shape:
--   {
--     frame        = <Frame>,                        -- required
--     displayName  = "Watcher: Greetings",           -- shown in the panel
--     onSave       = function(pos) end,              -- pos = {point, relativePoint, xOfs, yOfs}
--                                                    -- called on bulk Save for THIS frame
--   }
--
-- Caller is responsible for re-applying the saved position on the next
-- session — Movers itself only owns the in-session move; persistence is the
-- consumer's job (so each addon can put it wherever its SavedVariables
-- schema wants).

local Movers = {}
addon.MBLib.Movers = Movers

Movers._byId  = {}
Movers._order = {}   -- registration order, preserved for the settings panel

-- ===== Registration =====

function Movers:Register(id, spec)
  if type(id) ~= "string" or id == "" or type(spec) ~= "table" then return end
  if type(spec.frame) ~= "table" then return end
  if not self._byId[id] then
    table.insert(self._order, id)
  end
  self._byId[id] = spec
  -- Whenever a frame is registered while bulk-edit is already running, fold
  -- it in so newly-created consumer frames don't sit outside the session.
  if self._bulkActive then
    self:_armFrame(spec)
  end
end

function Movers:Unregister(id)
  if not self._byId[id] then return end
  self._byId[id] = nil
  for i, x in ipairs(self._order) do
    if x == id then table.remove(self._order, i); break end
  end
end

function Movers:Get(id)
  return self._byId[id]
end

function Movers:GetAll()
  local out = {}
  for _, id in ipairs(self._order) do
    out[#out + 1] = { id = id, spec = self._byId[id] }
  end
  return out
end

-- ===== Bulk edit mode =====
-- Each frame in the bulk session gets the same DragStart/DragStop wiring.
-- The session snapshots the frame's prior state so Cancel restores it
-- (movable / mouse-enabled / drag scripts).

Movers._bulkActive = false
Movers._bulkSnapshots = {}

function Movers:_armFrame(spec)
  local frame = spec.frame
  if not frame then return end
  -- Snapshot position alongside the input-state we restore on End. The
  -- position tuple is what Revert puts back; the rest is housekeeping so
  -- Save/Revert never leave the consumer's frame in a weird "still draggable"
  -- state after the session ends.
  local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint()
  local snap = {
    movable      = frame:IsMovable(),
    mouseEnabled = frame:IsMouseEnabled(),
    clamped      = frame:IsClampedToScreen(),
    onDragStart  = frame:GetScript("OnDragStart"),
    onDragStop   = frame:GetScript("OnDragStop"),
    wasShown     = frame:IsShown(),
    position     = {
      point         = point,
      relativeTo    = relativeTo,
      relativePoint = relativePoint,
      xOfs          = xOfs,
      yOfs          = yOfs,
    },
  }
  self._bulkSnapshots[frame] = snap
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:SetClampedToScreen(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
  frame:SetScript("OnDragStop",  function(self) self:StopMovingOrSizing() end)
  -- Force-show so the user can see/grab even normally-hidden notification
  -- frames. We snapshot wasShown to restore on Cancel.
  frame:Show()
end

function Movers:_disarmFrame(spec)
  local frame = spec.frame
  if not frame then return end
  local snap = self._bulkSnapshots[frame]
  if not snap then return end
  frame:SetMovable(snap.movable)
  frame:EnableMouse(snap.mouseEnabled)
  frame:SetClampedToScreen(snap.clamped)
  frame:SetScript("OnDragStart", snap.onDragStart)
  frame:SetScript("OnDragStop",  snap.onDragStop)
  if not snap.wasShown then frame:Hide() end
  self._bulkSnapshots[frame] = nil
end

-- ===== Bulk-mode UI =====
-- ShowAll arms every registered frame, then delegates the on-screen UI
-- (title, Save / Revert / [X], optional slider) to the shared
-- MBLib.MoverController. Same controller frame and same code as
-- MBLib.Mover single-frame mode uses — bulk mode just omits the
-- description line and the per-frame size slider.
--
-- Three button behaviors (consumed by MoverController):
--   Save   -> persist every frame's current position and end the session.
--   Revert -> restore positions from the start-of-session snapshot but
--             leave the session armed (user can keep dragging).
--   [X]    -> revert AND end the session (i.e. cancel everything).

-- Optional opts table: { settingsCategoryID = id }. When provided the
-- value is forwarded to MoverController so the Settings panel restore
-- on Save / Revert lands exactly on the consumer's subcategory (e.g.
-- Meower -> Movers). When omitted, the controller falls back to
-- probing Blizzard's current category.
function Movers:ShowAll(opts)
  if self._bulkActive then return end
  self._bulkActive = true

  for _, id in ipairs(self._order) do
    local spec = self._byId[id]
    if spec then self:_armFrame(spec) end
  end

  -- Title composed per session so the consumer addon's name is current
  -- (MBLib._addonName is set at MBLib:Init, well before ShowAll can run).
  MBLib.MoverController:Show({
    title    = MBLib.L.MOVERS_CONTROLLER_TITLE_FMT:format(MBLib._addonName or ""):gsub("^%s+", ""),
    -- No description in bulk mode — the controller shows just the title.
    -- No sizeSlider either: sizes are a per-frame concern handled by
    -- single-frame Mover sessions.
    settingsCategoryID = opts and opts.settingsCategoryID,
    onSave   = function() Movers:SaveAll() end,
    onRevert = function() Movers:RevertInPlace() end,
    onClose  = function() Movers:HideAll(false) end,
  })

  -- Fire optional onShowAll hook for consumers that want to e.g. close the
  -- main settings panel while bulk-editing.
  if type(self._onShowAll) == "function" then pcall(self._onShowAll) end
end

-- Restore every armed frame to its start-of-session position WITHOUT
-- ending the session. Snapshot is unchanged, so subsequent reverts always
-- go back to the same baseline. Used by the controller's "Revert" button
-- (the [X] button calls HideAll(false), which calls this then disarms).
function Movers:RevertInPlace()
  if not self._bulkActive then return end
  for _, id in ipairs(self._order) do
    local spec = self._byId[id]
    if spec then
      local snap = self._bulkSnapshots[spec.frame]
      -- SetPoint accepts nil relativeTo (defaults to parent), so the
      -- captured tuple round-trips cleanly even when the consumer
      -- originally anchored to UIParent implicitly.
      if snap and snap.position and snap.position.point then
        spec.frame:ClearAllPoints()
        spec.frame:SetPoint(
          snap.position.point,
          snap.position.relativeTo,
          snap.position.relativePoint,
          snap.position.xOfs,
          snap.position.yOfs
        )
      end
    end
  end
end

function Movers:HideAll(saved)
  if not self._bulkActive then return end
  if not saved then
    -- Revert path: roll positions back before disarming so the consumer's
    -- onSave isn't called with dragged values and any next ShowAll snapshot
    -- captures the original positions, not the in-flight ones.
    self:RevertInPlace()
  end
  for _, id in ipairs(self._order) do
    local spec = self._byId[id]
    if spec then self:_disarmFrame(spec) end
  end
  self._bulkActive = false
  MBLib.MoverController:Hide()
  if type(self._onHideAll) == "function" then pcall(self._onHideAll, saved and true or false) end
end

function Movers:SaveAll()
  if not self._bulkActive then return end
  for _, id in ipairs(self._order) do
    local spec = self._byId[id]
    if spec and type(spec.onSave) == "function" then
      local point, _, relativePoint, xOfs, yOfs = spec.frame:GetPoint()
      pcall(spec.onSave, {
        point         = point,
        relativePoint = relativePoint,
        xOfs          = xOfs,
        yOfs          = yOfs,
      })
    end
  end
  self:HideAll(true)
end

function Movers:IsBulkActive()
  return self._bulkActive
end

-- Optional hooks consumers can register to react to bulk-edit start/end
-- (e.g. close their addon's edit form so it doesn't sit over the movers).
function Movers:SetOnShowAll(fn) self._onShowAll = fn end
function Movers:SetOnHideAll(fn) self._onHideAll = fn end
