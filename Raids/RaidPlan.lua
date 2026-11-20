--[[
  Warcrest
  Raid groups planner: before a raid, officers put the people who signed up
  into groups 1 to 8 (five each) or on the bench. Everyone can see the plan.
  At raid time, Invite sign-ups invites only the planned groups (not the
  bench), and Arrange raid moves everyone into their planned group.

  Ledger entries (officers): RG = { ref (the raid), name, group }, where
  group is 1 to 8, 0 for the bench, or -1 to take someone out of the plan.
  The newest entry for each person counts.
]]

local _, ns = ...
local Ambiguate = ns.Ambiguate

ns.PLAN_GROUPS = 8
ns.PLAN_SLOTS = 5
local BENCH = 0

-- The plan for a raid: { [key] = { name, group } } for everyone placed.
function ns.RaidPlan(eventId)
  local entries = {}
  for _, e in ipairs(ns.LedgerEntries("RG")) do
    if e.ref == eventId then entries[#entries + 1] = e end
  end
  -- In the order they were made (within a second, by each officer's running number).
  local function seq(e) return tonumber(e.id:match("(%d+)$")) or 0 end
  table.sort(entries, function(a, b)
    if a.t ~= b.t then return a.t < b.t end
    if a.a ~= b.a then return a.a < b.a end
    return seq(a) < seq(b)
  end)
  local plan = {}
  for _, e in ipairs(entries) do
    local g = tonumber(e.group) or -1
    if g >= BENCH and g <= ns.PLAN_GROUPS then
      plan[ns.Key(e.name)] = { name = e.name, group = g }
    else
      plan[ns.Key(e.name)] = nil
    end
  end
  return plan
end

-- Who's in each group: groups[1..8] and bench = lists of { name, role, status }.
function ns.RaidPlanGroups(eventId)
  local plan = ns.RaidPlan(eventId)
  local signups, byKey = ns.Signups(eventId)
  local groups, bench, unplaced = {}, {}, {}
  for g = 1, ns.PLAN_GROUPS do groups[g] = {} end
  local roleOrder = { tank = 1, healer = 2, dps = 3 }
  local function info(name)
    local su = byKey[ns.Key(name)]
    return { name = Ambiguate(name, "short"), role = su and su.role or "dps", status = su and su.status or "accept" }
  end
  for _, p in pairs(plan) do
    local i = info(p.name)
    if p.group == BENCH then bench[#bench + 1] = i else table.insert(groups[p.group], i) end
  end
  for _, su in ipairs(signups) do
    if su.status ~= "decline" and not plan[ns.Key(su.name)] then unplaced[#unplaced + 1] = info(su.name) end
  end
  local function sort(list)
    table.sort(list, function(a, b)
      if a.role ~= b.role then return roleOrder[a.role] < roleOrder[b.role] end
      return a.name < b.name
    end)
  end
  for g = 1, ns.PLAN_GROUPS do sort(groups[g]) end
  sort(bench)
  sort(unplaced)
  return groups, bench, unplaced
end

-- Move someone in the plan: group 1-8, 0 for the bench, or nil/-1 to take them out.
function ns.SetPlanGroup(eventId, name, group)
  if not ns.IsAddonOfficer() then ns.Say("Only officers can plan raid groups.") return end
  group = tonumber(group) or -1
  if group >= 1 then
    local groups = ns.RaidPlanGroups(eventId)
    local inIt = false
    for _, p in ipairs(groups[group]) do if ns.Key(p.name) == ns.Key(name) then inIt = true end end
    if inIt then return true end
    if #groups[group] >= ns.PLAN_SLOTS then ns.Say(ns.TF("Group %d is full.", group)) return end
  end
  return ns.LedgerAdd("RG", { ref = eventId, name = Ambiguate(name, "short"), group = group })
end

-- Fill the groups from the sign-ups: tanks first, a healer in each group,
-- then everyone else; anyone who doesn't fit (or said Tentative) goes on the bench.
function ns.AutoPlan(eventId, size)
  if not ns.IsAddonOfficer() then ns.Say("Only officers can plan raid groups.") return end
  size = math.max(5, math.min(40, tonumber(size) or 40))
  local groupsNeeded = math.ceil(size / ns.PLAN_SLOTS)
  local groups, _, unplaced = ns.RaidPlanGroups(eventId)
  local count = {}
  local placed = 0
  for g = 1, ns.PLAN_GROUPS do count[g] = #groups[g]; placed = placed + #groups[g] end
  local byRole = { tank = {}, healer = {}, dps = {} }
  local later = {}
  for _, p in ipairs(unplaced) do
    if p.status == "accept" then table.insert(byRole[p.role], p) else later[#later + 1] = p end
  end
  local function put(p, prefer)
    if placed >= size then
      ns.SetPlanGroup(eventId, p.name, BENCH)
      return
    end
    local order = {}
    if prefer then order[#order + 1] = prefer end
    for g = 1, groupsNeeded do order[#order + 1] = g end
    for _, g in ipairs(order) do
      if count[g] < ns.PLAN_SLOTS then
        count[g] = count[g] + 1
        placed = placed + 1
        ns.SetPlanGroup(eventId, p.name, g)
        return
      end
    end
    ns.SetPlanGroup(eventId, p.name, BENCH)
  end
  for _, p in ipairs(byRole.tank) do put(p, 1) end
  for i, p in ipairs(byRole.healer) do put(p, ((i - 1) % groupsNeeded) + 1) end
  for _, p in ipairs(byRole.dps) do put(p) end
  for _, p in ipairs(later) do ns.SetPlanGroup(eventId, p.name, BENCH) end
  return true
end

function ns.ClearPlan(eventId)
  if not ns.IsAddonOfficer() then return end
  for _, p in pairs(ns.RaidPlan(eventId)) do ns.SetPlanGroup(eventId, p.name, -1) end
end

-- Whether a raid has a plan with anyone in groups 1-8.
function ns.HasRaidPlan(eventId)
  for _, p in pairs(ns.RaidPlan(eventId)) do
    if p.group >= 1 then return true end
  end
  return false
end

------------------------------------------------------------------------
-- Arranging the raid to match the plan
------------------------------------------------------------------------
-- Moves raid members into their planned groups (you need to lead or assist
-- the raid). A few moves a second; swaps when the target group is full.
function ns.ArrangeRaid(eventId)
  if not IsInRaid() then ns.Say("You need to be in a raid group.") return end
  if not (UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")) then
    ns.Say("You need to be raid leader or assistant to move people between groups.")
    return
  end
  if InCombatLockdown() then ns.Say("Groups can't be changed during combat.") return end
  local plan = ns.RaidPlan(eventId)
  local moves = {}
  for i = 1, GetNumGroupMembers() do
    local name, _, subgroup = GetRaidRosterInfo(i)
    local p = name and plan[ns.Key(name)]
    if p and p.group >= 1 and p.group ~= subgroup then moves[#moves + 1] = { index = i, name = name, to = p.group } end
  end
  if #moves == 0 then ns.Say("Everyone in the raid is already in their planned group.") return end
  local done = 0
  local function step()
    local m = table.remove(moves, 1)
    if not m or InCombatLockdown() then
      ns.Say(ns.TF("Arranged the raid: %d moved.", done))
      return
    end
    -- Where everyone is now (indexes can shift after a move).
    local counts, index, inTarget = {}, nil, nil
    for i = 1, GetNumGroupMembers() do
      local name, _, subgroup = GetRaidRosterInfo(i)
      counts[subgroup] = (counts[subgroup] or 0) + 1
      if name and ns.Key(name) == ns.Key(m.name) then index = i end
      if subgroup == m.to and name then
        local p = plan[ns.Key(name)]
        if not p or p.group ~= m.to then inTarget = inTarget or i end
      end
    end
    if index then
      if (counts[m.to] or 0) < 5 then
        SetRaidSubgroup(index, m.to)
        done = done + 1
      elseif inTarget then
        SwapRaidSubgroup(index, inTarget)
        done = done + 1
      end
    end
    C_Timer.After(0.25, step)
  end
  step()
  return true
end
