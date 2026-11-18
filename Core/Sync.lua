--[[
  Bannerhold
  Sync: shares recent history between guildmates so everyone's Death, Kill
  logs (and the leaderboards built on them) match.

  When you log in, your addon asks the guild for anything from the last two
  days that it missed. One online guildmate answers, sending the entries
  privately at a gentle pace. Entries already in your logs are skipped, and
  shared history never triggers alerts.
]]

local _, ns = ...

local WINDOW = 2 * 24 * 60 * 60   -- share up to two days back
local OVERLAP = 12 * 60 * 60      -- re-check the 12 hours before your newest entry
local MAX_ENTRIES = 150           -- per request
local CLAIM_WINDOW = 30           -- seconds a claim to answer someone lasts

local claimed = {}                -- requester -> time someone said they'd answer
local refreshPending = false

local function enqueue(target, ...) ns.QueueTo(target, ...) end

------------------------------------------------------------------------
-- Asking for history
------------------------------------------------------------------------
local function newestEntry()
  local newest = 0
  for _, log in ipairs({ ns.db.deathLog, ns.db.killLog }) do
    if log[1] and log[1].t > newest then newest = log[1].t end
  end
  return newest
end

function ns.RequestHistory(announce)
  if not IsInGuild() then return end
  local now = time()
  local since = math.max(now - WINDOW, newestEntry() - OVERLAP)
  if announce then since = now - WINDOW end
  local w = ns.db.wipes or {}
  -- The 0 is where older versions put the duel log.
  ns.Send("HQ", since, w.kills or 0, 0, w.audit or 0)
  if announce then ns.Say("Asking guildmates for the last two days of guild history...") end
end

table.insert(ns.OnGuildReady, function()
  C_Timer.After(10, function() ns.RequestHistory(false) end)
end)

------------------------------------------------------------------------
-- Answering someone else's request
------------------------------------------------------------------------
local function collect(since)
  local out = {}
  for _, e in ipairs(ns.db.deathLog) do
    if e.t > since then
      out[#out + 1] = { e.t, "HD", e.t, e.who, e.kind, e.sub or "", e.zone, e.killer or "", e.level or 0,
        e.mapID or "", e.x and ("%.4f"):format(e.x) or "", e.y and ("%.4f"):format(e.y) or "" }
    end
  end
  for _, k in ipairs(ns.db.killLog) do
    if k.t > since then
      out[#out + 1] = { k.t, "HK", k.t, k.kind, k.victim, k.zone, table.concat(k.killers, ",") }
    end
  end
  table.sort(out, function(a, b) return a[1] > b[1] end) -- newest first
  while #out > MAX_ENTRIES do table.remove(out) end
  return out
end

ns.OnMessage("HQ", function(parts, sender)
  if ns.IsMe(sender) then return end
  local since = tonumber(parts[2])
  if not since then return end
  local entries = collect(since)
  -- Clears they missed (only an officer's word is trusted for these).
  local wipes = {}
  if ns.IsAddonOfficer() then
    for _, w in ipairs(ns.WIPE_LOGS) do
      local which, position = w[1], w[2]
      local mine = ns.db.wipes[which] or 0
      if mine > (tonumber(parts[position]) or 0) then wipes[#wipes + 1] = { which, mine } end
    end
  end
  if #entries == 0 and #wipes == 0 then return end
  local who = ns.fullName(sender)
  -- Wait a moment; if another guildmate offers to answer first, let them.
  C_Timer.After(1 + math.random() * 4, function()
    local c = claimed[who]
    if c and GetTime() - c < CLAIM_WINDOW then return end
    ns.Send("HS", who)
    for _, w in ipairs(wipes) do enqueue(sender, "HW", w[1], w[2]) end
    for _, e in ipairs(entries) do enqueue(sender, unpack(e, 2)) end
    enqueue(sender, "HE", #entries)
  end)
end)

-- Someone said they'll answer a request.
ns.OnMessage("HS", function(parts)
  if parts[2] then claimed[ns.fullName(parts[2])] = GetTime() end
end)

------------------------------------------------------------------------
-- Receiving history (private messages from a guildmate)
------------------------------------------------------------------------
local received = 0

local function refreshSoon()
  if refreshPending then return end
  refreshPending = true
  C_Timer.After(1, function()
    refreshPending = false
    if ns.RefreshPanel then ns.RefreshPanel() end
    if ns.RefreshMapPins then ns.RefreshMapPins() end
  end)
end

local DEATH_KINDS = {}
for _, t in ipairs(ns.TYPES) do
  if t.group == "death" then DEATH_KINDS[t.key] = true end
end

ns.OnMessage("HD", function(p)
  local t, kind = tonumber(p[2]), p[4]
  if not t or not DEATH_KINDS[kind] or not p[3] or p[3] == "" then return end
  local mapID, x, y = tonumber(p[10]), tonumber(p[11]), tonumber(p[12])
  local valid = mapID and x and y and x >= 0 and x <= 1 and y >= 0 and y <= 1
  if ns.MergeDeath({ t = t, who = p[3], kind = kind, sub = p[5] or "", zone = p[6] or "Unknown",
      killer = p[7] or "", level = tonumber(p[8]) or 0,
      mapID = valid and mapID or nil, x = valid and x or nil, y = valid and y or nil }) then
    received = received + 1
  end
  refreshSoon()
end)

ns.OnMessage("HK", function(p)
  local t, kind = tonumber(p[2]), p[3]
  if not t or (kind ~= "kill_world" and kind ~= "kill_bg") or not p[4] or p[4] == "" then return end
  local killers = {}
  for name in (p[6] or ""):gmatch("[^,]+") do killers[#killers + 1] = name end
  if #killers == 0 then return end
  if ns.MergeKill({ t = t, kind = kind, victim = p[4], zone = p[5] or "Unknown", killers = killers }) then
    received = received + 1
  end
  refreshSoon()
end)

-- End of a batch.
ns.OnMessage("HE", function(_, sender)
  if received > 0 then
    ns.Say(("Caught up on %d guild event%s from %s."):format(received, received == 1 and "" or "s",
      Ambiguate(sender, "short")))
  end
  received = 0
end)
