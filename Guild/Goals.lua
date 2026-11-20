--[[
  Warcrest
  Guild goals: targets officers set for the whole guild, each week or each
  month. "Kill 100 enemy players this week", "Hold 8 raid nights this month".

  A goal starts over every period. Everyone sees how far along the guild is
  on the Achievements tab (Guild view), and when a goal is reached the guild
  hears about it. Goals are kept in the guild's shared record (kind GG; a
  goal removed is GQ), so every officer and member sees the same ones.
]]

local _, ns = ...

local MAX_GOALS = 4
ns.MAX_GOALS = MAX_GOALS
local TARGET_MAX = 100000

-- What a goal can count. `count(fromT, toT)` is the guild's total in the period.
ns.GOAL_KINDS = {
  { key = "kills",        label = "Enemy players killed",   one = "Kill %d enemy player",        many = "Kill %d enemy players" },
  { key = "rivalkills",   label = "Rival guild kills",      one = "Kill %d player of a rival guild", many = "Kill %d players of rival guilds" },
  { key = "bosses",       label = "Raid bosses killed",     one = "Kill %d raid boss",           many = "Kill %d raid bosses" },
  { key = "raidnights",   label = "Raid nights",            one = "Hold %d raid night",          many = "Hold %d raid nights" },
  { key = "events",       label = "Guild events",           one = "Hold %d guild event",         many = "Hold %d guild events" },
  { key = "achievements", label = "Achievements earned",    one = "Earn %d achievement",         many = "Earn %d achievements" },
  { key = "loot",         label = "Loot handed out",        one = "Hand out %d item of loot",    many = "Hand out %d items of loot" },
}
local KIND_BY_KEY = {}
for _, k in ipairs(ns.GOAL_KINDS) do KIND_BY_KEY[k.key] = k end
function ns.GoalKind(key) return KIND_BY_KEY[key] end

ns.GOAL_PERIODS = { { "week", "This week" }, { "month", "This month" } }

ns.OnLoad(function()
  ns.db.goalsDone = ns.db.goalsDone or {} -- goal id .. ":" .. period start -> true (already announced)
  local cutoff = time() - 120 * 86400
  for k in pairs(ns.db.goalsDone) do
    if (tonumber(k:match(":(%d+)$")) or 0) < cutoff then ns.db.goalsDone[k] = nil end
  end
end)

------------------------------------------------------------------------
-- Counting
------------------------------------------------------------------------
local function inRange(t, fromT, toT) return t and t >= fromT and t < toT end

local COUNTERS = {}
function COUNTERS.kills(fromT, toT)
  local n = 0
  for _, k in ipairs(ns.db.killLog or {}) do
    if inRange(k.t, fromT, toT) and not ns.KillHidden(k) then n = n + 1 end
  end
  return n
end
function COUNTERS.rivalkills(fromT, toT)
  local n = 0
  for _, k in ipairs(ns.db.killLog or {}) do
    if inRange(k.t, fromT, toT) and not ns.KillHidden(k) and ns.IsRival(k.vg or ns.EnemyGuild(k.victim)) then n = n + 1 end
  end
  return n
end
function COUNTERS.bosses(fromT, toT) return #ns.BossKills(fromT, toT) end
function COUNTERS.raidnights(fromT, toT)
  local n = 0
  for _, s in ipairs(ns.LedgerEntries("RS")) do
    if inRange(s.t, fromT, toT) and ns.IsOfficerName(s.a) then n = n + 1 end
  end
  return n
end
function COUNTERS.events(fromT, toT)
  local n, now = 0, time()
  for _, e in ipairs(ns.AllGuildEvents()) do
    if inRange(e.start, fromT, toT) and e.start <= now then n = n + 1 end
  end
  return n
end
function COUNTERS.achievements(fromT, toT)
  local n = 0
  for _, a in ipairs(ns.GuildAchievements()) do
    if inRange(a.t, fromT, toT) then n = n + 1 end
  end
  return n
end
function COUNTERS.loot(fromT, toT)
  local n = 0
  for _, l in ipairs(ns.LootHistory()) do
    if inRange(l.t, fromT, toT) then n = n + 1 end
  end
  return n
end

-- A period as a time range. offset 0 = the current one, -1 = the one before.
function ns.GoalRange(period, offset)
  if period == "month" then
    local fromT, toT = ns.MonthRange(offset or 0)
    return fromT, toT
  end
  local fromT, toT = ns.WeekRange(offset or 0)
  return fromT, toT
end

------------------------------------------------------------------------
-- Goals: ledger kinds GG { kind, target, period } and GQ { ref }
------------------------------------------------------------------------
local goals, goalsStamp
function ns.Goals()
  local stamp = ns.LedgerStamp("GG", "GQ")
  if goals and goalsStamp == stamp then return goals end
  goals, goalsStamp = {}, stamp
  local removed = {}
  for _, q in ipairs(ns.LedgerEntries("GQ")) do
    if ns.IsOfficerName(q.a) then removed[q.ref] = true end
  end
  for _, g in ipairs(ns.LedgerEntries("GG")) do
    if not removed[g.id] and KIND_BY_KEY[g.kind] and (g.amount or 0) > 0 and ns.IsOfficerName(g.a) then
      goals[#goals + 1] = { id = g.id, t = g.t, a = g.a, kind = g.kind, target = g.amount,
        period = g.period == "month" and "month" or "week" }
    end
  end
  -- Oldest first; only the first few count.
  while #goals > MAX_GOALS do table.remove(goals, 1) end
  return goals
end

function ns.GoalsFull() return #ns.Goals() >= MAX_GOALS end

-- The goal's wording: "Kill 100 enemy players".
function ns.GoalText(g)
  local k = KIND_BY_KEY[g.kind]
  return ns.TP(g.target, k.one, k.many, g.target)
end

-- How far along: { count, target, done, fromT, toT } for the period (offset 0: now).
function ns.GoalProgress(g, offset)
  local fromT, toT = ns.GoalRange(g.period, offset)
  local count = COUNTERS[g.kind](fromT, toT)
  return { count = count, target = g.target, done = count >= g.target, fromT = fromT, toT = toT }
end

function ns.AddGoal(kind, target, period)
  if not ns.IsAddonOfficer() then ns.Say("Only officers can set guild goals.") return end
  target = math.floor(tonumber(target) or 0)
  if not KIND_BY_KEY[kind] then return end
  if target < 1 or target > TARGET_MAX then ns.Say("Enter how many the guild should reach.") return end
  if ns.GoalsFull() then ns.Say(ns.TF("The guild can have %d goals at a time. Remove one first.", MAX_GOALS)) return end
  period = period == "month" and "month" or "week"
  return ns.LedgerAdd("GG", { kind = kind, amount = target, period = period })
end

function ns.RemoveGoal(id)
  if not ns.IsAddonOfficer() then return end
  return ns.LedgerAdd("GQ", { ref = id })
end

-- Every time a goal was reached, past periods included (since the goal was
-- set): { { goal, fromT }, ... }. For the achievements.
local done, doneVersion
function ns.GoalCompletions()
  local v = ns.LedgerVersion() .. ":" .. #(ns.db.killLog or {})
  if done and doneVersion == v then return done end
  done, doneVersion = {}, v
  for _, g in ipairs(ns.Goals()) do
    for offset = 0, -60, -1 do
      local p = ns.GoalProgress(g, offset)
      if p.toT <= g.t then break end
      if p.done then done[#done + 1] = { goal = g, fromT = p.fromT } end
    end
  end
  return done
end

------------------------------------------------------------------------
-- Announcing a goal reached
------------------------------------------------------------------------
local primed = false -- the first look only notes goals already reached (they were news before you logged in)
local function check()
  if not ns.db or not ns.db.goalsDone then return end
  for _, g in ipairs(ns.Goals()) do
    local p = ns.GoalProgress(g, 0)
    local key = g.id .. ":" .. p.fromT
    if p.done and not ns.db.goalsDone[key] then
      ns.db.goalsDone[key] = true
      if primed and ns.cfg and ns.cfg.enabled then
        local text = ns.TF("Guild goal reached: %s (%s).", ns.GoalText(g),
          ns.T(g.period == "month" and "this month" or "this week"))
        ns.Notify("|cff5ed36b" .. text .. "|r", nil, nil, nil, "celebrate", "Guild goal")
      end
      if ns.RefreshPanel then ns.RefreshPanel() end
    end
  end
  if (GetNumGuildMembers() or 0) > 0 then primed = true end
end
ns.CheckGoals = check

ns.OnLoad(function() C_Timer.NewTicker(20, check) end)
