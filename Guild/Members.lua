--[[
  Warcrest
  Member profiles: what each guildmate tells the guild about themselves.

  Main spec and role, the days and times they usually play, their birthday,
  and a short note. Their item level is added automatically from the gear
  they're wearing. The profile is kept in the guild's shared record (the
  latest one counts), shown on their player card, and listed for officers.

  On a member's birthday, the guild hears about it when they log in. Once a
  year after Warcrest first saw them in the guild, their anniversary too.
]]

local _, ns = ...
local Ambiguate = ns.Ambiguate

local DAY_NAMES = { "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun" }
local ROLES = { tank = true, healer = true, dps = true }
local ILVL_EVERY = 24 * 3600  -- share a changed item level at most once a day
local SPEC_MAX, NOTE_MAX = 24, 80

ns.PROFILE_DAYS = DAY_NAMES

ns.OnLoad(function()
  ns.db.celebrated = ns.db.celebrated or {} -- "bday:key:year" / "anniv:key:year" -> true
  ns.db.firstSeen = ns.db.firstSeen or {}   -- key -> when Warcrest first saw them in the guild
  -- Only this year's celebrations need remembering.
  local year = ":" .. date("%Y") .. "$"
  for key in pairs(ns.db.celebrated) do
    if not key:find(year) then ns.db.celebrated[key] = nil end
  end
end)

------------------------------------------------------------------------
-- Reading profiles
------------------------------------------------------------------------
local cache, cacheStamp
local function all()
  local stamp = ns.LedgerStamp("PF")
  if cache and cacheStamp == stamp then return cache end
  cache, cacheStamp = {}, stamp
  for _, e in ipairs(ns.LedgerEntries("PF")) do cache[ns.Key(e.a)] = e end -- oldest first: the latest wins
  return cache
end

-- "1111100" -> { true, true, true, true, true, false, false } (Monday first)
local function parseDays(s)
  local out = {}
  for i = 1, 7 do out[i] = (s or ""):sub(i, i) == "1" end
  return out
end

-- A member's profile, or nil if they haven't shared one:
-- { name, spec, role, days = { 7 booleans }, hours, bday = "MM-DD" or "", ilvl, note, t }
function ns.MemberProfile(name)
  local e = all()[ns.Key(name)]
  if not e then return nil end
  return { name = e.a, spec = e.spec or "", role = ROLES[e.role] and e.role or "", days = parseDays(e.days),
    hours = e.hours or "", bday = e.bday or "", ilvl = tonumber(e.ilvl) or 0, note = e.note or "", t = e.t }
end

function ns.MemberProfiles()
  local out = {}
  for _, e in pairs(all()) do
    if ns.RankOf(e.a) ~= nil then out[#out + 1] = ns.MemberProfile(e.a) end
  end
  table.sort(out, function(a, b) return a.name < b.name end)
  return out
end

-- "Mon-Fri", "Sat, Sun", "Every day", or "" for none.
function ns.DaysText(days)
  local on, runs, i = 0, {}, 1
  for d = 1, 7 do if days[d] then on = on + 1 end end
  if on == 0 then return "" end
  if on == 7 then return ns.T("Every day") end
  while i <= 7 do
    if days[i] then
      local j = i
      while j < 7 and days[j + 1] do j = j + 1 end
      if j - i >= 2 then
        runs[#runs + 1] = ns.T(DAY_NAMES[i]) .. "-" .. ns.T(DAY_NAMES[j])
      else
        for d = i, j do runs[#runs + 1] = ns.T(DAY_NAMES[d]) end
      end
      i = j + 1
    else
      i = i + 1
    end
  end
  return table.concat(runs, ", ")
end

-- "Mon-Fri, 19:00-23:00"
function ns.AvailabilityText(p)
  if not p then return "" end
  local days = ns.DaysText(p.days)
  if days ~= "" and p.hours ~= "" then return days .. ", " .. p.hours end
  return days ~= "" and days or p.hours
end

local MONTHS = { "January", "February", "March", "April", "May", "June", "July", "August", "September",
  "October", "November", "December" }
ns.MONTH_NAMES = MONTHS

function ns.BirthdayText(bday)
  local m, d = (bday or ""):match("^(%d%d)%-(%d%d)$")
  m, d = tonumber(m), tonumber(d)
  if not m or not MONTHS[m] then return "" end
  return ns.T(MONTHS[m]) .. " " .. d
end

------------------------------------------------------------------------
-- Item level
------------------------------------------------------------------------
local SLOTS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 } -- not the shirt or tabard

-- The average item level of the gear you're wearing (an empty slot counts as 0,
-- and an empty off hand doesn't count when the main hand is two-handed).
function ns.MyItemLevel()
  local total, slots = 0, 0
  for _, slot in ipairs(SLOTS) do
    local link = GetInventoryItemLink("player", slot)
    local lvl = 0
    if link then
      lvl = tonumber((select(4, GetItemInfo(link))))
      -- The game hasn't loaded this item yet: the average would come out too low.
      if not lvl then return 0 end
    end
    if slot == 17 and not link then
      local main = GetInventoryItemLink("player", 16)
      local loc = main and select(9, GetItemInfo(main))
      if loc == "INVTYPE_2HWEAPON" then slots = slots - 1 end
    end
    if slot == 18 and not link then slots = slots - 1 end -- no ranged slot item: not every class has one
    total = total + lvl
    slots = slots + 1
  end
  if slots <= 0 then return 0 end
  return math.floor(total / slots + 0.5)
end

------------------------------------------------------------------------
-- Saving yours
------------------------------------------------------------------------
-- fields: { spec, role, days = { 7 booleans }, hours, bday = "MM-DD", note }
function ns.SaveMyProfile(fields)
  if not IsInGuild() then ns.Say("You need to be in a guild to share a profile.") return end
  local days = {}
  for i = 1, 7 do days[i] = fields.days and fields.days[i] and "1" or "0" end
  local hours = strtrim(fields.hours or "")
  if hours ~= "" and not hours:match("^%d%d?:%d%d%s*%-%s*%d%d?:%d%d$") then
    ns.Say("Enter the times you play like 19:00-23:00.")
    return
  end
  hours = hours:gsub("%s", "")
  local bday = fields.bday or ""
  if bday ~= "" and not bday:match("^%d%d%-%d%d$") then bday = "" end
  local e = ns.LedgerAdd("PF", {
    spec = strtrim(fields.spec or ""):sub(1, SPEC_MAX),
    role = ROLES[fields.role] and fields.role or "",
    days = table.concat(days),
    hours = hours,
    bday = bday,
    ilvl = ns.MyItemLevel(),
    note = strtrim(fields.note or ""):sub(1, NOTE_MAX),
  })
  if e then
    ns.db.ilvlSharedAt = GetServerTime()
    ns.Say("Your profile is saved and shared with the guild.")
  end
  return e
end

-- Keep the item level on your profile up to date as your gear changes.
local function shareItemLevel()
  local mine = ns.MemberProfile(UnitName("player"))
  if not mine or not IsInGuild() then return end
  local now = ns.MyItemLevel()
  if now <= 0 or math.abs(now - mine.ilvl) < 1 then return end
  if GetServerTime() - (ns.db.ilvlSharedAt or 0) < ILVL_EVERY then return end
  ns.db.ilvlSharedAt = GetServerTime()
  local days = {}
  for i = 1, 7 do days[i] = mine.days[i] and "1" or "0" end
  ns.LedgerAdd("PF", { spec = mine.spec, role = mine.role, days = table.concat(days), hours = mine.hours,
    bday = mine.bday, ilvl = now, note = mine.note })
end

local gearPending = false
ns.OnEvent("PLAYER_EQUIPMENT_CHANGED", function()
  if gearPending then return end
  gearPending = true
  C_Timer.After(20, function() gearPending = false; shareItemLevel() end)
end)

------------------------------------------------------------------------
-- Member since, birthdays and anniversaries
------------------------------------------------------------------------
-- When Warcrest first saw someone in the guild: the earliest of what this
-- computer saw, anything they've put in the guild record, and a kill they took part in.
local sinceCache, sinceStamp
function ns.MemberSince(name)
  local k = ns.Key(name)
  local stamp = ns.LedgerVersion()
  if not sinceCache or sinceStamp ~= stamp then
    sinceCache, sinceStamp = {}, stamp
    for _, e in pairs(ns.db.ledger) do
      local a = ns.Key(e.a)
      if e.t and (not sinceCache[a] or e.t < sinceCache[a]) then sinceCache[a] = e.t end
    end
  end
  local best = sinceCache[k]
  local seen = ns.db.firstSeen[k]
  if seen and (not best or seen < best) then best = seen end
  return best
end

local function today()
  local d = date("*t")
  return ("%02d-%02d"):format(d.month, d.day), d.year
end

local function celebrate(key, text)
  if ns.db.celebrated[key] then return end
  ns.db.celebrated[key] = true
  local STAR = "|TInterface\\COMMON\\ReputationStar:14:14:0:0:32:32:0:16:0:16|t"
  ns.Notify(STAR .. " " .. text, nil, nil, nil, "celebrate", "Guild news")
end

-- Look at who's online: birthdays today, and anniversaries.
local function checkCelebrations()
  if not IsInGuild() then return end
  local md, year = today()
  local now = time()
  for _, m in ipairs(ns.GetRoster()) do
    local k = ns.Key(m.name)
    if not ns.db.firstSeen[k] then ns.db.firstSeen[k] = now end
    if m.online then
      local p = ns.MemberProfile(m.name)
      if p and p.bday == md then
        celebrate(("bday:%s:%d"):format(k, year), ns.IsMe(m.name) and ns.T("Happy birthday from your guild!")
          or ns.TF("It's %s's birthday today!", Ambiguate(m.name, "short")))
      end
      local since = ns.MemberSince(m.name)
      if since and date("%m-%d", since) == md then
        local years = year - tonumber(date("%Y", since))
        if years >= 1 then
          celebrate(("anniv:%s:%d"):format(k, year), years == 1
            and ns.TF("%s has been in the guild for a year!", Ambiguate(m.name, "short"))
            or ns.TF("%s has been in the guild for %d years!", Ambiguate(m.name, "short"), years))
        end
      end
    end
  end
end

table.insert(ns.OnGuildReady, function()
  C_Timer.After(15, checkCelebrations)
  C_Timer.NewTicker(300, checkCelebrations)
  C_Timer.After(30, shareItemLevel)
end)
