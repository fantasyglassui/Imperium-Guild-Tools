--[[
  The Imperium
  Official guild addon of <The Imperium>.

  Core: shared helpers, saved data, event and message routing, slash commands.
]]

local ADDON_NAME, ns = ...

ns.PREFIX = "TheImperium" -- hidden addon channel used to talk to guildmates
ns.SEP = "^"
ns.COLOR = "|cffd4af37"   -- Imperium gold

-- Guild artwork (Media folder). Paths are given without the .tga extension.
ns.MEDIA = "Interface\\AddOns\\TheImperium\\Media\\"
ns.ICON = ns.MEDIA .. "Icon"         -- 64x64 guild emblem: chat, addon list, minimap menu
ns.PORTRAIT = ns.MEDIA .. "Portrait" -- 128x128 guild emblem on navy: window portrait
ns.ARTWORK = ns.MEDIA .. "Artwork"   -- 512x512 full guild artwork: Options page
ns.ICON_TEXT = "|T" .. ns.ICON .. ":14:14|t"

-- Alert types members can announce and filter. Order is the display order.
ns.TYPES = {
  { key = "pvp",          group = "death", label = "World PvP" },
  { key = "environment",  group = "death", label = "Falling, drowning & fatigue" },
  { key = "kill_world",   group = "kill",  label = "World PvP kills" },
  { key = "kill_bg",      group = "kill",  label = "Battleground & arena kills" },
  { key = "kill_honor",   group = "kill",  label = "Honor kills only (no grey kills)", filter = true },
  { key = "wanted",       group = "wanted", label = "Wanted gankers spotted" },
  { key = "level_ten",    group = "celebrate", label = "Every 10 levels and max level" },
  { key = "level_all",    group = "celebrate", label = "Every level up" },
}
ns.GROUP_LABELS = { death = "Deaths", kill = "PvP kills by guild members",
  wanted = "Wanted list", celebrate = "Celebrations" }
ns.PVP_TYPES = { pvp = true }

local frame = CreateFrame("Frame")
local events, inits, handlers = {}, {}, {}
ns.loadErrors = {}

-- Run a piece of the addon; if it breaks, note the error instead of
-- stopping everything else.
local lastErrorShown = 0
local function safely(where, fn, ...)
  local ok, err = pcall(fn, ...)
  if ok then return end
  if #ns.loadErrors < 20 then ns.loadErrors[#ns.loadErrors + 1] = where .. ": " .. tostring(err) end
  if ns.db and ns.db.debug and GetTime() - lastErrorShown > 2 then
    lastErrorShown = GetTime()
    print("|cffff6060[The Imperium] error in " .. where .. ": " .. tostring(err) .. "|r")
  end
end

------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------
function ns.Say(msg)
  print(ns.ICON_TEXT .. " " .. ns.COLOR .. "[The Imperium]|r " .. msg)
end

-- Midnight-era clients can hand back "secret" values; never use those.
function ns.Usable(v)
  if v == nil then return nil end
  if issecretvalue and issecretvalue(v) then return nil end
  return v
end

function ns.First(...)
  for i = 1, select("#", ...) do
    local f = select(i, ...)
    if type(f) == "function" then return f end
  end
end

function ns.Clean(s)
  return ((tostring(s or "")):gsub("%" .. ns.SEP, ""))
end

-- Lowercase name without realm, for matching the same player across messages.
function ns.Key(name)
  return (tostring(name or ""):gsub("%-.*", "")):lower()
end

------------------------------------------------------------------------
-- Sending, within the game's limits
------------------------------------------------------------------------
-- WoW silently drops addon messages sent too fast: each prefix gets a small
-- burst allowance that refills about once a second. Every message goes
-- through this queue, which stays under that limit and sends the most
-- important messages first. Bulk catch-up data uses a second prefix, so it
-- has its own allowance and never holds up live alerts or loot bids.
ns.PREFIX_BULK = "TheImperiumB"
local BURST, REFILL = 8, 0.9            -- messages, and messages per second, per prefix
local MAX_BULK = 600                    -- bulk messages waiting before new ones are dropped
local URGENT = { B1 = true, B2 = true, B3 = true, B4 = true, B5 = true, K = true, D2 = true,
  S = true, L = true, W = true }
local queues = { {}, {}, {} }           -- 1 urgent, 2 normal, 3 bulk
local tokens = {}
local lastRefill
local bulkReady = {}                    -- name key -> true once they're known to read the bulk prefix

local function encode(...)
  local parts = {}
  for i = 1, select("#", ...) do parts[i] = ns.Clean((select(i, ...))) end
  return table.concat(parts, ns.SEP)
end

local function enqueue(level, prefix, channel, target, text)
  if level == 3 and #queues[3] >= MAX_BULK then return end
  table.insert(queues[level], { prefix = prefix, channel = channel, target = target, text = text, tries = 0 })
end

local THROTTLED = {}
local function throttleResults()
  local r = Enum and Enum.SendAddonMessageResult
  if r then
    for _, name in ipairs({ "AddonMessageThrottle", "ChannelThrottle", "GeneralError" }) do
      if r[name] then THROTTLED[r[name]] = true end
    end
  end
end

-- Send one message now. Returns false if the game said to slow down.
local function deliver(m)
  if m.channel == "GUILD" and not IsInGuild() then return true end
  if m.channel == "RAID" and not IsInRaid() then return true end
  local ok, result = pcall(C_ChatInfo.SendAddonMessage, m.prefix, m.text, m.channel, m.target)
  if not ok then return true end           -- a bad message: drop it
  if result == false or THROTTLED[result] then return false end
  return true
end

local function pump()
  local now = GetTime()
  local elapsed = lastRefill and (now - lastRefill) or 0
  lastRefill = now
  for _, prefix in ipairs({ ns.PREFIX, ns.PREFIX_BULK }) do
    tokens[prefix] = math.min(BURST, (tokens[prefix] or BURST) + elapsed * REFILL)
  end
  for level = 1, 3 do
    local q = queues[level]
    local i = 1
    while q[i] do
      local m = q[i]
      -- Bulk data on the main prefix always leaves room for alerts and bids.
      local need = (level == 3 and m.prefix == ns.PREFIX) and 4 or 1
      if tokens[m.prefix] >= need then
        tokens[m.prefix] = tokens[m.prefix] - 1
        if deliver(m) then
          table.remove(q, i)
        else
          -- The game held it back: wait a moment, then try again (a few times).
          tokens[m.prefix] = 0
          m.tries = m.tries + 1
          if m.tries > 5 then table.remove(q, i) else i = i + 1 end
        end
      else
        i = i + 1
      end
    end
  end
end

-- Started once the addon has loaded (see the end of this file).
ns.StartSendQueue = function()
  throttleResults()
  C_ChatInfo.RegisterAddonMessagePrefix(ns.PREFIX_BULK)
  C_Timer.NewTicker(0.1, pump)
end

-- Can this guildmate read the bulk prefix? (Version 2.6.0 and later.)
local function readsBulk(target)
  local k = ns.Key(target)
  if bulkReady[k] then return true end
  local v = (ns.versions and ns.versions[ns.fullName(target)])
    or (ns.db and ns.db.addonUsers and ns.db.addonUsers[k] and ns.db.addonUsers[k].version)
  if v and ns.CompareVersions(v, "2.6.0") >= 0 then bulkReady[k] = true return true end
  return false
end

-- Send a message to one guildmate's addon only.
function ns.SendTo(target, ...)
  local text = encode(...)
  enqueue(URGENT[(...)] and 1 or 2, ns.PREFIX, "WHISPER", target, text)
end

-- Send a message to everyone in your raid running the addon.
function ns.SendRaid(...)
  if not IsInRaid() then return end
  enqueue(URGENT[(...)] and 1 or 2, ns.PREFIX, "RAID", nil, encode(...))
end

-- Bulk data for one guildmate (catch-up history), sent after everything else.
function ns.QueueTo(target, ...)
  enqueue(3, readsBulk(target) and ns.PREFIX_BULK or ns.PREFIX, "WHISPER", target, encode(...))
end

-- Send a message to every guildmate running the addon.
function ns.Send(...)
  if not IsInGuild() then return end
  enqueue(URGENT[(...)] and 1 or 2, ns.PREFIX, "GUILD", nil, encode(...))
end

-- How many messages are waiting (for troubleshooting).
function ns.QueueSize()
  return #queues[1] + #queues[2] + #queues[3]
end

function ns.fullName(name)
  if not name then return nil end
  if name:find("-", 1, true) then return name end
  local realm = GetNormalizedRealmName and GetNormalizedRealmName()
  return realm and (name .. "-" .. realm) or name
end

function ns.IsMe(name)
  return ns.fullName(name) == ns.fullName(UnitName("player"))
end

-- Turn a Blizzard format string like "%s has promoted %s to %s." into a pattern.
-- Also returns which argument each capture is, for formats like
-- "%2$s has promoted %1$s" where the order is swapped.
local function escape(str)
  return (str:gsub("[%(%)%.%+%-%*%?%[%]%^%$]", "%%%0"))
end

function ns.FormatToPattern(fmt)
  if type(fmt) ~= "string" then return nil end
  local out, order, seq, i = {}, {}, 0, 1
  while i <= #fmt do
    local s, e, pos, conv = fmt:find("%%(%d*)%$?([sd])", i)
    if not s then
      out[#out + 1] = escape(fmt:sub(i))
      break
    end
    out[#out + 1] = escape(fmt:sub(i, s - 1))
    seq = seq + 1
    order[#order + 1] = tonumber(pos) or seq
    out[#out + 1] = (conv == "d") and "(%d+)" or "(.+)"
    i = e + 1
  end
  return "^" .. table.concat(out) .. "$", order
end

-- Match text against a FormatToPattern result. Returns the arguments by
-- position (args[1] is the format's first argument), or nil.
function ns.MatchFormat(text, pattern, order)
  local caps = { text:match(pattern) }
  if not caps[1] then return nil end
  local args = {}
  for i, v in ipairs(caps) do args[order[i] or i] = v end
  return args
end

local function parseVersion(v)
  local a, b, c = tostring(v or ""):match("^(%d+)%.?(%d*)%.?(%d*)")
  return tonumber(a) or 0, tonumber(b) or 0, tonumber(c) or 0
end

-- 1 if a is newer than b, -1 if older, 0 if the same.
function ns.CompareVersions(a, b)
  local a1, a2, a3 = parseVersion(a)
  local b1, b2, b3 = parseVersion(b)
  if a1 ~= b1 then return a1 > b1 and 1 or -1 end
  if a2 ~= b2 then return a2 > b2 and 1 or -1 end
  if a3 ~= b3 then return a3 > b3 and 1 or -1 end
  return 0
end

------------------------------------------------------------------------
-- Module registration
------------------------------------------------------------------------
function ns.OnLoad(fn) inits[#inits + 1] = fn end

function ns.OnEvent(event, fn)
  if not events[event] then
    events[event] = {}
    frame:RegisterEvent(event)
  end
  table.insert(events[event], fn)
end

function ns.OnMessage(kind, fn) handlers[kind] = fn end

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:SetScript("OnEvent", function(_, event, ...)
  if event == "ADDON_LOADED" then
    if ... ~= ADDON_NAME then
      local list = ns.db and events.ADDON_LOADED
      if list then for _, fn in ipairs(list) do safely("ADDON_LOADED", fn, ...) end end
      return
    end
    ns.isNewInstall = TheImperiumDB == nil
    TheImperiumDB = TheImperiumDB or {}
    ns.db = TheImperiumDB
    local getMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    ns.version = (getMeta and getMeta(ADDON_NAME, "Version")) or "0"
    C_ChatInfo.RegisterAddonMessagePrefix(ns.PREFIX)
    for _, fn in ipairs(inits) do safely("startup", fn) end
    return
  end
  if not ns.db then return end

  if event == "CHAT_MSG_ADDON" then
    local prefix, text, channel, sender = ...
    -- Private messages are only accepted from guild members.
    local member = sender and ns.RankOf and ns.RankOf(sender) ~= nil
    local trusted = channel == "GUILD" or ((channel == "WHISPER" or channel == "RAID") and member)
    if (prefix == ns.PREFIX or prefix == ns.PREFIX_BULK) and trusted and sender and text then
      local parts = { strsplit(ns.SEP, text) }
      local handler = handlers[parts[1]]
      if handler then safely("message " .. tostring(parts[1]), handler, parts, sender, channel) end
      if ns.NoteAddonUser and channel ~= "RAID" then ns.NoteAddonUser(sender) end
    end
    return
  end

  local list = events[event]
  if list then
    for _, fn in ipairs(list) do safely(event, fn, ...) end
  end
end)

------------------------------------------------------------------------
-- Alerts and quiet mode
------------------------------------------------------------------------
-- Every alert goes through ns.Notify. In quiet mode, alerts are held and
-- shown together once you're out of the dungeon, raid or combat.
local held = {}
local MAX_HELD = 50

function ns.IsQuiet()
  local db = ns.db
  if db.quietInstances then
    local inInstance, instanceType = IsInInstance()
    if inInstance and (instanceType == "party" or instanceType == "raid" or instanceType == "scenario") then
      return true
    end
  end
  if db.quietCombat then
    local ok, inCombat = pcall(UnitAffectingCombat, "player")
    if InCombatLockdown() or (ok and ns.Usable(inCombat)) then return true end
  end
  return false
end

local function playSound(kit)
  if ns.db.sound and kit then pcall(PlaySound, kit, "Master") end
end

-- chat: the chat line. warning: the center-screen text (defaults to chat).
-- sound: a SOUNDKIT id (defaults to the raid warning sound).
function ns.Notify(chat, warning, sound, force)
  if not force and ns.IsQuiet() then
    if #held < MAX_HELD then held[#held + 1] = chat end
    return
  end
  ns.Say(chat)
  if ns.db.warning and RaidWarningFrame then
    RaidNotice_AddMessage(RaidWarningFrame, warning or chat, ChatTypeInfo["RAID_WARNING"])
  end
  playSound(sound or (SOUNDKIT and SOUNDKIT.RAID_WARNING))
end

local function flushHeld()
  if #held == 0 or ns.IsQuiet() then return end
  ns.Say(("While you were busy, %d alert%s came in:"):format(#held, #held == 1 and "" or "s"))
  for _, line in ipairs(held) do print("   " .. line) end
  wipe(held)
  playSound(SOUNDKIT and SOUNDKIT.RAID_WARNING)
end

-- Where the player is on the map: mapID, x, y (x and y from 0 to 1).
-- Returns nothing where the game hides your position, such as in instances.
function ns.PlayerPosition()
  if not (C_Map and C_Map.GetBestMapForUnit) then return end
  local ok, mapID = pcall(C_Map.GetBestMapForUnit, "player")
  mapID = ok and ns.Usable(mapID)
  if not mapID then return end
  local ok2, pos = pcall(C_Map.GetPlayerMapPosition, mapID, "player")
  if not (ok2 and pos) then return end
  local ok3, x, y = pcall(pos.GetXY, pos)
  x, y = ok3 and ns.Usable(x), ok3 and ns.Usable(y)
  if type(x) ~= "number" or type(y) ~= "number" or (x == 0 and y == 0) then return end
  return mapID, x, y
end

-- Login greeting, then let modules sync once the guild roster is ready.
ns.OnEvent("PLAYER_ENTERING_WORLD", function(isLogin, isReload)
  if isLogin then
    ns.Say("v" .. ns.version .. " loaded. Type |cffffffff/imperium|r to open guild tools.")
  end
  if isLogin or isReload then
    C_Timer.After(8, function()
      if not IsInGuild() then return end
      if ns.RequestRoster then ns.RequestRoster() end
      if ns.OnGuildReady then
        for _, fn in ipairs(ns.OnGuildReady) do fn() end
      end
    end)
  end
end)
ns.OnGuildReady = {}

ns.OnEvent("PLAYER_REGEN_ENABLED", function() C_Timer.After(1, flushHeld) end)
ns.OnEvent("ZONE_CHANGED_NEW_AREA", function() C_Timer.After(2, flushHeld) end)
ns.OnEvent("PLAYER_ENTERING_WORLD", function() C_Timer.After(3, flushHeld) end)

ns.OnEvent("ADDON_ACTION_BLOCKED", function(who, func)
  if who == ADDON_NAME then
    ns.Say(("The game blocked %s for addons. Use the regular Guild window for that action."):format(tostring(func)))
  end
end)
ns.OnEvent("ADDON_ACTION_FORBIDDEN", function(who, func)
  if who == ADDON_NAME then
    ns.Say(("The game blocked %s for addons. Use the regular Guild window for that action."):format(tostring(func)))
  end
end)

------------------------------------------------------------------------
-- Slash commands
------------------------------------------------------------------------
SLASH_THEIMPERIUM1 = "/imperium"
SLASH_THEIMPERIUM2 = "/imp"
SlashCmdList.THEIMPERIUM = function(input)
  input = input or ""
  local msg = input:lower():match("^%s*(.-)%s*$")
  local function toggle(key, label)
    ns.db[key] = not ns.db[key]
    ns.Say(label .. ": " .. (ns.db[key] and "on" or "off"))
    if ns.RefreshPanel then ns.RefreshPanel() end
  end
  if msg == "" then
    if ns.TogglePanel then ns.TogglePanel() end
  elseif msg == "raids" or msg == "raid" then
    if ns.OpenPanel then ns.OpenPanel("raids") end
  elseif msg == "dkp" then
    if ns.OpenPanel then ns.OpenPanel("dkp") end
  elseif msg:find("^auction") then
    -- /imperium auction [item link] [minimum bid]
    local raw = input:gsub("^%s*[Aa][Uu][Cc][Tt][Ii][Oo][Nn]%s*", "")
    local link = raw:match("(|c.-|r)") or raw:match("(|H.-|h.-|h)")
    local min = tonumber(raw:match("(%d+)%s*$"))
    if ns.StartAuction then ns.StartAuction(link or "", min or 10, 30) end
  elseif msg == "kills" then
    if ns.OpenPanel then ns.OpenPanel("kills") end
  elseif msg == "wanted" then
    if ns.OpenPanel then ns.OpenPanel("wanted") end
  elseif msg == "quiet" then
    ns.db.quietCombat = not ns.db.quietCombat
    ns.Say("Hold alerts during combat: " .. (ns.db.quietCombat and "on" or "off"))
    if ns.RefreshPanel then ns.RefreshPanel() end
  elseif msg == "sync" then
    if ns.RequestHistory then ns.RequestHistory(true) end
    if ns.SyncKills then ns.SyncKills() end
  elseif msg == "test" then
    if ns.TestAlert then ns.TestAlert() end
  elseif msg == "sound" then toggle("sound", "Sound")
  elseif msg == "warn" then toggle("warning", "Center-screen warning")
  elseif msg == "minimap" then
    if ns.SetMinimapButtonShown then
      local show = not ns.IsMinimapButtonShown()
      ns.SetMinimapButtonShown(show)
      ns.Say("Minimap button " .. (show and "shown." or "hidden. Type /imperium minimap to bring it back."))
    end
  elseif msg == "debug" then
    ns.db.debug = not ns.db.debug
    ns.Say("Debug messages " .. (ns.db.debug and "on. Error details will show in chat." or "off."))
  elseif msg == "addon" or msg == "who" then
    if ns.OpenPanel then ns.OpenPanel("addon") end
  elseif msg == "versions" then
    if ns.CheckVersions then ns.CheckVersions() end
  elseif msg == "updates" or msg == "news" or msg == "changes" then
    if ns.ShowUpdates then ns.ShowUpdates(nil) end
  elseif msg == "version" then
    ns.Say("Version " .. ns.version .. (ns.QueueSize() > 0 and (" (" .. ns.QueueSize() .. " messages waiting to send)") or ""))
    if #ns.loadErrors > 0 then
      ns.Say(("|cffff6060%d problem%s so far. The first was:|r"):format(#ns.loadErrors, #ns.loadErrors == 1 and "" or "s"))
      print("  " .. ns.loadErrors[1])
    else
      print("  No problems so far.")
    end
  else
    ns.Say("Commands:")
    print("  /imperium - open guild tools")
    print("  /imperium raids - open raid sign-ups")
    print("  /imperium dkp - open DKP")
    print("  /imperium auction [item] [min bid] - auction an item to your raid (officers)")
    print("  /imperium kills - open the kill log")
    print("  /imperium wanted - open the wanted list")
    print("  /imperium quiet - hold alerts during combat on or off")
    print("  /imperium sync - fetch recent guild history from guildmates")
    print("  /imperium test - show a test alert")
    print("  /imperium sound | warn - toggle alert sound or center-screen warning")
    print("  /imperium minimap - show or hide the minimap button")
    print("  /imperium addon - see who has the addon installed")
    print("  /imperium versions - check which version guildmates have")
    print("  /imperium debug - show error details in chat (troubleshooting)")
    print("  /imperium updates - show what changed in recent versions")
    print("  /imperium version - show your installed version")
  end
end

------------------------------------------------------------------------
-- Addon compartment (the addons button by the minimap)
------------------------------------------------------------------------
function TheImperium_OnAddonCompartmentClick()
  if ns.TogglePanel then ns.TogglePanel() end
end

function TheImperium_OnAddonCompartmentEnter(_, button)
  GameTooltip:SetOwner(button, "ANCHOR_LEFT")
  GameTooltip:SetText("|T" .. ns.ICON .. ":20:20|t " .. ns.COLOR .. "The Imperium|r")
  GameTooltip:AddLine("Click to open guild tools.", 1, 1, 1)
  GameTooltip:AddLine("Version " .. (ns.version or "?"), 0.6, 0.6, 0.6)
  GameTooltip:Show()
end

function TheImperium_OnAddonCompartmentLeave()
  GameTooltip:Hide()
end

ns.OnLoad(ns.StartSendQueue)
