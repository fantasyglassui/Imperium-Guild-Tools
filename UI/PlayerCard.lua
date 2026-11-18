--[[
  Warcrest
  Player card: one guild member at a glance. PvP this month and overall,
  streaks, nemesis, DKP, attendance and recent loot. Opened by clicking a
  name on the Roster, Kills, DKP or Raids tabs, or with /warcrest card Name.
]]

local _, ns = ...
local UI = ns.UI
local C = UI.C

local WIDTH, HEIGHT = 420, 470
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
  f.status = UI.Label(f, "", "MutedSmall")
  f.status:SetPoint("TOPLEFT", 16, -80)
  f.status:SetWidth(inner - 130)
  f.status:SetWordWrap(false)

  -- PvP
  Section(f, "PvP", -104)
  f.monthKills = Tile(f, 16, -124, tileW, "This month")
  f.kills = Tile(f, 16 + (tileW + 8), -124, tileW, "All time")
  f.assists = Tile(f, 16 + 2 * (tileW + 8), -124, tileW, "Assists")
  f.deaths = Tile(f, 16 + 3 * (tileW + 8), -124, tileW, "Deaths")
  f.pvpLines = UI.Label(f, "", "Small")
  f.pvpLines:SetPoint("TOPLEFT", 16, -190)
  f.pvpLines:SetWidth(inner)
  f.pvpLines:SetSpacing(4)

  -- Raids and DKP
  Section(f, "Raids and DKP", -256)
  f.dkp = Tile(f, 16, -276, tileW, "DKP")
  f.attendance = Tile(f, 16 + (tileW + 8), -276, tileW, "Attended")
  f.noShows = Tile(f, 16 + 2 * (tileW + 8), -276, tileW, "No-shows")
  f.items = Tile(f, 16 + 3 * (tileW + 8), -276, tileW, "Items won")
  f.dkp.number:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
  f.lootLines = UI.Label(f, "", "Small")
  f.lootLines:SetPoint("TOPLEFT", 16, -342)
  f.lootLines:SetWidth(inner)
  f.lootLines:SetSpacing(4)

  f.whisper = UI.Button(f, "Whisper", 120)
  f.whisper:SetHeight(26)
  f.whisper:SetPoint("TOPRIGHT", -16, -46)
  f.whisper:SetScript("OnClick", function()
    if not shownName then return end
    if ChatFrameUtil and ChatFrameUtil.SendTell then
      ChatFrameUtil.SendTell(shownName)
    elseif ChatFrame_SendTell then
      ChatFrame_SendTell(shownName)
    end
  end)
  UI.Tooltip(f.whisper, "Whisper", "Starts a whisper to them in chat.")

  f.achievements = UI.Button(f, "", 120)
  f.achievements:SetHeight(22)
  f.achievements:SetPoint("TOPRIGHT", -16, -78)
  f.achievements:SetScript("OnClick", function() if shownName then ns.ShowAchievements(shownName) end end)
  UI.Tooltip(f.achievements, "Achievements", "Opens their achievements in the guild window.")
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
    f.info:SetText(("Level %d %s  ·  %s"):format(m.level, m.className, m.rankName))
    f.status:SetText(m.online and ("Online in " .. (m.zone ~= "" and m.zone or "an unknown zone"))
      or (m.mobile and "On mobile" or "Offline"))
  else
    f.info:SetText(UI.Code("muted") .. "Not in the guild right now|r")
    f.status:SetText("")
  end
  if p.main then
    f.status:SetText(f.status:GetText() .. "  ·  alt of " .. p.main)
  elseif #p.alts > 0 then
    f.status:SetText(f.status:GetText() .. "  ·  alts: " .. table.concat(p.alts, ", "))
  end

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

  f.dkp.number:SetText(p.dkp)
  f.attendance.number:SetText(p.raids > 0 and (p.attended .. " / " .. p.raids) or "-")
  f.noShows.number:SetText(#p.noShows)
  local noShowColor = #p.noShows > 0 and C.bad or C.text
  f.noShows.number:SetTextColor(noShowColor[1], noShowColor[2], noShowColor[3])
  f.items.number:SetText(p.itemsWon)
  local loot = {}
  if #p.wishes > 0 then
    local names = {}
    for i = 1, math.min(2, #p.wishes) do names[i] = p.wishes[i].name end
    loot[#loot + 1] = ("Wishlist: %s%d|r item%s%s: %s%s"):format(UI.Code("text"), #p.wishes, #p.wishes == 1 and "" or "s",
      p.wishNeed > 0 and (" (" .. p.wishNeed .. " Need)") or "", table.concat(names, ", "), #p.wishes > 2 and "..." or "")
  end
  if #p.loot > 0 then loot[#loot + 1] = "Recent loot:" end
  for _, l in ipairs(p.loot) do
    loot[#loot + 1] = ("%s%s|r  %s  %s"):format(UI.Code("muted"), date("%b %d", l.t), l.item,
      l.roll and (UI.Code("muted") .. "free roll|r") or (UI.Code("text") .. l.amount .. " DKP|r"))
  end
  if #p.loot == 0 then loot[#loot + 1] = UI.Code("muted") .. "No loot won yet.|r" end
  f.lootLines:SetText(table.concat(loot, "\n"))
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
