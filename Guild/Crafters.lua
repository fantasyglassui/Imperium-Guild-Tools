--[[
  Warcrest
  The crafters directory: who in the guild can make what.

  When you open a profession window, the recipes you know are noted and sent
  to the guild (only when they change). Guildmates keep everyone's lists, and
  ask whoever's online for theirs when they log in, so the directory fills in
  over time. Search it by name, filter by profession, and whisper a crafter.

  Recipes are kept as item IDs (or "e" and a spell ID for enchants), so they
  read in your own language. Messages: CR (a part of someone's list) and CQ
  (asking guildmates for theirs).
]]

local _, ns = ...

local CHUNK = 160                  -- characters of recipe IDs per message
local KEEP_DAYS = 180              -- lists not updated for this long are dropped
local ANSWER_QUIET = 300           -- seconds before answering the same guildmate again
local MAX_PROFS = 6

ns.OnLoad(function()
  ns.db.crafters = ns.db.crafters or {}     -- key -> { name, profs = { [prof] = { rank, max, v, ids = { id, ... } } } }
  ns.db.myCrafts = ns.db.myCrafts or {}     -- prof -> { rank, max, v, ids = { id = true } }
  ns.db.craftNames = ns.db.craftNames or {} -- id -> name (in your language), so lists search fast
  local cutoff = time() - KEEP_DAYS * 86400
  for k, c in pairs(ns.db.crafters) do
    for prof, p in pairs(c.profs or {}) do
      if (p.v or 0) < cutoff then c.profs[prof] = nil end
    end
    if not next(c.profs or {}) then ns.db.crafters[k] = nil end
  end
end)

local version = 0
function ns.CraftersVersion() return version end
local function changed()
  version = version + 1
  if ns.RefreshCrafters then ns.RefreshCrafters() end
end

------------------------------------------------------------------------
-- Storing a list
------------------------------------------------------------------------
local function store(name, prof, rank, max, v, ids)
  local k = ns.Key(name)
  local c = ns.db.crafters[k]
  if not c then
    c = { name = Ambiguate(name, "short"), profs = {} }
    ns.db.crafters[k] = c
  end
  local old = c.profs[prof]
  if old and (old.v or 0) >= v then return false end
  -- A guildmate can't fill the directory with professions.
  if not old then
    local n = 0
    for _ in pairs(c.profs) do n = n + 1 end
    if n >= MAX_PROFS then return false end
  end
  c.profs[prof] = { rank = rank, max = max, v = v, ids = ids }
  changed()
  return true
end

------------------------------------------------------------------------
-- Sending and receiving lists
------------------------------------------------------------------------
-- The message parts for one list: CR, owner, prof, rank, max, v, part, total, ids.
local function parts(owner, prof, p)
  local ids = {}
  for _, id in ipairs(p.ids) do ids[#ids + 1] = id end
  local chunks, cur = {}, ""
  for _, id in ipairs(ids) do
    if #cur + #id + 1 > CHUNK then chunks[#chunks + 1] = cur; cur = "" end
    cur = cur == "" and id or (cur .. "," .. id)
  end
  chunks[#chunks + 1] = cur
  local out = {}
  for i, chunk in ipairs(chunks) do
    out[i] = { "CR", owner, prof, p.rank, p.max, p.v, i, #chunks, chunk }
  end
  return out
end

local function sortedIds(set)
  local list = {}
  for id in pairs(set) do list[#list + 1] = id end
  table.sort(list)
  return list
end

local function myLists()
  local out = {}
  for prof, p in pairs(ns.db.myCrafts or {}) do
    out[prof] = { rank = p.rank, max = p.max, v = p.v, ids = sortedIds(p.ids) }
  end
  return out
end

local function sendMine(to)
  local me = UnitName("player")
  for prof, p in pairs(myLists()) do
    for _, msg in ipairs(parts(me, prof, p)) do
      if to then ns.QueueTo(to, unpack(msg)) else ns.Send(unpack(msg)) end
    end
  end
end

local pending = {} -- owner:prof:v -> { got = n, total, chunks = {} }
ns.OnMessage("CR", function(p, sender)
  local owner, prof = p[2], p[3]
  local rank, max, v = tonumber(p[4]) or 0, tonumber(p[5]) or 0, tonumber(p[6]) or 0
  local part, total = tonumber(p[7]) or 0, tonumber(p[8]) or 0
  if not owner or owner == "" or not prof or prof == "" or v <= 0 then return end
  if part < 1 or total < 1 or part > total or total > 40 then return end
  -- Lists come from the crafter, and only from guildmates.
  if ns.Key(owner) ~= ns.Key(sender) or ns.RankOf(sender) == nil then return end
  prof = prof:sub(1, 30)
  local known = ns.db.crafters[ns.Key(owner)]
  if known and known.profs[prof] and known.profs[prof].v >= v then return end
  local key = ns.Key(owner) .. ":" .. prof .. ":" .. v
  local pend = pending[key] or { got = 0, total = total, chunks = {} }
  pending[key] = pend
  if pend.chunks[part] then return end
  pend.chunks[part] = p[9] or ""
  pend.got = pend.got + 1
  if pend.got < pend.total then return end
  pending[key] = nil
  local ids = {}
  for i = 1, pend.total do
    for id in (pend.chunks[i] or ""):gmatch("[^,]+") do
      if id:match("^e?%d+$") then ids[#ids + 1] = id end
    end
  end
  store(owner, prof, rank, max, v, ids)
end)

-- A guildmate logged in and asks for lists: send yours (if you have any).
local answered = {}
ns.OnMessage("CQ", function(_, sender)
  if not next(ns.db.myCrafts or {}) then return end
  local k = ns.Key(sender)
  if answered[k] and GetTime() - answered[k] < ANSWER_QUIET then return end
  answered[k] = GetTime()
  sendMine(sender)
end)

table.insert(ns.OnGuildReady, function()
  C_Timer.After(40, function() ns.Send("CQ") end)
end)

------------------------------------------------------------------------
-- Reading your own profession windows
------------------------------------------------------------------------
local function idOf(link, enchant)
  if type(link) ~= "string" then return nil end
  local item = link:match("item:(%d+)")
  if item then return item end
  local spell = link:match("enchant:(%d+)") or link:match("spell:(%d+)")
  if spell then return "e" .. spell end
end

local sendTokens = {} -- prof -> the latest wait for sending it

-- Note a profession's recipes (and send them if anything is new).
function ns.NoteMyRecipes(prof, rank, max, found)
  if type(prof) ~= "string" or prof == "" or prof == "UNKNOWN" then return end
  local mine = ns.db.myCrafts[prof]
  local newOnes = false
  if not mine then
    mine = { rank = 0, max = 0, v = 0, ids = {} }
    ns.db.myCrafts[prof] = mine
    newOnes = true
  end
  -- Recipes found are added to what was known (a collapsed or filtered window shows fewer).
  for id, name in pairs(found) do
    if not mine.ids[id] then mine.ids[id] = true; newOnes = true end
    if name and name ~= "" then ns.db.craftNames[id] = name end
  end
  if mine.rank ~= rank or mine.max ~= max then newOnes = true end
  mine.rank, mine.max = rank or 0, max or 0
  if not newOnes or not next(mine.ids) then return end
  mine.v = math.max(time(), (mine.v or 0) + 1)
  store(UnitName("player"), prof, mine.rank, mine.max, mine.v, sortedIds(mine.ids))
  -- Rank goes up a point at a time: wait a little so a crafting spree is one update.
  sendTokens[prof] = (sendTokens[prof] or 0) + 1
  local token = sendTokens[prof]
  C_Timer.After(30, function()
    if token ~= sendTokens[prof] then return end
    local p = ns.db.myCrafts[prof]
    if p then
      for _, msg in ipairs(parts(UnitName("player"), prof, { rank = p.rank, max = p.max, v = p.v, ids = sortedIds(p.ids) })) do
        ns.Send(unpack(msg))
      end
    end
  end)
end

local function scanTradeSkills()
  if not GetTradeSkillLine then return end
  local prof, rank, max = GetTradeSkillLine()
  local found = {}
  for i = 1, (GetNumTradeSkills and GetNumTradeSkills() or 0) do
    local name, kind = GetTradeSkillInfo(i)
    if kind ~= "header" and kind ~= "subheader" then
      local id = idOf(GetTradeSkillItemLink and GetTradeSkillItemLink(i))
      if id then found[id] = name end
    end
  end
  ns.NoteMyRecipes(prof, rank, max, found)
end

local function scanCrafts()
  if not GetCraftDisplaySkillLine then return end
  local prof, rank, max = GetCraftDisplaySkillLine()
  if not prof then return end
  local found = {}
  for i = 1, (GetNumCrafts and GetNumCrafts() or 0) do
    local name, _, kind = GetCraftInfo(i)
    if kind ~= "header" then
      local id = idOf(GetCraftItemLink and GetCraftItemLink(i))
      if id then found[id] = name end
    end
  end
  ns.NoteMyRecipes(prof, rank, max, found)
end

local function later(fn)
  local waiting = false
  return function()
    if waiting then return end
    waiting = true
    C_Timer.After(1, function() waiting = false; pcall(fn) end)
  end
end
local tradeLater, craftLater = later(scanTradeSkills), later(scanCrafts)
ns.OnEvent("TRADE_SKILL_SHOW", tradeLater)
ns.OnEvent("TRADE_SKILL_UPDATE", tradeLater)
ns.OnEvent("CRAFT_SHOW", craftLater)
ns.OnEvent("CRAFT_UPDATE", craftLater)

------------------------------------------------------------------------
-- Looking things up
------------------------------------------------------------------------
-- A recipe's name in your language (nil while the game is still loading it).
function ns.RecipeName(id)
  local cached = ns.db.craftNames[id]
  if cached then return cached end
  local name
  local spell = id:match("^e(%d+)$")
  if spell then
    name = GetSpellInfo and GetSpellInfo(tonumber(spell))
  else
    name = GetItemInfo(tonumber(id))
    if not name and C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, tonumber(id)) end
  end
  if type(name) == "string" and name ~= "" then ns.db.craftNames[id] = name end
  return name
end

-- A recipe's link, for whispers (or its name, for enchants).
function ns.RecipeLink(id)
  local spell = id:match("^e(%d+)$")
  if spell then return ns.RecipeName(id) end
  local _, link = GetItemInfo(tonumber(id))
  return link or ns.RecipeName(id)
end

-- The professions anyone has shared, sorted.
function ns.CraftProfessions()
  local set, out = {}, {}
  for _, c in pairs(ns.db.crafters or {}) do
    if ns.RankOf(c.name) ~= nil then
      for prof in pairs(c.profs) do set[prof] = true end
    end
  end
  for prof in pairs(set) do out[#out + 1] = prof end
  table.sort(out)
  return out
end

-- Every member's professions: { { name, prof, rank, max, count } }, for profiles.
function ns.MemberProfessions(name)
  local c = ns.db.crafters[ns.Key(name)]
  local out = {}
  for prof, p in pairs(c and c.profs or {}) do
    out[#out + 1] = { prof = prof, rank = p.rank, max = p.max, count = #p.ids }
  end
  table.sort(out, function(a, b) return a.prof < b.prof end)
  return out
end

-- Recipes matching a search (any part of the name; "" for all), and who makes
-- them: { { id, name, prof, crafters = { { name, online, rank } } } }, by name.
function ns.CraftSearch(query, onlyProf)
  query = strtrim(query or ""):lower()
  local by, out, waiting = {}, {}, 0
  for _, c in pairs(ns.db.crafters or {}) do
    local m = ns.Member(c.name)
    if m then
      for prof, p in pairs(c.profs) do
        if not onlyProf or onlyProf == prof then
          for _, id in ipairs(p.ids) do
            local name = ns.RecipeName(id)
            if not name then waiting = waiting + 1 end
            local shown = name or ("#" .. id)
            if query == "" or shown:lower():find(query, 1, true) then
              local r = by[id]
              if not r then
                r = { id = id, name = shown, prof = prof, crafters = {} }
                by[id] = r
                out[#out + 1] = r
              end
              r.crafters[#r.crafters + 1] = { name = c.name, online = m.online and true or false, rank = p.rank }
            end
          end
        end
      end
    end
  end
  for _, r in ipairs(out) do
    table.sort(r.crafters, function(a, b)
      if a.online ~= b.online then return a.online end
      return a.name < b.name
    end)
  end
  table.sort(out, function(a, b)
    if a.name ~= b.name then return a.name < b.name end
    return a.id < b.id
  end)
  return out, waiting
end

-- How many members have shared lists, and how many recipes they know between them.
function ns.CraftStats()
  local people, recipes = 0, {}
  for _, c in pairs(ns.db.crafters or {}) do
    if ns.Member(c.name) then
      people = people + 1
      for _, p in pairs(c.profs) do for _, id in ipairs(p.ids) do recipes[id] = true end end
    end
  end
  local n = 0
  for _ in pairs(recipes) do n = n + 1 end
  return people, n
end

-- Ask a crafter for something: open a whisper to them.
function ns.AskCrafter(name, id)
  local what = ns.RecipeLink(id) or ""
  local text = ns.TF("Hi! Could you craft %s for me?", what)
  if ChatFrame_OpenChat then
    ChatFrame_OpenChat("/w " .. Ambiguate(name, "none") .. " " .. text)
  else
    SendChatMessage(text, "WHISPER", nil, name)
  end
end

-- Item names arrive after asking: refresh the window once they have.
ns.OnEvent("GET_ITEM_INFO_RECEIVED", function()
  if ns.RefreshCrafters and not ns.craftersRefreshSoon then
    ns.craftersRefreshSoon = true
    C_Timer.After(0.5, function() ns.craftersRefreshSoon = false; ns.RefreshCrafters() end)
  end
end)
