--[[
  Warcrest
  Boss kills and raid progress.

  When the guild kills a raid boss, a guildmate in the raid records it in the
  shared ledger (kind BK): the boss, the raid, and which guild members were
  there. Several guildmates may record the same kill; kills of the same boss
  within a couple of hours count once, with everyone who was there.

  A boss counts when it dies in a raid instance with at least 5 guild
  members, making up at least half the raid.

  From these come the guild's progress through each raid, first-kill
  announcements ("Guild first!"), the calendar's raid history, the weekly
  recap and boss achievements.
]]

local _, ns = ...

local SAME_KILL = 2 * 60 * 60    -- kills of one boss this close together are the same kill
local MIN_GUILD = 5              -- guild members needed for a kill to count...
local MIN_SHARE = 0.5            -- ...and the share of the raid they must be
local ANNOUNCE_WITHIN = 15 * 60  -- only announce kills from the last 15 minutes

-- How many bosses each raid has, when known, for "3 of 8" progress.
-- (Raids not listed show just the bosses killed.)
ns.RAID_BOSSES = {
  ["Barrow Deeps"] = 8,
  ["Hyjal Summit"] = 13,
  ["Onyxia's Lair"] = 1,
  ["Molten Core"] = 10,
  ["Blackwing Lair"] = 8,
  ["Zul'Gurub"] = 10,
  ["Ruins of Ahn'Qiraj"] = 6,
  ["Temple of Ahn'Qiraj"] = 9,
  ["Naxxramas"] = 15,
}

------------------------------------------------------------------------
-- Reading the kills
------------------------------------------------------------------------
local cache
local cacheStamp

ns.OnLoad(function()
  -- Only boss kill entries change the kills.
  ns.OnLedgerChanged(function()
    local stamp = ns.LedgerStamp("BK")
    if stamp ~= cacheStamp then cache, cacheStamp = nil, stamp end
  end)
end)

local function splitNames(text)
  local out = {}
  for n in (text or ""):gmatch("[^,]+") do out[#out + 1] = n end
  return out
end

-- Every boss kill, newest first: { boss, name, raid, t, names = {...}, first = bool }.
local function build()
  local entries = {}
  for _, e in ipairs(ns.LedgerEntries("BK")) do entries[#entries + 1] = e end
  table.sort(entries, function(a, b) return a.t < b.t end)

  local kills, last = {}, {} -- last: boss -> the kill entries merge into
  local seen = {}            -- boss -> killed before
  for _, e in ipairs(entries) do
    local k = last[e.boss]
    if k and e.t - k.t <= SAME_KILL then
      for _, n in ipairs(splitNames(e.names)) do
        if not k.set[ns.Key(n)] then
          k.set[ns.Key(n)] = true
          k.names[#k.names + 1] = n
        end
      end
    else
      k = { boss = e.boss, name = e.name, raid = e.raid, t = e.t, names = {}, set = {}, first = not seen[e.boss] }
      for _, n in ipairs(splitNames(e.names)) do
        if not k.set[ns.Key(n)] then
          k.set[ns.Key(n)] = true
          k.names[#k.names + 1] = n
        end
      end
      seen[e.boss] = true
      last[e.boss] = k
      kills[#kills + 1] = k
    end
  end
  -- Newest first.
  local out = {}
  for i = #kills, 1, -1 do out[#out + 1] = kills[i] end
  -- Each member's kills, oldest first, so achievements and player cards don't
  -- search every kill for every member.
  local byMember = {}
  for _, k in ipairs(kills) do
    for key in pairs(k.set) do
      local m = byMember[key]
      if not m then m = { kills = {}, times = {}, firsts = {} }; byMember[key] = m end
      m.kills[#m.kills + 1] = k
      m.times[#m.times + 1] = k.t
      if k.first then m.firsts[#m.firsts + 1] = k.t end
    end
  end
  cache = { kills = out, byMember = byMember }
  cacheStamp = ns.LedgerStamp("BK")
  return cache
end

-- Every boss kill, newest first. fromT/toT: only kills in that time.
function ns.BossKills(fromT, toT)
  local all = (cache or build()).kills
  if not fromT and not toT then return all end
  local out = {}
  for _, k in ipairs(all) do
    if (not fromT or k.t >= fromT) and (not toT or k.t < toT) then out[#out + 1] = k end
  end
  return out
end

-- The guild's progress, one entry per raid, most recently raided first:
-- { raid, total (or nil), bosses = { { boss, name, first, last, kills } }, killed, last }.
function ns.RaidProgress()
  local raids, order = {}, {}
  local all = ns.BossKills()
  for i = #all, 1, -1 do -- oldest first, so first kills come first
    local k = all[i]
    local r = raids[k.raid]
    if not r then
      r = { raid = k.raid, total = ns.RAID_BOSSES[k.raid], bosses = {}, byBoss = {}, killed = 0, last = 0 }
      raids[k.raid] = r
      order[#order + 1] = r
    end
    local b = r.byBoss[k.boss]
    if not b then
      b = { boss = k.boss, name = k.name, first = k.t, kills = 0 }
      r.byBoss[k.boss] = b
      r.bosses[#r.bosses + 1] = b
      r.killed = r.killed + 1
    end
    b.kills = b.kills + 1
    b.last = k.t
    r.last = math.max(r.last, k.t)
  end
  for _, r in ipairs(order) do
    if r.total and r.killed > r.total then r.total = r.killed end
  end
  table.sort(order, function(a, b) return a.last > b.last end)
  return order
end

-- How many boss kills a guild member was at, and the times: sorted list.
-- (A shared list: read it, don't change it.)
local NONE = {}
function ns.BossKillTimes(name, firstsOnly)
  local m = (cache or build()).byMember[ns.Key(name)]
  if not m then return NONE end
  return firstsOnly and m.firsts or m.times
end

-- The boss kills a guild member was at, oldest first (shared: read only).
function ns.MemberBossKills(name)
  local m = (cache or build()).byMember[ns.Key(name)]
  return m and m.kills or NONE
end

------------------------------------------------------------------------
-- Recording a kill
------------------------------------------------------------------------
-- Guild members in your raid, and how many are in it.
local function guildInRaid()
  local names, total = {}, 0
  for _, m in ipairs(ns.CurrentRaidMembers()) do
    total = total + 1
    if m.inGuild then names[#names + 1] = Ambiguate(m.name, "short") end
  end
  return names, total
end

local function alreadyRecorded(boss, t)
  for _, e in ipairs(ns.LedgerEntries("BK")) do
    if e.boss == boss and math.abs(e.t - t) <= SAME_KILL then return true end
  end
end

-- Record a kill (unless a guildmate already has). Called a few seconds after
-- the boss dies, at a random moment, so usually only one guildmate sends it.
function ns.RecordBossKill(boss, name, raid, names)
  if alreadyRecorded(boss, GetServerTime()) then return end
  return ns.LedgerAdd("BK", { boss = boss, name = name, raid = raid, size = #names,
    names = table.concat(names, ",") })
end

-- What happened at the last few boss fights, and why each did or didn't
-- count: shown with /warcrest bosses, and in chat while debug is on. If kills
-- aren't recorded on raid night, this says why.
local function note(text)
  local log = ns.db.bossChecks
  table.insert(log, 1, date("%H:%M:%S") .. "  " .. text)
  for i = #log, 21, -1 do log[i] = nil end
  if ns.db.debug then ns.Say("Boss check: " .. text) end
end

ns.OnLoad(function() ns.db.bossChecks = ns.db.bossChecks or {} end)

-- A stable number for a boss the game gave no ID for (from its name).
local function idFromName(name)
  local n = 0
  for i = 1, #name do n = (n * 31 + name:byte(i)) % 2000000000 end
  return 1000000 + n % 1000000000
end

local lastSeen = {} -- boss name -> time, so ENCOUNTER_END and BOSS_KILL count once

local function bossDied(source, encounterID, encounterName)
  local name = ns.Usable(encounterName)
  local id = tonumber(ns.Usable(encounterID))
  local raid, kind, difficulty, _, maxPlayers = GetInstanceInfo()
  raid = ns.Usable(raid)
  local names, total = guildInRaid()
  local what = ("%s: %s (ID %s) in %s (%s, %s players, difficulty %s). Guild %d of %d in the group."):format(
    source, tostring(name), tostring(id), tostring(raid), tostring(kind), tostring(maxPlayers),
    tostring(difficulty), #names, total)
  if not name or name == "" then note(what .. " Not counted: the game didn't say which boss.") return end
  if lastSeen[name] and GetTime() - lastSeen[name] < 60 then return end -- already handled
  lastSeen[name] = GetTime()
  if kind ~= "raid" then note(what .. " Not counted: not a raid instance.") return end
  if not IsInRaid() then note(what .. " Not counted: you're not in a raid group.") return end
  if #names < MIN_GUILD then note(what .. (" Not counted: fewer than %d guild members."):format(MIN_GUILD)) return end
  if #names < total * MIN_SHARE then note(what .. " Not counted: guild members aren't half the raid.") return end
  id = id or idFromName(name)
  note(what .. " Counted.")
  C_Timer.After(1 + math.random() * 4, function()
    ns.RecordBossKill(id, name, raid or "Raid", names)
  end)
end

ns.OnEvent("ENCOUNTER_END", function(encounterID, encounterName, _, _, success)
  local ok = ns.Usable(success)
  if ok ~= 1 and ok ~= true then
    if ns.db.debug and ns.Usable(encounterName) then note("Wipe on " .. tostring(ns.Usable(encounterName)) .. ": not counted.") end
    return
  end
  bossDied("Encounter end", encounterID, encounterName)
end)

-- Some clients send BOSS_KILL as well (or instead): the same check.
ns.OnEvent("BOSS_KILL", function(encounterID, encounterName)
  bossDied("Boss kill", encounterID, encounterName)
end)

-- /warcrest bosses: the last boss checks.
function ns.ShowBossChecks()
  local log = ns.db.bossChecks or {}
  if #log == 0 then
    ns.Say("No boss fights seen yet. When a raid boss dies, Warcrest notes here whether it counted for the guild, and why.")
    return
  end
  ns.Say("Last boss fights (newest first):")
  for i = 1, math.min(8, #log) do print("  " .. log[i]) end
end

------------------------------------------------------------------------
-- Guild firsts
------------------------------------------------------------------------
local announced = {}

local function wanted()
  local c, show = ns.cfg, ns.db.show
  return c and c.enabled and c.types.boss_first and show.boss_first
end

ns.OnLoad(function()
  ns.OnLedgerChanged(function()
    local now = GetServerTime()
    for _, r in ipairs(ns.RaidProgress()) do
      for _, b in ipairs(r.bosses) do
        local key = b.boss .. ":" .. b.first
        if not announced[key] and now - b.first <= ANNOUNCE_WITHIN then
          announced[key] = true
          if wanted() then
            local text = ("Guild first! %s is down in %s."):format(b.name, r.raid)
            if r.total and r.killed == r.total and b.first == r.last then
              text = text .. (r.total == 1 and (" %s is cleared!"):format(r.raid)
                or (" That's all %d bosses: %s is cleared!"):format(r.total, r.raid))
            end
            ns.Notify(ns.COLOR .. text .. "|r", ns.COLOR .. text .. "|r", nil, nil, "boss", "Guild first")
          end
        end
      end
    end
  end)
end)
