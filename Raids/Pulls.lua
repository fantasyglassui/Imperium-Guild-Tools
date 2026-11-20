--[[
  Warcrest
  Wipe tracking: every boss pull in a guild raid, kill or wipe, and how long
  it took. From these: pulls and wipes per boss, the best kill time and the
  last one, shown on the Raids tab's Progress view. A new best kill time is
  announced to the raid's guild members.

  A pull counts under the same rule as boss kills: a raid instance, with at
  least 5 guild members making up at least half the raid. Several guildmates
  may record the same pull; pulls of one boss within a minute count once.

  Shared record: BP { raid, enc, ok, secs } (enc is the boss's name).
]]

local _, ns = ...

local SAME_PULL = 60   -- seconds: records of one boss this close are the same pull
local MIN_GUILD = 5
local MIN_SHARE = 0.5
local MIN_SECS = 8     -- shorter "pulls" are resets, not attempts

------------------------------------------------------------------------
-- The pulls
------------------------------------------------------------------------
local cache, cacheStamp
local function build()
  local stamp = ns.LedgerStamp("BP")
  if cache and cacheStamp == stamp then return cache end
  cache, cacheStamp = {}, stamp
  local list = {}
  for _, e in ipairs(ns.LedgerEntries("BP")) do list[#list + 1] = e end
  table.sort(list, function(a, b) return a.t < b.t end)
  local lastOf = {}
  for _, e in ipairs(list) do
    local key = (e.raid or "") .. "\0" .. (e.enc or "")
    local prev = lastOf[key]
    if not (prev and e.t - prev.t <= SAME_PULL) then
      lastOf[key] = e
      local b = cache[key]
      if not b then
        b = { raid = e.raid, boss = e.enc, pulls = 0, wipes = 0, kills = 0 }
        cache[key] = b
      end
      local secs = tonumber(e.secs) or 0
      b.pulls = b.pulls + 1
      if e.ok == "1" then
        b.kills = b.kills + 1
        b.lastKill, b.lastKillAt = secs, e.t
        if secs > 0 and (not b.best or secs < b.best) then b.best, b.bestAt = secs, e.t end
        b.wipesBeforeFirst = b.wipesBeforeFirst or b.wipes
      else
        b.wipes = b.wipes + 1
        b.lastWipeAt = e.t
      end
    end
  end
  return cache
end

-- One boss: { pulls, wipes, kills, best, bestAt, lastKill, lastWipeAt, wipesBeforeFirst }, or nil.
function ns.BossPulls(raid, boss)
  return build()[(raid or "") .. "\0" .. (boss or "")]
end

-- Every boss of a raid with pulls recorded.
function ns.RaidPulls(raid)
  local out = {}
  for _, b in pairs(build()) do if b.raid == raid then out[#out + 1] = b end end
  return out
end

-- Raids with pulls recorded: { raid = last pull time }.
function ns.PulledRaids()
  local out = {}
  for _, b in pairs(build()) do
    out[b.raid] = math.max(out[b.raid] or 0, b.lastKillAt or 0, b.lastWipeAt or 0)
  end
  return out
end

-- "4:32"
function ns.FightTime(secs)
  secs = math.floor(tonumber(secs) or 0)
  return ("%d:%02d"):format(math.floor(secs / 60), secs % 60)
end

------------------------------------------------------------------------
-- Recording a pull
------------------------------------------------------------------------
local started = {} -- boss name -> GetTime() at the pull

local function guildCount()
  local guild, total = 0, 0
  for _, m in ipairs(ns.CurrentRaidMembers()) do
    total = total + 1
    if m.inGuild then guild = guild + 1 end
  end
  return guild, total
end

local function alreadyRecorded(raid, boss, t)
  for _, e in ipairs(ns.LedgerEntries("BP")) do
    if e.enc == boss and e.raid == raid and math.abs(e.t - t) <= SAME_PULL then return true end
  end
end

function ns.RecordPull(raid, boss, ok, secs)
  if alreadyRecorded(raid, boss, GetServerTime()) then return end
  local before = ns.BossPulls(raid, boss)
  local best = before and before.best
  local e = ns.LedgerAdd("BP", { raid = raid, enc = boss, ok = ok and "1" or "0", secs = math.floor(secs) })
  if e and ok and best and secs < best then
    ns.Send("BR", raid, boss, math.floor(secs), best)
  end
  return e
end

ns.OnEvent("ENCOUNTER_START", function(_, name)
  name = ns.Usable(name)
  if name then started[name] = GetTime() end
end)

ns.OnEvent("ENCOUNTER_END", function(_, name, _, _, success)
  name = ns.Usable(name)
  if not name or not started[name] then return end
  local secs = GetTime() - started[name]
  started[name] = nil
  local raid, kind = GetInstanceInfo()
  raid = ns.Usable(raid)
  if kind ~= "raid" or not IsInRaid() or not raid then return end
  local ok = ns.Usable(success)
  ok = ok == 1 or ok == true
  if not ok and secs < MIN_SECS then return end
  local guild, total = guildCount()
  if guild < MIN_GUILD or guild < total * MIN_SHARE then return end
  -- A random moment, so usually only one guildmate sends it.
  C_Timer.After(1 + math.random() * 4, function() ns.RecordPull(raid, name, ok, secs) end)
end)

-- A new best kill time.
ns.OnMessage("BR", function(p)
  local boss, secs, old = p[3], tonumber(p[4]), tonumber(p[5])
  if not boss or not secs or not old then return end
  if not (ns.cfg and ns.cfg.enabled and ns.cfg.types.boss_first and ns.db.show.boss_first) then return end
  ns.Notify(ns.TF("New best kill time on %s: %s (was %s).", "|cffffffff" .. boss .. "|r", ns.FightTime(secs),
    ns.FightTime(old)), nil, nil, nil, "boss", "Best kill time")
end)
