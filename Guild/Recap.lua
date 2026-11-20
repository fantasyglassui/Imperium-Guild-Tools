--[[
  Warcrest
  Weekly recap: after the Tuesday reset, a short summary of the guild's
  last week in chat. PvP kills and the top hunters, guild members killed by
  enemy players, raid nights, bosses and loot.

  Everyone builds it from their own copy of the shared history, so it waits
  a couple of minutes after login for that to catch up with guildmates.
]]

local _, ns = ...

local HEADER = "|cffd4af37"
local CATCH_UP = 120 -- seconds after login before the recap shows

ns.OnLoad(function()
  if ns.db.weeklyRecap == nil then ns.db.weeklyRecap = true end
  -- Someone who just installed has no week to look back on yet.
  if ns.isNewInstall and ns.db.recapWeek == nil then ns.db.recapWeek = select(3, ns.WeekRange(-1)) end
end)

local function inRange(t, fromT, toT) return t and t >= fromT and t < toT end

local function unique(list, value)
  for _, v in ipairs(list) do if v == value then return end end
  list[#list + 1] = value
end

-- Everything the recap says about one week. offset -1 = last week, 0 = this week so far.
function ns.WeeklyRecap(offset)
  local fromT, toT, week = ns.WeekRange(offset or -1)
  local r = { from = fromT, to = toT, week = week, raids = {}, bosses = {}, hunters = {} }

  -- PvP kills
  local kills = ns.QueryKills("all", fromT, toT)
  r.kills = #kills
  r.hunters = ns.KillStats(kills, 3)

  -- Guild members killed by enemy players, and who did it most
  r.deaths = 0
  local byKiller, names = {}, {}
  for _, d in ipairs(ns.db.deathLog or {}) do
    if d.kind == "pvp" and inRange(d.t, fromT, toT) then
      r.deaths = r.deaths + 1
      if d.killer and d.killer ~= "" then
        local k = ns.Key(d.killer)
        byKiller[k] = (byKiller[k] or 0) + 1
        names[k] = Ambiguate(d.killer, "short")
      end
    end
  end
  for k, n in pairs(byKiller) do
    if n >= 2 and (not r.nemesis or n > r.nemesis.count or (n == r.nemesis.count and names[k] < r.nemesis.name)) then
      r.nemesis = { name = names[k], count = n }
    end
  end

  -- Raid nights and bosses
  r.raidNights = 0
  for _, s in ipairs(ns.LedgerEntries("RS")) do
    if inRange(s.t, fromT, toT) then
      r.raidNights = r.raidNights + 1
      unique(r.raids, s.title)
    end
  end
  for _, k in ipairs(ns.BossKills(fromT, toT)) do unique(r.bosses, k.name) end
  -- Before boss kills were recorded (3.0 and earlier), boss DKP shows them.
  for _, c in ipairs(ns.DKPChanges()) do
    local boss = c.entry.reason and c.entry.reason:match("^Boss: (.+)$")
    if boss and not c.undone and inRange(c.entry.t, fromT, toT) then unique(r.bosses, boss) end
  end

  -- Loot
  r.items = 0
  for _, l in ipairs(ns.LootHistory()) do
    if inRange(l.t, fromT, toT) then
      r.items = r.items + 1
      if not l.roll and l.amount > 0 and (not r.biggest or l.amount > r.biggest.amount) then r.biggest = l end
    end
  end

  r.empty = r.kills == 0 and r.deaths == 0 and r.raidNights == 0 and r.items == 0
  return r
end

-- The recap as chat lines.
function ns.RecapLines(r)
  local lines = {}
  if r.kills > 0 then
    local line = ("PvP: %d enemy player%s killed."):format(r.kills, r.kills == 1 and "" or "s")
    local places = {}
    for i, e in ipairs(r.hunters) do
      if e.count > 0 then places[#places + 1] = ("%d. %s (%d)"):format(i, e.name, e.count) end
    end
    if #places > 0 then line = line .. "  Top Head Hunters: " .. table.concat(places, "  ") end
    lines[#lines + 1] = line
  end
  if r.deaths > 0 then
    local line = ("Guild members killed by enemy players: %d."):format(r.deaths)
    if r.nemesis then line = line .. ("  Most kills on us: %s (%d)."):format(r.nemesis.name, r.nemesis.count) end
    lines[#lines + 1] = line
  end
  if r.raidNights > 0 then
    local line = ("Raids: %d raid night%s (%s)"):format(r.raidNights, r.raidNights == 1 and "" or "s",
      table.concat(r.raids, ", "))
    if #r.bosses > 0 then
      line = line .. (", %d boss%s killed"):format(#r.bosses, #r.bosses == 1 and "" or "es")
    end
    lines[#lines + 1] = line .. "."
  end
  if r.items > 0 then
    local line = ("Loot: %d item%s handed out."):format(r.items, r.items == 1 and "" or "s")
    if r.biggest then
      line = line .. ("  Biggest buy: %s, %s for %d DKP."):format(r.biggest.winner, r.biggest.item, r.biggest.amount)
    end
    lines[#lines + 1] = line
  end
  return lines
end

-- Show a week's recap in chat. offset -1 = last week, 0 = this week so far.
function ns.ShowRecap(offset, quietIfEmpty)
  local r = ns.WeeklyRecap(offset)
  if r.empty and quietIfEmpty then return false end
  local span = ns.Date("%b %d", r.from) .. " - " .. ns.Date("%b %d", (offset or -1) == 0 and GetServerTime() or (r.to - 1))
  ns.Say(HEADER .. ((offset or -1) == 0 and "This week so far" or "Last week in the guild") .. "|r  (" .. span .. ")")
  local lines = ns.RecapLines(r)
  if #lines == 0 then
    print("  A quiet week: no kills, raids or loot.")
  else
    for _, line in ipairs(lines) do print("  " .. line) end
  end
  return true
end

-- Once per week, after the reset. Anyone offline then sees it at their next login.
local function weeklyCheck()
  if not ns.db or not ns.db.weeklyRecap then return end
  local _, _, week = ns.WeekRange(-1)
  if ns.db.recapWeek == week then return end
  ns.db.recapWeek = week
  ns.ShowRecap(-1, true)
end
ns.WeeklyRecapCheck = weeklyCheck

table.insert(ns.OnGuildReady, function()
  C_Timer.After(CATCH_UP, weeklyCheck)
  C_Timer.NewTicker(5 * 60, weeklyCheck) -- online when the week turns over
end)
