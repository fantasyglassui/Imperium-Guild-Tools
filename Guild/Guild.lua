--[[
  Warcrest
  Guild: roster, permissions, management actions, guild-wide settings
  and addon version checks.
]]

local _, ns = ...
local Ambiguate = ns.Ambiguate
local CG = C_GuildInfo or {}

------------------------------------------------------------------------
-- Roster and permissions
------------------------------------------------------------------------
-- The game only lists offline members while the guild window's "Show offline
-- members" is ticked (on Classic-style clients). Warcrest needs everyone, for
-- player cards, achievements, DKP and checking who's an officer, so it keeps
-- that on. (Warcrest's own Roster tab has its own Show offline box.)
local function showEveryone()
  local get = ns.First(CG.GetShowOffline, GetGuildRosterShowOffline)
  local set = ns.First(CG.SetShowOffline, SetGuildRosterShowOffline)
  if not (get and set) then return false end
  local ok, on = pcall(get)
  if ok and not ns.Usable(on) then pcall(set, true) return true end
  return false
end

function ns.RequestRoster()
  showEveryone()
  local f = ns.First(CG.GuildRoster, GuildRoster)
  if f then pcall(f) end
end

-- The roster is read from the game once and kept until it changes, so
-- tabs and lookups don't walk hundreds of members over and over.
local rosterCache, rosterByKey, rosterAt
local levelsVersion = 0
function ns.RosterLevelsVersion() return levelsVersion end
local ROSTER_FRESH = 10 -- seconds; the game also tells us when it changes

local function readRoster()
  local list = {}
  for i = 1, (GetNumGuildMembers() or 0) do
    local name, rankName, rankIndex, level, className, zone, publicNote, officerNote,
          isOnline, _, classFile, _, _, isMobile, _, _, guid = GetGuildRosterInfo(i)
    if name then
      -- How long they've been offline, in days (0 when online).
      local offline = 0
      if not isOnline and GetGuildRosterLastOnline then
        local ok, y, mo, d, h = pcall(GetGuildRosterLastOnline, i)
        if ok then offline = (y or 0) * 365 + (mo or 0) * 30 + (d or 0) + (h or 0) / 24 end
      end
      list[#list + 1] = {
        offlineDays = offline,
        index = i, name = name, full = ns.fullName(name), rankName = rankName or "",
        rankIndex = rankIndex or 99, level = level or 0, className = className or "",
        classFile = classFile, zone = zone or "", publicNote = publicNote or "",
        officerNote = officerNote or "", online = isOnline, mobile = isMobile, guid = guid,
      }
    end
  end
  return list
end

local function loadRoster()
  if not rosterCache or #rosterCache ~= (GetNumGuildMembers() or 0) or GetTime() - rosterAt > ROSTER_FRESH then
    -- Offline members hidden (someone unticked "Show offline members" in the
    -- guild window): list everyone again, then read.
    if showEveryone() then
      local f = ns.First(CG.GuildRoster, GuildRoster)
      if f then pcall(f) end
    end
    local before = rosterByKey
    rosterCache, rosterAt = readRoster(), GetTime()
    rosterByKey = {}
    local levelled = false
    for _, m in ipairs(rosterCache) do
      local k = ns.Key(m.name)
      rosterByKey[k] = m
      if before and before[k] and before[k].level ~= m.level then levelled = true end
    end
    -- Someone levelled up: achievements that depend on level (Max Level) are due a fresh look.
    if levelled then
      levelsVersion = levelsVersion + 1
      if ns.OnLevelsChanged then C_Timer.After(0, ns.OnLevelsChanged) end
    end
  end
end

-- Forget the cached roster (the game says it changed).
function ns.RosterChanged() rosterCache, rosterAt = nil, nil end

-- Every guild member: { index, name, rankName, rankIndex, level, classFile, ... }.
-- A new list each time (callers may sort it); the members themselves are shared.
function ns.GetRoster()
  loadRoster()
  local copy = {}
  for i, m in ipairs(rosterCache) do copy[i] = m end
  return copy
end

-- One guild member by name (with or without realm), or nil.
function ns.Member(name)
  if not name then return end
  loadRoster()
  return rosterByKey[ns.Key(name)]
end

function ns.RankOf(name)
  local target = ns.fullName(name)
  local m = ns.Member(name)
  if not m then return nil end -- nobody in the guild has that name
  if m.full == target then return m.rankIndex end
  -- (Two members with the same name on different realms: look the slow way.)
  for i = 1, (GetNumGuildMembers() or 0) do
    local n, _, rankIndex = GetGuildRosterInfo(i)
    if n and ns.fullName(n) == target then return rankIndex end
  end
end

function ns.MyRank()
  local _, _, rankIndex = GetGuildInfo("player")
  return rankIndex
end

function ns.IsAddonOfficer()
  local r = ns.MyRank()
  return r ~= nil and ns.cfg ~= nil and r <= ns.cfg.officerRank
end

local function perm(...)
  local f = ns.First(...)
  if not f then return false end
  local ok, v = pcall(f)
  return ok and v and true or false
end

-- What the server says this character's rank is allowed to do.
function ns.Perms()
  return {
    invite = perm(CanGuildInvite),
    promote = perm(CanGuildPromote),
    demote = perm(CanGuildDemote),
    remove = perm(CanGuildRemove),
    motd = perm(CanEditMOTD),
    publicNote = perm(CanEditPublicNote),
    officerNote = perm(CG.CanEditOfficerNote, CanEditOfficerNote),
    viewOfficerNote = perm(CG.CanViewOfficerNote, CanViewOfficerNote),
  }
end

-- Officer tools (like the Officer Log) are for addon officers or anyone
-- whose rank can promote, demote or remove members.
function ns.CanSeeOfficerTools()
  if ns.IsAddonOfficer() then return true end
  local p = ns.Perms()
  return p.promote or p.demote or p.remove
end

------------------------------------------------------------------------
-- Management actions (the server still checks rank permissions)
------------------------------------------------------------------------
local function act(label, fn, ...)
  if not fn then
    ns.Say(label .. " isn't available to addons on this client. Use the Guild window instead.")
    return false
  end
  local ok, err = pcall(fn, ...)
  if not ok then ns.Say(label .. " failed: " .. tostring(err)) end
  C_Timer.After(1, ns.RequestRoster)
  return ok
end

function ns.SetNote(m, note, isPublic)
  local ok
  if CG.SetNote and m.guid then
    ok = act("Edit note", CG.SetNote, m.guid, note, isPublic)
  elseif isPublic then
    ok = act("Edit note", GuildRosterSetPublicNote, m.index, note)
  else
    ok = act("Edit note", GuildRosterSetOfficerNote, m.index, note)
  end
  -- The note's text is never broadcast, only that it changed.
  if ok and ns.LogAction then ns.LogAction(isPublic and "note" or "onote", Ambiguate(m.name, "short")) end
  return ok
end

------------------------------------------------------------------------
-- Guild-wide settings, set by officers and synced over the addon channel
------------------------------------------------------------------------
local heardCfgAt = 0

local function fillConfig(c)
  if c.enabled == nil then c.enabled = true end
  if c.officerRank == nil then c.officerRank = 1 end
  if c.dkp == nil then c.dkp = true end -- the guild uses DKP for loot
  if c.bounties == nil then c.bounties = false end -- bounties: off until an officer turns them on
  c.stamp = c.stamp or 0
  c.by = c.by or ""
  if not c.types then
    c.types = {}
    -- carry over 1.2 settings
    if c.world == false then c.types.pvp = false end
  end
  c.world, c.battlegrounds = nil, nil
  -- removed death types: battleground (1.6.1), dungeon, raid and world (1.8.2)
  for _, k in ipairs({ "battleground", "dungeon", "raid", "world", "duel" }) do c.types[k] = nil end
  for _, t in ipairs(ns.TYPES) do
    if c.types[t.key] == nil then c.types[t.key] = true end
  end
  c.types.kill_honor = true -- grey kills never count
end

local function syncGuildConfig()
  local db = ns.db
  local guild = GetGuildInfo("player")
  if guild and db.cfgGuild ~= guild then
    db.cfg, db.cfgGuild = nil, guild -- new guild: start from defaults
  end
  db.cfg = db.cfg or {}
  fillConfig(db.cfg)
  ns.cfg = db.cfg
end
ns.OnLoad(syncGuildConfig)
ns.OnLoad(ns.ApplyGuildLook)
table.insert(ns.OnGuildReady, ns.ApplyGuildLook)
ns.OnEvent("PLAYER_GUILD_UPDATE", function()
  ns.RosterChanged()
  ns.ApplyGuildLook()
  syncGuildConfig()
  if ns.RefreshPanel then ns.RefreshPanel() end
end)
ns.OnEvent("GUILD_ROSTER_UPDATE", function()
  ns.RosterChanged()
  ns.ApplyGuildLook()
  syncGuildConfig()
  if ns.RefreshPanel then ns.RefreshPanel() end
end)
ns.OnEvent("GUILD_MOTD", function()
  if ns.RefreshPanel then ns.RefreshPanel() end
end)

-- Which alert groups each settings message knows about. Older versions only
-- understand the older messages, so officers send all of them.
local CONFIG_GROUPS = {
  -- 3.1.0 and later: also guild features (like DKP on or off), after the sender's name.
  C8 = { death = true, kill = true, duel = true, wanted = true, celebrate = true, streak = true, achievement = true,
    raid = true },
  C7 = { death = true, kill = true, duel = true, wanted = true, celebrate = true, streak = true, achievement = true }, -- 2.14.0 to 3.0
  C6 = { death = true, kill = true, duel = true, wanted = true, celebrate = true, streak = true }, -- 2.13.x
  C5 = { death = true, kill = true, duel = true, wanted = true, celebrate = true }, -- 1.8.0 and later
  C4 = { death = true, kill = true, duel = true }, -- 1.5.x to 1.7.x
  C3 = { death = true, kill = true },              -- 1.4.x
  C2 = { death = true },                           -- 1.3.x
}

local function typesCSV(types, groups)
  local keys = {}
  for _, t in ipairs(ns.TYPES) do
    if types[t.key] and groups[t.group] then keys[#keys + 1] = t.key end
  end
  return table.concat(keys, ",")
end

local function sendConfig()
  local c = ns.cfg
  local on = c.enabled and "1" or "0"
  local features = {}
  if c.dkp then features[#features + 1] = "dkp" end
  if c.bounties then features[#features + 1] = "bounties" end
  -- Raid night recaps (3.3.0) are on unless turned off, so settings from older
  -- versions, which don't know about them, leave them on.
  if not c.types.raid_recap then features[#features + 1] = "norecap" end
  if not c.types.achievement_chat then features[#features + 1] = "noachchat" end
  if c.memberPolls then features[#features + 1] = "memberpolls" end
  ns.Send("C8", c.stamp, on, typesCSV(c.types, CONFIG_GROUPS.C8), c.officerRank, c.by, table.concat(features, ","))
  for _, msg in ipairs({ "C7", "C6", "C5", "C4", "C3", "C2" }) do
    ns.Send(msg, c.stamp, on, typesCSV(c.types, CONFIG_GROUPS[msg]), c.officerRank, c.by)
  end
end

-- new = { enabled = bool, types = { key = bool }, officerRank = number, dkp = bool, bounties = bool (both optional) }
function ns.PushConfig(new)
  if not ns.IsAddonOfficer() then
    ns.Say("Your rank can't change the guild's alert settings.")
    return false
  end
  if new.officerRank ~= ns.cfg.officerRank and ns.MyRank() ~= 0 then
    ns.Say("Only the Guild Master can change which ranks manage these settings.")
    return false
  end
  local c = ns.cfg
  c.enabled, c.officerRank = new.enabled, new.officerRank
  if new.dkp ~= nil then c.dkp = new.dkp and true or false end
  if new.bounties ~= nil then c.bounties = new.bounties and true or false end
  if new.memberPolls ~= nil then c.memberPolls = new.memberPolls and true or false end
  for _, t in ipairs(ns.TYPES) do c.types[t.key] = new.types[t.key] and true or false end
  c.types.kill_honor = true -- grey kills never count, whatever an older version sends
  c.stamp, c.by = GetServerTime(), UnitName("player")
  sendConfig()
  if ns.LogAction then ns.LogAction("settings") end
  ns.Say("Guild settings saved and sent to everyone online.")
  if ns.RefreshPanel then ns.RefreshPanel() end
  return true
end

-- groups = the alert groups this message knows about; others are left alone.
local function handleConfig(parts, sender, retried, groups)
  local stamp = tonumber(parts[2]) or 0
  if stamp == ns.cfg.stamp then heardCfgAt = GetTime() end
  if stamp <= ns.cfg.stamp then return end

  -- The sender name comes from the server, so it can't be faked; check their rank.
  local rank = ns.RankOf(sender)
  if rank == nil then
    if not retried then
      ns.RequestRoster()
      C_Timer.After(3, function() handleConfig(parts, sender, true, groups) end)
    end
    return
  end
  local newOfficerRank = tonumber(parts[5]) or ns.cfg.officerRank
  if rank > ns.cfg.officerRank then return end
  if newOfficerRank ~= ns.cfg.officerRank and rank ~= 0 then return end

  local on = {}
  for key in (parts[4] or ""):gmatch("[^,]+") do on[key] = true end

  local c = ns.cfg
  c.stamp = stamp
  c.enabled = parts[3] == "1"
  for _, t in ipairs(ns.TYPES) do
    if groups[t.group] and not t.feature then c.types[t.key] = on[t.key] or false end
  end
  c.officerRank = newOfficerRank
  c.by = (parts[6] and parts[6] ~= "") and parts[6] or Ambiguate(sender, "short")
  if groups.raid then -- C8 and later: guild features
    local features = {}
    for f in (parts[7] or ""):gmatch("[^,]+") do features[f] = true end
    c.dkp = features.dkp or false
    c.bounties = features.bounties or false
    c.types.raid_recap = not features.norecap
    c.types.achievement_chat = not features.noachchat
    c.memberPolls = features.memberpolls or false
  end
  heardCfgAt = GetTime()
  if ns.RefreshPanel then ns.RefreshPanel() end
end
for msg, groups in pairs(CONFIG_GROUPS) do
  ns.OnMessage(msg, function(parts, sender) handleConfig(parts, sender, false, groups) end)
end

-- Someone logged in and asked for the current settings.
ns.OnMessage("R", function(_, sender)
  if ns.IsMe(sender) or not ns.IsAddonOfficer() or ns.cfg.stamp == 0 then return end
  local askedAt = GetTime()
  C_Timer.After(1 + math.random() * 4, function()
    if heardCfgAt > askedAt then return end -- another officer already answered
    sendConfig()
  end)
end)

table.insert(ns.OnGuildReady, function()
  syncGuildConfig()
  ns.Send("R")
end)

------------------------------------------------------------------------
-- Version check
------------------------------------------------------------------------
ns.versions = {}          -- full name -> version seen this session
local warnedNewer = false
local lastReplyHeard = 0

-- Remembered across sessions: who has been seen running the addon, which
-- version, and when. name key -> { name, version, t }
ns.OnLoad(function() ns.db.addonUsers = ns.db.addonUsers or {} end)

-- Any message from a guildmate's addon shows they have it installed.
function ns.NoteAddonUser(sender, v)
  if not (ns.db and ns.db.addonUsers) then return end
  local k = ns.Key(sender)
  local u = ns.db.addonUsers[k] or { name = Ambiguate(sender, "short") }
  u.t = time()
  if v then u.version = v end
  ns.db.addonUsers[k] = u
end

local function noteVersion(sender, v)
  ns.versions[ns.fullName(sender)] = v
  ns.NoteAddonUser(sender, v)
  if not warnedNewer and ns.CompareVersions(v, ns.version) > 0 then
    warnedNewer = true
    ns.Say(("|cffff8800A newer version (v%s) is out. You have v%s. Please update Warcrest.|r")
      :format(v, ns.version))
  end
  if ns.RefreshPanel then ns.RefreshPanel() end
end

-- "V^version" announces at login; "V^version^r" is a reply.
ns.OnMessage("V", function(parts, sender)
  local v = parts[2]
  if not v or v == "" then return end
  noteVersion(sender, v)
  if parts[3] == "r" then
    if ns.CompareVersions(v, ns.version) >= 0 then lastReplyHeard = GetTime() end
    return
  end
  -- Tell an out-of-date member, but only one of us needs to.
  if not ns.IsMe(sender) and ns.CompareVersions(ns.version, v) > 0 then
    local askedAt = GetTime()
    C_Timer.After(1 + math.random() * 5, function()
      if lastReplyHeard > askedAt then return end
      ns.Send("V", ns.version, "r")
    end)
  end
end)

-- An officer asked everyone to report their version.
ns.OnMessage("VQ", function()
  C_Timer.After(math.random() * 6, function() ns.Send("V", ns.version, "r") end)
end)

function ns.CheckVersions()
  ns.versions[ns.fullName(UnitName("player"))] = ns.version
  ns.Send("VQ")
  ns.Say("Asking everyone online which version they have. Results appear in the Addon tab.")
end

function ns.NewestVersion()
  local newest = ns.version
  for _, v in pairs(ns.versions) do
    if ns.CompareVersions(v, newest) > 0 then newest = v end
  end
  return newest
end

function ns.VersionSummary(roster)
  local newest = ns.NewestVersion()
  local online, with, outdated = 0, 0, 0
  for _, m in ipairs(roster) do
    if m.online then
      online = online + 1
      local v = ns.versions[m.full]
      if v then
        with = with + 1
        if ns.CompareVersions(v, newest) < 0 then outdated = outdated + 1 end
      end
    end
  end
  return online, with, outdated, newest
end

table.insert(ns.OnGuildReady, function()
  ns.versions[ns.fullName(UnitName("player"))] = ns.version
  ns.NoteAddonUser(UnitName("player"), ns.version)
  ns.Send("V", ns.version)
end)
