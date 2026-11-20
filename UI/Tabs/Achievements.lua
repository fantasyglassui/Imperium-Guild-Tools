--[[
  Warcrest
  Achievements tab. Three views, switched at the top:
    PvP, Hunts, Raids, Loot & more: a member's achievements as tiles (yours, or whoever's
                       you opened from their player card), with progress.
    Guild:             achievements earned across the guild, newest first,
                       and who has the most.
  Also where you choose your title (the button at the top right).
]]

local _, ns = ...
local UI = ns.UI
local C = UI.C

local P = { tiles = {} }
local TAB
local viewing -- whose achievements; nil = yours

local COLS = 4
local GAP = 10
local TOP = 66              -- the strip with the member's name above the tiles
local TILE_W = (740 - (COLS - 1) * GAP) / COLS -- changes when the window is resized
local TILE_H = 86
local MAX_TILES = 16

local function who() return viewing or UnitName("player") end
local function isMe() return ns.Key(who()) == ns.Key(UnitName("player")) end

------------------------------------------------------------------------
-- Your title: a button at the top of the tab ("Title: the Pioneer") that
-- opens a list of every title. The ones you've earned can be picked; the
-- rest show which achievement gives them.
------------------------------------------------------------------------
local chooser

local function titleRows()
  local me = UnitName("player")
  local rows = { { id = "", title = ns.T("No title"), earned = true } }
  local earned, locked = {}, {}
  for _, a in ipairs(ns.ACHIEVEMENTS) do
    if a.title then
      local row = { id = a.id, title = a.title, achievement = a, earned = ns.HasAchievement(me, a.id) }
      if row.earned then earned[#earned + 1] = row else locked[#locked + 1] = row end
    end
  end
  for _, r in ipairs(earned) do rows[#rows + 1] = r end
  for _, r in ipairs(locked) do rows[#rows + 1] = r end
  return rows, #earned
end

local function currentTitle()
  local _, id = ns.TitleOf(UnitName("player"))
  return id or ""
end

local function refreshChooser()
  if not (chooser and chooser:IsShown()) then return end
  local rows, n = titleRows()
  chooser.count:SetText(ns.TF("%d of %d titles earned", n, #rows - 1))
  chooser.list:SetItems(rows)
end

local function BuildChooser()
  chooser = UI.Window("WarcrestTitles", 420, 470, "Your title")
  local intro = UI.Label(chooser, "Shown after your name on your player card, around the guild window, in kill alerts "
    .. "and in chat. Guildmates with Warcrest see it. Click an earned title to use it.", "MutedSmall")
  intro:SetPoint("TOPLEFT", 16, -42)
  intro:SetWidth(388)
  chooser.count = UI.Label(chooser, "", "Subheading")
  chooser.count:SetPoint("TOPLEFT", 16, -76)
  local box = UI.Box(chooser, 15, -100, 390, 310)
  chooser.list = UI.List(box, 380, 304, 40,
    function(row)
      UI.RowSelection(row)
      row.check = UI.Icon(row, "check", 12, C.accent)
      row.check:SetPoint("LEFT", 12, 0)
      row.title = UI.Label(row, "", "Body")
      row.title:SetPoint("TOPLEFT", 32, -5)
      row.title:SetWidth(330)
      row.title:SetWordWrap(false)
      row.how = UI.Label(row, "", "MutedSmall")
      row.how:SetPoint("TOPLEFT", 32, -22)
      row.how:SetWidth(330)
      row.how:SetWordWrap(false)
      row:SetScript("OnClick", function(self)
        local r = self.item
        if not r.earned then
          ns.Say(ns.TF("Earn %s to use this title.", ns.T(r.achievement.name)))
          return
        end
        ns.SetTitle(r.id)
        -- Show it straight away (the guild hears about it in a moment).
        chooser.pendingId = r.id
        refreshChooser()
        if ns.RefreshPanel then ns.RefreshPanel() end
      end)
    end,
    function(row, r)
      local current = chooser.pendingId or currentTitle()
      local me = Ambiguate(UnitName("player"), "short")
      if r.id == "" then
        row.title:SetText(r.title)
        row.how:SetText(ns.T("Just your name."))
      else
        row.title:SetText(me .. " " .. (r.earned and UI.Code("accent") or UI.Code("faint")) .. ns.T(r.title) .. "|r")
        row.how:SetText(r.earned and ns.TF("From %s", ns.T(r.achievement.name))
          or ns.TF("Earn %s: %s", ns.T(r.achievement.name), ns.T(r.achievement.desc)))
      end
      row.title:SetAlpha(r.earned and 1 or 0.6)
      row.check:SetShown(r.id == current)
      UI.SetRowSelected(row, r.id == current)
    end, true)
  chooser.list.frame:SetPoint("TOPLEFT", box, "TOPLEFT", 4, -3)
  chooser.chat = UI.Check(chooser, "Show titles in chat", 10, -(470 - 46))
  chooser.chat:SetScript("OnClick", function(self) ns.db.chatTitles = self:GetChecked() and true or false end)
  UI.Tooltip(chooser.chat, "Titles in chat", "Shows guildmates' titles in gold at the start of their chat messages, in your chat window: "
    .. "[Lyra]: (the Avenger) hello. Only you see the change; it doesn't alter what they sent.")
  local done = UI.Button(chooser, "Done", 100, "primary")
  done:SetHeight(28)
  done:SetPoint("BOTTOMRIGHT", -16, 14)
  done:SetScript("OnClick", function() chooser:Hide() end)
end

function ns.ShowTitleChooser()
  if not chooser then BuildChooser() end
  chooser.pendingId = nil
  chooser.chat:SetChecked(ns.db.chatTitles and true or false)
  chooser:Show()
  refreshChooser()
end

local function refreshTitleButton(b)
  local _, id = ns.TitleOf(UnitName("player"))
  local title = id and ns.Achievement(id) and ns.Achievement(id).title
  if chooser and chooser.pendingId then
    local a = ns.Achievement(chooser.pendingId)
    title = a and a.title or nil
    if chooser.pendingId == "" then title = nil end
    if (id or "") == chooser.pendingId then chooser.pendingId = nil end -- the change has landed
  end
  b:SetText(ns.TF("Title: %s", title and ns.T(title) or ns.T("No title")))
end

local function makeTitleButton(parent, width)
  local b = UI.Button(parent, "", width)
  b:SetHeight(26)
  b:GetFontString():ClearAllPoints()
  b:GetFontString():SetPoint("CENTER", -6, 0)
  UI.Icon(b, "chevron", 10, C.accent):SetPoint("RIGHT", -7, 0)
  b:SetScript("OnClick", ns.ShowTitleChooser)
  UI.Tooltip(b, "Your title", "Choose the title shown after your name. You can pick from the titles you've earned.")
  return b
end

------------------------------------------------------------------------
-- Tiles
------------------------------------------------------------------------
local function Tile(parent, i)
  local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
  local t = UI.Box(parent, col * (TILE_W + GAP), -TOP - row * (TILE_H + GAP), TILE_W, TILE_H)
  t.icon = UI.Icon(t, "trophy", 16, C.faint)
  t.icon:SetPoint("TOPLEFT", 12, -12)
  t.name = UI.Label(t, "", "Subheading")
  t.name:SetPoint("TOPLEFT", 34, -12)
  t.name:SetWidth(TILE_W - 46)
  -- "TITLE" for achievements that give one: bottom right, so the name has the width.
  t.tag = UI.Label(t, "TITLE", "Label")
  t.tag:SetPoint("BOTTOMRIGHT", -12, 11)
  t.tag:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
  t.name:SetWordWrap(false)
  t.desc = UI.Label(t, "", "MutedSmall")
  t.desc:SetPoint("TOPLEFT", 12, -34)
  t.desc:SetWidth(TILE_W - 24)
  t.desc:SetSpacing(1)
  t.status = UI.Label(t, "", "Small")
  t.status:SetPoint("BOTTOMLEFT", 12, 10)
  t.status:SetWidth(TILE_W - 24)
  t.status:SetWordWrap(false)
  -- Progress: a bar to the right of the count.
  t.track = t:CreateTexture(nil, "BORDER")
  t.track:SetPoint("BOTTOMLEFT", 82, 15)
  t.track:SetPoint("BOTTOMRIGHT", -12, 15) -- moved left of the tag in fillTile
  t.track:SetHeight(3)
  t.track:SetColorTexture(C.line[1], C.line[2], C.line[3], 1)
  t.fill = t:CreateTexture(nil, "ARTWORK")
  t.fill:SetPoint("BOTTOMLEFT", 82, 15)
  t.fill:SetHeight(3)
  t.fill:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.7)
  t.edge = UI.Border(t, C.accent[1], C.accent[2], C.accent[3], 0.6, 1)
  t:EnableMouse(true)
  UI.Tooltip(t, function() return t.a and t.a.name or "" end, function()
    local a = t.a
    if not a then return end
    local lines = { a.desc }
    if a.title then lines[#lines + 1] = "Title: " .. who() .. " " .. a.title end
    return table.concat(lines, "\n")
  end)
  return t
end

local function fillTile(t, a, e)
  t.a = a
  local earned = e and e.t
  local ic = earned and C.accent or C.faint
  t.icon:SetVertexColor(ic[1], ic[2], ic[3])
  t.name:SetText(a.name)
  local nc = earned and C.text or C.textSoft
  t.name:SetTextColor(nc[1], nc[2], nc[3])
  t.desc:SetText(a.desc)
  t.edge:SetColor(C.accent[1], C.accent[2], C.accent[3], earned and 0.5 or 0)
  t.tag:SetShown(a.title ~= nil)
  local tagRoom = a.title and (t.tag:GetStringWidth() + 10) or 0
  t.track:SetPoint("BOTTOMRIGHT", -12 - tagRoom, 15)
  t.status:SetWidth(TILE_W - 24 - tagRoom)
  local titleTag = ""
  if earned then
    t.status:SetText(UI.Code("good") .. (e.t > 0 and ns.TF("Earned %s", date(ns.T("%b %d, %Y"), e.t)) or ns.T("Earned")) .. "|r" .. titleTag)
    t.track:Hide()
    t.fill:Hide()
  else
    local n = math.min(e and e.progress or 0, a.goal)
    t.status:SetText(a.goal > 1 and (UI.Code("muted") .. n .. " / " .. a.goal .. "|r" .. titleTag)
      or (UI.Code("faint") .. ns.T("Not yet") .. "|r" .. titleTag))
    t.track:SetShown(a.goal > 1)
    t.fill:SetShown(a.goal > 1 and n > 0)
    t.fill:SetWidth(math.max(1, (TILE_W - 94 - tagRoom) * n / a.goal))
  end
end

------------------------------------------------------------------------
-- Views
------------------------------------------------------------------------
local function RefreshTiles(cat)
  local name = who()
  local mine = ns.MemberAchievements(name)
  local shown = {}
  for _, a in ipairs(ns.ACHIEVEMENTS) do
    if a.cat == cat then shown[#shown + 1] = a end
  end
  for i = 1, MAX_TILES do
    local t = P.tiles[i]
    local a = shown[i]
    t:SetShown(a ~= nil)
    if a then fillTile(t, a, mine[a.id]) end
  end

  -- The strip at the top.
  local m = ns.Member(name)
  P.who:SetText(ns.TitledName(name))
  P.who:SetTextColor(UI.ClassColor(m and m.classFile))
  local count, total = ns.AchievementCount(name), #ns.ACHIEVEMENTS
  P.summary:SetText(("%s%d|r of %d earned"):format(UI.Code("accent"), count, total))
  P.bar:SetWidth(math.max(1, P.barW * count / total))
  P.back:SetShown(not isMe())
  P.picker:SetShown(isMe())
  if isMe() then refreshTitleButton(P.picker) end
  refreshChooser()
end

local function RefreshGuild()
  local feed = ns.GuildAchievements()
  P.feed:SetEmptyText("Nobody in the guild has earned an achievement yet.")
  P.feed:SetItems(feed)
  local leaders = ns.AchievementLeaders(8)
  for i, row in ipairs(P.leaders) do
    local e = leaders[i]
    row:SetShown(e ~= nil)
    if e then
      row.entry = e
      row.rank:SetText(i)
      row.name:SetText(ns.TitledName(e.name))
      row.name:SetTextColor(UI.ClassColor(e.classFile))
      row.count:SetText(e.count)
    end
  end
  P.leadersEmpty:SetShown(#leaders == 0)
end

local function Refresh()
  local view = P.view.value
  P.tilesView:SetShown(view ~= "guild")
  P.guildView:SetShown(view == "guild")
  if view == "guild" then RefreshGuild() else RefreshTiles(view) end
end

local function BuildTiles(page)
  local f = CreateFrame("Frame", nil, page)
  P.tilesView = f
  f:SetPoint("TOPLEFT")
  f:SetSize(740, 450)

  P.who = UI.Label(f, "", "Title")
  P.who:SetPoint("TOPLEFT", 2, -4)
  P.who:SetWidth(420)
  P.who:SetWordWrap(false)
  P.summary = UI.Label(f, "", "Small")
  P.summary:SetPoint("TOPLEFT", 2, -30)
  P.barW = 200
  local track = f:CreateTexture(nil, "BORDER")
  track:SetPoint("TOPLEFT", 2, -50)
  track:SetSize(P.barW, 3)
  track:SetColorTexture(C.line[1], C.line[2], C.line[3], 1)
  P.bar = f:CreateTexture(nil, "ARTWORK")
  P.bar:SetPoint("TOPLEFT", 2, -50)
  P.bar:SetHeight(3)
  P.bar:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)

  P.picker = makeTitleButton(f, 230)
  P.picker:SetPoint("TOPRIGHT", 0, -6)
  P.back = UI.Button(f, "Back to yours", 130)
  P.back:SetHeight(26)
  P.back:SetPoint("TOPRIGHT", 0, -6)
  P.back:SetScript("OnClick", function() viewing = nil; ns.RefreshPanel() end)
  local card = UI.Button(f, "Player card", 110)
  card:SetHeight(26)
  card:SetPoint("TOPRIGHT", -238, -6)
  card:SetScript("OnClick", function() ns.ShowPlayerCard(who()) end)
  P.cardButton = card

  for i = 1, MAX_TILES do P.tiles[i] = Tile(f, i) end
end

local LEAD_W = 250
local FEED_W = 740 - LEAD_W - 14

local function BuildGuild(page)
  local f = CreateFrame("Frame", nil, page)
  P.guildView = f
  f:SetPoint("TOPLEFT")
  f:SetSize(740, 450)

  local card = UI.Box(f, 0, 0, FEED_W, 450)
  P.feedCard = card
  local y = UI.TableHeads(card, { { "WHEN", 12 }, { "WHO", 104 }, { "ACHIEVEMENT", 244 } })
  P.feed = UI.List(card, FEED_W - 24, 450 + y - 2, 26,
    function(row)
      row.when = UI.Label(row, "", "MutedSmall")
      row.when:SetPoint("LEFT", 12, 0)
      row.who = UI.Label(row, "", "Subheading")
      row.who:SetPoint("LEFT", 104, 0)
      row.who:SetWidth(132)
      row.who:SetWordWrap(false)
      row.what = UI.Label(row, "", "Small")
      row.what:SetPoint("LEFT", 244, 0)
      row.what:SetWidth(FEED_W - 24 - 252)
      row.what:SetWordWrap(false)
      UI.RowLine(row)
      row:SetScript("OnClick", function(self) ns.ShowAchievements(self.item.name) end)
      UI.Tooltip(row, function() return ns.Achievement(row.item.id).name end, function()
        local a = ns.Achievement(row.item.id)
        return a.desc .. (a.title and ("\nTitle: " .. a.title) or "") .. "\n\nClick to see all of " .. row.item.name .. "'s achievements."
      end)
    end,
    function(row, e)
      local a = ns.Achievement(e.id)
      row.when:SetText(e.t > 0 and ns.Date("%b %d", e.t) or "-")
      row.who:SetText(e.name)
      row.who:SetTextColor(UI.ClassColor(e.classFile))
      row.what:SetText(a.name .. (a.title and ("  " .. UI.Code("accent") .. "title|r") or ""))
    end, true)
  P.feed.frame:SetPoint("TOPLEFT", card, "TOPLEFT", 0, y - 1)

  local lead = UI.Box(f, FEED_W + 14, 0, LEAD_W, 450)
  P.leadCard = lead
  UI.Label(lead, "MOST ACHIEVEMENTS", "Label"):SetPoint("TOPLEFT", 14, -13)
  P.leaders = {}
  for i = 1, 8 do
    local row = CreateFrame("Button", nil, lead)
    row:SetPoint("TOPLEFT", 0, -34 - (i - 1) * 30)
    row:SetSize(LEAD_W - 2, 30)
    row.rank = UI.Label(row, "", "Muted")
    row.rank:SetPoint("LEFT", 14, 0)
    row.rank:SetWidth(14)
    row.rank:SetJustifyH("RIGHT")
    row.name = UI.Label(row, "", "Subheading")
    row.name:SetPoint("LEFT", 36, 0)
    row.name:SetWidth(LEAD_W - 90)
    row.name:SetWordWrap(false)
    row.count = UI.Label(row, "", "Number")
    row.count:SetPoint("RIGHT", -14, 0)
    row.count:SetJustifyH("RIGHT")
    local hover = row:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.08)
    row:SetScript("OnClick", function(self) if self.entry then ns.ShowAchievements(self.entry.name) end end)
    P.leaders[i] = row
  end
  P.leadersEmpty = UI.Label(lead, "Nobody yet.", "Muted")
  P.leadersEmpty:SetPoint("TOPLEFT", 14, -38)
end

-- A wider window: wider tiles, four to a row.
local function relayoutTiles(width)
  TILE_W = (width - (COLS - 1) * GAP) / COLS
  for i, t in ipairs(P.tiles) do
    local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", P.tilesView, "TOPLEFT", col * (TILE_W + GAP) + 1, -TOP - row * (TILE_H + GAP) - 1)
    t:SetWidth(TILE_W - 2)
    t.name:SetWidth(TILE_W - 46)
    t.desc:SetWidth(TILE_W - 24)
    t.status:SetWidth(TILE_W - 24)
  end
end

local function Build(page)
  P.view = UI.Segmented(page.headerBar, { { "pvp", "PvP" }, { "hunt", "Hunts" }, { "raid", "Raids" },
    { "loot", "Loot & more" }, { "guild", "Guild" } },
    ns.RefreshPanel)
  P.view:SetPoint("RIGHT")
  TAB.view = P.view
  BuildTiles(page)
  BuildGuild(page)
  UI.Grow(page, P.guildView, 1, 1)
  UI.Grow(page, P.feedCard, 1, 1)
  UI.Grow(page, P.feed, 1, 1)
  UI.Follow(page, P.leadCard, 1, 0)
  UI.Grow(page, P.leadCard, 0, 1)
  UI.Grow(page, P.tilesView, 1, 0)
  table.insert(page.growth, function(dw) relayoutTiles(740 + dw) end)
end

-- Open the tab on someone's achievements (nil: yours).
function ns.ShowAchievements(name)
  viewing = name and Ambiguate(name, "short") or nil
  if viewing and ns.Key(viewing) == ns.Key(UnitName("player")) then viewing = nil end
  local view = P.view and P.view.value
  ns.OpenPanel("achievements", (view == nil or view == "guild") and "pvp" or view)
end

local function Subtitle()
  if P.view and P.view.value == "guild" then
    local feed = ns.GuildAchievements()
    return #feed == 0 and "Achievements earned across the guild" or (#feed .. " earned across the guild")
  end
  local name = who()
  -- Your count is shown under your name already.
  if isMe() then return ns.T("Earn achievements and titles; click any name to see someone's record.") end
  return ns.TF("%s: %d of %d earned", Ambiguate(name, "short"), ns.AchievementCount(name), #ns.ACHIEVEMENTS)
end

TAB = { id = "achievements", title = "Achievements", build = Build, refresh = Refresh, subtitle = Subtitle }
UI.AddTab(TAB)
