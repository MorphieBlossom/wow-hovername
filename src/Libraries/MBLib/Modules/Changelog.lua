local addonName, addon = ...
local MBLib = addon.MBLib

local Changelog = {}
Changelog.list = {}

-- Replace the changelog entries. Each entry is:
--   { version = "X.Y.Z", date = "YYYY-MM-DD", notify = bool, categories = { ["Cat"] = { "line", ... } } }
function Changelog:Set(list)
  if type(list) ~= "table" then return end
  self.list = list
end

function Changelog:Build(contentFrame)
  local totalHeight = 10
  local width = contentFrame:GetWidth() - 40
  local leftPadding = 15

  for _, entry in ipairs(self.list or {}) do
    local v = contentFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    v:SetWidth(width)
    v:SetJustifyH("LEFT")
    v:SetText("|cffffd200" .. entry.version .. "|r (" .. entry.date .. ")")
    v:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", leftPadding, -totalHeight)
    totalHeight = totalHeight + v:GetStringHeight() + 8

    for catName, changes in pairs(entry.categories) do
      local cat = contentFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
      cat:SetWidth(width)
      cat:SetJustifyH("LEFT")
      cat:SetText("|cffffffff" .. catName .. ":|r")
      cat:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", leftPadding + 5, -totalHeight)
      totalHeight = totalHeight + cat:GetStringHeight() + 5

      for _, text in ipairs(changes) do
        local chg = contentFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        chg:SetWidth(width - 20)
        chg:SetJustifyH("LEFT")
        chg:SetText("|cffcccccc- " .. text .. "|r")
        chg:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", leftPadding + 10, -totalHeight)
        totalHeight = totalHeight + chg:GetStringHeight() + 4
      end

      totalHeight = totalHeight + 10
    end

    totalHeight = totalHeight + 20
  end

  contentFrame:SetHeight(totalHeight + 20)
end

MBLib.Changelog = Changelog
