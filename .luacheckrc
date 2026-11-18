-- Lua checks for The Imperium, run on every pull request by
-- .github/workflows/tests.yml. Run locally with: luacheck .
std = "lua51"
max_line_length = false
self = false -- unused "self" in methods is normal
exclude_files = { "tests/**", ".luarocks/**", ".lua/**" }

-- Globals the addon creates on purpose.
globals = {
  "TheImperiumDB",                       -- saved variables
  "SlashCmdList", "SLASH_THEIMPERIUM1", "SLASH_THEIMPERIUM2",
  "StaticPopupDialogs",
  "TheImperium_OnAddonCompartmentClick", "TheImperium_OnAddonCompartmentEnter",
  "TheImperium_OnAddonCompartmentLeave",
  "TheImperiumDeathPinMixin",            -- named by UI/MapPins.xml
}

-- The game's own functions and tables the addon uses. A name missing here
-- is flagged, which catches typos; add new game functions as they're used.
read_globals = {
  -- Lua helpers WoW adds
  "date", "time", "strsplit", "strtrim", "tinsert", "wipe", "hooksecurefunc", "issecretvalue",
  -- C_ namespaces and Enum
  "C_AddOns", "C_ChatInfo", "C_ClassColor", "C_DateAndTime", "C_GuildInfo", "C_Item", "C_Map",
  "C_NamePlate", "C_PartyInfo", "C_RandomRoll", "C_Spell", "C_Timer", "Enum",
  -- Units, groups and the guild
  "Ambiguate", "GetGuildInfo", "GetGuildRosterInfo", "GetGuildRosterMOTD", "GetNormalizedRealmName",
  "GetNumGroupMembers", "GetNumGuildMembers", "GetRaidRosterInfo", "GetUnitName", "GuildControlGetNumRanks",
  "GuildControlGetRankName", "GuildRoster", "GuildRosterSetOfficerNote", "GuildRosterSetPublicNote",
  "CanEditMOTD", "CanEditOfficerNote", "CanEditPublicNote", "CanGuildDemote", "CanGuildInvite",
  "CanGuildPromote", "CanGuildRemove", "CanViewOfficerNote", "ConvertToRaid", "InviteUnit",
  "IsInGroup", "IsInGuild", "IsInInstance", "IsInRaid", "UnitAffectingCombat", "UnitCanAttack", "UnitClass",
  "UnitExists", "UnitIsDeadOrGhost", "UnitIsFeignDeath", "UnitIsGroupLeader", "UnitIsPVP", "UnitIsPlayer",
  "UnitIsUnit", "UnitLevel", "UnitName", "UnitReaction",
  -- Game state
  "GetAddOnMetadata", "GetCursorPosition", "GetItemIcon", "GetItemInfoInstant", "GetMaxPlayerLevel",
  "GetMinimapShape", "GetPVPLifetimeStats", "GetRealZoneText", "GetServerTime", "GetTime", "GetZoneText",
  "InCombatLockdown", "IsFalling", "IsHarmfulSpell", "IsShiftKeyDown", "PlaySound", "RandomRoll",
  -- Interface
  "ChatEdit_InsertLink", "ChatFontNormal", "ChatFrameUtil", "ChatTypeInfo", "CreateFont", "CreateFrame", "CreateFromMixins", "STANDARD_TEXT_FONT",
  "CreateVector2D", "GameTooltip", "HideUIPanel", "MapCanvasDataProviderMixin", "MapCanvasPinMixin",
  "Minimap", "Mixin", "OpenWorldMap", "PanelTemplates_SetNumTabs", "PanelTemplates_SetTab",
  "PanelTemplates_TabResize", "RaidNotice_AddMessage", "RaidWarningFrame", "Settings", "SettingsPanel",
  "ShowUIPanel", "StaticPopup_Show", "UIParent", "UISpecialFrames", "WorldMapFrame",
  -- Constants and global strings
  "CANCEL", "MAX_PLAYER_LEVEL", "NO", "OKAY", "RAID_CLASS_COLORS", "RANDOM_ROLL_RESULT", "SOUNDKIT", "YES",
  -- Other addons
  "TomTom",
}
