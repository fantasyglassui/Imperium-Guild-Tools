--[[
  Warcrest
  Looking after Warcrest's saved data (WarcrestDB).

  The game writes saved data when you log out. Two things are done here so
  your history is never lost:

    - Before the game writes it, anything it can't save is taken out. (Newer
      game clients have "secret" values, like some names in instances, that
      can't be written to saved data; one of those could stop the whole save.)

    - A small second record (WarcrestState) notes how much history there was.
      If Warcrest starts and its data is gone though there was some last time
      (the game didn't keep it), you're told, and your addon asks the guild
      for everything it can send back: the guild record (raids, DKP, sign-ups,
      achievements) comes back from officers, and up to 60 days of kills and
      deaths from any guildmate.
]]

local _, ns = ...

local function count(t)
  local n = 0
  if type(t) == "table" then for _ in pairs(t) do n = n + 1 end end
  return n
end

-- How much history there is right now.
local function sizes(db)
  return { kills = count(db.killLog), deaths = count(db.deathLog), ledger = count(db.ledger),
    achievements = count(db.achievements) }
end

-- Older copies of Warcrest's history, saved under its earlier names. If one is
-- still there with history in it, everything in it that's missing here is
-- added (once): kills, deaths, the guild record and achievements.
local OLD_COPIES = { { "BannerholdDB", "Bannerhold" }, { "TheImperiumDB", "TheImperium" } }
local LOG_MAX = { killLog = 2000, deathLog = 500 }

local function hasHistory(src)
  return type(src) == "table" and not src.movedToWarcrest
    and (count(src.killLog) + count(src.deathLog) + count(src.ledger) + count(src.achievements)) > 0
end

local function mergeLog(dst, src, max, who)
  if type(src) ~= "table" then return 0 end
  local have, added = {}, 0
  for _, e in ipairs(dst) do have[ns.Key(e[who]) .. ":" .. tostring(e.t)] = true end
  for _, e in ipairs(src) do
    if type(e) == "table" and tonumber(e.t) then
      local tag = ns.Key(e[who]) .. ":" .. tostring(e.t)
      if not have[tag] then dst[#dst + 1] = e; have[tag] = true; added = added + 1 end
    end
  end
  if added > 0 then
    table.sort(dst, function(a, b) return a.t > b.t end)
    while #dst > max do table.remove(dst) end
  end
  return added
end

local function mergeOld(db, src)
  local added = 0
  db.killLog, db.deathLog = db.killLog or {}, db.deathLog or {}
  db.ledger, db.achievements = db.ledger or {}, db.achievements or {}
  added = added + mergeLog(db.killLog, src.killLog, LOG_MAX.killLog, "victim")
  added = added + mergeLog(db.deathLog, src.deathLog, LOG_MAX.deathLog, "who")
  for id, e in pairs(type(src.ledger) == "table" and src.ledger or {}) do
    if type(e) == "table" and not db.ledger[id] then db.ledger[id] = e; added = added + 1 end
  end
  for k, ids in pairs(type(src.achievements) == "table" and src.achievements or {}) do
    if type(ids) == "table" then
      db.achievements[k] = db.achievements[k] or {}
      for id, t in pairs(ids) do
        local old = db.achievements[k][id]
        if not old then added = added + 1 end
        if not old or (tonumber(t) and tonumber(t) < old) then db.achievements[k][id] = tonumber(t) or 0 end
      end
    end
  end
  -- Settings only where this copy has none of its own.
  for key, v in pairs(src) do
    if db[key] == nil and key ~= "movedToWarcrest" and key ~= "movedToBannerhold" then db[key] = v end
  end
  return added
end

local function mergeOldCopies()
  local getMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
  local total = 0
  for _, old in ipairs(OLD_COPIES) do
    local name, folder = old[1], old[2]
    local src = _G[name]
    if src ~= ns.db and hasHistory(src) then
      total = total + mergeOld(ns.db, src)
      -- Empty it only when it's the hand-over folder, not an old copy of the full addon.
      if getMeta and getMeta(folder, "X-Warcrest-Handover") == "1" then
        _G[name] = { movedToWarcrest = time() }
      else
        src.movedToWarcrest = time()
      end
    end
  end
  return total
end

ns.OnLoad(function()
  local found = mergeOldCopies()
  if found > 0 then
    ns.foundOldHistory = found
    C_Timer.After(10, function()
      ns.Say("Found history Warcrest had saved under an older name, and added it back.")
    end)
  end
  local last = type(WarcrestState) == "table" and WarcrestState or nil
  local now = sizes(ns.db)
  local had = last and ((last.kills or 0) + (last.deaths or 0) + (last.ledger or 0)) or 0
  local has = now.kills + now.deaths + now.ledger
  if had > 0 and has == 0 then
    -- The saved data didn't come back.
    ns.db.lostDataAt = time()
    ns.dataWasLost = true
    C_Timer.After(12, function()
      ns.Say("Warcrest's saved history didn't load this time (the game didn't keep it). "
        .. "Asking your guild to send it back; it fills in over the next few minutes.")
      if ns.RequestHistory then ns.RequestHistory(false, true) end
      if ns.RequestLedger then ns.RequestLedger() end
    end)
  end
end)

-- Take out anything the game can't write (secret values, functions), so the save never fails.
local function clean(t, depth, seen)
  if depth > 12 or seen[t] then return end
  seen[t] = true
  for k, v in pairs(t) do
    local bad = (issecretvalue and (issecretvalue(k) or issecretvalue(v)))
      or type(v) == "function" or type(v) == "userdata" or type(v) == "thread"
    if bad then
      t[k] = nil
    elseif type(v) == "table" then
      clean(v, depth + 1, seen)
    end
  end
end

ns.OnEvent("PLAYER_LOGOUT", function()
  if not ns.db then return end
  pcall(clean, ns.db, 0, {})
  local s = sizes(ns.db)
  s.savedAt, s.version = time(), ns.version
  WarcrestState = s
end)
