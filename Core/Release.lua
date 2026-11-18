--[[
  Warcrest
  Release: starts everyone on a clean slate for the release version.

  Everything recorded before the release was test data. The first time a
  player loads this version, their kills, PvP deaths, Wanted sightings,
  raids, sign-ups, DKP and Officer log are cleared (personal settings are
  kept). It only happens once.

  From then on, anything stamped before the release time is refused, so test
  data can't come back from players still on an older version.
]]

local _, ns = ...

ns.RELEASE_ID = "2.1.0"
ns.RELEASE_CUTOFF = 1794592484 -- 13 Nov 2026, 17:54 UTC

-- True for anything recorded before the release.
function ns.BeforeRelease(t)
  return (tonumber(t) or 0) < ns.RELEASE_CUTOFF
end

-- Runs before every other part of the addon sets up its data.
ns.OnLoad(function()
  local db = ns.db
  if db.releaseReset == ns.RELEASE_ID then return end
  local hadData = (db.killLog and #db.killLog > 0) or (db.deathLog and #db.deathLog > 0)
    or (db.ledger and next(db.ledger) ~= nil)
  db.killLog, db.deathLog, db.spotted, db.audit = {}, {}, {}, {}
  db.ledger, db.reminded, db.wantedHidden = {}, {}, {}
  db.session, db.duelLog, db.wipes = nil, nil, nil
  db.releaseReset = ns.RELEASE_ID
  if hadData then
    C_Timer.After(10, function()
      ns.Say("Welcome to the release version! Test data from before launch has been cleared, so everything starts fresh.")
    end)
  end
end)
