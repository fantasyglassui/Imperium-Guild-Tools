--[[
  Warcrest
  Player card: one guild member at a glance. Their profile (spec, when they
  play, birthday), PvP this month and overall, streaks, nemesis, DKP,
  attendance and recent loot. Opened by clicking a
  name on the Roster, Kills, DKP or Raids tabs, or with /warcrest card Name.
]]

local _, ns = ...
local UI = ns.UI
local C = UI.C

local WIDTH, HEIGHT = 420, 550
local DOWN = 64 -- room for the profile under the name
local card -- the window
local shownName

-- A stat tile: a big number with a word under it.
local function Tile(parent, x, y, w, label)
  local t = CreateFrame("Frame", nil, parent)
  t:SetPoint("TOPLEFT", x, y)
  t:SetSize(w, 56)
  UI.Card(t)
  t.number = UI.Label(t, "", "Heading")
  t.number:SetPoint("TOPLEFT", 10, -10)
  t.label = UI.Label(t, label:upper(), "Label")
  t.label:SetPoint("TOPLEFT", 10, -34)
  t.label:SetWidth(w - 16)
  t.label:SetWordWrap(false)
  return t
end

local function Section(parent, text, y)
  local fs = UI.Label(parent, text, "Heading")
  fs:SetPoint("TOPLEFT", 16, y)
  return fs
end

local function Build()
  local f = UI.Window("WarcrestPlayerCard", WIDTH, HEIGHT, "Player card")
  card = f
  local inner = WIDTH - 32
  local tileW = (inner - 3 * 8) / 4

  f.name = UI.Label(f, "", "Title")
  f.name:SetPoint("TOPLEFT", 16, -42)
  f.name:SetWidth(inner - 130)
  f.name:SetWordWrap(false)
  f.info = UI.Label(f, "", "Small")
  f.info:SetPoint("TOPLEFT", 16, -64)
  f.info:SetWidth(inner - 130)
  f.info:SetWordWrap(false)
  f.status = UI.Label(f, "", "MutedSmall")
  f.status:SetPoint("TOPLEFT", 16, -80)
  f.status:SetWidth(inner - 130)
  f.status:SetWordWrap(false)

  -- What they've told the guild about themselves.
  f.profile = {}
  for i = 1, 3 do
    local fs = UI.Label(f, "", "Small")
    fs:SetPoint("TOPLEFT", 16, -104 - (i - 1) * 18)
    fs:SetWidth(inner)
    fs:SetWordWrap(false)
    f.profile[i] = fs
  end

  -- PvP
  Section(f, "PvP", -104 - DOWN)
  f.monthKills = Tile(f, 16, -124 - DOWN, tileW, "This month")
  f.kills = Tile(f, 16 + (tileW + 8), -124 - DOWN, tileW, "All time")
  f.assists = Tile(f, 16 + 2 * (tileW + 8), -124 - DOWN, tileW, "Assists")
  f.deaths = Tile(f, 16 + 3 * (tileW + 8), -124 - DOWN, tileW, "Deaths")
  f.pvpLines = UI.Label(f, "", "Small")
  f.pvpLines:SetPoint("TOPLEFT", 16, -190 - DOWN)
  f.pvpLines:SetWidth(inner)
  f.pvpLines:SetSpacing(4)

  -- Raids and DKP
  Section(f, "Raids and DKP", -256 - DOWN)
  f.dkp = Tile(f, 16, -276 - DOWN, tileW, "DKP")
  f.attendance = Tile(f, 16 + (tileW + 8), -276 - DOWN, tileW, "Attended")
  f.noShows = Tile(f, 16 + 2 * (tileW + 8), -276 - DOWN, tileW, "No-shows")
  f.items = Tile(f, 16 + 3 * (tileW + 8), -276 - DOWN, tileW, "Items won")
  f.dkp.number:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
  f.lootLines = UI.Label(f, "", "Small")
  f.lootLines:SetPoint("TOPLEFT", 16, -342 - DOWN)
  f.lootLines:SetWidth(inner)
  f.lootLines:SetSpacing(4)

  f.whisper = UI.Button(f, "Whisper", 120)
  f.whisper:SetHeight(26)
  f.whisper:SetPoint("TOPRIGHT", -16, -46)
  f.whisper:SetScript("OnClick", function()
    if not shownName then return end
    if ns.IsMe(shownName) then
      if ns.ShowProfileEditor then ns.ShowProfileEditor() end
      return
    end
    if ChatFrameUtil and ChatFrameUtil.SendTell then
      ChatFrameUtil.SendTell(shownName)
    elseif ChatFrame_SendTell then
      ChatFrame_SendTell(shownName)
    end
  end)
  UI.Tooltip(f.whisper, function() return shownName and ns.IsMe(shownName) and "Edit profile" or "Whisper" end,
    function() return shownName and ns.IsMe(shownName)
      and "Tell the guild your main spec, when you play, your birthday and a short note."
      or "Starts a whisper to them in chat." end)

  f.achievements = UI.Button(f, "", 120)
  f.achievements:SetHeight(22)
  f.achievements:SetPoint("TOPRIGHT", -16, -78)
  f.achievements:SetScript("OnClick", function() if shownName then ns.ShowAchievements(shownName) end end)
  UI.Tooltip(f.achievements, "Achievements", "Opens their achievements in the guild window.")
end

-- Someone outside your guild: their guild, if the game can tell (they're your
-- target, mouseover, focus, in your group or on a nameplate).
local function guildOf(name)
  local units = { "target", "mouseover", "focus" }
  for i = 1, 40 do units[#units + 1] = "raid" .. i end
  for i = 1, 4 do units[#units + 1] = "party" .. i end
  for _, u in ipairs(ns.NameplateUnits and ns.NameplateUnits() or {}) do units[#units + 1] = u end
  local key = ns.Key(name)
  for _, u in ipairs(units) do
    local ok, unitName = pcall(UnitName, u)
    unitName = ok and ns.Usable(unitName)
    if unitName and ns.Key(unitName) == key then
      local ok2, guild = pcall(GetGuildInfo, u)
      guild = ok2 and ns.Usable(guild)
      return true, (type(guild) == "string" and guild ~= "") and guild or nil
    end
  end
  return false
end

local function fill(p)
  local f = card
  local m = p.member
  local title = ns.TitleOf and ns.TitleOf(p.name)
  f.name:SetText(Ambiguate(p.name, "short") .. (title and (" " .. UI.Code("accent") .. title .. "|r") or ""))
  if ns.AchievementCount then
    local n = ns.AchievementCount(p.name)
    f.achievements:SetText(n == 1 and "1 achievement" or (n .. " achievements"))
  end
  f.name:SetTextColor(UI.ClassColor(m and m.classFile))
  if m then
    local guild = ns.GuildName()
    f.info:SetText(ns.TF("Level %d %s", m.level, m.className) .. "  ·  " .. m.rankName
      .. (guild and ("  ·  " .. UI.Code("accent") .. "<" .. guild .. ">|r") or ""))
    f.status:SetText(m.online and ns.TF("Online in %s", m.zone ~= "" and m.zone or ns.T("an unknown zone"))
      or ns.T(m.mobile and "On mobile" or "Offline"))
  else
    local seen, guild = guildOf(p.name)
    f.info:SetText(UI.Code("muted") .. (guild and ns.TF("In %s", "<" .. guild .. ">")
      or ns.T(seen and "Not in a guild" or "Not in your guild")) .. "|r")
    f.status:SetText(UI.Code("faint") .. ns.T("Their record here is from your guild's history.") .. "|r")
  end
  if p.main then
    f.status:SetText(f.status:GetText() .. "  ·  alt of " .. p.main)
  elseif #p.alts > 0 then
    f.status:SetText(f.status:GetText() .. "  ·  alts: " .. table.concat(p.alts, ", "))
  end

  -- Their profile.
  local me = ns.IsMe(p.name)
  f.whisper:SetText(ns.T(me and "Edit profile" or "Whisper"))
  local pf = ns.MemberProfile and ns.MemberProfile(p.name)
  local plines = {}
  if pf then
    local top = {}
    if pf.spec ~= "" then top[#top + 1] = UI.Code("text") .. pf.spec .. "|r" end
    if pf.role ~= "" then top[#top + 1] = ns.T(({ tank = "Tank", healer = "Healer", dps = "DPS" })[pf.role]) end
    if pf.ilvl > 0 then top[#top + 1] = ns.TF("item level %d", pf.ilvl) end
    if #top > 0 then plines[#plines + 1] = table.concat(top, "  ·  ") end
    local second = {}
    local avail = ns.AvailabilityText(pf)
    if avail ~= "" then second[#second + 1] = ns.T("Plays") .. " " .. UI.Code("text") .. avail .. "|r" end
    local bday = ns.BirthdayText(pf.bday)
    if bday ~= "" then second[#second + 1] = ns.T("Birthday") .. " " .. UI.Code("text") .. bday .. "|r" end
    if #second > 0 then plines[#plines + 1] = table.concat(second, "  ·  ") end
    if pf.note ~= "" then plines[#plines + 1] = UI.Code("muted") .. "\"" .. pf.note .. "\"|r" end
  else
    plines[#plines + 1] = UI.Code("muted") .. ns.T(me and "You haven't shared a profile yet. Click Edit profile to tell the guild about you."
      or "No profile shared yet.") .. "|r"
  end
  local extra = {}
  local since = m and ns.MemberSince and ns.MemberSince(p.name)
  if since then extra[#extra + 1] = ns.T("Member since") .. " " .. date("%b %Y", since) end
  local events = ns.EventsAttended and ns.EventsAttended(p.name, 30) or 0
  if events > 0 then extra[#extra + 1] = ns.TF(events == 1 and "%d guild event in 30 days" or "%d guild events in 30 days", events) end
  if #extra > 0 and #plines < 3 then plines[#plines + 1] = UI.Code("muted") .. table.concat(extra, "  ·  ") .. "|r" end
  for i, fs in ipairs(f.profile) do fs:SetText(plines[i] or "") end

  f.monthKills.number:SetText(p.monthKills)
  f.kills.number:SetText(p.kills)
  f.assists.number:SetText(p.assists)
  f.deaths.number:SetText(p.deaths)
  local lines = {}
  local streak = p.streak > 0 and ("%s%d|r right now"):format(UI.Code("accent"), p.streak) or "none right now"
  lines[#lines + 1] = ("Streak: %s  ·  best %s%d|r"):format(streak, UI.Code("text"), p.bestStreak)
  lines[#lines + 1] = p.nemesis and ("Nemesis: %s%s|r, who has killed them %d time%s"):format(UI.Code("bad"),
    p.nemesis, p.nemesisCount, p.nemesisCount == 1 and "" or "s") or "Nemesis: nobody yet"
  lines[#lines + 1] = p.favorite and ("Most killed: %s%s|r, %d time%s"):format(UI.Code("text"), p.favorite,
    p.favoriteCount, p.favoriteCount == 1 and "" or "s") or "Most killed: nobody yet"
  f.pvpLines:SetText(table.concat(lines, "\n"))

  f.dkp.number:SetText(ns.UsesDKP() and p.dkp or "-")
  f.attendance.number:SetText(p.raids > 0 and (p.attended .. " / " .. p.raids) or "-")
  f.noShows.number:SetText(#p.noShows)
  local noShowColor = #p.noShows > 0 and C.bad or C.text
  f.noShows.number:SetTextColor(noShowColor[1], noShowColor[2], noShowColor[3])
  f.items.number:SetText(p.itemsWon)
  local loot = {}
  if p.bossKills > 0 then
    loot[#loot + 1] = ("Boss kills: %s%d|r%s"):format(UI.Code("text"), p.bossKills,
      p.bossFirsts > 0 and (" (" .. p.bossFirsts .. " guild first" .. (p.bossFirsts == 1 and "" or "s") .. ")") or "")
  end
  if #p.wishes > 0 then
    -- The first item they want (Need first), cut short so the line fits.
    local first = p.wishes[1].name
    if #first > 30 then first = first:sub(1, 28) .. "..." end
    if #p.wishes == 1 then
      loot[#loot + 1] = ("Wishlist: %s%s|r (%s)"):format(UI.Code("text"), first, p.wishNeed > 0 and "Need" or "Want")
    else
      loot[#loot + 1] = ("Wishlist: %s%d|r items%s, like %s"):format(UI.Code("text"), #p.wishes,
        p.wishNeed > 0 and (" (" .. p.wishNeed .. " Need)") or "", first)
    end
  end
  if #p.loot > 0 then loot[#loot + 1] = "Recent loot:" end
  for _, l in ipairs(p.loot) do
    loot[#loot + 1] = ("%s%s|r  %s  %s"):format(UI.Code("muted"), date("%b %d", l.t), l.item,
      l.roll and (UI.Code("muted") .. "free roll|r") or (l.council and (UI.Code("muted") .. "loot council|r")
        or (UI.Code("text") .. l.amount .. " DKP|r")))
  end
  if #p.loot == 0 then loot[#loot + 1] = UI.Code("muted") .. "No loot won yet.|r" end
  f.lootLines:SetText(table.concat(loot, "\n"))
  -- As tall as what's on it: no empty space under a short record.
  f:SetHeight(math.min(HEIGHT, math.max(400 + DOWN, 342 + DOWN + math.ceil(f.lootLines:GetStringHeight()) + 30)))
end

-- Open a guild member's card.
function ns.ShowPlayerCard(name)
  if not name or name == "" then return end
  name = Ambiguate(name, "short")
  if not card then Build() end
  shownName = name
  fill(ns.PlayerProfile(name))
  card:Show()
end

-- Refresh it when something changes while it's open.
function ns.RefreshPlayerCard()
  if card and card:IsShown() and shownName then fill(ns.PlayerProfile(shownName)) end
end
