--[[
  Warcrest
  Attunements and keys: who in the guild can enter which raid.

  The game knows which quests a character has finished, so Warcrest checks
  the attunement and key quests by itself (at login and whenever a quest is
  handed in) and shares what it finds. Nobody fills anything in. Officers
  see who's attuned in the Attunements window (Raids tab, Progress view, or
  /warcrest attune), and raid sign-ups flag anyone not attuned for that raid.

  Shared record: kind AN { list }, each member's own, the latest counts.
]]

local _, ns = ...
local Ambiguate = ns.Ambiguate

local MAX_LEVEL = 60

-- quests: finishing any of them counts (Alliance and Horde versions, or the
-- Naxxramas ones by reputation). raid: the raid it opens, for sign-ups.
ns.ATTUNEMENTS = {
  { key = "mc",     name = "Molten Core",           short = "MC",     quests = { 7848 },             raid = "Molten Core" },
  { key = "ony",    name = "Onyxia's Lair",         short = "Ony",    quests = { 6502, 6602 },       raid = "Onyxia's Lair" },
  { key = "bwl",    name = "Blackwing Lair",        short = "BWL",    quests = { 7761 },             raid = "Blackwing Lair" },
  { key = "naxx",   name = "Naxxramas",             short = "Naxx",   quests = { 9121, 9122, 9123 }, raid = "Naxxramas" },
  { key = "ubrs",   name = "Upper Blackrock Spire", short = "UBRS",   quests = { 4743 },             isKey = true },
  { key = "scholo", name = "Scholomance",           short = "Scholo", quests = { 5505, 5511 },       isKey = true },
}
local BY_KEY = {}
for _, a in ipairs(ns.ATTUNEMENTS) do BY_KEY[a.key] = a end

------------------------------------------------------------------------
-- Your own: from the quests you've finished
------------------------------------------------------------------------
local function questDone(id)
  if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
    local ok, done = pcall(C_QuestLog.IsQuestFlaggedCompleted, id)
    if ok then return done and true or false end
  end
  if IsQuestFlaggedCompleted then
    local ok, done = pcall(IsQuestFlaggedCompleted, id)
    if ok then return done and true or false end
  end
  return false
end

-- The attunements you have, as a sorted "mc,ony" list.
function ns.MyAttunements()
  local have = {}
  for _, a in ipairs(ns.ATTUNEMENTS) do
    for _, q in ipairs(a.quests) do
      if questDone(q) then have[#have + 1] = a.key break end
    end
  end
  table.sort(have)
  return table.concat(have, ",")
end

------------------------------------------------------------------------
-- Everyone's, from the shared record
------------------------------------------------------------------------
local cache, cacheStamp
local function build()
  local stamp = ns.LedgerStamp("AN")
  if cache and cacheStamp == stamp then return cache end
  cache, cacheStamp = {}, stamp
  for _, e in ipairs(ns.LedgerEntries("AN")) do -- oldest first: the latest counts
    local set = {}
    for k in tostring(e.list or ""):gmatch("[^,]+") do
      if BY_KEY[k] then set[k] = true end
    end
    cache[ns.Key(e.a)] = { set = set, t = e.t }
  end
  return cache
end

-- A member's attunements: { mc = true, ... } and when they were last shared,
-- or nil if their addon hasn't shared any yet.
function ns.AttunementsOf(name)
  local r = name and build()[ns.Key(name)]
  if r then return r.set, r.t end
end

function ns.IsAttuned(name, key)
  local set = ns.AttunementsOf(name)
  return set ~= nil and set[key] == true
end

-- The attunement a raid needs (by its name), or nil.
function ns.AttunementForRaid(raid)
  if type(raid) ~= "string" then return nil end
  local lower = raid:lower()
  for _, a in ipairs(ns.ATTUNEMENTS) do
    if a.raid and (lower == a.raid:lower() or lower:find(a.raid:lower(), 1, true)
        or lower:find("%f[%a]" .. a.short:lower() .. "%f[%A]")) then
      return a
    end
  end
end

-- The guild's attunements: { { name, classFile, level, online, set, known } }, by name.
function ns.GuildAttunements(maxLevelOnly)
  local out = {}
  for _, m in ipairs(ns.GetRoster()) do
    if not maxLevelOnly or (m.level or 0) >= MAX_LEVEL then
      local set = ns.AttunementsOf(m.name)
      out[#out + 1] = { name = Ambiguate(m.name, "short"), classFile = m.classFile, level = m.level, online = m.online,
        set = set or {}, known = set ~= nil }
    end
  end
  table.sort(out, function(a, b)
    if a.known ~= b.known then return a.known end
    return a.name < b.name
  end)
  return out
end

-- How many are attuned for each: { mc = 12, ... }, and how many shared at all.
function ns.AttunementCounts(maxLevelOnly)
  local counts, known = {}, 0
  for _, r in ipairs(ns.GuildAttunements(maxLevelOnly)) do
    if r.known then
      known = known + 1
      for k in pairs(r.set) do counts[k] = (counts[k] or 0) + 1 end
    end
  end
  return counts, known
end

------------------------------------------------------------------------
-- Sharing yours when it changes
------------------------------------------------------------------------
local function check(quiet)
  if not ns.db or not IsInGuild() then return end
  local mine = ns.MyAttunements()
  local shared = build()[ns.Key(UnitName("player"))]
  local before = {}
  if shared then for k in pairs(shared.set) do before[#before + 1] = k end end
  table.sort(before)
  if shared and table.concat(before, ",") == mine then return end
  ns.LedgerAdd("AN", { list = mine })
  -- A new one: tell the guild (not the first time Warcrest looks).
  if shared and not quiet then
    for k in mine:gmatch("[^,]+") do
      if not shared.set[k] then
        local a = BY_KEY[k]
        ns.Send("AA", k)
        ns.Say(ns.TF("You're now attuned: %s.", ns.T(a.name)))
      end
    end
  end
end
ns.CheckAttunements = check

table.insert(ns.OnGuildReady, function() C_Timer.After(20, function() check(true) end) end)
ns.OnEvent("QUEST_TURNED_IN", function() C_Timer.After(2, function() check(false) end) end)

-- A guildmate got a new attunement.
ns.OnMessage("AA", function(p, sender)
  local a = BY_KEY[p[2] or ""]
  if not a or ns.IsMe(sender) then return end
  -- With the level-up celebrations: the guild cheering each other on.
  local c, show = ns.cfg, ns.db.show
  if c and c.enabled and ((c.types.level_ten and show.level_ten) or (c.types.level_all and show.level_all)) then
    ns.Notify(ns.TF("%s is now attuned: %s.", Ambiguate(sender, "short"), ns.T(a.name)), nil, nil, nil, "celebrate", "Attunement")
  end
end)
