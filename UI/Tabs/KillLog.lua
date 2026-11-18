--[[
  The Imperium
  Kills tab: PvP kills by guild members, and the Top Head Hunters board.
]]

local _, ns = ...
local UI = ns.UI

local P = {}
local TOP_N = 18

StaticPopupDialogs["IMPERIUM_REMOVE_KILL"] = {
  text = "Remove this kill for the whole guild?\n\n%s",
  button1 = YES,
  button2 = NO,
  OnAccept = function(_, k) if k then ns.RemoveKill(k) end end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
}

StaticPopupDialogs["IMPERIUM_CLEAR_KILLS"] = {
  text = "Clear the kill log for the whole guild? This can't be undone.",
  button1 = YES,
  button2 = NO,
  OnAccept = function() ns.ClearKillLog() end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
}

local function Refresh()
  P.clear:SetShown(ns.IsGuildMaster()) -- only the Guild Master can clear logs
  local fromT, toT, monthName
  if P.period.value == "month" then
    fromT, toT, monthName = ns.MonthRange(0)
  elseif P.period.value == "lastmonth" then
    fromT, toT, monthName = ns.MonthRange(-1)
  elseif P.period.value == "week" then
    fromT = time() - 7 * 86400
  end
  local kills = ns.QueryKills(P.filter.value, fromT, toT)
  P.boardTitle:SetText("Top Head Hunters" .. (monthName and (" - " .. monthName) or ""))

  -- Last month's winner, under the board.
  local lastFrom, lastTo, lastName = ns.MonthRange(-1)
  local champ = ns.KillStats(ns.QueryKills("all", lastFrom, lastTo), 1)[1]
  P.champion:SetText(champ and ("|cffd4af37%s champion:|r %s (%d)"):format(lastName, champ.name, champ.count) or "")
  P.list:SetEmptyText(fromT and "No kills yet this month." or "No kills recorded yet.")
  P.list:SetItems(kills)
  P.total:SetText(("%d kills shown"):format(#kills))

  local top = ns.KillStats(kills, TOP_N)
  for i, fs in ipairs(P.hunters) do
    local e = top[i]
    if e then
      local name = i <= 3 and ("|cffd4af37" .. e.name .. "|r") or e.name -- gold for the top three
      local assists = e.assists > 0 and ("  |cff888888+%d assist%s|r"):format(e.assists, e.assists == 1 and "" or "s") or ""
      fs:SetText(("%d.  %s  |cffffffff%d|r%s"):format(i, name, e.count, assists))
    else
      fs:SetText(i == 1 and (P.period.value == "month" and "|cff888888No kills yet this month|r"
        or "|cff888888No kills yet|r") or "")
    end
  end
end

local function Board(page, title, y)
  P.boardTitle = UI.Label(page, title, "GameFontNormalLarge")
  P.boardTitle:SetPoint("TOPLEFT", 444, y)
  local lines = {}
  for i = 1, TOP_N do
    local fs = UI.Label(page, "", "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", 450, y - 8 - i * 16)
    fs:SetWidth(220)
    lines[i] = fs
  end
  return lines
end

local function Build(page)
  P.filter = UI.Cycle(page, 150, {
    { "all", "All kills" }, { "kill_world", "World PvP" }, { "kill_bg", "Battlegrounds & arenas" },
  }, ns.RefreshPanel)
  P.filter:SetPoint("TOPLEFT", 6, -2)
  UI.Tooltip(P.filter, "Which kills", "Click to switch between all kills, world PvP only, and battlegrounds and arenas only.")

  P.period = UI.Cycle(page, 130, {
    { "month", "This month" }, { "lastmonth", "Last month" }, { "week", "Last 7 days" }, { "all", "All time" },
  }, ns.RefreshPanel)
  P.period:SetPoint("LEFT", P.filter, "RIGHT", 6, 0)
  UI.Tooltip(P.period, "Time period", "Click to switch between this month, last month, the last 7 days and all time. Top Head Hunters follows the same period.")

  local clear = UI.Button(page, "Clear log", 90)
  P.clear = clear
  clear:SetPoint("TOPRIGHT", -4, -2)
  clear:SetScript("OnClick", function() StaticPopup_Show("IMPERIUM_CLEAR_KILLS") end)
  UI.Tooltip(clear, "Clear the kill log", "Clears the kill log and the leaderboard for the whole guild. Only the Guild Master can do this, and you'll be asked to confirm.")

  P.list = UI.List(page, 400, 320, 18,
    function(row)
      row.text = UI.Label(row, "", "GameFontHighlightSmall")
      row.text:SetPoint("LEFT", 4, 0)
      row.text:SetPoint("RIGHT", -4, 0)
      row.text:SetWordWrap(false)
      row:RegisterForClicks("RightButtonUp")
      row:SetScript("OnClick", function(self, button)
        if button == "RightButton" and ns.IsAddonOfficer() then
          StaticPopup_Show("IMPERIUM_REMOVE_KILL", ns.DescribeKill(self.item), nil, self.item)
        end
      end)
      row:SetScript("OnEnter", function(self)
        local k = self.item
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(k.victim .. (k.level and k.level > 0 and ("  (level " .. k.level .. ")") or ""), 1, 1, 1)
        GameTooltip:AddLine("Killing blow: " .. ns.KillingBlow(k), 0.25, 1, 0.25)
        local assists = ns.Assists(k)
        if #assists > 0 then GameTooltip:AddLine("Assists: " .. table.concat(assists, ", "), 0.8, 0.8, 0.8, true) end
        GameTooltip:AddLine(k.zone .. ", " .. UI.FormatTime(k.t), 0.7, 0.7, 0.7)
        if ns.IsAddonOfficer() then GameTooltip:AddLine("Right-click to remove this kill for the guild.", 1, 0.5, 0.5) end
        GameTooltip:Show()
      end)
      row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end,
    function(row, k)
      row.text:SetText(("|cff999999%s|r  %s%s|r"):format(date("%b %d %H:%M", k.t), ns.KILL_COLOR, ns.DescribeKill(k)))
    end)
  P.list.frame:SetPoint("TOPLEFT", 4, -32)

  P.total = UI.Label(page, "", "GameFontDisableSmall")
  P.total:SetPoint("TOPLEFT", 8, -360)

  P.hunters = Board(page, "Top Head Hunters", -34)
  P.champion = UI.Label(page, "", "GameFontHighlightSmall")
  P.champion:SetPoint("TOPLEFT", 450, -346)
  P.champion:SetWidth(220)

  local note = UI.Label(page, "Ranked by killing blows (whoever hit last, a best guess). "
    .. "The board starts fresh on the 1st of each month.", "GameFontDisableSmall")
  note:SetPoint("TOPLEFT", 8, -378)
end

UI.AddTab({ id = "kills", title = "Kills", build = Build, refresh = Refresh })
