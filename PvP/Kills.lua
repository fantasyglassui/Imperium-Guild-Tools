--[[
  Warcrest
  Kills: tells the guild when a member kills an enemy player in PvP.

  Without the combat log the addon can't see killing blows, so a kill only
  counts when you actually attacked that enemy player in the last 10 seconds:
  you cast a harmful spell while they were your target, you were auto-attacking
  or shooting them, or your pet was attacking them. Then their death, or an
  honorable kill for them, reports the kill.

  Just being in a party (which shares honorable kills), targeting an enemy, or
  being attacked by one is not enough.
  Guildmates who kill the same player together are shown in one alert.

  Killing blow: each killer reports how long before the death they last hit
  the victim. The one who hit closest to the death gets the killing blow, the
  rest get assists. It's a best guess, since the exact blow can't be seen.

  Grey kills: a victim whose level is grey (far below the killer's, giving no
  honor) isn't reported, alerted or logged at all, whatever the game says about
  honor. When the victim's level couldn't be seen, the game's honor message
  decides. Guildmates' reports are checked against the killers' levels too,
  so grey kills from older versions are dropped, and any already in the log
  are cleared out. Officers can remove other bad kills for the whole guild.
]]

local _, ns = ...

local ENGAGE_WINDOW = 10  -- seconds since you last attacked a player for their death to count
local SAME_KILL = 15      -- seconds in which repeat reports of one victim are ignored
local MERGE_DELAY = 2.5   -- seconds to wait for guildmates' reports of the same kill

local MAX_LOG = 2000 -- enough for several months of kills, so last month is always there
local SAME_KILL_LOGGED = 30 -- seconds: reports of one victim this close together are one kill
local engaged = {}        -- victim key -> { name, time, level }
local honorSeen = {}      -- victim key -> time the game gave honor for them
local REPORT_DELAY = 1.5  -- seconds to wait for the honor message before reporting
local reported = {}       -- victim key -> time we last reported them
local lastHKs
local pending = {}        -- victim key -> alert being gathered from guildmates

local KILL_ICON = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_7:0|t"
local KILL_COLOR = "|cff40ff40"

local function key(name) return ns.Key(name) end

local function alive()
  local ok, dead = pcall(UnitIsDeadOrGhost, "player")
  return ok and not ns.Usable(dead)
end

------------------------------------------------------------------------
-- Reporting your own kills
------------------------------------------------------------------------
-- The highest level that's "grey" (gives no honor) to a player of this level.
local function greyLevel(level)
  if level <= 5 then return 0 end
  if level <= 39 then return level - 5 - math.floor(level / 10) end
  return level - 1 - math.floor(level / 5)
end

-- e: the engaged entry for the victim.
local function report(e)
  if not e or not e.name or e.name == "" then return end
  local k = key(e.name)
  if reported[k] and GetTime() - reported[k] < SAME_KILL then return end
  reported[k] = GetTime()

  local _, instanceType = IsInInstance()
  local kind = (instanceType == "pvp" or instanceType == "arena") and "kill_bg" or "kill_world"
  -- (Kills are always recorded, even with their alerts turned off: they count
  -- for the leaderboard, streaks and achievements. The alert settings only
  -- decide what's shown.)
  local zone = GetRealZoneText() or GetZoneText() or "Unknown"
  local diedAt, stamp = GetTime(), GetServerTime()
  local gap = math.max(0, diedAt - e.time) -- how long before the death you last hit them
  -- Wait a moment for the game's honor message, then report.
  C_Timer.After(REPORT_DELAY, function()
    local honor
    local mine = tonumber(ns.Usable(UnitLevel("player")))
    if e.level and e.level < 0 then
      honor = true -- "??": far above your level
    elseif e.level and mine then
      honor = e.level > greyLevel(mine) -- the level decides, even if the game gave honor
    else
      honor = honorSeen[k] and math.abs(honorSeen[k] - diedAt) <= 5 -- level unknown: go by the game
    end
    ns.lastReport = { victim = e.name, level = e.level, mine = mine, honor = honor and true or false, at = stamp }
    if not honor then -- grey kills aren't reported at all
      if ns.db.debug then
        ns.Say(("Kill check: %s (level %s) is grey to you, so it doesn't count."):format(e.name, tostring(e.level or "?")))
      end
      return
    end
    if ns.db.debug then ns.Say(("Kill check: you killed %s. Sent to the guild."):format(e.name)) end
    ns.Send("K", kind, e.name, zone, stamp, ("%.1f"):format(gap), e.level or "", "1")
  end)
end

-- Record that you attacked the enemy player on this unit.
local function markAttack(unit)
  local name, isPlayer = ns.UnitInfo(unit)
  if name and isPlayer then
    local ok, level = pcall(UnitLevel, unit)
    level = ok and tonumber(ns.Usable(level)) or nil
    local old = engaged[key(name)]
    engaged[key(name)] = { name = name, time = GetTime(), level = level or (old and old.level) }
  end
end

-- Melee auto-attack and auto-repeat (shooting, wands) switch on and off with these events.
local autoAttacking, autoShooting = false, false
ns.OnEvent("PLAYER_ENTER_COMBAT", function() autoAttacking = true end)
ns.OnEvent("PLAYER_LEAVE_COMBAT", function() autoAttacking = false end)
ns.OnEvent("START_AUTOREPEAT_SPELL", function() autoShooting = true end)
ns.OnEvent("STOP_AUTOREPEAT_SPELL", function() autoShooting = false end)

local function isHarmful(spellID)
  local check = (C_Spell and C_Spell.IsSpellHarmful) or IsHarmfulSpell
  if not check then return true end -- can't tell: casting at an enemy counts
  local ok, harmful = pcall(check, spellID)
  if not ok then return true end
  return ns.Usable(harmful) and true or false
end

-- You finished casting a harmful spell: it counts against your target.
ns.OnEvent("UNIT_SPELLCAST_SUCCEEDED", function(unit, _, spellID)
  if unit ~= "player" then return end
  if isHarmful(spellID) then markAttack("target") end
end)

-- 1. Keep track of enemy players you're attacking, and notice when they die.
local function scan()
  if not alive() then return end
  if autoAttacking or autoShooting then markAttack("target") end
  local okPet, petFighting = pcall(function() return UnitExists("pet") and UnitAffectingCombat("pet") end)
  if okPet and ns.Usable(petFighting) then markAttack("pettarget") end

  local units = { "target", "focus" }
  for _, u in ipairs(ns.NameplateUnits()) do units[#units + 1] = u end

  for _, unit in ipairs(units) do
    local name, isPlayer = ns.UnitInfo(unit)
    if name and isPlayer then
      local k = key(name)
      local ok, dead = pcall(function()
        if UnitIsFeignDeath and UnitIsFeignDeath(unit) then return false end
        return UnitIsDeadOrGhost(unit)
      end)
      dead = ok and ns.Usable(dead)
      if dead then
        local e = engaged[k]
        if e and GetTime() - e.time <= ENGAGE_WINDOW then
          engaged[k] = nil
          report(e)
        end
      end
    end
  end
end

ns.OnLoad(function() C_Timer.NewTicker(0.5, scan) end)

-- 2. Honorable kill messages name the victim. The whole party gets them, so
-- they only count for a player you attacked yourself.
local honorPatterns = {}
ns.OnLoad(function()
  for _, g in ipairs({ "COMBATLOG_HONORGAIN", "COMBATLOG_HONORGAIN_NO_RANK", "COMBATLOG_HONORGAIN_EXHAUSTION1" }) do
    local p = ns.FormatToPattern(_G[g])
    if p then honorPatterns[#honorPatterns + 1] = p end
  end
  if GetPVPLifetimeStats then
    local ok, hks = pcall(GetPVPLifetimeStats)
    if ok then lastHKs = ns.Usable(hks) end
  end
end)

ns.OnEvent("CHAT_MSG_COMBAT_HONOR_GAIN", function(text)
  text = ns.Usable(text)
  if type(text) ~= "string" then return end
  for _, p in ipairs(honorPatterns) do
    local victim = text:match(p)
    if victim then
      honorSeen[key(victim)] = GetTime()
      local e = engaged[key(victim)]
      if e and GetTime() - e.time <= ENGAGE_WINDOW then
        engaged[key(victim)] = nil
        report(e)
      end
      return
    end
  end
end)

-- 3. Your honorable kill count went up: credit the player you attacked most recently.
ns.OnEvent("PLAYER_PVP_KILLS_CHANGED", function()
  if not GetPVPLifetimeStats then return end
  local ok, hks = pcall(GetPVPLifetimeStats)
  hks = ok and ns.Usable(hks)
  if type(hks) ~= "number" then return end
  local gained = lastHKs and hks > lastHKs
  lastHKs = hks
  if not gained then return end
  C_Timer.After(0.3, function() -- let the honor message report it first
    local best
    for _, e in pairs(engaged) do
      if GetTime() - e.time <= ENGAGE_WINDOW and (not best or e.time > best.time) then best = e end
    end
    if best then
      honorSeen[key(best.name)] = GetTime() -- the honorable kill count went up
      engaged[key(best.name)] = nil
      report(best)
    end
  end)
end)

------------------------------------------------------------------------
-- Showing guildmates' kills
------------------------------------------------------------------------
local function joinNames(names)
  if #names == 1 then return names[1] end
  if #names == 2 then return names[1] .. " and " .. names[2] end
  return table.concat(names, ", ", 1, #names - 1) .. " and " .. names[#names]
end

-- Who got the killing blow: the killer who hit closest to the death.
-- Ties, and kills without timings, go to the name first in alphabetical order,
-- so every guildmate's copy credits the same person.
function ns.KillingBlow(k)
  local best, bestGap
  for _, name in ipairs(k.killers) do
    local g = (k.gaps and k.gaps[name]) or math.huge
    if not best or g < bestGap or (g == bestGap and name < best) then best, bestGap = name, g end
  end
  return best
end

function ns.Assists(k)
  local kb, out = ns.KillingBlow(k), {}
  for _, name in ipairs(k.killers) do
    if name ~= kb then out[#out + 1] = name end
  end
  return out
end

-- Guild members' levels, to check guildmates' reports for grey kills.
local levels, levelsAt = {}, nil
local greyMemo = setmetatable({}, { __mode = "k" }) -- kill -> grey or not, until levels are looked up again
local function refreshLevels()
  local now = GetTime()
  if not levelsAt or now - levelsAt > 30 or (next(levels) == nil and now - levelsAt > 2) then
    levels, levelsAt = {}, now
    greyMemo = setmetatable({}, { __mode = "k" })
    for _, m in ipairs(ns.GetRoster()) do
      local lv = tonumber(ns.Usable(m.level))
      if lv and lv > 0 then levels[key(m.name)] = lv end
    end
  end
end
local function memberLevel(name) return levels[key(name)] end

-- Killers' levels now only say what was grey for a fresh kill. Players level
-- up, and an older kill that gave honor at the time mustn't turn grey later.
local FRESH = 3 * 3600

-- A grey kill: for a fresh kill, the victim's level is grey to every killer
-- whose level is known; otherwise the report said there was no honor.
-- (Kills from older versions with no honor information still count.)
local function isGrey(k)
  local victim = tonumber(k.level)
  if victim and victim >= 0 and GetServerTime() - (tonumber(k.t) or 0) < FRESH then
    local judged = false
    for _, name in ipairs(k.killers or {}) do
      local lv = memberLevel(name)
      if lv then
        judged = true
        if victim > greyLevel(lv) then return false end
      end
    end
    if judged then return true end
  end
  return k.honor == false
end

function ns.IsGreyKill(k)
  refreshLevels()
  local grey = greyMemo[k]
  if grey == nil then
    grey = isGrey(k)
    greyMemo[k] = grey
  end
  return grey
end

-- Grey kills always are left out now. (Kept for anything that still asks.)
function ns.HonorOnly() return true end
function ns.KillHidden(k) return ns.IsGreyKill(k) end

-- titled: the killer with their title ("Lyra the Avenger killed ..."), for alerts.
function ns.DescribeKill(k, titled)
  local kb = ns.KillingBlow(k)
  if titled and ns.TitledName then kb = ns.TitledName(kb) end
  local line = ("%s killed %s in %s"):format(kb, k.victim, k.zone)
  local assists = ns.Assists(k)
  if #assists > 0 then line = line .. " (assist: " .. joinNames(assists) .. ")" end
  if k.kind == "kill_bg" then line = line .. " (battleground)" end
  if k.bounty then line = line .. " - Wanted bounty claimed!" end
  return line
end

function ns.ShowKill(k, force)
  if not force then
    local c, show = ns.cfg, ns.db.show
    if not (c.enabled and c.types[k.kind] and show[k.kind]) then return end
    if ns.KillHidden(k) then return end
  end
  local text = KILL_COLOR .. ns.DescribeKill(k, true) .. "|r"
  ns.Notify(KILL_ICON .. " " .. text, KILL_ICON .. " " .. text .. " " .. KILL_ICON, nil, force, "kill")
end

ns.KILL_ICON, ns.KILL_COLOR = KILL_ICON, KILL_COLOR

ns.OnLoad(function() ns.db.killLog = ns.db.killLog or {} end)

------------------------------------------------------------------------
-- Kills removed by officers (kept in the shared ledger, so they stay removed)
------------------------------------------------------------------------
local removed -- list of { victim key, time }

local function loadRemoved()
  removed = {}
  if not ns.LedgerEntries then return removed end
  for _, e in ipairs(ns.LedgerEntries("KD")) do
    local v, t = e.ref:match("^(.+):(%d+)$")
    if v then removed[#removed + 1] = { v, tonumber(t) } end
  end
  return removed
end

function ns.KillRemoved(k)
  local v = key(k.victim)
  for _, r in ipairs(removed or loadRemoved()) do
    if r[1] == v and math.abs(r[2] - k.t) <= SAME_KILL_LOGGED then return true end
  end
  return false
end

-- An officer removes a kill for the whole guild.
function ns.RemoveKill(k)
  if not ns.IsAddonOfficer() then ns.Say("Only officers can remove kills.") return end
  ns.LedgerAdd("KD", { ref = key(k.victim) .. ":" .. k.t })
end

ns.OnLoad(function()
  if not ns.OnLedgerChanged then return end
  local seenStamp
  ns.OnLedgerChanged(function()
    -- Only kill removals matter here; other changes (DKP, sign-ups...) leave the log alone.
    local stamp = ns.LedgerStamp("KD")
    if stamp == seenStamp then return end
    seenStamp = stamp
    loadRemoved()
    local log = ns.db.killLog
    for i = #log, 1, -1 do
      if ns.KillRemoved(log[i]) then table.remove(log, i) end
    end
    if ns.OnHistoryChanged then ns.OnHistoryChanged() end
  end)
end)

-- Combine another report of the same kill into an entry: every killer,
-- the closest hit timing for each, the highest level seen, and honor if any
-- report had it.
local function combine(into, k)
  local changed = false
  into.gaps = into.gaps or {}
  for _, name in ipairs(k.killers) do
    local known = false
    for _, have in ipairs(into.killers) do
      if have == name then known = true break end
    end
    if not known then table.insert(into.killers, name); changed = true end
    local g = k.gaps and k.gaps[name]
    if g and (not into.gaps[name] or g < into.gaps[name]) then into.gaps[name] = g end
  end
  if k.level and (not into.level or k.level > into.level) then into.level = k.level end
  if k.honor == true and into.honor ~= true then into.honor = true; changed = true end
  if into.honor == nil and k.honor == false then into.honor = false end
  return changed
end

-- Adds a kill to the log, or adds killers to the same kill already there.
-- Returns true if it was a new kill.
function ns.MergeKill(k)
  if ns.IsWiped and ns.IsWiped("kills", k.t) then return false end
  if ns.KillRemoved(k) then return false end
  if ns.IsGreyKill(k) then return false end
  local victim = key(k.victim)
  for _, old in ipairs(ns.db.killLog) do
    if key(old.victim) == victim and math.abs(old.t - k.t) <= SAME_KILL_LOGGED then
      combine(old, k)
      return false
    end
  end
  ns.InsertSorted(ns.db.killLog, k, MAX_LOG)
  if ns.OnHistoryChanged then ns.OnHistoryChanged() end
  return true
end

-- filter: "all", "kill_world" or "kill_bg". fromT/toT: a time range, or nil for all time.
function ns.QueryKills(filter, fromT, toT)
  local out = {}
  for _, k in ipairs(ns.db.killLog) do
    if (not fromT or k.t >= fromT) and (not toT or k.t < toT)
        and (filter == "all" or k.kind == filter) and not ns.KillHidden(k) then
      out[#out + 1] = k
    end
  end
  return out
end

------------------------------------------------------------------------
-- Months (Top Head Hunters starts fresh on the 1st of each month)
------------------------------------------------------------------------
-- Months follow the realm's clock, so the whole guild resets at the same
-- moment wherever they live.
local MONTH_NAMES = { "January", "February", "March", "April", "May", "June", "July",
  "August", "September", "October", "November", "December" }

local function daysIn(year, month)
  if month == 2 then
    return ((year % 4 == 0 and year % 100 ~= 0) or year % 400 == 0) and 29 or 28
  end
  return (month == 4 or month == 6 or month == 9 or month == 11) and 30 or 31
end

-- The realm's date and time now: year, month, day, hour, minute.
local function realmNow()
  if C_DateAndTime and C_DateAndTime.GetCurrentCalendarTime then
    local ok, d = pcall(C_DateAndTime.GetCurrentCalendarTime)
    if ok and d and d.year then return d.year, d.month, d.monthDay, d.hour, d.minute end
  end
  local d = date("*t")
  return d.year, d.month, d.day, d.hour, d.min
end

-- A month as a time range. offset 0 = this month, -1 = last month.
-- Returns its start, its end, its name and a key ("2026-11").
function ns.MonthRange(offset)
  local now = GetServerTime()
  local year, month, day, hour, minute = realmNow()
  local thisStart = now - ((day - 1) * 86400 + hour * 3600 + minute * 60 + now % 60)
  local fromT, y, m = thisStart, year, month
  for _ = 1, -(offset or 0) do
    m = m - 1
    if m == 0 then m, y = 12, y - 1 end
    fromT = fromT - daysIn(y, m) * 86400
  end
  local toT = fromT + daysIn(y, m) * 86400
  return fromT, toT, MONTH_NAMES[m], ("%d-%02d"):format(y, m)
end

-- On reset day (the 1st), the guild hears last month's Top Head Hunters.
-- Anyone who wasn't online that day hears it at their first login that week.
local MEDALS = { "|cffd4af37", "|cffc0c0c0", "|cffcd7f32" } -- gold, silver, bronze
local ANNOUNCE_DAYS = 7

local function announceChampion()
  if not ns.db then return end
  local fromT, toT, name, monthKey = ns.MonthRange(-1)
  if ns.db.championMonth == monthKey then return end
  ns.db.championMonth = monthKey
  if GetServerTime() - toT > ANNOUNCE_DAYS * 86400 then return end -- old news
  local top = ns.KillStats(ns.QueryKills("all", fromT, toT), 3)
  if not top[1] or top[1].count == 0 then return end
  local places = {}
  for i, e in ipairs(top) do
    if e.count > 0 then
      places[#places + 1] = ("%s%d. %s|r (%d)"):format(MEDALS[i], i, e.name, e.count)
    end
  end
  local heading = ("The month has reset! Top Head Hunters of %s:"):format(name)
  ns.Notify(KILL_ICON .. " |cffd4af37" .. heading .. "|r  " .. table.concat(places, "   "),
    ("|cffd4af37%s champion: %s with %d killing blow%s!|r"):format(name, top[1].name, top[1].count,
      top[1].count == 1 and "" or "s"), nil, nil, "champion")
end
ns.AnnounceChampion = announceChampion

table.insert(ns.OnGuildReady, function()
  -- Give the kill log time to catch up with guildmates first.
  C_Timer.After(90, announceChampion)
  C_Timer.NewTicker(5 * 60, announceChampion) -- online when the month turns over
end)

-- Top Head Hunters: ranked by killing blows, then assists.
function ns.KillStats(kills, n)
  local blows, assists = {}, {}
  for _, k in ipairs(kills) do
    local kb = ns.KillingBlow(k)
    for _, name in ipairs(k.killers) do
      if name == kb then blows[name] = (blows[name] or 0) + 1
      else assists[name] = (assists[name] or 0) + 1 end
    end
  end
  local top, seen = {}, {}
  for name in pairs(blows) do seen[name] = true end
  for name in pairs(assists) do seen[name] = true end
  for name in pairs(seen) do
    top[#top + 1] = { name = name, count = blows[name] or 0, assists = assists[name] or 0 }
  end
  table.sort(top, function(a, b)
    if a.count ~= b.count then return a.count > b.count end
    if a.assists ~= b.assists then return a.assists > b.assists end
    return a.name < b.name
  end)
  while #top > n do table.remove(top) end
  return top
end

function ns.ClearKillLog() ns.WipeLog("kills") end

ns.OnMessage("K", function(parts, sender)
  local kind, victim, zone, stamp = parts[2], parts[3], parts[4], tonumber(parts[5])
  if (kind ~= "kill_world" and kind ~= "kill_bg") or not victim or victim == "" then return end
  local gap, level = tonumber(parts[6]), tonumber(parts[7])
  local honor -- nil from older versions, which don't say
  if parts[8] == "1" then honor = true elseif parts[8] == "0" then honor = false end
  local k = key(victim)
  local who = Ambiguate(sender, "short")
  if ns.IsMe(sender) then ns.lastOwnKillHeard = { victim = victim, at = GetServerTime() } end
  local thisReport = { killers = { who }, gaps = { [who] = gap }, level = level, honor = honor }
  local p = pending[k]
  if p then
    combine(p, thisReport)
    return
  end
  pending[k] = { killers = { who }, gaps = { [who] = gap }, level = level, honor = honor,
    victim = Ambiguate(victim, "short"), kind = kind, zone = zone or "Unknown", t = stamp or time() }
  C_Timer.After(MERGE_DELAY, function()
    local done = pending[k]
    pending[k] = nil
    -- Was the victim on the Wanted list? (Checked before the kill is logged,
    -- since logging it takes them off.)
    local wasWanted = done and ns.WantedInfo and ns.WantedInfo(done.victim) ~= nil
    if done and ns.MergeKill(done) then
      if ns.ClaimBounty then ns.ClaimBounty(done.victim, done.t) end
      done.bounty = wasWanted and ns.db.wantedRemoveOnKill or nil
      ns.ShowKill(done)
      if ns.OnLiveKill then ns.OnLiveKill(done) end -- streaks and revenge
      if ns.RefreshPanel then ns.RefreshPanel() end
    end
  end)
end)


------------------------------------------------------------------------
-- Keeping everyone's kill log the same
------------------------------------------------------------------------
-- Every 15 minutes (and shortly after login) your addon sends a short
-- fingerprint of your kill log. A guildmate whose log is different answers
-- with a summary per day; for each day that differs, both of you send each
-- other that day's kills. Kills are matched exactly (victim and time), and
-- the killers on matching kills are combined, so after an exchange both logs
-- are identical. Over a few rounds the whole guild ends up with the same log.

local SYNC_EVERY = 15 * 60
local CLAIM_WINDOW = 30
local claimedBy = {}     -- requester -> time someone said they'd answer
local incoming = {}      -- sender -> their per-day summary
local refreshPending = false

local function dayOf(t) return math.floor(t / 86400) end

local function hash(str)
  local h = 0
  for i = 1, #str do h = (h * 31 + str:byte(i)) % 2147483647 end
  return h
end

-- A kill's identity plus its killers, so differing killer lists also count as a difference.
local function fingerprintOf(k)
  local names = {}
  for i, n in ipairs(k.killers) do names[i] = n end
  table.sort(names)
  return hash(key(k.victim) .. ":" .. k.t .. ":" .. table.concat(names, ","))
end

-- day -> { count, sum } and the whole log's count and sum.
local function digest()
  local days, total, sum = {}, 0, 0
  for _, k in ipairs(ns.db.killLog) do
    local d = dayOf(k.t)
    local e = days[d] or { 0, 0 }
    e[1] = e[1] + 1
    e[2] = (e[2] + fingerprintOf(k)) % 2147483647
    days[d] = e
    total = total + 1
    sum = (sum + fingerprintOf(k)) % 2147483647
  end
  return days, total, sum
end

local function refreshSoon()
  if refreshPending then return end
  refreshPending = true
  C_Timer.After(1, function()
    refreshPending = false
    if ns.OnHistoryChanged then ns.OnHistoryChanged() end
    if ns.RefreshPanel then ns.RefreshPanel() end
  end)
end

-- Merge a kill from another guildmate's log: exact match first, then the
-- same victim within a few seconds. Matching kills keep the earlier time and
-- every killer, so both sides end up identical.
local function mergeSynced(k)
  if ns.IsWiped and ns.IsWiped("kills", k.t) then return end
  if ns.KillRemoved(k) then return end
  if ns.IsGreyKill(k) then return end
  local victim = key(k.victim)
  local match
  for _, old in ipairs(ns.db.killLog) do
    if key(old.victim) == victim and old.t == k.t then match = old break end
  end
  if not match then
    for _, old in ipairs(ns.db.killLog) do
      if key(old.victim) == victim and math.abs(old.t - k.t) <= SAME_KILL_LOGGED then match = old break end
    end
  end
  if not match then
    ns.InsertSorted(ns.db.killLog, k, MAX_LOG)
    if ns.ClaimBounty then ns.ClaimBounty(k.victim, k.t) end
    refreshSoon()
    return
  end
  local changed = combine(match, k)
  if k.t < match.t then
    match.t = k.t
    table.sort(ns.db.killLog, function(a, b) return a.t > b.t end)
    changed = true
  end
  if changed then refreshSoon() end
end

local function sendDay(target, day)
  for _, k in ipairs(ns.db.killLog) do
    if dayOf(k.t) == day then
      local gaps = {}
      for i, name in ipairs(k.killers) do
        local g = k.gaps and k.gaps[name]
        gaps[i] = g and ("%.1f"):format(g) or "-"
      end
      local honor = (k.honor == true and "1") or (k.honor == false and "0") or ""
      ns.QueueTo(target, "KX", k.t, k.kind, k.victim, k.zone, table.concat(k.killers, ","),
        table.concat(gaps, ","), k.level or "", honor)
    end
  end
end

function ns.SyncKills()
  if not IsInGuild() then return end
  local _, total, sum = digest()
  local wipe = ns.db.wipes and ns.db.wipes.kills or 0
  ns.Send("KQ", total, sum, wipe)
end

table.insert(ns.OnGuildReady, function()
  C_Timer.After(15 + math.random() * 30, ns.SyncKills)
  C_Timer.NewTicker(SYNC_EVERY + math.random() * 60, ns.SyncKills)
end)

-- A guildmate sent their fingerprint. If ours differs, offer a per-day summary.
ns.OnMessage("KQ", function(p, sender)
  if ns.IsMe(sender) then return end
  local theirTotal, theirSum, theirWipe = tonumber(p[2]) or 0, tonumber(p[3]) or 0, tonumber(p[4]) or 0
  local _, total, sum = digest()
  local myWipe = ns.db.wipes and ns.db.wipes.kills or 0
  local olderWipe = myWipe > theirWipe and ns.IsAddonOfficer()
  if total == theirTotal and sum == theirSum and not olderWipe then return end
  local who = ns.fullName(sender)
  C_Timer.After(0.5 + math.random() * 3, function()
    local c = claimedBy[who]
    if c and GetTime() - c < CLAIM_WINDOW then return end
    ns.Send("KS", who)
    if olderWipe then ns.QueueTo(sender, "HW", "kills", myWipe) end
    local chunk, len = {}, 0
    for day, e in pairs((digest())) do
      local item = day .. ":" .. e[1] .. ":" .. e[2]
      if len + #item > 200 then
        ns.QueueTo(sender, "KG", table.concat(chunk, ","))
        chunk, len = {}, 0
      end
      chunk[#chunk + 1] = item
      len = len + #item + 1
    end
    if #chunk > 0 then ns.QueueTo(sender, "KG", table.concat(chunk, ",")) end
    ns.QueueTo(sender, "KGE")
  end)
end)

ns.OnMessage("KS", function(p)
  if p[2] then claimedBy[ns.fullName(p[2])] = GetTime() end
end)

ns.OnMessage("KG", function(p, sender)
  local d = incoming[sender] or {}
  incoming[sender] = d
  for day, count, sum in (p[2] or ""):gmatch("(%d+):(%d+):(%d+)") do
    d[tonumber(day)] = { tonumber(count), tonumber(sum) }
  end
end)

-- Their summary is complete: swap every day that differs, both ways.
ns.OnMessage("KGE", function(_, sender)
  local theirs = incoming[sender] or {}
  incoming[sender] = nil
  local mine = digest()
  local differ = {}
  for day, e in pairs(theirs) do
    local m = mine[day]
    if not m or m[1] ~= e[1] or m[2] ~= e[2] then differ[day] = true end
  end
  for day in pairs(mine) do
    if not theirs[day] then differ[day] = true end
  end
  local list = {}
  for day in pairs(differ) do list[#list + 1] = day end
  for i = 1, #list, 25 do
    ns.QueueTo(sender, "KR", table.concat(list, ",", i, math.min(i + 24, #list)))
  end
  for _, day in ipairs(list) do sendDay(sender, day) end
end)

-- They asked for the days that differ.
ns.OnMessage("KR", function(p, sender)
  for d in (p[2] or ""):gmatch("%d+") do sendDay(sender, tonumber(d)) end
end)

-- A kill from a guildmate's log.
ns.OnMessage("KX", function(p)
  local t, kind, victim = tonumber(p[2]), p[3], p[4]
  if not t or (kind ~= "kill_world" and kind ~= "kill_bg") or not victim or victim == "" then return end
  local killers, gaps = {}, {}
  for name in (p[6] or ""):gmatch("[^,]+") do killers[#killers + 1] = name end
  if #killers == 0 then return end
  local i = 0
  for g in (p[7] or ""):gmatch("[^,]+") do
    i = i + 1
    if killers[i] and tonumber(g) then gaps[killers[i]] = tonumber(g) end
  end
  local honor
  if p[9] == "1" then honor = true elseif p[9] == "0" then honor = false end
  mergeSynced({ t = t, kind = kind, victim = victim, zone = p[5] or "Unknown", killers = killers,
    gaps = gaps, level = tonumber(p[8]), honor = honor })
end)
