--[[
  Warcrest
  Achievements tab. Three views, switched at the top:
    PvP, Raids & more: a member's achievements as tiles (yours, or whoever's
                       you opened from their player card), with progress.
    Guild:             achievements earned across the guild, newest first,
                       and who has the most.
  Also the title picker, used here and on the Settings tab.
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
local TILE_W = (740 - (COLS - 1) * GAP) / COLS
local TILE_H = 86
local MAX_TILES = 16

local function who() return viewing or UnitName("player") end
local function isMe() return ns.Key(who()) == ns.Key(UnitName("player")) end

------------------------------------------------------------------------
-- Title picker: a Cycle of your earned titles. Several can exist (this tab
-- and Settings); each refreshes itself.
------------------------------------------------------------------------
local pickers = {}

local function refreshPicker(c)
  local titles = ns.MyTitles()
  local options = { { "", "No title" } }
  for _, t in ipairs(titles) do options[#options + 1] = { t.id, t.title } end
  c.options = options
  local _, current = ns.TitleOf(UnitName("player"))
  current = current or ""
  for i, opt in ipairs(options) do
    if opt[1] == current then c.index, c.value = i, opt[1]; c:SetText("Title: " .. opt[2]) end
  end
  UI.SetEnabled(c, #titles > 0)
end

local function makePicker(parent, width)
  local c = UI.Cycle(parent, width, { { "", "No title" } }, function(v) ns.SetTitle(v) end)
  c:SetHeight(26)
  -- UI.Cycle steps through c.options; show "Title: ..." on the button.
  c:HookScript("OnClick", function(self)
    local opt = self.options[self.index]
    if opt then self:SetText("Title: " .. opt[2]) end
  end)
  UI.Tooltip(c, "Your title", function()
    return #ns.MyTitles() > 0 and "Click to change the title shown after your name on your player card and in the guild window. Guildmates see it too."
      or "Earn an achievement that comes with a title (like Executioner, Avenger or Iron Raider) to pick one here."
  end)
  pickers[#pickers + 1] = c
  refreshPicker(c)
  return c
end

-- The Settings tab's General view puts a picker in its "Your title" card.
function ns.BuildTitlePicker(card)
  local c = makePicker(card, card:GetWidth() - 28)
  c:SetPoint("TOPLEFT", 14, -40)
  local hint = UI.Label(card, "Shown after your name on your player card and around the guild window. "
    .. "Earn more on the Achievements tab.", "MutedSmall")
  hint:SetPoint("TOPLEFT", 14, -76)
  hint:SetWidth(card:GetWidth() - 28)
  ns.SetSettingsTitleRefresh(function() refreshPicker(c) end)
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
  t.name:SetWidth(TILE_W - 90)
  t.tag = UI.Label(t, "TITLE", "Label")
  t.tag:SetPoint("TOPRIGHT", -12, -14)
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
  t.track:SetPoint("BOTTOMRIGHT", -12, 15)
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
  local titleTag = ""
  if earned then
    t.status:SetText(UI.Code("good") .. (e.t > 0 and ("Earned " .. date("%b %d, %Y", e.t)) or "Earned") .. "|r" .. titleTag)
    t.track:Hide()
    t.fill:Hide()
  else
    local n = math.min(e and e.progress or 0, a.goal)
    t.status:SetText(a.goal > 1 and (UI.Code("muted") .. n .. " / " .. a.goal .. "|r" .. titleTag)
      or (UI.Code("faint") .. "Not yet|r" .. titleTag))
    t.track:SetShown(a.goal > 1)
    t.fill:SetShown(a.goal > 1 and n > 0)
    t.fill:SetWidth(math.max(1, (TILE_W - 94) * n / a.goal))
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
    if a.cat == cat or (cat == "raid" and a.cat == "guild") then shown[#shown + 1] = a end
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
  if isMe() then refreshPicker(P.picker) end
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
  for _, c in ipairs(pickers) do if c ~= P.picker then refreshPicker(c) end end
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

  P.picker = makePicker(f, 230)
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
      row.when:SetText(e.t > 0 and date("%b %d", e.t) or "-")
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

local function Build(page)
  P.view = UI.Segmented(page.headerBar, { { "pvp", "PvP" }, { "raid", "Raids & more" }, { "guild", "Guild" } },
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
  return (isMe() and "Yours: " or (Ambiguate(name, "short") .. ": ")) .. ns.AchievementCount(name) .. " of "
    .. #ns.ACHIEVEMENTS .. " earned"
end

TAB = { id = "achievements", title = "Achievements", build = Build, refresh = Refresh, subtitle = Subtitle }
UI.AddTab(TAB)
