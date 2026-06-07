local _, addon = ...

-- ===== MBLib.L (Strings) =====
-- Single source of truth for every user-facing string in MBLib. Add new
-- text here, then reference via MBLib.L.<KEY> in the module that uses it.
--
-- Standard for all MorphieBlossom addons: every user-facing literal lives
-- in one Strings table. Consumer addons follow the same pattern with
-- their own addon.L. Internal debug / log format strings stay inline
-- where they're consumed — those aren't UI text and aren't worth a key.
--
-- Naming convention (mirrors the consumer pattern in Meower):
--   <SCREEN>_<ELEMENT>_<KIND>          e.g. MOVERS_PANEL_TITLE
--   <SCREEN>_..._FMT                   format strings with %s / %d
--   <SCREEN>_..._TOOLTIP_TITLE/DESC    paired tooltip text
--
-- Load order: Strings.lua sits at the top of MBLib.xml so every other
-- module can read MBLib.L at parse time (a few modules build labels at
-- file scope, not in functions).

addon.MBLib = addon.MBLib or {}
addon.MBLib.L = {
  -- ===== Mover (single-frame accessory) =====
  MOVER_DEFAULT_TITLE              = "Drag to position",
  MOVER_SAVE_BTN                   = "Save",
  MOVER_REVERT_BTN                 = "Revert",
  MOVER_REVERT_TOOLTIP_TITLE       = "Revert",
  MOVER_REVERT_TOOLTIP_DESC        = "Discard the drag and return this frame to where it was before you clicked Show.",
  MOVER_SIZE_LABEL                 = "Size",
  MOVER_SIZE_LABEL_FMT             = "Size: %d",

  -- ===== Movers (bulk controller + registry) =====
  MOVERS_CONTROLLER_TITLE_FMT      = "%s Movers", -- %s = consumer addon name
  MOVERS_REVERT_TOOLTIP_DESC       = "Return every mover to where it was before \"Show movers\" was clicked. The session stays open so you can keep dragging.",
  MOVERS_CLOSE_TOOLTIP_TITLE       = "Cancel",
  MOVERS_CLOSE_TOOLTIP_DESC        = "Revert any drags made in this session and close the controller.",

  -- ===== Movers settings panel =====
  MOVERS_PANEL_TITLE               = "Movers",
  MOVERS_PANEL_DESC                = "Reposition the addon's on-screen display frames.",
  MOVERS_PANEL_SHOW_BTN            = "Show movers",
  MOVERS_PANEL_HIDE_BTN            = "Hide movers",
  MOVERS_PANEL_ROW_SHOW_BTN        = "Show",
  MOVERS_PANEL_EMPTY               = "No movable frames are registered yet.",

  -- ===== Options screen (main canvas) =====
  OPTIONS_OTHER_ADDONS_TITLE       = "Other Addons by MorphieBlossom:",
  OPTIONS_OTHER_ADDONS_INSTALLED   = "You already have this addon",
  OPTIONS_OTHER_ADDONS_MISSING     = "You don't have this addon yet",
  OPTIONS_OTHER_ADDONS_GET_FMT     = "Get %s", -- %s = addon name
  OPTIONS_OTHER_ADDONS_GET_DESC    = "Copy the link below and open it in your browser to find this addon on CurseForge.",
  OPTIONS_OTHER_ADDONS_AUTHOR_TITLE = "Other addons by MorphieBlossom",
  OPTIONS_OTHER_ADDONS_AUTHOR_DESC = "Copy the link below and open it in your browser to see all of my addons on CurseForge.",
  OPTIONS_CONTACT_CTA              = "Questions or issues? Reach out on:",
  OPTIONS_COMMANDS_TITLE           = "Available Chat Commands:",
  OPTIONS_PREDECESSOR_FMT          = "|cffaaaaaaThis is a continuation from the original addon|r |cffffd200%s|r |cffaaaaaaby|r %s", -- %s, %s = predecessor name, joined authors
  OPTIONS_PREDECESSOR_AUTHOR_SEP   = " |cffaaaaaa&|r ",
  OPTIONS_FIELD_VERSION            = "|cffffd200Version:|r ",
  OPTIONS_FIELD_AUTHOR             = "|cffffd200Author:|r ",
  OPTIONS_FIELD_LAST_UPDATED       = "|cffffd200Last Updated:|r ",
  OPTIONS_DESC_ITEM_FMT            = "— %s", -- for Other Addons row descriptions

  -- ===== Settings subcategory =====
  SETTINGS_SUBCATEGORY_DEFAULT     = "Display Settings",
  SETTINGS_DEFAULT_SUFFIX_FMT      = "(Default: %s)",

  -- ===== Release notes subcategory =====
  RELEASE_NOTES_TITLE              = "Release Notes",

  -- ===== Icon picker =====
  ICON_PICKER_TITLE                = "Pick an icon",
  ICON_PICKER_ID_LABEL             = "ID:",
  ICON_PICKER_SEARCH_LABEL         = "Search:",
  ICON_PICKER_SELECTED_LABEL       = "Selected:",
  ICON_PICKER_CANCEL_BTN           = "Cancel",
}
