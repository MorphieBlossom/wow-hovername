local _, addon = ...

local Changelog = {}
Changelog.list = {
  {
    version = "12.0.0.3",
    date = "2026-02-04",
    categories = {
      ["New"] = {
        "Added this whole new fancy option menu where you can configure what you want to see on hover.",
        "Added option to change the font size of the hover text.",
        "Added option to choose the font type, available options are loaded from other installed fonts and addons (shared library).",
        "Added option to display Guild name + rank for player targets.",
        "Added option to display race for player targets.",
        "Added option to display faction for player and NPC targets.",
        "Added option to display the creature Type for NPC targets.",
        "Added option to hide the completed quest objectives from the hover text.",
      }
    }
  },
  {
    version = "12.0.0.2",
    date = "2026-01-24",
    categories = {
      ["Fixes"] = {
        "Changed previous fix to be more effective; it seems that Blizzard's code is not working properly when leaving instance.",
      }
    }
  },
  {
    version = "12.0.0.1",
    date = "2026-01-23",
    categories = {
      ["Fixes"] = {
        "Fixed issue that the hovering no longer worked in instances (Blizzard's combat addon purge).",
      }
    }
  },
  {
    version = "12.0.0.0",
    date = "2026-01-15",
    categories = {
      ["Version update"] = {
        "Updated to game version 12.0.0",
      }
    }
  },
  {
    version = "11.2.7.0",
    date = "2025-12-02",
    categories = {
      ["Version update"] = {
        "Updated to game version 11.2.7",
      }
    }
  },
  {
    version = "11.2.0.1",
    date = "2025-09-07",
    categories = {
      ["Improvements"] = {
        "Split up some code into separate modules, making it easier to build in legacy WoW-API support.",
        "Added support for Legacy WoW-API for quest information.",
      }
    }
  },
  {
    version = "11.2.0.0",
    date = "2025-07-23",
    categories = {
      ["Version update"] = {
        "Updated to game version 11.2.0",
      }
    }
  },
  {
    version = "11.1.7.1",
    date = "2025-05-31",
    categories = {
      ["General"] = {
        "Update TOC to include Curse and Wago IDs. Removed Library TOC file.",
      }
    }
  },
  {
    version = "11.1.7.0",
    date = "2025-05-31",
    categories = {
      ["Version update"] = {
        "Updated to game version 11.1.7",
      },
      ["Improvements"] = {
        "Changed some underlying structure to now also include slash commands and able to store settings.",
      },
      ["Fixes"] = {
        "Improved some check to catch 'exceptional' cases from other AddOns making 'bad' frames, such as OPie having a nameless overlay frame.",
      }
    }
  },
  {
    version = "11.1.5.0",
    date = "2025-04-22",
    categories = {
      ["Version update"] = {
        "Updated to game version 11.1.5",
      }
    }
  },
  {
    version = "11.1.0.0",
    date = "2025-02-20",
    categories = {
      ["Version update"] = {
        "Updated to game version 11.1.0",
      }
    }
  },
  {
    version = "11.0.7.2",
    date = "2025-02-03",
    categories = {
      ["Improvements"] = {
        "For targets that are counting to multiple objectives it will now show all of them. Sorted based on completion.",
      }
    }
  },
  {
    version = "11.0.7.1",
    date = "2025-02-02",
    categories = {
      ["New"] = {
        "Targets that are part of an active (world) quest will now have that quest objective displayed.",
        "Progress quests will display the percentage they yield towards total progress.",
      }
    }
  },
  {
    version = "11.0.7.0",
    date = "2024-12-20",
    categories = {
      ["Version update"] = {
        "Updated to game version 11.0.7",
      }
    }
  },
  {
    version = "11.0.5.0",
    date = "2024-10-23",
    categories = {
      ["Version update"] = {
        "Updated to game version 11.0.5",
      }
    }
  },
  {
    version = "11.0.0.4",
    date = "2024-08-02",
    categories = {
      ["Fixes"] = {
        "Fixed issue that caused in some cases the text to never be displayed at all.",
      }
    }
  },
  {
    version = "11.0.0.3",
    date = "2024-08-02",
    categories = {
      ["New"] = {
        "Added display text for unit classification (World Boss, Elite, Rare, etc) above the level/name.",
        "Added new status 'pvp' - displayed if a player has pvp enabled.",
      },
      ["Improvements"] = {
        "Moved status display (Afk, Dnd) above level/name and reduced font-size.",
        "Changed colors to match standard UI colors.",
        "Cleaned up original code for better structure and reusability.",
      },
      ["Fixes"] = {
        "Target's target name will now be properly displayed in class color.",
      }
    }
  },
  {
    version = "11.0.0.2",
    date = "2024-07-27",
    categories = {
      ["Improvements"] = {
        "Updated addon version to match WoW version: [warcraft version].[addon build].",
      },
      ["Fixes"] = {
        "Fixed issue that could cause Lua error when there is no UnitName.",
      }
    }
  },
  {
    version = "1.1",
    date = "2024-07-26",
    categories = {
      ["General"] = {
        "Re-created the project.",
      },
      ["Fixes"] = {
        "Fixed issues caused by the WoW API changes for game version 11.0.0.",
      }
    }
  },
}

function Changelog:Build(contentFrame)
  local totalHeight = 10
  local width = contentFrame:GetWidth() - 40
  local leftPadding = 15 -- Constant left alignment for everything

  for i, entry in ipairs(self.list or {}) do
    -- 1. Version Header (Gold/Normal)
    local v = contentFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    v:SetWidth(width)
    v:SetJustifyH("LEFT")
    v:SetText("|cffffd200" .. entry.version .. "|r (" .. entry.date .. ")")
    v:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", leftPadding, -totalHeight)
    totalHeight = totalHeight + v:GetStringHeight() + 8

    -- 2. Categories and Changes
    for catName, changes in pairs(entry.categories) do
      -- Category (Green/Small)
      local cat = contentFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
      cat:SetWidth(width)
      cat:SetJustifyH("LEFT")
      cat:SetText("|cffffffff" .. catName .. ":|r")
      cat:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", leftPadding + 5, -totalHeight)
      totalHeight = totalHeight + cat:GetStringHeight() + 5

      for _, text in ipairs(changes) do
        -- Individual Change (Grey/Small)
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

-- Expose module
addon.Changelog = Changelog
