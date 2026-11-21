--[[
  Warcrest
  Raid night recap: when an officer ends a raid night (End raid on the Raids
  tab), everyone in the guild gets a short summary in chat: how long it ran,
  the bosses killed (guild firsts marked), the loot and who won it, how many
  attended, and what you earned. A banner says it's there.

  Everything comes from the shared record (raid start and end, attendance,
  boss kills, DKP and loot), so everyone sees the same recap.
  /warcrest raidrecap shows the last raid night's again.
]]

local _, ns = ...
local Ambiguate = ns.Ambiguate

local HEADER = "|cff66ccff"
local FRESH = 30 * 60 -- only raid nights that ended in the last half hour are announced

-- The raid nights (RS entries) that have ended, newest first, with when they ended.
local function endedNights()
  local ends = {}
  for _, e in ipairs(ns.LedgerEntries("RE")) do ends[e.ref] = e end
  local out = {}
  local starts = ns.LedgerEntries("RS")
  for i = #starts, 1, -1 do
    local s = starts[i]
    if ends[s.id] then out[#out + 1] = { session = s, ended = ends[s.id] } end
  end
  return out
end

-- The recap of one raid night (an RS entry): { title, from, to, attended,
-- standby, bosses (oldest first), loot (oldest first), dkp (name key -> earned) }.
function ns.RaidNightRecap(s, endT)
  local to = endT or (s.t + 12 * 3600)
  local r = { id = s.id, title = s.title ~= "" and s.title or "Raid night", from = s.t, to = to,
    attended = 0, standby = {}, bosses = {}, loot = {}, dkp = {} }

  local standby = ns.Standby(s.id)
  for _, name in pairs(standby) do r.standby[#r.standby + 1] = Ambiguate(name, "short") end
  table.sort(r.standby)
  for k in pairs(ns.AttendedSet(s)) do
    if not standby[k] then r.attended = r.attended + 1 end
  end

  local kills = ns.BossKills(s.t, to + 60)
  for i = #kills, 1, -1 do r.bosses[#r.bosses + 1] = kills[i] end

  local loot = ns.LootHistory()
  for i = #loot, 1, -1 do
    local l = loot[i]
    if l.t >= s.t and l.t <= to + 60 then r.loot[#r.loot + 1] = l end
  end

  -- DKP earned (awards only, not spending; undone changes don't count).
  local undone = ns.UndoneSet()
  for _, e in ipairs(ns.LedgerEntries("DK")) do
    if e.t >= s.t and e.t <= to + 60 and e.amount > 0 and not undone[e.id] then
      for name in e.names:gmatch("[^,]+") do
        local k = ns.Key(ns.MainOf(name))
        r.dkp[k] = (r.dkp[k] or 0) + e.amount
      end
    end
  end
  return r
end

local function duration(seconds)
  local m = math.floor(seconds / 60 + 0.5)
  if m < 60 then return ns.TF("%d min", m) end
  return ns.TF("%dh %02dm", math.floor(m / 60), m % 60)
end

-- The recap as chat lines.
function ns.RaidNightRecapLines(r)
  local lines = {}
  if #r.bosses > 0 then
    local names = {}
    for _, b in ipairs(r.bosses) do
      names[#names + 1] = b.name .. (b.first and (" |cffd4af37(" .. ns.T("guild first!") .. ")|r") or "")
    end
    lines[#lines + 1] = ns.TF("Bosses (%d): %s", #r.bosses, table.concat(names, ", "))
  else
    lines[#lines + 1] = ns.T("Bosses: none killed.")
  end
  if #r.loot > 0 then
    local items = {}
    for _, l in ipairs(r.loot) do
      local how = l.council and ns.T("council") or (l.roll and ns.T("roll"))
        or (l.amount > 0 and ns.TF("%d DKP", l.amount)) or nil
      items[#items + 1] = ns.TF("%s to %s", l.item, l.winner) .. (how and (" (" .. how .. ")") or "")
    end
    lines[#lines + 1] = ns.TF("Loot (%d): %s", #r.loot, table.concat(items, ", "))
  end
  local who = ns.TF("Raiders: %d attended", r.attended)
  if #r.standby > 0 then who = who .. ns.TF(", %d on standby (%s)", #r.standby, table.concat(r.standby, ", ")) end
  lines[#lines + 1] = who .. "."
  if ns.UsesDKP() then
    local mine = r.dkp[ns.Key(ns.MainOf(UnitName("player")))]
    if mine then lines[#lines + 1] = ns.TF("You earned %d DKP.", mine) end
  end
  return lines
end

-- Short version for the banner.
function ns.RaidNightRecapSummary(r)
  local parts = { ns.TF("%d bosses", #r.bosses), ns.TF("%d items", #r.loot), ns.TF("%d raiders", r.attended) }
  if #r.bosses == 1 then parts[1] = ns.T("1 boss") end
  if #r.loot == 1 then parts[2] = ns.T("1 item") end
  return r.title .. ": " .. table.concat(parts, ", ")
end

function ns.PrintRaidNightRecap(r)
  ns.Say(HEADER .. ns.TF("Raid night recap: %s", r.title) .. "|r  (" .. ns.Date("%a %b %d", r.from) .. ", "
    .. duration(r.to - r.from) .. ")")
  for _, line in ipairs(ns.RaidNightRecapLines(r)) do print("  " .. line) end
end

-- /warcrest raidrecap: the last raid night's recap.
function ns.ShowLastRaidNight()
  local last = endedNights()[1]
  if not last then ns.Say("No raid nights yet. Officers start one with Start raid in Raids.") return end
  ns.PrintRaidNightRecap(ns.RaidNightRecap(last.session, last.ended.t))
end

------------------------------------------------------------------------
-- Announcing it when a raid night ends
------------------------------------------------------------------------
local seen = {}
local ready = false

local function wanted()
  local c, show = ns.cfg, ns.db.show
  return c.enabled and c.types.raid_recap and show.raid_recap
end

local function announce(quiet)
  for _, n in ipairs(endedNights()) do
    local id = n.session.id
    if not seen[id] then
      seen[id] = true
      if ready and not quiet and GetServerTime() - n.ended.t < FRESH then
        -- Give the last loot and kills a moment to arrive.
        C_Timer.After(8, function()
          if not wanted() then return end
          local r = ns.RaidNightRecap(n.session, n.ended.t)
          if r.attended == 0 and #r.bosses == 0 and #r.loot == 0 then return end
          ns.PrintRaidNightRecap(r)
          if ns.AlertStyle() == "banner" and ns.ShowBanner and not ns.IsQuiet() then
            ns.ShowBanner("raid", ns.RaidNightRecapSummary(r), "Raid night recap")
          end
        end)
      end
    end
  end
end

table.insert(ns.OnGuildReady, function()
  announce(true)
  ready = true
end)

ns.OnLoad(function()
  ns.OnLedgerChanged(function() announce() end)
end)
