--[[
  The Imperium
  Achievements and titles.

  Achievements are worked out from the guild's shared history (the kill log,
  the death history and the ledger), so every guildmate sees the same ones
  without anything extra being sent. Once earned, an achievement is also
  remembered on your own computer, so it stays even if old history is
  archived or a log is cleared.

  Some achievements come with a title. Members pick one to show (or none);
  the choice is a ledger entry (kind TI) written by the member themselves,
  and a title only shows if its owner has earned it.

  When someone earns an achievement while you're online, the guild hears
  about it (alert type "achievement").
]]

local _, ns = ...

local REVENGE_WINDOW = 30 * 60
local WANTED_WINDOW = 30 * 86400
local WANTED_KILLS = 3
local NEMESIS_KILLS = 3
local ANNOUNCE_WITHIN = 15 * 60   -- only announce achievements earned in the last 15 minutes
local MAX_LEVEL = 60

------------------------------------------------------------------------
-- The achievements. goal: how many of stat it takes. stat(s) returns the
-- player's list of times (sorted), or a time / nil for one-off ones.
------------------------------------------------------------------------
local LIST = {
  -- PvP
  { id = "kill1", cat = "pvp", name = "First Blood", desc = "Land a killing blow on an enemy player.", stat = "kills", goal = 1 },
  { id = "kill25", cat = "pvp", name = "Head Hunter", desc = "25 killing blows on enemy players.", stat = "kills", goal = 25 },
  { id = "kill100", cat = "pvp", name = "Executioner", desc = "100 killing blows.", stat = "kills", goal = 100, title = "the Executioner" },
  { id = "kill250", cat = "pvp", name = "Warlord", desc = "250 killing blows.", stat = "kills", goal = 250, title = "the Warlord" },
  { id = "assist25", cat = "pvp", name = "Wingman", desc = "Help guildmates with 25 kills.", stat = "assists", goal = 25 },
  { id = "streak3", cat = "pvp", name = "On a Roll", desc = "3 killing blows in a row without dying.", stat = "streak3", goal = 1 },
  { id = "streak5", cat = "pvp", name = "Rampage", desc = "A 5-kill streak.", stat = "streak5", goal = 1 },
  { id = "streak10", cat = "pvp", name = "Unstoppable", desc = "A 10-kill streak.", stat = "streak10", goal = 1, title = "the Unstoppable" },
  { id = "revenge1", cat = "pvp", name = "Payback", desc = "Kill an enemy who killed a guildmate in the last 30 minutes.", stat = "revenge", goal = 1 },
  { id = "revenge10", cat = "pvp", name = "Avenger", desc = "10 revenge kills.", stat = "revenge", goal = 10, title = "the Avenger" },
  { id = "bounty", cat = "pvp", name = "Bounty Hunter", desc = "Kill an enemy who killed guild members 3 times in 30 days.", stat = "bounty", goal = 1, title = "the Bounty Hunter" },
  { id = "nemesis", cat = "pvp", name = "Nemesis Slayer", desc = "Kill an enemy who has killed you 3 times.", stat = "nemesis", goal = 1, title = "the Nemesis Slayer" },
  { id = "champion", cat = "pvp", name = "Champion", desc = "Finish a month top of Top Head Hunters.", stat = "champion", goal = 1, title = "the Champion" },
  -- Raids and loot
  { id = "raid1", cat = "raid", name = "Raider", desc = "Attend a raid night.", stat = "raids", goal = 1 },
  { id = "raid10", cat = "raid", name = "Veteran Raider", desc = "Attend 10 raid nights.", stat = "raids", goal = 10 },
  { id = "raid25", cat = "raid", name = "Iron Raider", desc = "Attend 25 raid nights.", stat = "raids", goal = 25, title = "the Iron Raider" },
  { id = "loot1", cat = "raid", name = "Lucky", desc = "Win an item at a loot auction or roll.", stat = "loot", goal = 1 },
  { id = "spender", cat = "raid", name = "Big Spender", desc = "Spend 100 DKP or more on one item.", stat = "bigBuy", goal = 1, title = "the Big Spender" },
  { id = "wish", cat = "raid", name = "Wish Granted", desc = "Win an item that was on your wishlist.", stat = "wish", goal = 1 },
  -- Guild
  { id = "level", cat = "guild", name = "Max Level", desc = "Reach level " .. MAX_LEVEL .. ".", stat = "maxLevel", goal = 1 },
  { id = "decorated", cat = "guild", name = "Decorated", desc = "Earn 10 other achievements.", stat = "others", goal = 10, title = "the Decorated" },
}
ns.ACHIEVEMENTS = LIST
local BY_ID = {}
for i, a in ipairs(LIST) do a.order = i; BY_ID[a.id] = a end
function ns.Achievement(id) return BY_ID[id] end

------------------------------------------------------------------------
-- Stats from the shared history, for everyone at once
------------------------------------------------------------------------
local index -- built once per change

local function push(t, key, value)
  local list = t[key]
  if not list then list = {}; t[key] = list end
  list[#list + 1] = value
end

local function sortAll(t)
  for _, list in pairs(t) do table.sort(list) end
end

local function buildIndex()
  local kills, assists = {}, {}
  local deathsByKiller = {} -- enemy key -> times they killed a guild member
  local deathsOf = {}       -- member key -> { enemy key -> sorted times }
  for _, d in ipairs(ns.db.deathLog or {}) do
    if d.kind == "pvp" and d.killer and d.killer ~= "" then
      local enemy = ns.Key(d.killer)
      push(deathsByKiller, enemy, d.t)
      local who = ns.Key(d.who)
      deathsOf[who] = deathsOf[who] or {}
      push(deathsOf[who], enemy, d.t)
    end
  end
  sortAll(deathsByKiller)
  for _, byEnemy in pairs(deathsOf) do sortAll(byEnemy) end

  local function countIn(list, fromT, toT)
    local n = 0
    for _, t in ipairs(list or {}) do
      if t >= fromT and t < toT then n = n + 1 end
    end
    return n
  end

  local revenge, bounty, nemesis = {}, {}, {}
  for _, k in ipairs(ns.db.killLog or {}) do
    if not ns.KillHidden(k) then
      local kb = ns.KillingBlow(k)
      if kb then
        local me, enemy = ns.Key(kb), ns.Key(k.victim)
        push(kills, me, k.t)
        local theirs = deathsByKiller[enemy]
        if theirs then
          if countIn(theirs, k.t - REVENGE_WINDOW, k.t + 1) > 0 then push(revenge, me, k.t) end
          if countIn(theirs, k.t - WANTED_WINDOW, k.t) >= WANTED_KILLS then push(bounty, me, k.t) end
        end
        local mine = deathsOf[me] and deathsOf[me][enemy]
        if mine and countIn(mine, 0, k.t) >= NEMESIS_KILLS then push(nemesis, me, k.t) end
      end
      for _, a in ipairs(ns.Assists(k)) do push(assists, ns.Key(a), k.t) end
    end
  end
  sortAll(kills); sortAll(assists); sortAll(revenge); sortAll(bounty); sortAll(nemesis)

  -- Champions: the leader of each finished month that had kills.
  local champion = {}
  local oldest = math.huge
  for _, k in ipairs(ns.db.killLog or {}) do oldest = math.min(oldest, k.t) end
  for offset = -1, -24, -1 do
    local fromT, toT = ns.MonthRange(offset)
    if toT <= oldest then break end
    local top = ns.KillStats(ns.QueryKills("all", fromT, toT), 2)
    if top[1] and top[1].count > 0 and not (top[2] and top[2].count == top[1].count) then
      push(champion, ns.Key(top[1].name), toT)
    end
  end
  sortAll(champion)

  -- Loot.
  local loot, bigBuy, wonItem = {}, {}, {}
  for _, l in ipairs(ns.LootHistory()) do
    local k = ns.Key(l.winner)
    push(loot, k, l.t)
    if not l.roll and l.amount >= 100 then push(bigBuy, k, l.t) end
    local id = ns.ItemID(l.item)
    if id then
      wonItem[k] = wonItem[k] or {}
      wonItem[k][id] = math.min(wonItem[k][id] or math.huge, l.t)
    end
  end
  sortAll(loot); sortAll(bigBuy)

  index = { kills = kills, assists = assists, revenge = revenge, bounty = bounty, nemesis = nemesis,
    champion = champion, loot = loot, bigBuy = bigBuy, wonItem = wonItem }
  return index
end

-- One member's stat: a sorted list of times.
local function statTimes(name, stat)
  local ix = index or buildIndex()
  local k = ns.Key(name)
  if ix[stat] then return ix[stat][k] or {} end
  if stat == "raids" then return ns.RaidNightsAttended(name) end
  if stat:find("^streak") then
    local t = ns.FirstStreakOf(name, tonumber(stat:match("%d+")))
    return t and { t } or {}
  end
  if stat == "wish" then
    local out = {}
    for _, w in ipairs(ns.Wishes and ns.Wishes(name) or {}) do
      local t = ix.wonItem[k] and ix.wonItem[k][w.id]
      if w.won and t then out[#out + 1] = t end
    end
    table.sort(out)
    return out
  end
  if stat == "maxLevel" then
    for _, m in ipairs(ns.GetRoster()) do
      if ns.Key(m.name) == k and m.level >= MAX_LEVEL then return { 0 } end -- 0: earned, when unknown
    end
    return {}
  end
  return {}
end

------------------------------------------------------------------------
-- Earned achievements
------------------------------------------------------------------------
local earnedCache = {} -- key -> { id -> { t = time or 0, progress = n } }

ns.OnLoad(function() ns.db.achievements = ns.db.achievements or {} end)

local function compute(name)
  local k = ns.Key(name)
  local saved = ns.db.achievements[k] or {}
  local out, count = {}, 0
  for _, a in ipairs(LIST) do
    if a.stat ~= "others" then
      local times = statTimes(name, a.stat)
      local got = times[a.goal]
      if got then
        out[a.id] = { t = got, progress = a.goal }
      elseif saved[a.id] then
        out[a.id] = { t = saved[a.id], progress = a.goal }
      else
        out[a.id] = { progress = #times }
      end
      if out[a.id].t then count = count + 1 end
    end
  end
  -- Decorated: earned once 10 others are.
  local d = BY_ID.decorated
  if count >= d.goal then
    local times = {}
    for _, e in pairs(out) do if e.t then times[#times + 1] = e.t end end
    table.sort(times)
    out.decorated = { t = saved.decorated or times[d.goal], progress = d.goal }
  else
    out.decorated = { progress = count }
  end
  -- Remember what's earned, so it stays even if history goes.
  for id, e in pairs(out) do
    if e.t then
      ns.db.achievements[k] = ns.db.achievements[k] or {}
      ns.db.achievements[k][id] = ns.db.achievements[k][id] or e.t
    end
  end
  earnedCache[k] = out
  return out
end

-- A member's achievements: id -> { t = when earned (0 if unknown) or nil, progress = n }.
function ns.MemberAchievements(name)
  return earnedCache[ns.Key(name)] or compute(name)
end

function ns.HasAchievement(name, id)
  local e = ns.MemberAchievements(name)[id]
  return e ~= nil and e.t ~= nil
end

function ns.AchievementCount(name)
  local n = 0
  for _, e in pairs(ns.MemberAchievements(name)) do if e.t then n = n + 1 end end
  return n
end

-- Recently earned across the guild: { { name, id, t }, ... }, newest first.
function ns.GuildAchievements()
  local out = {}
  for _, m in ipairs(ns.GetRoster()) do
    local short = Ambiguate(m.name, "short")
    for id, e in pairs(ns.MemberAchievements(short)) do
      -- (Ones with no known date, like Max Level, aren't news.)
      if e.t and e.t > 0 then out[#out + 1] = { name = short, id = id, t = e.t, classFile = m.classFile } end
    end
  end
  table.sort(out, function(a, b)
    if a.t ~= b.t then return a.t > b.t end
    if a.name ~= b.name then return a.name < b.name end
    return BY_ID[a.id].order < BY_ID[b.id].order
  end)
  return out
end

-- Members with the most achievements: { { name, count, classFile }, ... }.
function ns.AchievementLeaders(n)
  local out = {}
  for _, m in ipairs(ns.GetRoster()) do
    local short = Ambiguate(m.name, "short")
    local c = ns.AchievementCount(short)
    if c > 0 then out[#out + 1] = { name = short, count = c, classFile = m.classFile } end
  end
  table.sort(out, function(a, b)
    if a.count ~= b.count then return a.count > b.count end
    return a.name < b.name
  end)
  while n and #out > n do table.remove(out) end
  return out
end

------------------------------------------------------------------------
-- Titles
------------------------------------------------------------------------
-- The title a member chose (the achievement's id), if they've earned it.
function ns.TitleOf(name)
  local k, id = ns.Key(name), nil
  for _, e in ipairs(ns.LedgerEntries("TI")) do
    if ns.Key(e.a) == k then id = e.title end
  end
  local a = id and BY_ID[id]
  if a and a.title and ns.HasAchievement(name, id) then return a.title, id end
end

-- "Lyra the Avenger", or just "Lyra".
function ns.TitledName(name)
  local short = Ambiguate(name, "short")
  local title = ns.TitleOf(short)
  return title and (short .. " " .. title) or short
end

-- The titles you've earned: { { id, title }, ... }.
function ns.MyTitles()
  local me = UnitName("player")
  local out = {}
  for _, a in ipairs(LIST) do
    if a.title and ns.HasAchievement(me, a.id) then out[#out + 1] = { id = a.id, title = a.title } end
  end
  return out
end

-- Pick your title (an achievement id), or "" for none.
function ns.SetTitle(id)
  id = id or ""
  if id ~= "" and not (BY_ID[id] and BY_ID[id].title and ns.HasAchievement(UnitName("player"), id)) then
    ns.Say("You haven't earned that title yet.")
    return
  end
  local _, current = ns.TitleOf(UnitName("player"))
  if (current or "") == id then return end
  return ns.LedgerAdd("TI", { title = id })
end

------------------------------------------------------------------------
-- Keeping up to date, and announcing new achievements
------------------------------------------------------------------------
local pending = false
local ready = false -- the first look after login only notes what's already earned

local function wanted()
  local c, show = ns.cfg, ns.db.show
  return c and c.enabled and c.types.achievement and show.achievement
end

local function recheck()
  pending = false
  local before = earnedCache
  index, earnedCache = nil, {}
  local now = GetServerTime()
  for _, m in ipairs(ns.GetRoster()) do
    local short = Ambiguate(m.name, "short")
    local was = before[ns.Key(short)]
    local is = ns.MemberAchievements(short)
    if ready and was then
      for _, a in ipairs(LIST) do
        local e = is[a.id]
        if e.t and not (was[a.id] and was[a.id].t) and e.t > 0 and now - e.t <= ANNOUNCE_WITHIN and wanted() then
          local text = ("%s earned %s!"):format(short, a.name)
          if a.title then text = text .. (" New title: %s %s."):format(short, a.title) end
          ns.Notify(ns.COLOR .. text .. "|r", ns.COLOR .. text .. "|r")
        end
      end
    end
  end
  if #ns.GetRoster() > 0 then ready = true end
  if ns.RefreshPanel then ns.RefreshPanel() end
  if ns.RefreshPlayerCard then ns.RefreshPlayerCard() end
end

local function changed()
  if pending then return end
  pending = true
  C_Timer.After(1, recheck)
end

local previousHook = ns.OnHistoryChanged
function ns.OnHistoryChanged()
  changed()
  if previousHook then previousHook() end
end
ns.OnLedgerChanged(changed)
table.insert(ns.OnGuildReady, changed)
-- Until the roster has loaded once, keep looking (that first look is the baseline).
ns.OnEvent("GUILD_ROSTER_UPDATE", function() if not ready then changed() end end)
