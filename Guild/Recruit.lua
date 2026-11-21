--[[
  Warcrest
  Recruiting, for officers: the guild's list of recruits and where each is
  up to, the recruiting message, and trials.

  Recruits move through: New, Contacted, Trial, then Joined or Declined.
  The list is kept in the guild's shared record, so every officer sees the
  same one. When a trial ends, officers hear how it went (raid nights and
  events attended). Players outside the guild who whisper an officer about
  joining are noted, so they're easy to add.
]]

local _, ns = ...
local Ambiguate = ns.Ambiguate

ns.RECRUIT_STATUSES = {
  { key = "new",       label = "New",       color = "66ccff" },
  { key = "contacted", label = "Contacted", color = "ffd200" },
  { key = "trial",     label = "Trial",     color = "ffad33" },
  { key = "joined",    label = "Joined",    color = "5ed36b" },
  { key = "declined",  label = "Declined",  color = "8a8a8a" },
  { key = "removed",   label = "Removed",   color = "8a8a8a", hidden = true },
}
local STATUS_BY_KEY = {}
for _, s in ipairs(ns.RECRUIT_STATUSES) do STATUS_BY_KEY[s.key] = s end
function ns.RecruitStatus(key) return STATUS_BY_KEY[key] or STATUS_BY_KEY.new end

local DEFAULT_TRIAL_DAYS = 14
local MESSAGE_MAX = 170
local WHISPER_WORDS = { "guild", "join", "recruit", "apply", "invite", "inv", "gquild", "ginv" }
local WHISPERS_KEPT = 10

ns.OnLoad(function()
  ns.db.trialDays = ns.db.trialDays or DEFAULT_TRIAL_DAYS
  ns.db.trialsNoted = ns.db.trialsNoted or {}
  ns.db.recruitChannel = ns.db.recruitChannel or ""
end)

------------------------------------------------------------------------
-- Recruits
------------------------------------------------------------------------
-- Each recruit's latest entry, with when their trial started.
local cache, cacheStamp
local function build()
  local stamp = ns.LedgerStamp("RC")
  if cache and cacheStamp == stamp then return cache end
  cache, cacheStamp = {}, stamp
  for _, e in ipairs(ns.LedgerEntries("RC")) do
    local k = ns.Key(e.name)
    local prev = cache[k]
    local r = { name = e.name, class = e.class ~= "" and e.class or (prev and prev.class or ""),
      level = (tonumber(e.level) or 0) > 0 and tonumber(e.level) or (prev and prev.level or 0),
      note = e.note, status = STATUS_BY_KEY[e.status] and e.status or "new", t = e.t, by = e.a,
      added = prev and prev.added or e.t, trialStart = prev and prev.trialStart or nil }
    if r.status == "trial" and (not prev or prev.status ~= "trial") then r.trialStart = e.t end
    cache[k] = r
  end
  return cache
end

function ns.Recruit(name) return build()[ns.Key(name)] end

-- The recruits still on the list (not removed), most recently changed first.
function ns.Recruits()
  local out = {}
  for _, r in pairs(build()) do
    if r.status ~= "removed" then
      r.inGuild = ns.RankOf(r.name) ~= nil
      out[#out + 1] = r
    end
  end
  table.sort(out, function(a, b)
    if a.t ~= b.t then return a.t > b.t end
    return a.name < b.name
  end)
  return out
end

-- Add a recruit, or change one: status, note, class and level (any left out stay as they were).
function ns.SetRecruit(name, fields)
  if not ns.IsAddonOfficer() then ns.Say("Only officers can manage recruits.") return end
  name = strtrim(name or "")
  if name == "" then ns.Say("Enter the player's name.") return end
  name = Ambiguate(name, "none")
  name = name:sub(1, 1):upper() .. name:sub(2)
  local old = ns.Recruit(name)
  fields = fields or {}
  return ns.LedgerAdd("RC", {
    name = name,
    class = fields.class or (old and old.class) or "",
    level = fields.level or (old and old.level) or 0,
    note = (fields.note or (old and old.note) or ""):sub(1, 80),
    status = fields.status or (old and old.status) or "new",
  })
end

function ns.RemoveRecruit(name)
  local r = ns.Recruit(name)
  if r then return ns.SetRecruit(r.name, { status = "removed" }) end
end

-- Invite a recruit to the guild (and mark them Contacted if they were New).
function ns.InviteRecruit(name)
  if not ns.IsAddonOfficer() then return end
  local f = (C_GuildInfo and C_GuildInfo.Invite) or GuildInvite
  if f then pcall(f, name) end
  local r = ns.Recruit(name)
  if r and r.status == "new" then ns.SetRecruit(r.name, { status = "contacted" }) end
  ns.Say(ns.TF("Guild invite sent to %s.", Ambiguate(name, "short")))
end

-- A trial: days in, days long, and how it's going.
function ns.TrialProgress(r)
  if not r or r.status ~= "trial" or not r.trialStart then return nil end
  local length = ns.db.trialDays or DEFAULT_TRIAL_DAYS
  local days = math.floor((GetServerTime() - r.trialStart) / 86400)
  local nights = 0
  if ns.RaidNightsAttended then
    for _, t in ipairs(ns.RaidNightsAttended(r.name)) do if t >= r.trialStart then nights = nights + 1 end end
  end
  local events = ns.EventsAttended and ns.EventsAttended(r.name, math.max(1, days + 1)) or 0
  return { days = days, length = length, over = days >= length, nights = nights, events = events }
end

------------------------------------------------------------------------
-- The recruiting message
------------------------------------------------------------------------
function ns.RecruitMessage()
  local list = ns.LedgerEntries("RM")
  local last = list[#list]
  if last and last.text ~= "" then return last.text end
  local g = ns.GuildName and ns.GuildName() or ""
  return ns.TF("<%s> is recruiting! Raids, PvP and a friendly crew. Whisper me to join.", g ~= "" and g or ns.T("Our guild"))
end

function ns.SetRecruitMessage(text)
  if not ns.IsAddonOfficer() then return end
  text = strtrim(text or ""):sub(1, MESSAGE_MAX)
  if text == ns.RecruitMessage() then return end
  return ns.LedgerAdd("RM", { text = text })
end

-- The public channels you're in, as { id, name }.
function ns.ChatChannels()
  local out = {}
  local list = { GetChannelList() }
  -- (id, name, disabled) triples on newer clients; (id, name) pairs on older ones.
  local step = (type(list[3]) == "boolean") and 3 or 2
  for i = 1, #list, step do
    local id, name = tonumber(list[i]), list[i + 1]
    if id and type(name) == "string" then out[#out + 1] = { id = id, name = name } end
  end
  return out
end

-- Post the recruiting message in a chat channel (by number).
function ns.PostRecruitMessage(channelId)
  channelId = tonumber(channelId)
  if not channelId then ns.Say("Pick a chat channel to post in first.") return end
  ns.SendChat(ns.RecruitMessage(), "CHANNEL", nil, channelId)
  ns.db.recruitPostedAt = time()
  return true
end

------------------------------------------------------------------------
-- Whispers about joining
------------------------------------------------------------------------
ns.recruitWhispers = {} -- { name, text, t }, newest first (this session)

local function asksToJoin(text)
  text = (text or ""):lower()
  for _, w in ipairs(WHISPER_WORDS) do
    if text:find("%f[%a]" .. w .. "%f[%A]") then return true end
  end
  return false
end

ns.OnEvent("CHAT_MSG_WHISPER", function(text, sender)
  if not ns.IsAddonOfficer() or not sender or ns.RankOf(sender) ~= nil then return end
  if issecretvalue and (issecretvalue(text) or issecretvalue(sender)) then return end
  if not asksToJoin(text) then return end
  local name = Ambiguate(sender, "none")
  for i = #ns.recruitWhispers, 1, -1 do
    if ns.Key(ns.recruitWhispers[i].name) == ns.Key(name) then table.remove(ns.recruitWhispers, i) end
  end
  table.insert(ns.recruitWhispers, 1, { name = name, text = text, t = time() })
  while #ns.recruitWhispers > WHISPERS_KEPT do table.remove(ns.recruitWhispers) end
  if not ns.Recruit(name) then
    ns.Say(ns.TF("%s whispered about joining. Add them on the Recruit tab, or /warcrest recruit.", Ambiguate(name, "short")))
  end
  if ns.RefreshPanel then ns.RefreshPanel() end
end)

------------------------------------------------------------------------
-- Joining and trials
------------------------------------------------------------------------
local function checkRecruits()
  if not ns.IsAddonOfficer() then return end
  for _, r in ipairs(ns.Recruits()) do
    local p = ns.TrialProgress(r)
    local key = r.name .. ":" .. (r.trialStart or 0)
    if p and p.over and not ns.db.trialsNoted[key] then
      ns.db.trialsNoted[key] = true
      ns.Say(("|cffffad33%s's trial is over (%d days):|r %d raid night%s and %d event%s attended. Set them to Joined or Declined on the Recruit tab.")
        :format(Ambiguate(r.name, "short"), p.days, p.nights, p.nights == 1 and "" or "s", p.events, p.events == 1 and "" or "s"))
    end
  end
end

table.insert(ns.OnGuildReady, function()
  C_Timer.After(25, checkRecruits)
  C_Timer.NewTicker(1800, checkRecruits)
end)
