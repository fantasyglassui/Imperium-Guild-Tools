--[[
  Warcrest
  Raids: scheduled raids and sign-ups, the current raid group, reminders,
  and raid sessions that award attendance DKP.

  A raid session is started by an officer while in the raid. Everyone in the
  raid who is in the guild gets the on-time bonus right away, then the hourly
  amount every hour until the session ends. The hourly awards come from the
  officer who started the session, so they need to stay in the raid.
]]

local _, ns = ...

local SHOW_PAST = 6 * 60 * 60       -- keep showing a raid for 6 hours after it starts
local SESSION_MAX = 12 * 60 * 60    -- a session left running is treated as over after 12 hours
local REMIND_BEFORE = 15 * 60
local STATUSES = { accept = true, tentative = true, decline = true }
local ROLES = { tank = true, healer = true, dps = true }

ns.OnLoad(function() ns.db.reminded = ns.db.reminded or {} end)

------------------------------------------------------------------------
-- Scheduled raids and sign-ups
------------------------------------------------------------------------
local function cancelled()
  local set = {}
  for _, e in ipairs(ns.LedgerEntries("EX")) do set[e.ref] = true end
  return set
end

-- Upcoming raids (and ones that started in the last few hours), soonest first.
function ns.RaidEvents()
  local gone, now, out = cancelled(), time(), {}
  for _, e in ipairs(ns.LedgerEntries("EV")) do
    if not gone[e.id] and e.start >= now - SHOW_PAST then out[#out + 1] = e end
  end
  table.sort(out, function(a, b) return a.start < b.start end)
  return out
end

-- Every raid that wasn't cancelled, past ones too (as far back as the
-- record goes), for the calendar.
function ns.AllRaidEvents()
  local gone, out = cancelled(), {}
  for _, e in ipairs(ns.LedgerEntries("EV")) do
    if not gone[e.id] then out[#out + 1] = e end
  end
  table.sort(out, function(a, b) return a.start < b.start end)
  return out
end

function ns.RaidEvent(id)
  return id and ns.db.ledger[id]
end

-- Each member's latest sign-up for a raid.
function ns.Signups(eventId)
  local byKey = {}
  for _, e in ipairs(ns.LedgerEntries("SU")) do
    if e.ref == eventId and STATUSES[e.status] then
      byKey[ns.Key(e.a)] = { name = e.a, status = e.status, role = ROLES[e.role] and e.role or "dps", t = e.t }
    end
  end
  local list = {}
  for _, s in pairs(byKey) do list[#list + 1] = s end
  local order = { accept = 1, tentative = 2, decline = 3 }
  local roleOrder = { tank = 1, healer = 2, dps = 3 }
  table.sort(list, function(a, b)
    if a.status ~= b.status then return order[a.status] < order[b.status] end
    if a.role ~= b.role then return roleOrder[a.role] < roleOrder[b.role] end
    return a.name < b.name
  end)
  return list, byKey
end

function ns.SignupCounts(eventId)
  local counts = { accept = 0, tentative = 0, decline = 0, tank = 0, healer = 0, dps = 0 }
  for _, s in ipairs((ns.Signups(eventId))) do
    counts[s.status] = counts[s.status] + 1
    if s.status == "accept" then counts[s.role] = counts[s.role] + 1 end
  end
  return counts
end

------------------------------------------------------------------------
-- Raid makeup: who's coming by role and class, and what's missing
------------------------------------------------------------------------
local ROLE_WORDS = { tank = { "tank", "tanks" }, healer = { "healer", "healers" } }
local CLASS_CHECK_FROM = 10 -- only point out missing classes once this many have accepted

local function plural(n, role) return ROLE_WORDS[role][n == 1 and 1 or 2] end

local function joinOr(list)
  if #list <= 1 then return list[1] or "" end
  return table.concat(list, ", ", 1, #list - 1) .. " or " .. list[#list]
end

-- How many tanks and healers a raid of this size wants.
function ns.RolesWanted(players)
  return players >= 10 and 2 or 1, math.max(1, math.ceil(players / 5))
end

-- Accepted and tentative sign-ups by role and class, plus the gaps:
-- { accept, tentative, roles = {tank, healer, dps}, maybe = {...},
--   classes = { {classFile, name, count}, ... }, classOf = {key -> classFile}, warnings = { text, ... } }
function ns.RaidMakeup(eventId)
  local classOf, classNames, inGuild = {}, {}, {}
  local maxLevel = (GetMaxPlayerLevel and GetMaxPlayerLevel()) or 0
  for _, m in ipairs(ns.GetRoster()) do
    if m.classFile then
      classOf[ns.Key(m.name)] = m.classFile
      classNames[m.classFile] = (m.className ~= "" and m.className) or m.classFile
      if m.level >= maxLevel then inGuild[m.classFile] = true end
    end
  end

  local mk = { accept = 0, tentative = 0, roles = { tank = 0, healer = 0, dps = 0 },
    maybe = { tank = 0, healer = 0, dps = 0 }, classes = {}, classOf = classOf, warnings = {} }
  local byClass = {}
  for _, su in ipairs((ns.Signups(eventId))) do
    if su.status == "accept" then
      mk.accept = mk.accept + 1
      mk.roles[su.role] = mk.roles[su.role] + 1
      local cls = classOf[ns.Key(su.name)]
      if cls then byClass[cls] = (byClass[cls] or 0) + 1 end
    elseif su.status == "tentative" then
      mk.tentative = mk.tentative + 1
      mk.maybe[su.role] = mk.maybe[su.role] + 1
    end
  end
  for cls, n in pairs(byClass) do
    mk.classes[#mk.classes + 1] = { classFile = cls, name = classNames[cls] or cls, count = n }
  end
  table.sort(mk.classes, function(a, b)
    if a.count ~= b.count then return a.count > b.count end
    return a.name < b.name
  end)

  if mk.accept == 0 then return mk end
  local wantTanks, wantHealers = ns.RolesWanted(mk.accept)
  for _, need in ipairs({ { "tank", wantTanks }, { "healer", wantHealers } }) do
    local role, want = need[1], need[2]
    local have = mk.roles[role]
    if have < want then
      local text = have == 0 and ("No " .. plural(2, role)) or ("Only " .. have .. " " .. plural(have, role))
      text = text .. (" (%d wanted for %d players)"):format(want, mk.accept)
      if mk.maybe[role] > 0 then text = text .. (", %d tentative"):format(mk.maybe[role]) end
      mk.warnings[#mk.warnings + 1] = text
    end
  end
  if mk.accept >= CLASS_CHECK_FROM then
    local missing = {}
    for cls in pairs(inGuild) do
      if not byClass[cls] then missing[#missing + 1] = classNames[cls] end
    end
    table.sort(missing)
    if #missing > 0 then mk.warnings[#mk.warnings + 1] = "No " .. joinOr(missing) .. " signed up" end
  end
  return mk
end

function ns.MySignup(eventId)
  local _, byKey = ns.Signups(eventId)
  return byKey[ns.Key(UnitName("player"))]
end

function ns.CreateRaid(title, start, notes)
  if title == "" then ns.Say("Give the raid a name.") return end
  if start < time() - 60 then ns.Say("That date and time has already passed.") return end
  return ns.LedgerAdd("EV", { title = title, start = start, notes = notes or "" })
end

function ns.CancelRaid(id)
  return ns.LedgerAdd("EX", { ref = id })
end

function ns.SignUp(eventId, status, role)
  return ns.LedgerAdd("SU", { ref = eventId, status = status, role = role })
end

------------------------------------------------------------------------
-- The current raid group
------------------------------------------------------------------------
-- Everyone in your raid: name, class, role, online, and whether they're in the guild.
function ns.CurrentRaidMembers()
  local out = {}
  if not IsInRaid() then return out end
  for i = 1, GetNumGroupMembers() do
    local name, _, _, level, className, classFile, _, online, _, _, _, combatRole = GetRaidRosterInfo(i)
    if name then
      local role = (combatRole == "TANK" and "tank") or (combatRole == "HEALER" and "healer")
        or (combatRole == "DAMAGER" and "dps") or nil
      out[#out + 1] = { name = name, level = level, className = className, classFile = classFile,
        online = online, role = role, inGuild = ns.RankOf(name) ~= nil }
    end
  end
  return out
end

-- Guild members in your raid who are online: the ones who earn attendance DKP.
function ns.RaidAttendees()
  local names = {}
  for _, m in ipairs(ns.CurrentRaidMembers()) do
    if m.inGuild and m.online then names[#names + 1] = Ambiguate(m.name, "none") end
  end
  return names
end

------------------------------------------------------------------------
-- Raid sessions (attendance DKP), standby, attendance and no-shows
------------------------------------------------------------------------
local ATTENDANCE_DAYS = 30
local NAMES_CHARS = 170

-- The session in progress for the guild, if any.
function ns.ActiveSession()
  local ended = {}
  for _, e in ipairs(ns.LedgerEntries("RE")) do ended[e.ref] = true end
  local starts = ns.LedgerEntries("RS")
  for i = #starts, 1, -1 do
    local s = starts[i]
    if not ended[s.id] and GetServerTime() - s.t < SESSION_MAX then return s end
  end
end

-- Write names into the ledger in pieces that fit one message each.
local function chunked(names, write)
  local chunk, len = {}, 0
  local function flush()
    if #chunk > 0 then write(table.concat(chunk, ",")) end
    chunk, len = {}, 0
  end
  for _, name in ipairs(names) do
    if len + #name > NAMES_CHARS then flush() end
    chunk[#chunk + 1] = name
    len = len + #name + 1
  end
  flush()
end

local function recordAttendance(sessionId, names, how)
  if #names == 0 then return end
  chunked(names, function(list) ns.LedgerAdd("AT", { ref = sessionId, names = list, how = how }) end)
end

-- Standby for a session: name key -> name.
function ns.Standby(sessionId)
  local set = {}
  if not sessionId then return set end
  for _, e in ipairs(ns.LedgerEntries("SB")) do
    if e.ref == sessionId then
      for name in e.names:gmatch("[^,]+") do
        if e.state == "on" then set[ns.Key(name)] = name else set[ns.Key(name)] = nil end
      end
    end
  end
  return set
end

function ns.StandbyList(sessionId)
  local list = {}
  for _, name in pairs(ns.Standby(sessionId)) do list[#list + 1] = name end
  table.sort(list)
  return list
end

-- Officers put a guild member on standby: they earn the same DKP as the raid.
function ns.AddStandby(name)
  local s = ns.ActiveSession()
  if not s then ns.Say("Start the raid first, then add standby.") return end
  name = strtrim(name or "")
  if name == "" then return end
  if ns.RankOf(name) == nil then ns.Say(name .. " isn't in the guild.") return end
  name = Ambiguate(name, "none")
  if ns.Standby(s.id)[ns.Key(name)] then return end
  ns.LedgerAdd("SB", { ref = s.id, names = name, state = "on" })
  recordAttendance(s.id, { name }, "standby")
  if s.onTime > 0 then ns.AwardDKP({ name }, s.onTime, "On time (standby): " .. s.title) end
  ns.Say(name .. " is on standby and gets the raid's DKP.")
end

function ns.RemoveStandby(name)
  local s = ns.ActiveSession()
  if not s then return end
  name = Ambiguate(strtrim(name or ""), "none")
  if name == "" or not ns.Standby(s.id)[ns.Key(name)] then return end
  ns.LedgerAdd("SB", { ref = s.id, names = name, state = "off" })
end

-- Everyone who earns DKP right now: guild members in the raid, plus standby.
local function earners(sessionId)
  local names, seen = {}, {}
  for _, n in ipairs(ns.RaidAttendees()) do
    names[#names + 1] = n
    seen[ns.Key(n)] = true
  end
  local standby = {}
  for k, n in pairs(ns.Standby(sessionId)) do
    if not seen[k] then names[#names + 1] = n; standby[#standby + 1] = n end
  end
  return names, standby
end

function ns.StartRaidSession(eventId, title, onTime, hourly, boss)
  if not ns.IsAddonOfficer() then ns.Say("Only officers can start a raid.") return end
  if not IsInRaid() then ns.Say("You need to be in a raid group to start a raid.") return end
  if ns.ActiveSession() then ns.Say("A raid is already in progress. End it first.") return end
  onTime, hourly, boss = tonumber(onTime) or 0, tonumber(hourly) or 0, tonumber(boss) or 0
  if not ns.UsesDKP() then onTime, hourly, boss = 0, 0, 0 end -- the guild doesn't use DKP
  local e = ns.LedgerAdd("RS", { ref = eventId or "", onTime = onTime, hourly = hourly, title = title, boss = boss })
  if not e then return end
  ns.db.session = { id = e.id, title = title, hourly = hourly, boss = boss, bosses = {}, hour = 0,
    nextTick = GetServerTime() + 3600 }
  local names = ns.RaidAttendees()
  recordAttendance(e.id, names, "raid")
  if onTime > 0 and #names > 0 then ns.AwardDKP(names, onTime, "On time: " .. title) end
  if onTime + hourly + boss > 0 then
    ns.Say(("Raid started: %s. %d members got %d DKP for being on time; %d DKP every hour%s from now.")
      :format(title, #names, onTime, hourly, boss > 0 and (" and " .. boss .. " per boss kill") or ""))
  else
    ns.Say(("Raid started: %s. Attendance recorded for %d members."):format(title, #names))
  end
  -- Let guildmates who signed up but aren't here know the raid has started.
  if eventId and eventId ~= "" then
    local here = {}
    for _, n in ipairs(names) do here[ns.Key(n)] = true end
    for _, su in ipairs((ns.Signups(eventId))) do
      if su.status ~= "decline" and not here[ns.Key(su.name)] then
        ns.SendTo(su.name, "RN", title)
      end
    end
  end
end

-- You signed up and the raid started without you.
ns.OnMessage("RN", function(p, sender)
  if not ns.IsOfficerName(sender) then return end
  ns.Notify(("|cff66ccffThe raid has started: %s. You signed up - log in or ask %s for an invite!|r")
    :format(p[2] or "raid", Ambiguate(sender, "short")), nil, nil, true, "raid", "Raid started")
end)

function ns.EndRaidSession()
  local s = ns.ActiveSession()
  if s then ns.LedgerAdd("RE", { ref = s.id }) end
  ns.db.session = nil
  ns.Say(ns.UsesDKP() and "Raid ended. No more hourly DKP will be awarded." or "Raid ended.")
end

-- Hourly awards, run by the officer who started the session.
local function sessionTick()
  local s = ns.db and ns.db.session
  if not s then return end
  local active = ns.ActiveSession()
  if not active or active.id ~= s.id then ns.db.session = nil return end
  if GetServerTime() < s.nextTick then return end
  s.hour = s.hour + 1
  s.nextTick = s.nextTick + 3600
  local names, standby = earners(s.id)
  recordAttendance(s.id, ns.RaidAttendees(), "raid")
  if s.hourly > 0 and #names > 0 then
    ns.AwardDKP(names, s.hourly, ("Hour %d: %s"):format(s.hour, s.title))
    ns.Say(("%d members got %d DKP for hour %d of %s%s."):format(#names, s.hourly, s.hour, s.title,
      #standby > 0 and (" (" .. #standby .. " on standby)") or ""))
  end
end

-- A boss died: the officer running the raid awards the boss DKP.
ns.OnEvent("ENCOUNTER_END", function(encounterID, encounterName, _, _, success)
  local s = ns.db and ns.db.session
  if not (s and (s.boss or 0) > 0) then return end
  if ns.Usable(success) ~= 1 and ns.Usable(success) ~= true then return end
  local active = ns.ActiveSession()
  if not active or active.id ~= s.id then return end
  local id = tostring(ns.Usable(encounterID) or encounterName or "?")
  s.bosses = s.bosses or {}
  if s.bosses[id] then return end -- each boss only once per raid night
  s.bosses[id] = true
  local name = ns.Usable(encounterName) or "a boss"
  local names = earners(s.id)
  if #names > 0 then
    ns.AwardDKP(names, s.boss, "Boss: " .. name)
    ns.Say(("%d members got %d DKP for killing %s."):format(#names, s.boss, name))
  end
end)

-- Who attended a session: name key -> true. Sessions from before attendance
-- was recorded fall back to who got the on-time DKP.
local function attendedSet(session)
  local set = {}
  for _, e in ipairs(ns.LedgerEntries("AT")) do
    if e.ref == session.id then
      for name in e.names:gmatch("[^,]+") do set[ns.Key(name)] = true end
    end
  end
  if next(set) == nil then
    for _, e in ipairs(ns.LedgerEntries("DK")) do
      if math.abs(e.t - session.t) <= 120 and e.reason:find("^On time") then
        for name in e.names:gmatch("[^,]+") do set[ns.Key(name)] = true end
      end
    end
  end
  return set
end

ns.AttendedSet = attendedSet

-- Attendance over the last 30 days for everyone, worked out once per change.
local attendanceCache
ns.OnLedgerChanged(function() attendanceCache = nil end)

local function buildAttendance()
  local since = GetServerTime() - ATTENDANCE_DAYS * 86400
  local sessions = {}
  for _, s in ipairs(ns.LedgerEntries("RS")) do
    if s.t >= since then sessions[#sessions + 1] = s end
  end
  local byKey = {}
  local function get(k)
    byKey[k] = byKey[k] or { attended = 0, noShows = {} }
    return byKey[k]
  end
  for _, s in ipairs(sessions) do
    local set, mains = attendedSet(s), {}
    for k in pairs(set) do mains[ns.Key(ns.MainOf(k))] = true end -- an alt attending counts for its main
    for k in pairs(mains) do get(k).attended = get(k).attended + 1 end
    -- No-shows: accepted the raid this session was for, but never attended.
    if s.ref ~= "" then
      local ev = ns.RaidEvent(s.ref)
      for _, su in ipairs((ns.Signups(s.ref))) do
        local k = ns.Key(ns.MainOf(su.name))
        if su.status == "accept" and not set[ns.Key(su.name)] and not mains[k] then
          table.insert(get(k).noShows, ev and ev.title or s.title)
        end
      end
    end
  end
  attendanceCache = { total = #sessions, byKey = byKey }
  return attendanceCache
end

-- Every raid night each member attended, all time (as far back as the record
-- goes): main's name key -> sorted list of session start times.
local nightsCache
ns.OnLedgerChanged(function() nightsCache = nil end)
function ns.RaidNightsAttended(name)
  if not nightsCache then
    nightsCache = {}
    for _, s in ipairs(ns.LedgerEntries("RS")) do
      local mains = {}
      for k in pairs(attendedSet(s)) do mains[ns.Key(ns.MainOf(k))] = true end
      for k in pairs(mains) do
        nightsCache[k] = nightsCache[k] or {}
        table.insert(nightsCache[k], s.t)
      end
    end
  end
  return nightsCache[ns.Key(ns.MainOf(name))] or {}
end

-- attended, total sessions, and the raids they accepted but didn't show for.
function ns.Attendance(name)
  local a = attendanceCache or buildAttendance()
  local m = a.byKey[ns.Key(ns.MainOf and ns.MainOf(name) or name)]
  return m and m.attended or 0, a.total, m and m.noShows or {}
end

-- The raid night (session) held for a scheduled raid, if any.
function ns.SessionForEvent(eventId)
  local starts = ns.LedgerEntries("RS")
  for i = #starts, 1, -1 do
    if starts[i].ref == eventId then return starts[i] end
  end
end

-- Accepted sign-ups who didn't attend the raid night held for this raid.
function ns.NoShows(eventId)
  local s = ns.SessionForEvent(eventId)
  if not s then return nil end
  local set, out = attendedSet(s), {}
  for _, su in ipairs((ns.Signups(eventId))) do
    if su.status == "accept" and not set[ns.Key(su.name)] then out[#out + 1] = Ambiguate(su.name, "short") end
  end
  return out, set
end

------------------------------------------------------------------------
-- Inviting everyone who signed up
------------------------------------------------------------------------
local inviteQueue = {}

local function invite(name)
  local f = (C_PartyInfo and C_PartyInfo.InviteUnit) or InviteUnit
  if f then pcall(f, name) end
end

local function inviteMore()
  if #inviteQueue == 0 then return end
  local room = IsInRaid() and 40 or 5
  local size = math.max(1, GetNumGroupMembers())
  -- A party holds 5: invite 4, then turn it into a raid once someone joins.
  local n = IsInRaid() and #inviteQueue or math.min(#inviteQueue, room - size)
  for _ = 1, n do invite(table.remove(inviteQueue, 1)) end
end

ns.OnEvent("GROUP_ROSTER_UPDATE", function()
  if #inviteQueue == 0 then return end
  if IsInGroup() and not IsInRaid() and UnitIsGroupLeader("player") then
    local f = (C_PartyInfo and C_PartyInfo.ConvertToRaid) or ConvertToRaid
    if f then pcall(f) end
  end
  if IsInRaid() then inviteMore() end
end)

-- Invite these guild members: the online ones not already in your group.
-- `what` says who they are, for the message ("who signed up").
function ns.InviteNames(names, what)
  local inGroup = {}
  for _, m in ipairs(ns.CurrentRaidMembers()) do inGroup[ns.Key(m.name)] = true end
  if IsInGroup() and not IsInRaid() then
    for i = 1, GetNumGroupMembers() - 1 do
      local n = UnitName("party" .. i)
      if n then inGroup[ns.Key(n)] = true end
    end
  end
  local online = {}
  for _, m in ipairs(ns.GetRoster()) do
    if m.online then online[ns.Key(m.name)] = m.name end
  end
  wipe(inviteQueue)
  local offline = 0
  for _, name in ipairs(names) do
    local k = ns.Key(name)
    if not ns.IsMe(name) and not inGroup[k] then
      if online[k] then inviteQueue[#inviteQueue + 1] = Ambiguate(online[k], "none") else offline = offline + 1 end
    end
  end
  if #inviteQueue == 0 then
    ns.Say("Everyone " .. what .. " who is online is already in your group.")
    return 0
  end
  ns.Say(("Inviting %d member%s %s%s."):format(#inviteQueue, #inviteQueue == 1 and "" or "s", what,
    offline > 0 and (" (" .. offline .. " offline)") or ""))
  local n = #inviteQueue
  inviteMore()
  return n
end

-- Invite every online guild member who accepted (or is tentative) and isn't in your group.
function ns.InviteSignups(eventId)
  if not ns.IsAddonOfficer() then ns.Say("Only officers can send raid invites.") return end
  -- With a raid plan, only the planned groups are invited (not the bench).
  local plan = ns.HasRaidPlan and ns.HasRaidPlan(eventId) and ns.RaidPlan(eventId)
  local names = {}
  for _, su in ipairs((ns.Signups(eventId))) do
    local k = ns.Key(su.name)
    local planned = not plan or (plan[k] and plan[k].group >= 1)
    if su.status ~= "decline" and planned then names[#names + 1] = su.name end
  end
  ns.InviteNames(names, "who signed up")
end

------------------------------------------------------------------------
-- Reminders
------------------------------------------------------------------------
local MAKEUP_WARN_BEFORE = 60 * 60

local function remind()
  local now = time()
  for _, e in ipairs(ns.RaidEvents()) do
    -- An hour before, officers hear about any gaps in the raid's makeup.
    if e.start > now and e.start - now <= MAKEUP_WARN_BEFORE and not ns.db.reminded[e.id .. "#makeup"]
        and ns.IsAddonOfficer() then
      ns.db.reminded[e.id .. "#makeup"] = true
      local mk = ns.RaidMakeup(e.id)
      if #mk.warnings > 0 then
        ns.Say(("|cffff9900%s in %d min, %d signed up:|r %s."):format(e.title,
          math.max(1, math.floor((e.start - now) / 60)), mk.accept, table.concat(mk.warnings, "; ")))
      end
    end
    local mine = ns.MySignup(e.id)
    if e.start > now and e.start - now <= REMIND_BEFORE and not ns.db.reminded[e.id]
        and mine and mine.status ~= "decline" then
      ns.db.reminded[e.id] = true
      local mins = math.max(1, math.floor((e.start - now) / 60))
      ns.Notify(("|cff66ccffRaid reminder: %s starts at %s (in %d min).|r"):format(e.title,
        date("%H:%M", e.start), mins), nil, nil, nil, "raid", "Raid reminder")
    end
  end
end

ns.OnLoad(function()
  C_Timer.NewTicker(30, function()
    sessionTick()
    remind()
  end)
end)

ns.OnEvent("GROUP_ROSTER_UPDATE", function()
  if ns.RefreshPanel then ns.RefreshPanel() end
end)
