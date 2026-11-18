--[[
  The Imperium
  Wanted tab: enemy players who keep killing guild members.
]]

local _, ns = ...
local UI = ns.UI

local P = {}

local function ago(t)
  local s = time() - t
  if s < 3600 then return math.max(1, math.floor(s / 60)) .. " min ago" end
  if s < 86400 then return math.floor(s / 3600) .. " h ago" end
  return math.floor(s / 86400) .. " d ago"
end

local function Refresh()
  local list = ns.WantedList()
  P.list:SetEmptyText(("Nobody has killed guild members %d or more times in world PvP in the last 30 days."):format(
    ns.db.wantedThreshold or 3))
  P.list:SetItems(list)

  for i, opt in ipairs(P.threshold.options) do
    if opt[1] == ns.db.wantedThreshold then
      P.threshold.index, P.threshold.value = i, opt[1]
      P.threshold:SetText(opt[2])
    end
  end

  P.removeOnKill:SetChecked(ns.db.wantedRemoveOnKill)

  local hidden = ns.HiddenWantedCount()
  P.unhide:SetShown(hidden > 0)
  P.unhide:SetText(("Show hidden (%d)"):format(hidden))
end

local function Build(page)
  local desc = UI.Label(page, "Enemy players who keep killing guild members in world PvP (last 30 days). "
    .. "When a guildmate sees one, the guild is alerted and the sighting is marked on the map.",
    "GameFontHighlightSmall")
  desc:SetPoint("TOPLEFT", 8, -8)
  desc:SetWidth(470)

  local options = { { 2, "Wanted after 2 kills" }, { 3, "Wanted after 3 kills" },
    { 5, "Wanted after 5 kills" }, { 10, "Wanted after 10 kills" } }
  P.threshold = UI.Cycle(page, 160, options, function(v) ns.SetWantedThreshold(v) end)
  P.threshold.options = options
  P.threshold:SetPoint("TOPRIGHT", -4, -2)

  P.unhide = UI.Button(page, "Show hidden", 160)
  P.unhide:SetPoint("TOPRIGHT", -4, -28)
  P.unhide:SetScript("OnClick", ns.UnhideAllWanted)

  -- column headings
  local headings = { { "Player", 8 }, { "Guild kills", 200 }, { "Members killed", 290 },
    { "Last kill", 400 }, { "Last seen", 500 } }
  for _, h in ipairs(headings) do
    UI.Label(page, h[1], "GameFontNormalSmall"):SetPoint("TOPLEFT", h[2], -64)
  end

  P.list = UI.List(page, 660, 270, 20,
    function(row)
      row.cols = {}
      for i, h in ipairs(headings) do
        local fs = UI.Label(row, "", "GameFontHighlightSmall")
        fs:SetPoint("LEFT", h[2] - 4, 0)
        fs:SetWidth(i == 1 and 185 or (i == 5 and 150 or 100))
        fs:SetWordWrap(false)
        row.cols[i] = fs
      end
      row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
      row:SetScript("OnClick", function(self, button)
        local w = self.item
        if button == "RightButton" then
          ns.HideWanted(w.name)
        elseif w.seen and w.seen.mapID and ns.ShowDeathOnMap then
          ns.ShowDeathOnMap(w.seen)
        end
      end)
      row:SetScript("OnEnter", function(self)
        local w = self.item
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("|cffff66ff" .. w.name .. "|r")
        GameTooltip:AddLine(("Killed guild members %d times (%d different members)."):format(w.count, w.victimCount), 1, 1, 1, true)
        GameTooltip:AddLine(("Last killed %s in %s, %s."):format(w.lastVictim, w.lastZone, ago(w.last)), 0.8, 0.8, 0.8, true)
        if w.seen then
          GameTooltip:AddLine(("Last seen in %s by %s, %s."):format(w.seen.zone, w.seen.by, ago(w.seen.t)), 0.8, 0.8, 0.8, true)
          if w.seen.mapID then GameTooltip:AddLine("Click to see where on the map.", 0.5, 0.8, 1) end
        end
        GameTooltip:AddLine("Right-click to hide from your list.", 0.6, 0.6, 0.6)
        GameTooltip:Show()
      end)
      row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end,
    function(row, w)
      row.cols[1]:SetText("|cffff66ff" .. w.name .. "|r")
      row.cols[2]:SetText(w.count)
      row.cols[3]:SetText(w.victimCount)
      row.cols[4]:SetText(ago(w.last))
      row.cols[5]:SetText(w.seen and (ago(w.seen.t) .. " in " .. w.seen.zone) or "|cff8b95a7-|r")
    end)
  P.list.frame:SetPoint("TOPLEFT", 4, -80)

  P.removeOnKill = UI.Check(page, "Remove from the list when a guild member kills them", 4, -350)
  P.removeOnKill:SetScript("OnClick", function(self) ns.SetWantedRemoveOnKill(self:GetChecked()) end)
  P.removeOnKill:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Bounty claimed")
    GameTooltip:AddLine("When a guild member kills a wanted player, their count starts over. They come back if they keep killing guild members.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  P.removeOnKill:SetScript("OnLeave", function() GameTooltip:Hide() end)

  local note = UI.Label(page, "Built from the guild's shared death history. Hiding someone only affects your own list.",
    "GameFontDisableSmall")
  note:SetPoint("TOPLEFT", 8, -382)

  UI.Grow(page, P.list, 1, 1)
  UI.FollowAll(page, { P.removeOnKill, note }, 0, 1)
end

UI.AddTab({ id = "wanted", title = "Wanted", build = Build, refresh = Refresh })
