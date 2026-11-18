--[[
  Warcrest
  Player profiles: everything the guild's shared history says about one
  member, for their player card. PvP (kills, assists, deaths, streaks,
  nemesis), DKP, attendance and loot.
]]

local _, ns = ...

-- The entry in a { key = count } table with the highest count.
local function most(counts, names)
  local bestKey, bestN
  for k, n in pairs(counts) do
    if not bestN or n > bestN or (n == bestN and names[k] < names[bestKey]) then bestKey, bestN = k, n end
  end
  if bestKey then return names[bestKey], bestN end
end

function ns.PlayerProfile(name)
  local key = ns.Key(name)
  local p = { name = name }

  -- Roster details.
  for _, m in ipairs(ns.GetRoster()) do
    if ns.Key(m.name) == key then p.member = m break end
  end

  -- PvP: this month and all time.
  local monthFrom, monthTo = ns.MonthRange(0)
  p.kills, p.monthKills, p.assists = 0, 0, 0
  local victims, victimNames = {}, {}
  for _, k in ipairs(ns.db.killLog or {}) do
    if not ns.KillHidden(k) then
      if ns.Key(ns.KillingBlow(k)) == key then
        p.kills = p.kills + 1
        if k.t >= monthFrom and k.t < monthTo then p.monthKills = p.monthKills + 1 end
        local v = ns.Key(k.victim)
        victims[v] = (victims[v] or 0) + 1
        victimNames[v] = k.victim
      else
        for _, a in ipairs(ns.Assists(k)) do
          if ns.Key(a) == key then p.assists = p.assists + 1 end
        end
      end
    end
  end
  p.favorite, p.favoriteCount = most(victims, victimNames)

  p.deaths = 0
  local killers, killerNames = {}, {}
  for _, d in ipairs(ns.db.deathLog or {}) do
    if d.kind == "pvp" and ns.Key(d.who) == key then
      p.deaths = p.deaths + 1
      if d.killer and d.killer ~= "" then
        local short = Ambiguate(d.killer, "short")
        local k = ns.Key(short)
        killers[k] = (killers[k] or 0) + 1
        killerNames[k] = short
      end
    end
  end
  p.nemesis, p.nemesisCount = most(killers, killerNames)

  p.streak = ns.CurrentStreak and ns.CurrentStreak(name) or 0
  p.bestStreak = 0
  if ns.BestStreaks then
    for _, s in ipairs(ns.BestStreaks()) do
      if ns.Key(s.name) == key then p.bestStreak = s.count break end
    end
  end

  -- DKP, attendance and loot.
  p.dkp = ns.Balance(name)
  p.attended, p.raids, p.noShows = ns.Attendance(name)
  local main = ns.MainOf(name)
  if main and ns.Key(main) ~= key then p.main = main end
  p.alts = ns.AltsOf(name)
  p.loot, p.itemsWon = {}, 0
  for _, l in ipairs(ns.LootHistory()) do
    if ns.Key(l.winner) == key then
      p.itemsWon = p.itemsWon + 1
      if #p.loot < 4 then p.loot[#p.loot + 1] = l end
    end
  end
  -- Wishlist: what they still want.
  p.wishes, p.wishNeed = {}, 0
  for _, w in ipairs(ns.Wishes and ns.Wishes(name) or {}) do
    if not w.won then
      p.wishes[#p.wishes + 1] = w
      if w.prio == "need" then p.wishNeed = p.wishNeed + 1 end
    end
  end
  return p
end
