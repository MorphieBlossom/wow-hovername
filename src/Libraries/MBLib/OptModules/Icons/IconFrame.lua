local _, addon = ...
local MBLib = addon.MBLib

-- ===== MBLib.IconFrame =====
-- Generic textured display frame with a built-in fade timer. Any addon
-- with a "flash an icon on the screen as a notification" requirement can
-- use this; the frame owns its texture, its size, and its fade lifecycle.
-- It does NOT own its position — the consumer applies that, typically
-- through MBLib.Movers (so the same frame can be repositioned via Settings
-- → Movers like any other movable display).
--
-- Lifecycle:
--   MBLib.IconFrame:Create(name)         -> new IconFrame instance
--   frame:SetIcon(fileID)                 -> set the texture
--   frame:SetIconSize(size)               -> set width = height = size
--   frame:Flash(seconds)                  -> show, then fade after `seconds`
--   frame:CancelFlash()                   -> abort any in-flight fade
--   frame:GetIconFrame()                  -> the underlying Frame (for Movers / SetPoint)
--
-- Concurrency: a second Flash() while one is in flight replaces the timer
-- — the icon stays visible and the new countdown starts from zero. This
-- matches "watcher fires twice in a row" semantics: one icon on screen,
-- always reset by the latest hit.

local IconFrame = {}
addon.MBLib.IconFrame = IconFrame

local instanceMt = { __index = {} }
local Instance = instanceMt.__index

-- ===== Frame construction =====

function IconFrame:Create(name)
  local self = setmetatable({}, instanceMt)

  -- The display frame: bare textured Frame, no backdrop. Strata is MEDIUM
  -- by default — consumers can override via GetIconFrame():SetFrameStrata.
  local f = CreateFrame("Frame", name, UIParent)
  f:SetSize(48, 48)
  f:SetClampedToScreen(true)
  f:Hide()

  local tex = f:CreateTexture(nil, "ARTWORK")
  tex:SetAllPoints()
  -- Default texture is the WoW "icon not yet set" placeholder; consumers
  -- usually call SetIcon before showing, but this keeps Flash() safe even
  -- without a configured icon (otherwise SetTexture(nil) would render an
  -- empty frame, easy to miss when debugging).
  tex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
  -- Trim the Blizzard 1px icon border so the visible art fills the frame.
  tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  f.icon = tex

  self._frame = f
  self._iconTexture = tex
  self._fadeTimer = nil
  self._fadeAnim  = nil
  return self
end

-- ===== Public methods (on each instance) =====

function Instance:GetIconFrame()
  return self._frame
end

function Instance:SetIcon(fileID)
  if not self._iconTexture then return end
  if fileID and fileID ~= 0 then
    -- SetTexture accepts both string paths and numeric FileDataIDs; the
    -- picker returns numeric IDs.
    self._iconTexture:SetTexture(fileID)
  else
    self._iconTexture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
  end
end

function Instance:SetIconSize(size)
  if not self._frame then return end
  size = tonumber(size) or 48
  self._frame:SetSize(size, size)
end

-- Abort any in-flight fade. Called internally before starting a new Flash
-- and exposed publicly so consumers can yank the icon mid-fade (e.g. when
-- the watcher is deleted or disabled).
function Instance:CancelFlash()
  if self._fadeTimer then
    self._fadeTimer:Cancel()
    self._fadeTimer = nil
  end
  if self._fadeAnim then
    self._fadeAnim:Stop()
    self._fadeAnim = nil
  end
  if self._frame then
    self._frame:SetAlpha(1)
  end
end

-- Show the icon and schedule a fade-out after `seconds`. seconds <= 0
-- shows the icon indefinitely until CancelFlash() (treats the slider's
-- minimum as "no auto-fade" if a consumer wants that).
function Instance:Flash(seconds)
  if not self._frame then return end
  seconds = tonumber(seconds) or 0

  self:CancelFlash()
  self._frame:SetAlpha(1)
  self._frame:Show()

  if seconds <= 0 then return end

  -- C_Timer fires after `seconds`, then a short alpha-tween hides the
  -- frame. Splitting the visible hold from the fade keeps the math simple:
  -- the slider value is "how long to stay visible", not "total time
  -- including fade".
  local FADE_OUT_SECONDS = 0.5
  self._fadeTimer = C_Timer.NewTimer(seconds, function()
    if not self._frame then return end
    local ag = self._frame:CreateAnimationGroup()
    local fade = ag:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0)
    fade:SetDuration(FADE_OUT_SECONDS)
    fade:SetSmoothing("OUT")
    ag:SetScript("OnFinished", function()
      if self._frame then
        self._frame:Hide()
        self._frame:SetAlpha(1)  -- ready for the next Flash
      end
      self._fadeAnim = nil
    end)
    self._fadeAnim = ag
    ag:Play()
  end)
end
