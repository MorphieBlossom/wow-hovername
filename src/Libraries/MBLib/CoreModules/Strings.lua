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

  -- ===== Profiles panel =====
  PROFILES_SUBCATEGORY_NAME        = "Profiles",
  PROFILES_TITLE                   = "Profiles",
  PROFILES_DESC                    = "Profiles let you keep different configurations per character. Pick which one is active on this character, copy or export a profile to share it, and import profiles other people gave you. The currently-active profile for this character is highlighted.",
  PROFILES_NEW_BTN                 = "New profile",
  PROFILES_IMPORT_BTN              = "Import",
  PROFILES_ACTIVE_LABEL            = "Active profile:",
  PROFILES_ACTIVE_NONE             = "(no profile selected)",
  PROFILES_ROW_RENAME_BTN          = "Rename",
  PROFILES_ROW_COPY_BTN            = "Copy",
  PROFILES_ROW_EXPORT_BTN          = "Export",
  PROFILES_ROW_DELETE_BTN          = "Delete",
  PROFILES_ROW_DELETE_TOOLTIP_DESC = "Permanently remove this profile. There is no undo.",
  PROFILES_ROW_CHARS_NONE          = "Not used by any character",
  PROFILES_RENAME_TITLE            = "Rename profile",
  PROFILES_RENAME_PROMPT_FMT       = "Renaming \"%s\". Enter the new name:",
  PROFILES_NEW_TITLE               = "New profile",
  PROFILES_NEW_PROMPT              = "Enter a name for the new profile:",
  PROFILES_COPY_TITLE              = "Copy profile",
  PROFILES_COPY_PROMPT_FMT         = "Copying \"%s\". Enter a name for the new copy:",
  PROFILES_IMPORT_TITLE            = "Import profile",
  PROFILES_IMPORT_PROMPT           = "Paste the export string below, then click Import.",
  PROFILES_IMPORT_NAME_TITLE       = "Name the imported profile",
  PROFILES_IMPORT_NAME_PROMPT      = "Enter the name to save this profile under:",
  PROFILES_EXPORT_TITLE_FMT        = "Export profile \"%s\"",
  PROFILES_EXPORT_PROMPT           = "Copy the export string below (Ctrl+C). Paste it into Import on another character or share with another player.",
  PROFILES_DELETE_TITLE            = "Delete profile?",
  PROFILES_DELETE_BODY_FMT         = "Permanently delete the profile \"%s\"? This cannot be undone.",
  PROFILES_DELETE_BODY_BOUND_FMT   = "Permanently delete the profile \"%s\"? %d character(s) currently use it — they will become profile-less until you switch them to another profile. This cannot be undone.",
  PROFILES_DELETE_CONFIRM_BTN      = "Delete",
  PROFILES_POPUP_OK_BTN            = "OK",
  PROFILES_POPUP_CANCEL_BTN        = "Cancel",
  PROFILES_POPUP_CLOSE_BTN         = "Close",
  PROFILES_ERR_EMPTY_NAME          = "Name can't be blank.",
  PROFILES_ERR_NAME_IN_USE         = "A profile with that name already exists.",
  PROFILES_ERR_LAST_PROFILE        = "Can't delete the only profile — create another one first.",
  PROFILES_ERR_BOUND_CHARS         = "Can't delete: %d character(s) still use this profile. Switch them first.",
  PROFILES_ERR_INVALID             = "Not a valid profile (%s).",
  PROFILES_ERR_NOT_PROFILE         = "This export is not a profile envelope.",
  PROFILES_ERR_GENERIC             = "Couldn't complete that action (%s).",
}
