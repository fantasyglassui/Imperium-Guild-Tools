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

ns.OnLoad(function()
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
