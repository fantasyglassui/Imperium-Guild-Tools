--[[
  Warcrest
  Officers tab: guild changes recorded while you're online. A searchable
  table with a filter at the top, and the last 7 days at a glance.
  Only shown to addon officers and ranks that can promote, demote or remove.
]]

local _, ns = ...
local Ambiguate = ns.Ambiguate
local UI = ns.UI
local C = UI.C

local P = {}
local query = ""

local TABLE_W = 500
local SIDE_X = TABLE_W + 14
local SIDE_W = 740 - SIDE_X
local INNER = SIDE_W - 30
local WEEK = 7 * 86400

StaticPopupDialogs["IMPERIUM_CLEAR_AUDIT"] = {
  text = "Clear the officer log for the whole guild? This can't be undone.",
  button1 = YES,
  button2 = NO,
  OnAccept = function() ns.ClearAudit() end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
}

-- Which filter each kind of entry belongs to.
local KIND = {
  promote = "ranks", demote = "ranks",
  join = "members", leave = "members", remove = "members",
  note = "notes", onote = "notes", motd = "notes", settings = "notes",
}

-- The tiles: label, which actions count.
local TILES = {
  { "Promoted", { promote = true } },
  { "Demoted", { demote = true } },
  { "Joined", { join = true } },
  { "Left", { leave = true, remove = true } },
}

local function classColorOf(name)
  local m = ns.Member(name)
  if m then return UI.ClassColor(m.classFile) end
  return C.textSoft[1], C.textSoft[2], C.textSoft[3]
end

local function Refresh()
  P.clear:SetShown(ns.IsGuildMaster()) -- only the Guild Master can clear logs
  local filter, q = P.filter.value, query:lower()
  local shown = {}
  for _, e in ipairs(ns.db.audit) do
    local text = ns.DescribeAction(e)
    if (filter == "all" or KIND[e.action] == filter) and (q == "" or text:lower():find(q, 1, true)) then
      shown[#shown + 1] = e
    end
  end
  P.list:SetEmptyText(#ns.db.audit == 0
    and "Nothing recorded yet. Promotions, demotions, joins, leaves and removals show here once they happen while you're online."
    or "Nothing matches.")
  P.list:SetItems(shown)
  P.count:SetText(("%d of %d entries"):format(#shown, #ns.db.audit))

  -- The last 7 days.
  local since = time() - WEEK
  for _, tile in ipairs(P.tiles) do
    local n = 0
    for _, e in ipairs(ns.db.audit) do
      if e.t >= since and tile.actions[e.action] then n = n + 1 end
    end
    tile.number:SetText(n)
    local c = n > 0 and C.text or C.faint
    tile.number:SetTextColor(c[1], c[2], c[3])
  end
end

local function BuildTable(page)
  P.search = UI.SearchBox(page, 260, "Search names or changes", function(text)
    query = text
    ns.RefreshPanel()
  end)
  P.search:SetPoint("TOPLEFT", 1, -1)
  P.count = UI.Label(page, "", "MutedSmall")
  P.count:SetPoint("TOPRIGHT", page, "TOPLEFT", TABLE_W - 4, -8)
  P.count:SetJustifyH("RIGHT")

  local card = UI.Box(page, 0, -36, TABLE_W, 412)
  P.card = card
  local y = UI.TableHeads(card, { { "WHEN", 12 }, { "WHO", 112 }, { "WHAT HAPPENED", 222 } })
  P.list = UI.List(card, TABLE_W - 24, 412 + y - 2, 26,
    function(row)
      row.time = UI.Label(row, "", "MutedSmall")
      row.time:SetPoint("LEFT", 12, 0)
      row.time:SetWidth(96)
      row.time:SetWordWrap(false)
      row.who = UI.Label(row, "", "Subheading")
      row.who:SetPoint("LEFT", 112, 0)
      row.who:SetWidth(104)
      row.who:SetWordWrap(false)
      row.text = UI.Label(row, "", "Small")
      row.text:SetPoint("LEFT", 222, 0)
      row.text:SetPoint("RIGHT", -8, 0)
      row.text:SetWordWrap(false)
      UI.RowLine(row)
      UI.Tooltip(row, function() return UI.FormatTime(row.item.t) end, function() return ns.DescribeAction(row.item) end)
    end,
    function(row, e)
      row.time:SetText(ns.Date("%b %d · %H:%M", e.t))
      local who = e.actor ~= "" and e.actor or e.target
      row.who:SetText(Ambiguate(who, "short"))
      row.who:SetTextColor(classColorOf(who))
      row.text:SetText(ns.DescribeAction(e))
    end, true)
  P.list.frame:SetPoint("TOPLEFT", card, "TOPLEFT", 0, y - 1)
end

local function BuildSide(page)
  local side = CreateFrame("Frame", nil, page)
  P.side = side
  side:SetPoint("TOPLEFT", SIDE_X, 0)
  side:SetSize(SIDE_W, 450)

  local week = UI.Label(side, "LAST 7 DAYS", "Label")
  week:SetPoint("TOPLEFT", 2, -8)
  P.tiles = {}
  local tileW = (SIDE_W - 10) / 2
  for i, t in ipairs(TILES) do
    local col, rowN = (i - 1) % 2, math.floor((i - 1) / 2)
    local tile = UI.StatTile(side, col * (tileW + 10), -36 - rowN * 82, tileW, 72, t[1])
    tile.actions = t[2]
    P.tiles[i] = tile
  end

  local about = CreateFrame("Frame", nil, side)
  P.about = about
  about:SetPoint("BOTTOMLEFT", 1, 1)
  about:SetSize(SIDE_W - 2, 196)
  UI.Card(about, 1)
  UI.Label(about, "About this log", "Heading"):SetPoint("TOPLEFT", 14, -12)
  local text = UI.Label(about, "Promotions, demotions, removals, joins and leaves come from the game, so they're logged "
    .. "however they were done, but only while you're online. Note, Message of the Day and settings changes made with "
    .. "the addon are logged too, without the text. \"Left\" counts removals as well.", "Small")
  text:SetPoint("TOPLEFT", 14, -38)
  text:SetWidth(INNER)
  text:SetSpacing(3)
end

local function Build(page)
  P.filter = UI.Segmented(page.headerBar, {
    { "all", "All" }, { "ranks", "Ranks" }, { "members", "Joins & leaves" }, { "notes", "Notes & settings" },
  }, ns.RefreshPanel)
  P.filter:SetPoint("RIGHT")
  P.clear = UI.Button(page.headerBar, "Clear log", 90)
  P.clear:SetHeight(26)
  P.clear:SetPoint("RIGHT", P.filter, "LEFT", -8, 0)
  P.clear:SetScript("OnClick", function() StaticPopup_Show("IMPERIUM_CLEAR_AUDIT") end)
  UI.Tooltip(P.clear, "Clear the officer log", "Clears the officer log for the whole guild. Only the Guild Master can do this, and you'll be asked to confirm.")

  BuildTable(page)
  BuildSide(page)
  UI.Grow(page, P.card, 1, 1)
  UI.Grow(page, P.list, 1, 1)
  UI.Follow(page, P.count, 1, 0)
  UI.Follow(page, P.side, 1, 0)
  UI.Grow(page, P.side, 0, 1)
end

local function Subtitle()
  local n = #ns.db.audit
  if n == 0 then return "Guild changes, recorded while you're online" end
  return ("%d change%s recorded · newest %s"):format(n, n == 1 and "" or "s", ns.Date("%b %d", ns.db.audit[1].t))
end

UI.AddTab({ id = "officers", title = "Officers", build = Build, refresh = Refresh, subtitle = Subtitle,
  visible = ns.CanSeeOfficerTools })
