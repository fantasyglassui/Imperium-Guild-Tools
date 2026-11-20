--[[
  Warcrest
  Guild polls: a question with a few answers, one vote each. "Raid on
  Thursday or Friday?", "Onyxia this week?".

  Officers can always start one; members can too when the guild allows it
  (Settings, Guild-wide: Members can start polls). Each member can have one
  poll open at a time, so it's hard to spam. A poll closes by itself after
  the days it was given, or when whoever asked (or an officer) closes it.
  Votes aren't secret: hover an answer to see who picked it. You can change
  your vote while the poll is open.

  Shared record: PO { q, opts, lasts } a poll, PV { ref, choice } a vote (the
  latest counts), PC { ref } a poll closed.
]]

local _, ns = ...
local Ambiguate = ns.Ambiguate

local Q_MAX = 80
local OPT_MAX = 28
local OPTS_MAX = 6
local OPTS_TEXT_MAX = 130
local KEEP_DAYS = 30
local OFFICER_OPEN = 5 -- polls an officer can have open at once (members: 1)

------------------------------------------------------------------------
-- Who can start one
------------------------------------------------------------------------
function ns.MembersCanPoll() return ns.cfg and ns.cfg.memberPolls and true or false end

local function canStart(name)
  if ns.IsOfficerName(name) then return true end
  return ns.MembersCanPoll() and ns.RankOf(name) ~= nil
end

------------------------------------------------------------------------
-- The polls
------------------------------------------------------------------------
local cache, cacheStamp
local function build()
  local stamp = ns.LedgerStamp("PO", "PV", "PC") .. ":" .. tostring(ns.MembersCanPoll())
  if cache and cacheStamp == stamp then return cache end
  cache, cacheStamp = { list = {}, byId = {} }, stamp
  local now = GetServerTime()
  for _, e in ipairs(ns.LedgerEntries("PO")) do
    local opts = {}
    for o in tostring(e.opts or ""):gmatch("[^;]+") do
      if #opts < OPTS_MAX then opts[#opts + 1] = o end
    end
    if #opts >= 2 and canStart(e.a) and now - e.t < KEEP_DAYS * 86400 then
      local days = math.max(1, math.min(14, tonumber(e.lasts) or 3))
      local p = { id = e.id, q = e.q, opts = opts, by = e.a, t = e.t, ends = e.t + days * 86400,
        votes = {}, closedAt = nil }
      cache.byId[e.id] = p
      cache.list[#cache.list + 1] = p
    end
  end
  for _, c in ipairs(ns.LedgerEntries("PC")) do
    local p = cache.byId[c.ref]
    if p and (ns.Key(c.a) == ns.Key(p.by) or ns.IsOfficerName(c.a)) and (not p.closedAt or c.t < p.closedAt) then
      p.closedAt = c.t
    end
  end
  for _, v in ipairs(ns.LedgerEntries("PV")) do -- oldest first: the latest vote counts
    local p = cache.byId[v.ref]
    local choice = tonumber(v.choice)
    if p and choice and p.opts[choice] and ns.RankOf(v.a) ~= nil then
      local closes = math.min(p.ends, p.closedAt or math.huge)
      if v.t <= closes then p.votes[ns.Key(v.a)] = { name = Ambiguate(v.a, "short"), choice = choice } end
    end
  end
  for _, p in ipairs(cache.list) do
    p.open = not p.closedAt and now < p.ends
    p.counts, p.total = {}, 0
    for i = 1, #p.opts do p.counts[i] = 0 end
    for _, v in pairs(p.votes) do
      p.counts[v.choice] = p.counts[v.choice] + 1
      p.total = p.total + 1
    end
  end
  -- Open first (closing soonest first), then the closed ones, newest first.
  table.sort(cache.list, function(a, b)
    if a.open ~= b.open then return a.open end
    if a.open then return a.ends < b.ends end
    return a.t > b.t
  end)
  return cache
end

function ns.Polls() return build().list end
function ns.Poll(id) return id and build().byId[id] end

function ns.MyVote(p)
  local v = p and p.votes[ns.Key(UnitName("player"))]
  return v and v.choice
end

function ns.OpenPollsBy(name)
  local n = 0
  for _, p in ipairs(build().list) do
    if p.open and ns.Key(p.by) == ns.Key(name) then n = n + 1 end
  end
  return n
end

function ns.CanStartPoll()
  local me = UnitName("player")
  if not canStart(me) then return false, ns.T("Only officers can start polls in this guild.") end
  local limit = ns.IsAddonOfficer() and OFFICER_OPEN or 1
  if ns.OpenPollsBy(me) >= limit then
    return false, ns.TP(limit, "You already have a poll open. Close it first.", "You already have %d polls open. Close one first.", limit)
  end
  return true
end

local function clean(s, max) return strtrim((s or ""):gsub("[;%^|~]", ","):gsub("%s+", " ")):sub(1, max) end

-- Start a poll: a question, 2 to 6 answers, open for some days.
function ns.StartPoll(question, answers, days)
  local ok, why = ns.CanStartPoll()
  if not ok then ns.Say(why) return end
  question = clean(question, Q_MAX)
  if question == "" then ns.Say("Write the question first.") return end
  local opts = {}
  for _, a in ipairs(answers or {}) do
    a = clean(a, OPT_MAX)
    if a ~= "" and #opts < OPTS_MAX then opts[#opts + 1] = a end
  end
  if #opts < 2 then ns.Say("A poll needs at least two answers.") return end
  local text = table.concat(opts, ";")
  while #text > OPTS_TEXT_MAX do
    table.remove(opts)
    text = table.concat(opts, ";")
  end
  local e = ns.LedgerAdd("PO", { q = question, opts = text, lasts = math.max(1, math.min(14, tonumber(days) or 3)) })
  if e then ns.Send("PN", e.id) end
  return e
end

function ns.VotePoll(id, choice)
  local p = ns.Poll(id)
  if not p or not p.open or not p.opts[choice] then return end
  if ns.MyVote(p) == choice then return true end
  return ns.LedgerAdd("PV", { ref = id, choice = choice })
end

function ns.ClosePoll(id)
  local p = ns.Poll(id)
  if not p or not p.open then return end
  if not (ns.IsMe(p.by) or ns.IsAddonOfficer()) then return end
  return ns.LedgerAdd("PC", { ref = id })
end

-- A guildmate started a poll: let people know.
ns.OnMessage("PN", function(p, sender)
  if ns.IsMe(sender) then return end
  C_Timer.After(2, function() -- the poll itself arrives with it
    local poll = ns.Poll(p[2])
    if not poll or not poll.open or not ns.db.eventNews then return end
    ns.Notify(ns.TF("%s asks the guild: %s Vote on the Events tab.", Ambiguate(sender, "short"),
      "|cffffffff" .. poll.q .. "|r"), nil, nil, nil, "event", "Guild poll")
  end)
end)
