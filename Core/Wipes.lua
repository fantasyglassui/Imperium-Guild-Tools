--[[
  Bannerhold
  Wipes: the guild leader can clear the Kills and Officer logs for the
  whole guild.

  A clear wipes everything recorded up to that moment, on every guildmate's
  copy, and stops older entries coming back through shared history. Only a
  clear from the guild leader is accepted. Guildmates who were offline get it
  when they next catch up, passed along by an officer.
]]

local _, ns = ...

local LOGS = {
  kills = { db = "killLog", label = "kill log" },
  audit = { db = "audit",   label = "officer log" },
}
-- Each log and where its clear time sits in a catch-up request.
ns.WIPE_LOGS = { { "kills", 3 }, { "audit", 5 } }

ns.OnLoad(function()
  ns.db.wipes = ns.db.wipes or {}
  for which in pairs(LOGS) do ns.db.wipes[which] = ns.db.wipes[which] or 0 end
end)

function ns.IsGuildMaster()
  return ns.MyRank() == 0
end

-- True if an entry from this time was cleared by the guild leader.
function ns.IsWiped(which, t)
  if ns.BeforeRelease(t) then return true end
  return ns.db.wipes and t <= (ns.db.wipes[which] or 0)
end

local function apply(which, stamp)
  local info = LOGS[which]
  if not info or stamp <= (ns.db.wipes[which] or 0) then return false end
  ns.db.wipes[which] = stamp
  local log = ns.db[info.db] or {}
  for i = #log, 1, -1 do
    if log[i].t <= stamp then table.remove(log, i) end
  end
  if ns.OnHistoryChanged then ns.OnHistoryChanged() end
  if ns.RefreshPanel then ns.RefreshPanel() end
  return true
end

-- The guild leader clears a log for everyone.
function ns.WipeLog(which)
  if not ns.IsGuildMaster() then
    ns.Say("Only the Guild Master can clear the logs.")
    return
  end
  local stamp = GetServerTime()
  apply(which, stamp)
  ns.Send("W", which, stamp)
  ns.Say(("The %s was cleared for the whole guild."):format(LOGS[which].label))
end

-- Straight from the guild leader.
ns.OnMessage("W", function(p, sender)
  if ns.RankOf(sender) ~= 0 then return end
  if apply(p[2], tonumber(p[3]) or 0) and not ns.IsMe(sender) then
    ns.Say(("%s cleared the guild's %s."):format(Ambiguate(sender, "short"), LOGS[p[2]].label))
  end
end)

-- Passed along during catch-up: only trusted from officers.
ns.OnMessage("HW", function(p, sender)
  if not ns.IsOfficerName(sender) then return end
  apply(p[2], tonumber(p[3]) or 0)
end)
