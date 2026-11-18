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

ns.OnLoad(function()
  ns.OnLedgerChanged(function() cache = nil end)
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
  cache = { kills = out }
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
function ns.BossKillTimes(name, firstsOnly)
  local key, out = ns.Key(name), {}
  for _, k in ipairs(ns.BossKills()) do
    if k.set[key] and (not firstsOnly or k.first) then out[#out + 1] = k.t end
  end
  table.sort(out)
  return out
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

ns.OnEvent("ENCOUNTER_END", function(encounterID, encounterName, _, _, success)
  if ns.Usable(success) ~= 1 and ns.Usable(success) ~= true then return end
  if not IsInRaid() then return end
  local raid, kind = GetInstanceInfo()
  if kind ~= "raid" then return end
  local names, total = guildInRaid()
  if #names < MIN_GUILD or #names < total * MIN_SHARE then return end
  local boss = tonumber(ns.Usable(encounterID))
  local name = ns.Usable(encounterName)
  if not boss or not name then return end
  C_Timer.After(1 + math.random() * 4, function()
    ns.RecordBossKill(boss, name, ns.Usable(raid) or "Raid", names)
  end)
end)

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
              text = text .. (" That's all %d bosses: %s is cleared!"):format(r.total, r.raid)
            end
            ns.Notify(ns.COLOR .. text .. "|r", ns.COLOR .. text .. "|r")
          end
        end
      end
    end
  end)
end)
