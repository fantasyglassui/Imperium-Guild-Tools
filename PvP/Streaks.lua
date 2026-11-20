--[[
  Warcrest
  Kill streaks and revenge.

  A streak is a guild member's killing blows in a row without dying to an
  enemy player, each within an hour of the last. The guild hears when
  someone reaches 3, 5, 10, 15... and when a streak of 5 or more is ended.

  Revenge: a guild member kills an enemy player who killed a guildmate in
  the last 30 minutes.

  Everything is worked out from the shared kill log and death history, so
  every guildmate sees the same streaks.
]]

local _, ns = ...
local Ambiguate = ns.Ambiguate

local STREAK_GAP = 60 * 60       -- kills further apart than this start a new streak
local REVENGE_WINDOW = 30 * 60   -- how long after a death killing the killer counts as revenge
local ANNOUNCE_ENDED = 5         -- a streak this long gets a mention when it ends
local MILESTONE = { [3] = true, [5] = true, [10] = true, [15] = true, [20] = true, [25] = true, [30] = true }

local STREAK_COLOR = "|cffffad33"
local REVENGE_COLOR = "|cffff6b6b"

-- Every guild member's killing blows and deaths to enemy players, oldest
-- first, built in one pass over the logs and kept until they change.
local byKey, builtFor
local function signature()
  local kl, dl = ns.db.killLog or {}, ns.db.deathLog or {}
  return #kl .. ":" .. (kl[1] and kl[1].t or 0) .. ":" .. #dl .. ":" .. (dl[1] and dl[1].t or 0) .. ":"
    .. (ns.LedgerStamp and ns.LedgerStamp("KD") or "") -- removed kills
end

local function byTime(a, b)
  if a.t ~= b.t then return a.t < b.t end
  return (a.death and 1 or 0) < (b.death and 1 or 0) -- a kill and death at the same moment: kill first
end

local function build()
  local sig = signature()
  if byKey and builtFor == sig then return byKey end
  byKey = {}
  local function add(key, e)
    local list = byKey[key]
    if not list then list = {}; byKey[key] = list end
    list[#list + 1] = e
  end
  for _, k in ipairs(ns.db.killLog or {}) do
    local kb = not ns.KillHidden(k) and ns.KillingBlow(k)
    if kb then add(ns.Key(kb), { t = k.t, kill = true, name = kb }) end
  end
  for _, d in ipairs(ns.db.deathLog or {}) do
    if d.kind == "pvp" then add(ns.Key(d.who), { t = d.t, death = true }) end
  end
  for _, list in pairs(byKey) do table.sort(list, byTime) end
  builtFor = sig
  return byKey
end

-- One guild member's killing blows and deaths to enemy players, oldest first.
-- before: only events earlier than this time.
local function events(name, before)
  local list = build()[ns.Key(name)] or {}
  if not before then return list end
  local out = {}
  for _, e in ipairs(list) do
    if e.t < before then out[#out + 1] = e else break end
  end
  return out
end

-- Each streak in a list of events: fn(count, firstKill, lastKill, stillGoing).
local function eachStreak(list, fn)
  local count, first, last = 0, nil, nil
  for _, e in ipairs(list) do
    if e.death or (last and e.t - last > STREAK_GAP) then
      if count > 0 then fn(count, first, last, false) end
      count, first, last = 0, nil, nil
    end
    if e.kill then
      count = count + 1
      first = first or e.t
      last = e.t
    end
  end
  if count > 0 then fn(count, first, last, true) end
end

-- A guild member's streak at a moment (now if not given): 0 if they have none.
function ns.CurrentStreak(name, at)
  at = at or GetServerTime()
  local current = 0
  eachStreak(events(name, at + 1), function(count, _, last, going)
    if going and at - last <= STREAK_GAP then current = count end
  end)
  return current
end

-- When a guild member first had a streak of n: the time of that kill, or nil.
function ns.FirstStreakOf(name, n)
  local count, last = 0, nil
  for _, e in ipairs(events(name)) do
    if e.death or (last and e.t - last > STREAK_GAP) then count, last = 0, nil end
    if e.kill then
      count = count + 1
      last = e.t
      if count >= n then return e.t end
    end
  end
end

-- The longest streaks in a period: { { name, count }, ... }, longest first.
function ns.BestStreaks(fromT, toT, max)
  local best = {}
  for _, list in pairs(build()) do
    local name, inRange = nil, {}
    for _, e in ipairs(list) do
      if (not fromT or e.t >= fromT) and (not toT or e.t < toT) then
        inRange[#inRange + 1] = e
        if e.kill then name = name or e.name end
      end
    end
    if name then
      local longest = 0
      eachStreak(inRange, function(count) longest = math.max(longest, count) end)
      if longest >= 2 then best[#best + 1] = { name = name, count = longest } end
    end
  end
  table.sort(best, function(a, b)
    if a.count ~= b.count then return a.count > b.count end
    return a.name < b.name
  end)
  if max then
    for i = #best, max + 1, -1 do best[i] = nil end
  end
  return best
end

-- Whether this alert type is on, for the guild and for you.
local function wanted(kind)
  local c, show = ns.cfg, ns.db.show
  return c and c.enabled and c.types[kind] and show[kind]
end

-- A guildmate's name with their title ("Lyra the Avenger"), as kill alerts show it.
local function titled(name)
  return ns.TitledName and ns.TitledName(name) or Ambiguate(name, "short")
end

local function ago(seconds)
  local m = math.floor(seconds / 60 + 0.5)
  if m < 1 then return ns.T("moments ago") end
  return m == 1 and ns.T("a minute ago") or ns.TF("%d minutes ago", m)
end

-- A guild member just got a kill (called once it's in the kill log).
function ns.OnLiveKill(k)
  local killer = ns.KillingBlow(k)
  if not killer then return end

  -- Revenge: did the victim kill a guildmate recently? The latest such death counts, once.
  local victim, avenged = ns.Key(k.victim), nil
  for _, d in ipairs(ns.db.deathLog or {}) do
    if d.kind == "pvp" and not d.avenged and d.killer and d.t <= k.t and k.t - d.t <= REVENGE_WINDOW
        and ns.Key(Ambiguate(d.killer, "short")) == victim then
      avenged = d
      break -- the log is newest first
    end
  end
  if avenged then
    avenged.avenged = true
    if wanted("kill_revenge") then
      local text
      if ns.Key(avenged.who) == ns.Key(killer) then
        text = ns.TF("Revenge! %s paid %s back for killing them %s.", titled(killer), k.victim, ago(k.t - avenged.t))
      else
        text = ns.TF("Revenge! %s killed %s, who killed %s %s.", titled(killer), k.victim,
          Ambiguate(avenged.who, "short"), ago(k.t - avenged.t))
      end
      ns.Notify(ns.KILL_ICON .. " " .. REVENGE_COLOR .. text .. "|r", REVENGE_COLOR .. text .. "|r", nil, nil, "revenge")
    end
  end

  -- Streak milestones.
  local n = ns.CurrentStreak(killer, k.t)
  if MILESTONE[n] and wanted("kill_streak") then
    local text = ns.TF("%s is on a %d-kill streak!", titled(killer), n)
    ns.Notify(ns.KILL_ICON .. " " .. STREAK_COLOR .. text .. "|r", STREAK_COLOR .. text .. "|r", nil, nil, "streak")
  end
end

-- A guild member just died to an enemy player (called once it's in the death history).
function ns.OnLiveDeath(d)
  if d.kind ~= "pvp" then return end
  local ended = ns.CurrentStreak(d.who, d.t - 1)
  if ended >= ANNOUNCE_ENDED and wanted("kill_streak") then
    local text = d.killer and ns.TF("%s's %d-kill streak was ended by %s.", titled(d.who), ended,
      Ambiguate(d.killer, "short")) or ns.TF("%s's %d-kill streak was ended.", titled(d.who), ended)
    ns.Notify(ns.KILL_ICON .. " " .. STREAK_COLOR .. text .. "|r", STREAK_COLOR .. text .. "|r", nil, nil, "streak")
  end
end
