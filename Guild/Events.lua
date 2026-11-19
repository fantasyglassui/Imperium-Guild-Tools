--[[
  Warcrest
  Guild events: everything that isn't a raid. PvP nights, world boss hunts,
  dungeon runs, guild meetings and get-togethers.

  Any guild member can put an event on the calendar. Guildmates answer
  Going, Maybe or Can't go, and get a reminder before it starts. Whoever
  made the event (or an officer) can invite everyone going, take attendance
  from their group, and cancel it. Everything is kept in the guild's shared
  record, so it reaches guildmates who were offline when it was made.
]]

local _, ns = ...

local SHOW_PAST = 6 * 3600        -- keep showing an event for 6 hours after it starts
local REMIND_BEFORE = 15 * 60
local NAMES_CHARS = 170
local STATUSES = { going = true, maybe = true, no = true }

-- The kinds of event: label, colour (hex) and a short word for the list.
ns.EVENT_TYPES = {
  { key = "pvp",      label = "PvP",        color = "ff5a4f" },
  { key = "worldboss", label = "World boss", color = "e070ff" },
  { key = "dungeon",  label = "Dungeon",    color = "66ccff" },
  { key = "meeting",  label = "Meeting",    color = "ffd200" },
  { key = "social",   label = "Social",     color = "5ed36b" },
  { key = "other",    label = "Other",      color = "c8c8c8" },
}
local TYPE_BY_KEY = {}
for _, t in ipairs(ns.EVENT_TYPES) do TYPE_BY_KEY[t.key] = t end

function ns.EventType(key) return TYPE_BY_KEY[key] or TYPE_BY_KEY.other end

ns.OnLoad(function()
  ns.db.eventReminded = ns.db.eventReminded or {}
  if ns.db.eventNews == nil then ns.db.eventNews = true end
end)

------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------
-- Who may change an event: whoever made it, or an officer.
function ns.CanManageEvent(e, name)
  if not e then return false end
  name = name or UnitName("player")
  return ns.Key(e.a) == ns.Key(name) or ns.IsOfficerName(name)
end

-- Cancellations that count (from the event's maker or an officer).
local function cancelled()
  local set = {}
  for _, x in ipairs(ns.LedgerEntries("GX")) do
    local e = ns.db.ledger[x.ref]
    if e and e.k == "GE" and ns.CanManageEvent(e, x.a) then set[x.ref] = true end
  end
  return set
end

function ns.GuildEvent(id)
  local e = id and ns.db.ledger[id]
  if e and e.k == "GE" then return e end
end

function ns.EventEnds(e) return e.start + math.max(30, tonumber(e.mins) or 120) * 60 end

-- Upcoming events (and ones that started in the last few hours), soonest first.
function ns.GuildEvents()
  local gone, now, out = cancelled(), time(), {}
  for _, e in ipairs(ns.LedgerEntries("GE")) do
    if not gone[e.id] and ns.EventEnds(e) >= now - SHOW_PAST then out[#out + 1] = e end
  end
  table.sort(out, function(a, b) return a.start < b.start end)
  return out
end

-- Every event that wasn't cancelled, past ones too, for the calendar.
function ns.AllGuildEvents()
  local gone, out = cancelled(), {}
  for _, e in ipairs(ns.LedgerEntries("GE")) do
    if not gone[e.id] then out[#out + 1] = e end
  end
  table.sort(out, function(a, b) return a.start < b.start end)
  return out
end

function ns.CreateGuildEvent(etype, title, start, notes, mins)
  if not IsInGuild() then ns.Say("You need to be in a guild to make an event.") return end
  title = strtrim(title or "")
  if title == "" then ns.Say("Give the event a name.") return end
  if start < time() - 60 then ns.Say("That date and time has already passed.") return end
  if not TYPE_BY_KEY[etype] then etype = "other" end
  return ns.LedgerAdd("GE", { title = title, start = start, etype = etype, notes = notes or "",
    mins = math.max(30, math.min(720, tonumber(mins) or 120)) })
end

function ns.CancelGuildEvent(id)
  local e = ns.GuildEvent(id)
  if not ns.CanManageEvent(e) then ns.Say("Only whoever made the event, or an officer, can cancel it.") return end
  return ns.LedgerAdd("GX", { ref = id })
end

------------------------------------------------------------------------
-- Who's going
------------------------------------------------------------------------
function ns.EventSignUp(id, status)
  if not ns.GuildEvent(id) or not STATUSES[status] then return end
  return ns.LedgerAdd("GS", { ref = id, status = status })
end

-- Each member's latest answer: a sorted list, and key -> answer.
function ns.EventSignups(id)
  local byKey = {}
  for _, e in ipairs(ns.LedgerEntries("GS")) do
    if e.ref == id and STATUSES[e.status] then byKey[ns.Key(e.a)] = { name = e.a, status = e.status, t = e.t } end
  end
  local list = {}
  for _, s in pairs(byKey) do list[#list + 1] = s end
  local order = { going = 1, maybe = 2, no = 3 }
  table.sort(list, function(a, b)
    if a.status ~= b.status then return order[a.status] < order[b.status] end
    return a.name < b.name
  end)
  return list, byKey
end

function ns.EventCounts(id)
  local c = { going = 0, maybe = 0, no = 0 }
  for _, s in ipairs((ns.EventSignups(id))) do c[s.status] = c[s.status] + 1 end
  return c
end

function ns.MyEventSignup(id)
  local _, byKey = ns.EventSignups(id)
  return byKey[ns.Key(UnitName("player"))]
end

------------------------------------------------------------------------
-- Attendance
------------------------------------------------------------------------
-- Guild members in your group right now (party or raid), you included.
local function groupMembers()
  local out, seen = {}, {}
  local function add(name)
    if name and not seen[ns.Key(name)] and ns.RankOf(name) ~= nil then
      seen[ns.Key(name)] = true
      out[#out + 1] = Ambiguate(name, "none")
    end
  end
  add(UnitName("player"))
  if IsInRaid() then
    for i = 1, GetNumGroupMembers() do
      local name, _, _, _, _, _, _, online = GetRaidRosterInfo(i)
      if online then add(name) end
    end
  elseif IsInGroup() then
    for i = 1, GetNumGroupMembers() - 1 do
      if UnitIsConnected("party" .. i) then add(UnitName("party" .. i)) end
    end
  end
  return out
end

-- Whoever made the event (or an officer) records who's there: everyone in their group.
function ns.TakeEventAttendance(id)
  local e = ns.GuildEvent(id)
  if not ns.CanManageEvent(e) then ns.Say("Only whoever made the event, or an officer, can take attendance.") return end
  if not IsInGroup() then
    ns.Say("Group up with everyone at the event first: attendance is everyone in your group.")
    return
  end
  local names = groupMembers()
  local chunk, len = {}, 0
  local function flush()
    if #chunk > 0 then ns.LedgerAdd("GT", { ref = id, names = table.concat(chunk, ",") }) end
    chunk, len = {}, 0
  end
  for _, n in ipairs(names) do
    if len + #n > NAMES_CHARS then flush() end
    chunk[#chunk + 1] = n
    len = len + #n + 1
  end
  flush()
  ns.Say(("Attendance taken for %s: %d guild member%s."):format(e.title, #names, #names == 1 and "" or "s"))
  return #names
end

-- Who came to an event: key -> name (nil if attendance was never taken).
function ns.EventAttended(id)
  local e = ns.GuildEvent(id)
  local set
  for _, t in ipairs(ns.LedgerEntries("GT")) do
    if t.ref == id and ns.CanManageEvent(e, t.a) then
      set = set or {}
      for name in t.names:gmatch("[^,]+") do set[ns.Key(name)] = name end
    end
  end
  return set
end

-- How many events someone came to in the last `days` days.
local attendCache
ns.OnLedgerChanged(function() attendCache = nil end)
function ns.EventsAttended(name, days)
  days = days or 30
  if not attendCache or attendCache.days ~= days then
    attendCache = { days = days, byKey = {} }
    local since = time() - days * 86400
    local gone = cancelled()
    for _, e in ipairs(ns.LedgerEntries("GE")) do
      if e.start >= since and not gone[e.id] then
        for k in pairs(ns.EventAttended(e.id) or {}) do
          local main = ns.Key(ns.MainOf and ns.MainOf(k) or k)
          attendCache.byKey[main] = (attendCache.byKey[main] or 0) + 1
        end
      end
    end
  end
  return attendCache.byKey[ns.Key(ns.MainOf and ns.MainOf(name) or name)] or 0
end

------------------------------------------------------------------------
-- Inviting everyone going
------------------------------------------------------------------------
function ns.InviteEventGoing(id)
  local e = ns.GuildEvent(id)
  if not ns.CanManageEvent(e) then ns.Say("Only whoever made the event, or an officer, can send invites.") return end
  local names = {}
  for _, s in ipairs((ns.EventSignups(id))) do
    if s.status ~= "no" then names[#names + 1] = s.name end
  end
  if ns.InviteNames then return ns.InviteNames(names, "going to " .. e.title) end
end

------------------------------------------------------------------------
-- News and reminders
------------------------------------------------------------------------
local function eventLine(e)
  return ("%s: %s, %s"):format(ns.T(ns.EventType(e.etype).label), e.title, date("%a %b %d, %H:%M", e.start))
end

-- A new event from someone else, heard live: let guildmates know (if they want to).
local seenEvents
ns.OnLedgerChanged(function()
  if not seenEvents then return end
  for _, e in ipairs(ns.LedgerEntries("GE")) do
    if not seenEvents[e.id] then
      seenEvents[e.id] = true
      local fresh = GetServerTime() - e.t < 300 and e.start > time()
      if fresh and not ns.IsMe(e.a) and ns.db.eventNews then
        ns.Notify(("|cff4fd1c5New guild event from %s. %s.|r"):format(Ambiguate(e.a, "short"), eventLine(e)),
          nil, nil, nil, "event", "New guild event")
      end
    end
  end
end)

local function remind()
  local now = time()
  for _, e in ipairs(ns.GuildEvents()) do
    local mine = ns.MyEventSignup(e.id)
    if e.start > now and e.start - now <= REMIND_BEFORE and not ns.db.eventReminded[e.id]
        and mine and mine.status ~= "no" then
      ns.db.eventReminded[e.id] = true
      ns.Notify(("|cff4fd1c5%s starts at %s (in %d min).|r"):format(e.title, date("%H:%M", e.start),
        math.max(1, math.floor((e.start - now) / 60))), nil, nil, nil, "event", "Guild event")
    end
  end
end

ns.OnLoad(function()
  seenEvents = {}
  for _, e in ipairs(ns.LedgerEntries("GE")) do seenEvents[e.id] = true end
  C_Timer.NewTicker(30, remind)
end)

-- Open an event on the Events tab (the UI fills this in).
function ns.SelectGuildEvent(id)
  if ns.UI and ns.UI.ShowGuildEvent then ns.UI.ShowGuildEvent(id) end
end
