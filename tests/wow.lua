-- A small stand-in for the parts of the WoW API the addon uses, so its
-- logic can run outside the game. Each simulated player gets their own copy.
-- harness.py sets: now_py() (the clock), send_py(...) (outgoing messages),
-- and PLAYER (this character's name) before loading this file.

unpack = unpack or table.unpack

------------------------------------------------------------------------
-- Time and timers
------------------------------------------------------------------------
function GetTime() return now_py() end
function GetServerTime() return math.floor(now_py()) end
function time(t) if t then return os.time(t) end return math.floor(now_py()) end
date = function(fmt, t) return os.date(fmt, t or math.floor(now_py())) end

realmOffset = 0 -- seconds the realm's clock is ahead of UTC
C_DateAndTime = { GetCurrentCalendarTime = function()
  local d = os.date("!*t", math.floor(now_py()) + realmOffset)
  return { year = d.year, month = d.month, monthDay = d.day, hour = d.hour, minute = d.min }
end }

local timers, tickers = {}, {}
C_Timer = {
  After = function(delay, fn) timers[#timers + 1] = { due = GetTime() + (delay or 0), fn = fn } end,
  NewTicker = function(interval, fn)
    local t = { iv = interval, fn = fn, due = GetTime() + interval }
    tickers[#tickers + 1] = t
    return { Cancel = function() t.cancelled = true end }
  end,
}

-- Run every timer and ticker that's due. Called by the harness each step.
function RunDue()
  local now = GetTime()
  local ready, waiting = {}, {}
  for _, t in ipairs(timers) do
    if t.due <= now then ready[#ready + 1] = t else waiting[#waiting + 1] = t end
  end
  timers = waiting
  for _, t in ipairs(ready) do t.fn() end
  for _, t in ipairs(tickers) do
    if not t.cancelled and t.due <= now then
      t.due = now + t.iv
      t.fn(t)
    end
  end
end

------------------------------------------------------------------------
-- Lua helpers WoW adds
------------------------------------------------------------------------
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function strsplit(sep, s)
  local out = {}
  for piece in (s .. sep):gmatch("(.-)%" .. sep) do out[#out + 1] = piece end
  return unpack(out)
end
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
tinsert = table.insert
function issecretvalue() return false end
function hooksecurefunc(owner, name, fn)
  if type(owner) == "string" then owner, name, fn = _G, owner, name end
  local orig = owner[name]
  owner[name] = function(...) local r = { orig and orig(...) }; fn(...); return unpack(r) end
end

printed = {}
print = function(...)
  local parts = {}
  for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
  printed[#printed + 1] = table.concat(parts, " ")
end

------------------------------------------------------------------------
-- Frames and widgets: any method not listed returns another widget, so
-- interface code can be built and refreshed without a real screen.
-- (Methods start with a capital letter; other fields are the addon's own.)
------------------------------------------------------------------------
frames = {}
local VALUES = {
  GetWidth = 140, GetHeight = 140, GetEffectiveScale = 1, GetStringHeight = 12, GetText = "",
  GetChecked = false, IsShown = false, HasFocus = false, IsEnabled = true, IsProtected = false,
  GetObjectType = "Frame", GetValue = 0, GetNumPoints = 0, GetID = 1, GetMapID = 0,
}
-- Parts that frame templates create (BasicFrameTemplate's title, and so on).
local CHILDREN = { TitleText = true, CloseButton = true, Icon = true, Text = true }
local widgetMeta
widgetMeta = { __index = function(self, key)
  if type(key) ~= "string" or not key:find("^%u") then return nil end
  if CHILDREN[key] then local c = NewWidget(); rawset(self, key, c); return c end
  if VALUES[key] ~= nil then
    local v = VALUES[key]
    return function(w) local own = rawget(w, "_" .. key); if own ~= nil then return own end return v end
  end
  if key == "GetCenter" then return function() return 0, 0 end end
  if key == "GetMinMaxValues" then return function() return 0, 100 end end
  if key == "SetText" then return function(w, v) rawset(w, "_GetText", v) end end
  if key == "SetChecked" then return function(w, v) rawset(w, "_GetChecked", v and true or false) end end
  if key == "Show" then return function(w) rawset(w, "_IsShown", true) end end
  if key == "Hide" then return function(w) rawset(w, "_IsShown", false) end end
  if key == "SetShown" then return function(w, v) rawset(w, "_IsShown", v and true or false) end end
  if key == "SetScript" then return function(w, name, fn) rawset(w, "script_" .. name, fn) end end
  if key == "HookScript" then return function(w, name, fn) rawset(w, "script_" .. name, fn) end end
  if key == "GetScript" then return function(w, name) return rawget(w, "script_" .. name) end end
  if key == "RegisterEvent" then return function(w, ev) w.events[ev] = true end end
  return function() return NewWidget() end
end }
function NewWidget(kind)
  local w = setmetatable({ events = {}, kind = kind }, widgetMeta)
  if kind == "EditBox" then rawset(w, "_GetObjectType", "EditBox") end
  if kind == "Slider" then rawset(w, "_GetObjectType", "Slider") end
  return w
end
function CreateFrame(kind, name)
  local f = NewWidget(kind)
  frames[#frames + 1] = f
  if name then _G[name] = f end
  return f
end

-- Deliver a game event to every frame listening for it.
function fire(event, ...)
  for _, f in ipairs(frames) do
    local handler = rawget(f, "script_OnEvent")
    if handler and (f.events[event] or event == "ADDON_LOADED") then handler(f, event, ...) end
  end
end

UIParent, Minimap, GameTooltip = NewWidget(), NewWidget(), NewWidget()
UISpecialFrames, StaticPopupDialogs, SlashCmdList = {}, {}, {}
ChatTypeInfo = { RAID_WARNING = {} }
SOUNDKIT = { RAID_WARNING = 8959 }
RAID_CLASS_COLORS = setmetatable({}, { __index = function() return { r = 1, g = 1, b = 1 } end })
YES, NO, OKAY, CANCEL = "Yes", "No", "Okay", "Cancel"
staticPopups = {}
function StaticPopup_Show(which, a, b, data) staticPopups[#staticPopups + 1] = { which = which, data = data } end
function PlaySound() end
function RaidNotice_AddMessage() end
RaidWarningFrame = NewWidget()
function InCombatLockdown() return false end
function IsShiftKeyDown() return false end
function GetCursorPosition() return 0, 0 end

------------------------------------------------------------------------
-- Addon messages
------------------------------------------------------------------------
Enum = { SendAddonMessageResult = { Success = 0, AddonMessageThrottle = 3, ChannelThrottle = 9, GeneralError = 1 } }
C_ChatInfo = {
  RegisterAddonMessagePrefix = function() return true end,
  SendAddonMessage = function(prefix, text, channel, target) return send_py(prefix, text, channel, target) end,
}
C_AddOns = { GetAddOnMetadata = function(_, field) if field == "Version" then return ADDON_VERSION end end }

------------------------------------------------------------------------
-- The player, the guild and the group (the harness fills these in)
------------------------------------------------------------------------
guildRoster = {}   -- { name, rankIndex, online, classFile }
raidMembers = {}   -- names in the player's raid
playerClass = "WARRIOR"
playerLevel = 60
inInstance, instanceType = false, "none"
inCombat = false
falling = false
pvpFlagged = false

function IsInGuild() return true end
function GetNormalizedRealmName() return "Realm" end
function Ambiguate(name) return (tostring(name):gsub("%-.*", "")) end
function UnitName(unit)
  if unit == nil or unit == "player" then return PLAYER end
  return units[unit] and units[unit].name
end
function GetGuildInfo()
  for _, r in ipairs(guildRoster) do
    if r[1] == PLAYER then return "The Imperium", "Rank", r[2] end
  end
end
function GetNumGuildMembers() return #guildRoster end
function GetGuildRosterInfo(i)
  local r = guildRoster[i]
  if not r then return end
  return r[1] .. "-Realm", "Rank " .. r[2], r[2], 60, "Class", "Zone", "", "", r[3] ~= false, 0, r[4] or "WARRIOR",
    0, 0, false, false, 0, "Player-" .. i
end
function GuildControlGetNumRanks() return 10 end
function GuildControlGetRankName(i) return "Rank " .. (i - 1) end
function GetGuildRosterMOTD() return "" end
C_GuildInfo = {}

partyOnly = false -- true while the group is a party rather than a raid
function IsInRaid() return #raidMembers > 0 and not partyOnly end
function IsInGroup() return #raidMembers > 0 end
function GetNumGroupMembers() return #raidMembers end
function GetRaidRosterInfo(i)
  local n = raidMembers[i]
  if n then return n, 0, 1, 60, "Class", "WARRIOR", "Zone", true, false, nil, false, "DAMAGER" end
end
function UnitIsGroupLeader() return true end

function UnitClass() return "Class", playerClass end
function UnitLevel(unit)
  if unit == nil or unit == "player" then return playerLevel end
  return units[unit] and units[unit].level or 60
end
function GetMaxPlayerLevel() return 60 end
function IsInInstance() return inInstance, instanceType end
function UnitAffectingCombat(unit)
  if unit == "player" then return inCombat end
  return units[unit] and units[unit].combat or false
end
function UnitIsPVP() return pvpFlagged end
function IsFalling() return falling end
function GetRealZoneText() return "Stranglethorn Vale" end
function GetZoneText() return "Stranglethorn Vale" end
function GetPVPLifetimeStats() return 0 end

-- Other units the player can see: units[unitToken] = { name, player, hostile, dead, level, targetingMe }
units = {}
function UnitExists(u)
  if units[u] then return true end
  local base = u:match("^(.-)target$")
  return base ~= nil and units[base] ~= nil and units[base].targetingMe == true
end
function UnitIsPlayer(u) return units[u] and units[u].player or false end
function UnitCanAttack(_, u) return units[u] and units[u].hostile and not units[u].dead or false end
function UnitReaction(_, u) return units[u] and units[u].hostile and 2 or 5 end
function GetUnitName(u) return units[u] and units[u].name end
function UnitIsDeadOrGhost(u)
  if u == "player" then return playerDead or false end
  return units[u] and units[u].dead or false
end
function UnitIsFeignDeath() return false end
function UnitIsUnit(a, b)
  if b == "player" then
    local base = a:match("^(.-)target$")
    return base ~= nil and units[base] ~= nil and units[base].targetingMe == true
  end
  return a == b
end
function UnitClassification(u) return units[u] and units[u].classification or "normal" end
C_NamePlate = { GetNamePlates = function()
  local out = {}
  for token in pairs(units) do
    if token:find("^nameplate") then out[#out + 1] = { namePlateUnitToken = token } end
  end
  return out
end }
C_Spell = { IsSpellHarmful = function(id) return harmfulSpells[id] == true end }
harmfulSpells = { [133] = true } -- Fireball

-- Items: link text containing a word picks its type.
C_Item = { GetItemInfoInstant = function(link)
  if link:find("Plate") then return 1, "Armor", "Plate", "INVTYPE_CHEST", 0, 4, 4 end
  if link:find("Wand") then return 2, "Weapon", "Wand", "INVTYPE_RANGED", 0, 2, 19 end
  return 3, "Armor", "Miscellaneous", "INVTYPE_FINGER", 0, 4, 0
end }

invited = {}
C_PartyInfo = {
  InviteUnit = function(name) invited[#invited + 1] = name end,
  ConvertToRaid = function() convertedToRaid = true; partyOnly = false end,
}
RANDOM_ROLL_RESULT = "%s rolls %d (%d-%d)"
DUEL_WINNER_KNOCKOUT = "%1$s has defeated %2$s in a duel"
COMBATLOG_HONORGAIN = "%s dies, honorable kill Rank: %s (%d Honor Points)"
ERR_GUILD_PROMOTE_SSS = "%s has promoted %s to %s."
ERR_GUILD_DEMOTE_SSS = "%s has demoted %s to %s."
ERR_GUILD_REMOVE_SS = "%s has been kicked out of the guild by %s."
ERR_GUILD_JOIN_S = "%s has joined the guild."
ERR_GUILD_LEAVE_S = "%s has left the guild."
