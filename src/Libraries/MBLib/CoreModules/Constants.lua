local addonName, addon = ...
local MBLib = addon.MBLib

-- Shared color/icon constants
MBLib.COLOR_ALLIANCE = { r = 0 / 255, g = 112 / 255, b = 221 / 255 }
MBLib.COLOR_COMPLETE = { r = 136 / 255, g = 136 / 255, b = 136 / 255 }
MBLib.COLOR_DEAD = { r = 136 / 255, g = 136 / 255, b = 136 / 255 }
MBLib.COLOR_DEFAULT = { r = 1, g = 1, b = 1 }
MBLib.COLOR_ELITE = { r = 213 / 255, g = 154 / 255, b = 18 / 255 }
MBLib.COLOR_GUILD = { r = 24 / 255, g = 222 / 255, b = 0 }
MBLib.COLOR_HORDE = { r = 1, g = 0, b = 0 }
MBLib.COLOR_HOSTILE = { r = 1, g = 68 / 255, b = 68 / 255 }
MBLib.COLOR_HOSTILE_UNATTACKABLE = { r = 210 / 255, g = 76 / 255, b = 56 / 255 }
MBLib.COLOR_NEUTRAL = { r = 1, g = 1, b = 68 / 255 }
MBLib.COLOR_RARE = { r = 226 / 255, g = 228 / 255, b = 226 / 255 }
MBLib.ICON_CHECKMARK = "|TInterface\\RaidFrame\\ReadyCheck-Ready:11|t"
MBLib.ICON_CROSS     = "|TInterface\\RaidFrame\\ReadyCheck-NotReady:11|t"
MBLib.ICON_LIST = "- "

-- Author's project landing page — used by the "not installed" addon row to
-- show a copyable link the user can paste in a browser. Shared because every
-- MBLib consumer is one of MorphieBlossom's addons.
MBLib.AUTHOR_URL = "https://www.curseforge.com/members/morphieblossom/projects"

-- Other MorphieBlossom addons advertised on every consumer's main options page.
-- The current addon is filtered out at render time, so this list is shared
-- verbatim across all consumers of MBLib.
MBLib.OTHER_ADDONS = {
  { name = "HoverName", description = "Shows player and NPC names when you hover over them in the world." },
  -- { name = "StatInfo",  description = "On-screen readout of primary, secondary, and tertiary stats with per-character priority highlighting." },
  { name = "Meower",    description = "Watches chat for custom phrases and reacts with replies, emotes, invites, or kick prompts." },
}
