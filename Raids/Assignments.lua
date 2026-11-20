--[[
  Warcrest
  Raid assignments: who does what on each boss. Tanks on which adds, healers
  on which groups, interrupts, decurses. Officers write them, one plan per
  boss (and one for the whole raid), and they're kept for next week.

  Everyone sees the plans, with their own name picked out, and when a boss
  is pulled (or targeted) Warcrest tells you your job. Officers can post a
  plan to raid chat.

  Shared record: kind RA { raid, enc (the boss), v, part, parts, text }. A plan longer
  than one message is sent in parts; the newest complete plan counts.
]]

local _, ns = ...
local Ambiguate = ns.Ambiguate

local PART = 110          -- characters of plan per entry (a message holds 255 in all)
local MAX_TEXT = 1200     -- characters in a plan
local NEWLINE = "~"       -- how a new line is kept in the shared record
local REMIND_QUIET = 30 * 60
local POST_MAX = 12       -- lines posted to raid chat at most

ns.WHOLE_RAID = "Whole raid"

-- The bosses of each raid, in order (raids not listed use the bosses killed).
ns.RAID_BOSS_LIST = {
  ["Molten Core"] = { "Lucifron", "Magmadar", "Gehennas", "Garr", "Shazzrah", "Baron Geddon", "Sulfuron Harbinger",
    "Golemagg the Incinerator", "Majordomo Executus", "Ragnaros" },
  ["Onyxia's Lair"] = { "Onyxia" },
  ["Blackwing Lair"] = { "Razorgore the Untamed", "Vaelastrasz the Corrupt", "Broodlord Lashlayer", "Firemaw", "Ebonroc",
    "Flamegor", "Chromaggus", "Nefarian" },
  ["Zul'Gurub"] = { "High Priestess Jeklik", "High Priest Venoxis", "High Priestess Mar'li", "Bloodlord Mandokir",
    "Edge of Madness", "High Priest Thekal", "Gahz'ranka", "High Priestess Arlokk", "Jin'do the Hexxer", "Hakkar" },
  ["Ruins of Ahn'Qiraj"] = { "Kurinnaxx", "General Rajaxx", "Moam", "Buru the Gorger", "Ayamiss the Hunter",
    "Ossirian the Unscarred" },
  ["Temple of Ahn'Qiraj"] = { "The Prophet Skeram", "Silithid Royalty", "Battleguard Sartura", "Fankriss the Unyielding",
    "Viscidus", "Princess Huhuran", "Twin Emperors", "Ouro", "C'Thun" },
  ["Naxxramas"] = { "Anub'Rekhan", "Grand Widow Faerlina", "Maexxna", "Noth the Plaguebringer", "Heigan the Unclean",
    "Loatheb", "Instructor Razuvious", "Gothik the Harvester", "The Four Horsemen", "Patchwerk", "Grobbulus", "Gluth",
    "Thaddius", "Sapphiron", "Kel'Thuzad" },
}

-- The raids to plan for: the known ones, then any others the guild has been to.
function ns.AssignmentRaids()
  local out, seen = {}, {}
  for _, raid in ipairs({ "Molten Core", "Onyxia's Lair", "Blackwing Lair", "Zul'Gurub", "Ruins of Ahn'Qiraj",
      "Temple of Ahn'Qiraj", "Naxxramas" }) do
    out[#out + 1] = raid
    seen[raid] = true
  end
  for raid in pairs(ns.RAID_BOSSES or {}) do
    if not seen[raid] then out[#out + 1] = raid; seen[raid] = true end
  end
  for _, k in ipairs(ns.BossKills and ns.BossKills() or {}) do
    if k.raid and k.raid ~= "" and not seen[k.raid] then out[#out + 1] = k.raid; seen[k.raid] = true end
  end
  return out
end

-- The bosses of a raid, in order, with "Whole raid" first.
function ns.AssignmentBosses(raid)
  local out, seen = { ns.WHOLE_RAID }, { [ns.WHOLE_RAID] = true }
  for _, b in ipairs(ns.RAID_BOSS_LIST[raid] or {}) do out[#out + 1] = b; seen[b] = true end
  for _, k in ipairs(ns.BossKills and ns.BossKills() or {}) do
    if k.raid == raid and k.name and not seen[k.name] then out[#out + 1] = k.name; seen[k.name] = true end
  end
  -- Plans written for bosses not listed (a raid new to Warcrest).
  for _, plan in pairs(ns.AllAssignments()) do
    if plan.raid == raid and not seen[plan.boss] then out[#out + 1] = plan.boss; seen[plan.boss] = true end
  end
  return out
end

------------------------------------------------------------------------
-- The plans
------------------------------------------------------------------------
local cache, cacheStamp
local function build()
  local stamp = ns.LedgerStamp("RA")
  if cache and cacheStamp == stamp then return cache end
  cache, cacheStamp = {}, stamp
  local versions = {} -- raid \0 boss \0 v -> { parts = {}, total, by, t }
  for _, e in ipairs(ns.LedgerEntries("RA")) do
    if ns.IsOfficerName(e.a) then
      local id = e.raid .. "\0" .. e.enc .. "\0" .. e.v
      local ver = versions[id]
      if not ver then
        ver = { raid = e.raid, boss = e.enc, v = tonumber(e.v) or 0, parts = {}, total = e.parts or 1, by = e.a, t = e.t }
        versions[id] = ver
      end
      ver.parts[e.part or 1] = e.text or ""
    end
  end
  for _, ver in pairs(versions) do
    local complete = true
    for i = 1, ver.total do if not ver.parts[i] then complete = false end end
    local key = ver.raid .. "\0" .. ver.boss
    if complete and (not cache[key] or ver.v > cache[key].v) then
      local text = table.concat(ver.parts, "", 1, ver.total):gsub(NEWLINE, "\n")
      cache[key] = { raid = ver.raid, boss = ver.boss, v = ver.v, text = text, by = ver.by, t = ver.t }
    end
  end
  return cache
end

function ns.AllAssignments() return build() end

-- A boss's plan: { text, by, t }, or nil.
function ns.Assignment(raid, boss)
  local plan = build()[(raid or "") .. "\0" .. (boss or "")]
  if plan and plan.text ~= "" then return plan end
end

-- Save a boss's plan (officers). An empty text clears it.
function ns.SaveAssignment(raid, boss, text)
  if not ns.IsAddonOfficer() then ns.Say("Only officers can write raid assignments.") return end
  if not raid or raid == "" or not boss or boss == "" then return end
  text = (text or ""):gsub("\r", ""):gsub(NEWLINE, "-"):gsub("|", "/")
  text = strtrim(text):sub(1, MAX_TEXT)
  local old = ns.Assignment(raid, boss)
  if (old and old.text or "") == text then return true end
  local stored = text:gsub("\n", NEWLINE)
  local parts = {}
  for i = 1, math.max(1, math.ceil(#stored / PART)) do parts[i] = stored:sub((i - 1) * PART + 1, i * PART) end
  local v = tostring(math.max(GetServerTime(), (old and old.v or 0) + 1))
  for i, chunk in ipairs(parts) do
    ns.LedgerAdd("RA", { raid = raid:sub(1, 40), enc = boss:sub(1, 40), v = v, part = i, parts = #parts, text = chunk })
  end
  return true
end

-- The lines of a plan that name a player (your jobs).
function ns.JobsIn(text, name)
  local out = {}
  name = (Ambiguate(name or "", "short") or ""):lower()
  if name == "" then return out end
  for line in (text or ""):gmatch("[^\n]+") do
    local lower = line:lower()
    if lower:find("%f[%w]" .. name:gsub("(%W)", "%%%1") .. "%f[%W]") then out[#out + 1] = strtrim(line) end
  end
  return out
end

-- The plan for a boss in any raid, by the boss's name.
local function planForBoss(boss)
  for _, plan in pairs(build()) do
    if plan.boss == boss and plan.text ~= "" then return plan end
  end
end

------------------------------------------------------------------------
-- Telling you your job when the boss is pulled or targeted
------------------------------------------------------------------------
local reminded = {} -- boss -> GetTime()
local function remind(boss)
  local plan = boss and planForBoss(boss)
  if not plan then return end
  if reminded[boss] and GetTime() - reminded[boss] < REMIND_QUIET then return end
  local jobs = ns.JobsIn(plan.text, UnitName("player"))
  if #jobs == 0 then return end
  reminded[boss] = GetTime()
  ns.Say(ns.TF("Your job on %s:", "|cffffffff" .. boss .. "|r"))
  for i = 1, math.min(3, #jobs) do print("   " .. jobs[i]) end
end
ns.RemindAssignment = remind

ns.OnEvent("ENCOUNTER_START", function(_, name) if IsInRaid() then remind(name) end end)
ns.OnEvent("PLAYER_TARGET_CHANGED", function()
  if not IsInRaid() or not UnitExists("target") or UnitIsPlayer("target") then return end
  local class = UnitClassification and UnitClassification("target")
  if class ~= "worldboss" and class ~= "elite" and class ~= "rareelite" then return end
  remind(UnitName("target"))
end)

------------------------------------------------------------------------
-- Posting a plan to raid chat (officers)
------------------------------------------------------------------------
function ns.PostAssignment(raid, boss)
  local plan = ns.Assignment(raid, boss)
  if not plan or not ns.IsAddonOfficer() then return end
  local channel = IsInRaid() and "RAID" or (IsInGroup() and "PARTY") or nil
  if not channel then ns.Say("Join a raid or group to post assignments.") return end
  local lines = { "[" .. boss .. "]" }
  for line in plan.text:gmatch("[^\n]+") do
    if strtrim(line) ~= "" and #lines <= POST_MAX then lines[#lines + 1] = strtrim(line):sub(1, 250) end
  end
  for i, line in ipairs(lines) do
    C_Timer.After((i - 1) * 0.4, function() SendChatMessage(line, channel) end)
  end
  return true
end
