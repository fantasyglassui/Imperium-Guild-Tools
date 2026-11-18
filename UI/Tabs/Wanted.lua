--[[
  The Imperium
  Wanted tab: enemy players who keep killing guild members. A table of the
  wanted on the left; on the right, the one you picked (or the most wanted)
  and how the list works.
]]

local _, ns = ...
local UI = ns.UI
local C = UI.C

local P = {}
local selectedKey

local TABLE_W = 470
local SIDE_X = TABLE_W + 14
local SIDE_W = 740 - SIDE_X
local INNER = SIDE_W - 30
local WANTED = "|cffff66ff"

local function ago(t)
  local s = time() - t
  if s < 3600 then return math.max(1, math.floor(s / 60)) .. " min ago" end
  if s < 86400 then return math.floor(s / 3600) .. " h ago" end
  return math.floor(s / 86400) .. " d ago"
end

local function selectedEntry(list)
  for _, w in ipairs(list) do
    if w.key == selectedKey then return w end
  end
  return list[1]
end

local function RefreshDetail(w, list)
  local d = P.detail
  UI.SetEnabled(d.show, w ~= nil and w.seen ~= nil and w.seen.mapID ~= nil)
  UI.SetEnabled(d.hide, w ~= nil)
  if not w then
    d.label:SetText("MOST WANTED")
    d.name:SetText(UI.Code("muted") .. "Nobody|r")
    d.count:SetText("")
    d.lines:SetText(UI.Code("muted") .. "Enemy players show up here once they've killed guild members "
      .. (ns.db.wantedThreshold or 3) .. " times in world PvP in 30 days.|r")
    return
  end
  d.label:SetText(w == list[1] and "MOST WANTED" or "SELECTED")
  d.name:SetText(WANTED .. w.name .. "|r")
  d.count:SetText(w.count)
  local lines = {
    ("Killed %s%d|r guild member%s, %d time%s in all."):format(UI.Code("text"), w.victimCount,
      w.victimCount == 1 and "" or "s", w.count, w.count == 1 and "" or "s"),
    ("Last kill: %s%s|r in %s, %s."):format(UI.Code("text"), Ambiguate(w.lastVictim, "short"), w.lastZone or "?", ago(w.last)),
    w.seen and ("Last seen: %s by %s, %s."):format(w.seen.zone, Ambiguate(w.seen.by, "short"), ago(w.seen.t))
      or (UI.Code("muted") .. "Not seen lately.|r"),
  }
  d.lines:SetText(table.concat(lines, "\n"))
end

local function Refresh()
  local list = ns.WantedList()
  P.list:SetEmptyText(("Nobody has killed guild members %d or more times in world PvP in the last 30 days."):format(
    ns.db.wantedThreshold or 3))
  local current = selectedEntry(list)
  P.current = current
  P.list:SetItems(list)
  RefreshDetail(current, list)

  for i, opt in ipairs(P.threshold.options) do
    if opt[1] == ns.db.wantedThreshold then
      P.threshold.index, P.threshold.value = i, opt[1]
      P.threshold:SetText(opt[2])
    end
  end
  P.removeOnKill:SetChecked(ns.db.wantedRemoveOnKill)
  P.how:SetText(("Enemy players who have killed guild members %d or more times in world PvP in the last 30 days. "
    .. "When a guildmate spots one, everyone is alerted and the spot is marked on the map for 30 minutes."):format(
    ns.db.wantedThreshold or 3))

  local hidden = ns.HiddenWantedCount()
  P.unhide:SetShown(hidden > 0)
  P.unhide:SetText(("Show hidden (%d)"):format(hidden))
end

local function BuildTable(page)
  local card = UI.Box(page, 0, 0, TABLE_W, 412)
  P.card = card
  local heads = { { "PLAYER", 12 }, { "KILLS", 214 }, { "MEMBERS", 270 }, { "LAST KILL", 350 } }
  local y = UI.TableHeads(card, heads)

  P.list = UI.List(card, TABLE_W - 24, 412 + y - 2, 26,
    function(row)
      UI.RowSelection(row)
      row.name = UI.Label(row, "", "Subheading")
      row.name:SetPoint("LEFT", 12, 0)
      row.name:SetWidth(190)
      row.name:SetWordWrap(false)
      row.count = UI.Label(row, "", "Number")
      row.count:SetPoint("LEFT", 214, 0)
      row.victims = UI.Label(row, "", "Small")
      row.victims:SetPoint("LEFT", 270, 0)
      row.last = UI.Label(row, "", "MutedSmall")
      row.last:SetPoint("LEFT", 350, 0)
      row.last:SetPoint("RIGHT", -8, 0)
      row.last:SetWordWrap(false)
      UI.RowLine(row)
      row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
      row:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
          ns.HideWanted(self.item.name)
        else
          selectedKey = self.item.key
          ns.RefreshPanel()
        end
      end)
      row:SetScript("OnDoubleClick", function(self)
        local w = self.item
        if w.seen and w.seen.mapID and ns.ShowDeathOnMap then ns.ShowDeathOnMap(w.seen) end
      end)
      UI.Tooltip(row, function() return WANTED .. row.item.name .. "|r" end,
        "Click to see details. Double-click to see where they were last seen. Right-click to hide them from your list.")
    end,
    function(row, w)
      row.name:SetText(WANTED .. w.name .. "|r")
      row.count:SetText(w.count)
      row.victims:SetText(w.victimCount)
      row.last:SetText(ago(w.last))
      UI.SetRowSelected(row, P.current ~= nil and P.current.key == w.key)
    end, true)
  P.list.frame:SetPoint("TOPLEFT", card, "TOPLEFT", 0, y - 1)

  P.note = UI.Label(page, "Built from the guild's shared death history. Hiding someone only changes your own list.", "MutedSmall")
  P.note:SetPoint("TOPLEFT", 4, -428)
  P.note:SetWidth(TABLE_W)
  P.note:SetWordWrap(false)
end

local function BuildSide(page)
  local side = CreateFrame("Frame", nil, page)
  P.side = side
  side:SetPoint("TOPLEFT", SIDE_X, 0)
  side:SetSize(SIDE_W, 450)

  local d = UI.Box(side, 0, 0, SIDE_W, 200)
  P.detail = d
  d.label = UI.Label(d, "MOST WANTED", "Label")
  d.label:SetPoint("TOPLEFT", 14, -13)
  d.name = UI.Label(d, "", "Display")
  d.name:SetPoint("TOPLEFT", 14, -30)
  d.name:SetWidth(INNER - 50)
  d.name:SetWordWrap(false)
  d.count = UI.Label(d, "", "Display")
  d.count:SetPoint("TOPRIGHT", -14, -30)
  d.count:SetJustifyH("RIGHT")
  d.count:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
  d.lines = UI.Label(d, "", "Small")
  d.lines:SetPoint("TOPLEFT", 14, -66)
  d.lines:SetWidth(INNER)
  d.lines:SetSpacing(5)

  local half = (INNER - 6) / 2
  d.show = UI.Button(d, "Show on map", half)
  d.show:SetHeight(26)
  d.show:SetPoint("BOTTOMLEFT", 14, 14)
  d.show:SetScript("OnClick", function()
    local w = P.current
    if w and w.seen and w.seen.mapID and ns.ShowDeathOnMap then ns.ShowDeathOnMap(w.seen) end
  end)
  UI.Tooltip(d.show, "Show on map", "Opens the world map where they were last seen.")
  d.hide = UI.Button(d, "Hide", half)
  d.hide:SetHeight(26)
  d.hide:SetPoint("LEFT", d.show, "RIGHT", 6, 0)
  d.hide:SetScript("OnClick", function()
    if P.current then ns.HideWanted(P.current.name) end
  end)
  UI.Tooltip(d.hide, "Hide", "Takes them off your own list. Nobody else's list changes. Show hidden at the top brings them back.")

  local rules = CreateFrame("Frame", nil, side)
  P.rules = rules
  rules:SetPoint("BOTTOMLEFT", 1, 1)
  rules:SetSize(SIDE_W - 2, 236)
  UI.Card(rules, 1)
  UI.Label(rules, "How it works", "Heading"):SetPoint("TOPLEFT", 14, -12)
  P.how = UI.Label(rules, "", "Small")
  P.how:SetPoint("TOPLEFT", 14, -38)
  P.how:SetWidth(INNER)
  P.how:SetSpacing(3)

  P.removeOnKill = UI.Check(rules, "Clear when we kill them", 10, -158)
  P.removeOnKill:SetScript("OnClick", function(self) ns.SetWantedRemoveOnKill(self:GetChecked()) end)
  UI.Tooltip(P.removeOnKill, "Bounty claimed",
    "When a guild member kills a wanted player, their count starts over. They come back if they keep killing guild members.")
  local claimed = UI.Label(rules, "Their count starts over, so they come back only if they keep at it.", "MutedSmall")
  claimed:SetPoint("TOPLEFT", 42, -186)
  claimed:SetWidth(INNER - 28)
end

local function BuildHeader(bar)
  local options = { { 2, "Wanted after 2 kills" }, { 3, "Wanted after 3 kills" },
    { 5, "Wanted after 5 kills" }, { 10, "Wanted after 10 kills" } }
  P.threshold = UI.Cycle(bar, 170, options, function(v) ns.SetWantedThreshold(v) end)
  P.threshold.options = options
  P.threshold:SetHeight(26)
  P.threshold:SetPoint("RIGHT")
  UI.Tooltip(P.threshold, "When someone is wanted", "How many guild members an enemy player has to kill in 30 days to go on your list. Click to change it. This is your own choice.")

  P.unhide = UI.Button(bar, "Show hidden", 130)
  P.unhide:SetHeight(26)
  P.unhide:SetPoint("RIGHT", P.threshold, "LEFT", -8, 0)
  P.unhide:SetScript("OnClick", ns.UnhideAllWanted)
end

local function Build(page)
  BuildHeader(page.headerBar)
  BuildTable(page)
  BuildSide(page)
  UI.Grow(page, P.card, 1, 1)
  UI.Grow(page, P.list, 1, 1)
  UI.Follow(page, P.note, 0, 1)
  UI.Follow(page, P.side, 1, 0)
  UI.Grow(page, P.side, 0, 1)
end

-- The header's subtitle: how many are on the list.
local function Subtitle()
  local n = #ns.WantedList()
  if n == 0 then return "Nobody is wanted right now" end
  return n == 1 and "1 enemy player wanted" or (n .. " enemy players wanted")
end

UI.AddTab({ id = "wanted", title = "Wanted", build = Build, refresh = Refresh, subtitle = Subtitle })
