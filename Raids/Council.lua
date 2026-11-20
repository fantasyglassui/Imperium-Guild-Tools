--[[
  Warcrest
  Loot council: officers decide who gets an item, instead of (or as well as)
  DKP bidding. Works whether or not the guild uses DKP.

  1. An officer (the loot master) starts a vote for an item in the raid.
  2. Everyone in the raid with Warcrest says Need, Greed or Pass.
  3. Officers in the raid see who wants it, with their wishlist, attendance,
     recent loot and DKP, and vote for one of them.
  4. The loot master awards it (usually to the most votes). It's recorded in
     the loot history like any other item, for 0 DKP.

  Raid messages:
    L1  a vote opened: id, item link, seconds to say Need/Greed/Pass
    L2  a raid member's answer: id, need | greed | pass
    L3  an officer's vote: id, candidate ("" to take it back)
    L4  the result: id, winner ("" if cancelled)
]]

local _, ns = ...

local ANSWER_TIME = 60
local CHOICES = { need = 1, greed = 2, pass = 3 }
ns.COUNCIL_CHOICES = CHOICES

ns.council = nil -- the vote in your raid: { id, link, by, ends, answers = {}, votes = {}, done, winner }

local function refresh()
  if ns.RefreshCouncilWindow then ns.RefreshCouncilWindow() end
end

local function short(name) return Ambiguate(name or "", "short") end

-- The officer running the vote (it's yours to award).
function ns.IsLootMaster()
  local c = ns.council
  return c ~= nil and ns.IsMe(c.by)
end

------------------------------------------------------------------------
-- Starting, answering, voting, awarding
------------------------------------------------------------------------
function ns.StartCouncil(link, seconds)
  if not ns.IsAddonOfficer() then ns.Say("Only officers can start a loot council vote.") return end
  if not IsInRaid() then ns.Say("You need to be in a raid group to start a loot council vote.") return end
  if ns.council and not ns.council.done then ns.Say("A loot council vote is already open.") return end
  link = strtrim(link or "")
  if link == "" then ns.Say("Put an item in first: Shift-click it into the item box.") return end
  seconds = math.max(15, math.min(300, math.floor(tonumber(seconds) or ANSWER_TIME)))
  local id = tostring(GetServerTime())
  ns.SendRaid("L1", id, link, seconds)
  return true
end

function ns.CouncilAnswer(choice)
  local c = ns.council
  if not c or c.done or not CHOICES[choice] then return end
  ns.SendRaid("L2", c.id, choice)
end

function ns.CouncilVote(candidate)
  local c = ns.council
  if not c or c.done or not ns.IsAddonOfficer() then return end
  local mine = c.votes[short(UnitName("player"))]
  ns.SendRaid("L3", c.id, (mine and ns.Key(mine) == ns.Key(candidate)) and "" or short(candidate))
end

function ns.CouncilAward(winner)
  local c = ns.council
  if not c or c.done or not ns.IsLootMaster() then return end
  winner = short(winner)
  if winner ~= "" then
    ns.LedgerAdd("DK", { amount = 0, names = winner, reason = "Won " .. c.link .. " (council)" })
  end
  ns.SendRaid("L4", c.id, winner)
end

function ns.CancelCouncil()
  local c = ns.council
  if not c or c.done or not ns.IsLootMaster() then return end
  ns.SendRaid("L4", c.id, "")
end

------------------------------------------------------------------------
-- What the council sees for each candidate
------------------------------------------------------------------------
-- The candidates: everyone who answered Need or Greed, Need first, then by
-- votes. { name, choice, votes, wish ("need"/"want"/nil), attended, raids,
-- items (won in the last 30 days), dkp }.
function ns.CouncilCandidates()
  local c = ns.council
  if not c then return {} end
  local votes = {}
  for _, candidate in pairs(c.votes) do votes[ns.Key(candidate)] = (votes[ns.Key(candidate)] or 0) + 1 end
  local since, recent = GetServerTime() - 30 * 86400, {}
  for _, l in ipairs(ns.LootHistory()) do
    if l.t >= since then recent[ns.Key(l.winner)] = (recent[ns.Key(l.winner)] or 0) + 1 end
  end
  local out = {}
  for name, choice in pairs(c.answers) do
    if choice ~= "pass" then
      local wish = ns.WishFor and ns.WishFor(name, c.link)
      local attended, raids = ns.Attendance(name)
      out[#out + 1] = { name = name, choice = choice, votes = votes[ns.Key(name)] or 0, wish = wish and wish.prio,
        attended = attended, raids = raids, items = recent[ns.Key(name)] or 0, dkp = ns.Balance(name) }
    end
  end
  table.sort(out, function(a, b)
    if a.choice ~= b.choice then return CHOICES[a.choice] < CHOICES[b.choice] end
    if a.votes ~= b.votes then return a.votes > b.votes end
    return a.name < b.name
  end)
  return out
end

------------------------------------------------------------------------
-- Messages
------------------------------------------------------------------------
ns.OnMessage("L1", function(p, sender)
  if not ns.IsOfficerName(sender) then return end
  ns.council = { id = p[2], link = p[3] or "", by = short(sender), ends = GetTime() + (tonumber(p[4]) or ANSWER_TIME),
    answers = {}, votes = {} }
  if ns.ShowCouncilWindow then ns.ShowCouncilWindow() end
  local wish = ns.WishFor and ns.WishFor(UnitName("player"), ns.council.link)
  ns.Say(ns.TF("Loot council: %s. Say Need, Greed or Pass in the window.", ns.council.link)
    .. (wish and (" " .. ns.T("It's on your wishlist.")) or ""))
end)

ns.OnMessage("L2", function(p, sender)
  local c = ns.council
  if not c or c.id ~= p[2] or c.done or not CHOICES[p[3]] then return end
  if GetTime() > c.ends + 2 then return end -- too late (2 seconds' grace for lag)
  c.answers[short(sender)] = p[3]
  refresh()
end)

ns.OnMessage("L3", function(p, sender)
  local c = ns.council
  if not c or c.id ~= p[2] or c.done or not ns.IsOfficerName(sender) then return end
  local candidate = p[3] or ""
  c.votes[short(sender)] = candidate ~= "" and candidate or nil
  refresh()
end)

ns.OnMessage("L4", function(p, sender)
  local c = ns.council
  if not c or c.id ~= p[2] or ns.Key(sender) ~= ns.Key(c.by) then return end
  c.done = true
  c.winner = (p[3] and p[3] ~= "") and p[3] or nil
  if c.winner then
    ns.Say(ns.TF("%s gets %s (loot council).", c.winner, c.link))
  else
    ns.Say("Loot council vote for " .. c.link .. " was cancelled.")
  end
  refresh()
  C_Timer.After(8, function()
    if ns.council == c and ns.HideCouncilWindow then ns.HideCouncilWindow() end
  end)
end)
