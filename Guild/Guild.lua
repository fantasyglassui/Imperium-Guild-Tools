--[[
  Warcrest
  Guild: roster, permissions, management actions, guild-wide settings
  and addon version checks.
]]

local _, ns = ...
local CG = C_GuildInfo or {}

------------------------------------------------------------------------
-- Roster and permissions
------------------------------------------------------------------------
function ns.RequestRoster()
  local f = ns.First(CG.GuildRoster, GuildRoster)
  if f then pcall(f) end
end

function ns.GetRoster()
  local list = {}
  for i = 1, (GetNumGuildMembers() or 0) do
    local name, rankName, rankIndex, level, className, zone, publicNote, officerNote,
          isOnline, _, classFile, _, _, isMobile, _, _, guid = GetGuildRosterInfo(i)
    if name then
      list[#list + 1] = {
        index = i, name = name, full = ns.fullName(name), rankName = rankName or "",
        rankIndex = rankIndex or 99, level = level or 0, className = className or "",
        classFile = classFile, zone = zone or "", publicNote = publicNote or "",
        officerNote = officerNote or "", online = isOnline, mobile = isMobile, guid = guid,
      }
    end
  end
  return list
end

function ns.RankOf(name)
  local target = ns.fullName(name)
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
  ns.ApplyGuildLook()
  syncGuildConfig()
  if ns.RefreshPanel then ns.RefreshPanel() end
end)
ns.OnEvent("GUILD_ROSTER_UPDATE", function()
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
  C7 = { death = true, kill = true, duel = true, wanted = true, celebrate = true, streak = true, achievement = true }, -- 2.14.0 and later
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
  for _, msg in ipairs({ "C7", "C6", "C5", "C4", "C3", "C2" }) do
    ns.Send(msg, c.stamp, on, typesCSV(c.types, CONFIG_GROUPS[msg]), c.officerRank, c.by)
  end
end

-- new = { enabled = bool, types = { key = bool }, officerRank = number }
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
    if groups[t.group] then c.types[t.key] = on[t.key] or false end
  end
  c.officerRank = newOfficerRank
  c.by = (parts[6] and parts[6] ~= "") and parts[6] or Ambiguate(sender, "short")
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
