--[[
  The Imperium
  DKP tab: everyone's DKP, each member's history, and (for officers)
  awarding DKP and running loot auctions.
]]

local _, ns = ...
local UI = ns.UI

local P = {}
local selected = {}       -- name key -> true, for officer awards
local filterText = ""
local raidOnly = false
local view = "standings"  -- "loot" or "changes"

StaticPopupDialogs["IMPERIUM_DECAY"] = {
  text = "Take %s%% off everyone's DKP now? This can only be done once a week.",
  button1 = YES,
  button2 = NO,
  OnAccept = function() ns.ApplyDecay(P.decay:GetText()) end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
}

StaticPopupDialogs["IMPERIUM_NEW_SEASON"] = {
  text = "Start a new DKP season?\n\nEveryone keeps their DKP, but DKP changes and loot history from before today, and raids older than 30 days, are archived for good. Export first if you want a copy.\n\nSeason name:",
  button1 = OKAY,
  button2 = CANCEL,
  hasEditBox = true,
  OnShow = function(self)
    local box = self.editBox or self.EditBox
    if box then box:SetText("Season " .. date("%b %Y")) end
  end,
  OnAccept = function(self)
    local box = self.editBox or self.EditBox
    ns.StartSeason(box and box:GetText() or "")
  end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
}

StaticPopupDialogs["IMPERIUM_UNDO_DKP"] = {
  text = "Undo this DKP change for everyone?\n\n%s",
  button1 = YES,
  button2 = NO,
  OnAccept = function(_, entry) if entry and ns.UndoDKP(entry, "") then ns.Say("DKP change undone.") end end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
}

StaticPopupDialogs["IMPERIUM_FIX_LOOT"] = {
  text = "%s\n\nType a name to give it to someone else instead, or leave it blank to refund the DKP.",
  button1 = OKAY,
  button2 = CANCEL,
  hasEditBox = true,
  OnAccept = function(self, l)
    local box = self.editBox or self.EditBox
    if l then ns.ReassignLoot(l, box and box:GetText() or "") end
  end,
  EditBoxOnEnterPressed = function(self)
    local parent = self:GetParent()
    if parent.data then ns.ReassignLoot(parent.data, self:GetText()) end
    parent:Hide()
  end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
}

local function RefreshChanges()
  local q, shown = filterText:lower(), {}
  for _, c in ipairs(ns.DKPChanges()) do
    local e = c.entry
    if q == "" or e.names:lower():find(q, 1, true) or e.reason:lower():find(q, 1, true) then shown[#shown + 1] = c end
  end
  P.changeList:SetEmptyText(q == "" and "No DKP changes yet." or "No changes match your search.")
  P.changeList:SetItems(shown)
end

local function RefreshLoot()
  local q, shown = filterText:lower(), {}
  for _, l in ipairs(ns.LootHistory()) do
    local itemText = l.item:gsub("|H.-|h(.-)|h", "%1"):lower()
    if q == "" or l.winner:lower():find(q, 1, true) or itemText:find(q, 1, true) then shown[#shown + 1] = l end
  end
  P.lootList:SetEmptyText(q == "" and "No loot has been won in an auction yet." or "No loot matches your search.")
  P.lootList:SetItems(shown)
end

local function Refresh()
  local officer = ns.IsAddonOfficer()
  local standings, loot, changes = view == "standings", view == "loot", view == "changes"
  P.list.frame:SetShown(standings)
  P.lootList.frame:SetShown(loot)
  P.changeList.frame:SetShown(changes)
  P.standingsHeads:SetShown(standings)
  P.lootHeads:SetShown(loot)
  P.changeHeads:SetShown(changes)
  P.raidOnly:SetShown(standings)
  if loot then RefreshLoot() end
  if changes then RefreshChanges() end
  P.export:SetShown(officer)
  P.import:SetShown(officer)
  P.season:SetShown(officer)
  local requests = #ns.PendingAltRequests()
  P.alts:SetText(requests > 0 and ("Alts |cffff6060(" .. requests .. ")|r") or "Alts")
  local list = ns.DKPStandings()
  local inRaid
  if raidOnly then
    inRaid = {}
    for _, m in ipairs(ns.CurrentRaidMembers()) do inRaid[ns.Key(m.name)] = true end
  end
  local q, shown = filterText:lower(), {}
  for _, m in ipairs(list) do
    if (q == "" or m.name:lower():find(q, 1, true)) and (not inRaid or inRaid[m.key]) then
      shown[#shown + 1] = m
    end
  end
  table.sort(shown, function(a, b)
    if a.dkp ~= b.dkp then return a.dkp > b.dkp end
    return a.name < b.name
  end)
  if q ~= "" or raidOnly then
    P.list:SetEmptyText(raidOnly and "Nobody in your raid matches." or "Nobody matches your search.")
  else
    P.list:SetEmptyText("Nobody has any DKP yet. Officers award it on the DKP tab, or it builds up from raid nights.")
  end
  P.list:SetItems(shown)

  local count = 0
  for _ in pairs(selected) do count = count + 1 end
  P.selectedText:SetText(("%d selected"):format(count))

  -- Officers get the award and auction tools; everyone else sees their own DKP.
  P.officer:SetShown(officer)
  P.member:SetShown(not officer)
  local sn = ns.CurrentSeason()
  P.mine:SetText(("Your DKP: |cffd4af37%d|r"):format(ns.Balance(UnitName("player")))
    .. (sn and ("  |cff888888(" .. sn.name .. ")|r") or ""))
  local lines = {}
  for i, e in ipairs(ns.DKPHistory(UnitName("player"))) do
    if i > 14 then break end
    lines[#lines + 1] = ("|cff999999%s|r  %s%d|r  %s"):format(date("%b %d", e.t),
      e.amount >= 0 and "|cff40ff40+" or "|cffff6060", e.amount, e.reason)
  end
  P.myHistory:SetText(#lines > 0 and table.concat(lines, "\n") or "|cff888888No DKP changes yet.|r")

  local rules = ns.DKPRules()
  if not P.decay:HasFocus() then P.decay:SetText(rules.decay) end
  P.weekly:SetChecked(rules.auto)
  P.hidden:SetChecked(rules.hidden)
  UI.SetEnabled(P.auctionStart, officer and not ns.AuctionRunning())
  UI.SetEnabled(P.auctionCancel, officer and ns.AuctionRunning())
end

local function selectedNames()
  local names, list = {}, ns.DKPStandings()
  for _, m in ipairs(list) do
    if selected[m.key] then names[#names + 1] = m.full and Ambiguate(m.full, "none") or m.name end
  end
  return names
end

local function award(sign)
  local amount = tonumber(P.amount:GetText())
  if not amount or amount <= 0 then ns.Say("Enter an amount of DKP.") return end
  local names = selectedNames()
  if #names == 0 then ns.Say("Tick the members to give DKP to.") return end
  local reason = strtrim(P.reason:GetText() or "")
  if ns.AwardDKP(names, sign * amount, reason) then
    ns.Say(("%s %d DKP %s %d member%s."):format(sign > 0 and "Gave" or "Took", amount,
      sign > 0 and "to" or "from", #names, #names == 1 and "" or "s"))
    wipe(selected)
    P.reason:SetText("")
    ns.RefreshPanel()
  end
end

local function BuildOfficer(parent)
  local o = CreateFrame("Frame", nil, parent)
  o:SetAllPoints()
  P.officer = o

  UI.Label(o, "Award DKP", "GameFontNormalLarge"):SetPoint("TOPLEFT", 0, -4)
  P.selectedText = UI.Label(o, "", "GameFontHighlightSmall")
  P.selectedText:SetPoint("TOPLEFT", 0, -28)

  local raidBtn = UI.Button(o, "Select current raid", 150)
  raidBtn:SetPoint("TOPLEFT", 0, -44)
  UI.Tooltip(raidBtn, "Select current raid", "Selects everyone in your raid group in the list, ready for an award.")
  raidBtn:SetScript("OnClick", function()
    for _, n in ipairs(ns.RaidAttendees()) do selected[ns.Key(n)] = true end
    ns.RefreshPanel()
  end)
  local clearBtn = UI.Button(o, "Clear selection", 120)
  clearBtn:SetPoint("LEFT", raidBtn, "RIGHT", 6, 0)
  clearBtn:SetScript("OnClick", function() wipe(selected); ns.RefreshPanel() end)

  UI.Label(o, "Amount", "GameFontNormalSmall"):SetPoint("TOPLEFT", 0, -74)
  P.amount = UI.EditBox(o, 60, 5)
  P.amount:SetPoint("TOPLEFT", 6, -88)
  P.amount:SetNumeric(true)
  UI.Label(o, "Reason", "GameFontNormalSmall"):SetPoint("TOPLEFT", 80, -74)
  P.reason = UI.EditBox(o, 200, 60)
  P.reason:SetPoint("TOPLEFT", 86, -88)

  local add = UI.Button(o, "Add DKP", 110)
  add:SetPoint("TOPLEFT", 0, -114)
  add:SetScript("OnClick", function() award(1) end)
  UI.Tooltip(add, "Add DKP", "Gives the amount to everyone selected, with the reason typed. Every guildmate's addon records it, and it can be undone from the All changes view.")
  local remove = UI.Button(o, "Remove DKP", 110)
  remove:SetPoint("LEFT", add, "RIGHT", 6, 0)
  remove:SetScript("OnClick", function() award(-1) end)
  UI.Tooltip(remove, "Remove DKP", "Takes the amount off everyone selected, with the reason typed. It can be undone from the All changes view.")

  -- Loot auction
  UI.Label(o, "Loot auction", "GameFontNormalLarge"):SetPoint("TOPLEFT", 0, -156)
  UI.Label(o, "Item (Shift-click it from your bags or the loot window)", "GameFontNormalSmall"):SetPoint("TOPLEFT", 0, -180)
  P.item = UI.EditBox(o, 300, 255)
  P.item:SetPoint("TOPLEFT", 6, -194)
  P.item:SetScript("OnEnter", function(self)
    local link = self:GetText()
    if link and link:find("|H") then
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      pcall(GameTooltip.SetHyperlink, GameTooltip, link:match("|H(.-)|h"))
      GameTooltip:Show()
    end
  end)
  P.item:SetScript("OnLeave", function() GameTooltip:Hide() end)

  UI.Label(o, "Minimum bid", "GameFontNormalSmall"):SetPoint("TOPLEFT", 0, -222)
  P.minBid = UI.EditBox(o, 60, 5)
  P.minBid:SetPoint("TOPLEFT", 6, -236)
  P.minBid:SetNumeric(true)
  P.minBid:SetText("10")
  P.duration = UI.Cycle(o, 110, { { 30, "30 seconds" }, { 45, "45 seconds" }, { 60, "60 seconds" },
    { 20, "20 seconds" } })
  P.duration:SetPoint("TOPLEFT", 90, -232)

  P.auctionStart = UI.Button(o, "Start auction", 120)
  P.auctionStart:SetPoint("TOPLEFT", 0, -264)
  P.auctionStart:SetScript("OnClick", function()
    if ns.StartAuction(P.item:GetText(), P.minBid:GetText(), P.duration.value) then
      P.item:SetText("")
      P.item:ClearFocus()
    end
    ns.RefreshPanel()
  end)
  P.auctionCancel = UI.Button(o, "Cancel auction", 120)
  P.auctionCancel:SetPoint("LEFT", P.auctionStart, "RIGHT", 6, 0)
  P.auctionCancel:SetScript("OnClick", function() ns.CancelAuction(); ns.RefreshPanel() end)
  UI.Tooltip(P.auctionStart, "Start auction", "Opens bidding on the item for everyone in your raid, for the time chosen. If nobody bids, raiders can /roll for it free.")

  local hint = UI.Label(o, "Raid members with the addon get a bid window. The highest bid wins, and DKP is "
    .. "deducted automatically.", "GameFontDisableSmall")
  hint:SetPoint("TOPLEFT", 0, -294)
  hint:SetWidth(330)

  P.export = UI.Button(o, "Export DKP", 90)
  P.export:SetPoint("TOPLEFT", 0, -330)
  P.export:SetScript("OnClick", function() ns.ShowExport(ns.ExportDKP()) end)
  UI.Tooltip(P.export, "Export DKP", "Shows everyone's DKP as text you can copy, for example into a spreadsheet.")
  P.import = UI.Button(o, "Import balances", 112)
  P.import:SetPoint("LEFT", P.export, "RIGHT", 6, 0)
  P.import:SetScript("OnClick", function() ns.ShowImportWindow() end)
  UI.Tooltip(P.import, "Import balances", "Sets members' DKP from a list you paste in, such as one copied from a spreadsheet.")
  P.season = UI.Button(o, "New season", 100)
  P.season:SetPoint("LEFT", P.import, "RIGHT", 6, 0)
  P.season:SetScript("OnClick", function() StaticPopup_Show("IMPERIUM_NEW_SEASON") end)
  P.season:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Start a new DKP season")
    GameTooltip:AddLine("Everyone keeps their DKP. Older history is archived to keep the addon fast: DKP changes and loot from before today, and raids and attendance older than 30 days. Export first if you want a copy.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  P.season:SetScript("OnLeave", function() GameTooltip:Hide() end)

  -- DKP rules, for the whole guild
  local function saveRules()
    ns.SetDKPRules(P.decay:GetText(), P.weekly:GetChecked(), P.hidden:GetChecked())
  end
  UI.Label(o, "Decay %", "GameFontNormalSmall"):SetPoint("TOPLEFT", 0, -366)
  P.decay = UI.EditBox(o, 32, 2)
  P.decay:SetPoint("TOPLEFT", 54, -360)
  P.decay:SetNumeric(true)
  P.decay:SetScript("OnEnterPressed", function(self) self:ClearFocus(); saveRules() end)
  local apply = UI.Button(o, "Decay now", 84)
  apply:SetPoint("TOPLEFT", 92, -358)
  apply:SetScript("OnClick", function() StaticPopup_Show("IMPERIUM_DECAY", P.decay:GetText()) end)
  UI.Tooltip(apply, "Decay now", "Takes the percentage off everyone's DKP right away. It can only be done once per week.")
  P.weekly = UI.Check(o, "Every week", 180, -356)
  P.weekly:SetScript("OnClick", saveRules)
  P.weekly:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Weekly decay")
    GameTooltip:AddLine("An online officer's addon takes this percentage off everyone's DKP once each week, after the Tuesday reset.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  P.weekly:SetScript("OnLeave", function() GameTooltip:Hide() end)
  P.hidden = UI.Check(o, "Hidden bids: winner pays 2nd-highest + 1", 0, -382)
  P.hidden:SetScript("OnClick", saveRules)
  P.hidden:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Hidden bids")
    GameTooltip:AddLine("Nobody sees anyone else's bid. The highest bid wins, but only pays one more than the second-highest bid, so people can bid what an item is really worth to them.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  P.hidden:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function BuildMember(parent)
  local m = CreateFrame("Frame", nil, parent)
  m:SetAllPoints()
  P.member = m
  P.mine = UI.Label(m, "", "GameFontNormalLarge")
  P.mine:SetPoint("TOPLEFT", 0, -4)
  UI.Label(m, "Your recent DKP", "GameFontNormal"):SetPoint("TOPLEFT", 0, -36)
  P.myHistory = UI.Label(m, "", "GameFontHighlightSmall")
  P.myHistory:SetPoint("TOPLEFT", 0, -56)
  P.myHistory:SetWidth(340)
  P.myHistory:SetSpacing(3)
end

local function Build(page)
  local viewButton = UI.Cycle(page, 120, { { "standings", "Standings" }, { "loot", "Loot history" },
    { "changes", "All changes" } },
    function(v) view = v; ns.RefreshPanel() end)
  viewButton:SetPoint("TOPLEFT", 4, -2)

  local search = UI.EditBox(page, 110, 40)
  search:SetPoint("TOPLEFT", 134, -4)
  search.hint = UI.Label(search, "Search", "GameFontDisableSmall")
  search.hint:SetPoint("LEFT", 2, 0)
  search:SetScript("OnTextChanged", function(self)
    filterText = self:GetText() or ""
    self.hint:SetShown(filterText == "")
    ns.RefreshPanel()
  end)
  local raid = UI.Check(page, "In raid", 250, 0)
  raid:SetScript("OnClick", function(self) raidOnly = self:GetChecked() and true or false; ns.RefreshPanel() end)
  P.raidOnly = raid

  P.standingsHeads = CreateFrame("Frame", nil, page)
  P.standingsHeads:SetAllPoints()
  UI.Label(P.standingsHeads, "Member", "GameFontNormalSmall"):SetPoint("TOPLEFT", 34, -32)
  UI.Label(P.standingsHeads, "Att.", "GameFontNormalSmall"):SetPoint("TOPLEFT", 238, -32)
  UI.Label(P.standingsHeads, "DKP", "GameFontNormalSmall"):SetPoint("TOPLEFT", 300, -32)

  -- Loot history view
  P.lootHeads = CreateFrame("Frame", nil, page)
  P.lootHeads:SetAllPoints()
  for _, h in ipairs({ { "Date", 8 }, { "Item", 78 }, { "Winner", 236 }, { "DKP", 318 } }) do
    UI.Label(P.lootHeads, h[1], "GameFontNormalSmall"):SetPoint("TOPLEFT", h[2], -32)
  end
  P.lootList = UI.List(page, 360, 330, 20,
    function(row)
      row.date = UI.Label(row, "", "GameFontDisableSmall")
      row.date:SetPoint("LEFT", 4, 0)
      row.item = UI.Label(row, "", "GameFontHighlightSmall")
      row.item:SetPoint("LEFT", 74, 0)
      row.item:SetWidth(156)
      row.item:SetWordWrap(false)
      row.winner = UI.Label(row, "", "GameFontHighlightSmall")
      row.winner:SetPoint("LEFT", 232, 0)
      row.winner:SetWidth(80)
      row.dkp = UI.Label(row, "", "GameFontHighlight")
      row.dkp:SetPoint("LEFT", 314, 0)
      row:RegisterForClicks("RightButtonUp")
      row:SetScript("OnClick", function(self, button)
        if button == "RightButton" and ns.IsAddonOfficer() then
          local l = self.item
          StaticPopup_Show("IMPERIUM_FIX_LOOT", ("%s won %s for %d DKP."):format(l.winner, l.item, l.amount), nil, l)
        end
      end)
      row:SetScript("OnEnter", function(self)
        local l = self.item
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local ok = pcall(GameTooltip.SetHyperlink, GameTooltip, l.item:match("|H(.-)|h") or "")
        if not ok then GameTooltip:SetText(l.item) end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(("Won by %s for %d DKP"):format(l.winner, l.amount), 1, 0.82, 0)
        GameTooltip:AddLine(date("%A %b %d, %H:%M", l.t) .. (l.raid and (" - " .. l.raid) or ""), 0.8, 0.8, 0.8)
        GameTooltip:AddLine((l.roll and "Free roll" or "Auction") .. " run by " .. l.by, 0.6, 0.6, 0.6)
        if ns.IsAddonOfficer() then
          GameTooltip:AddLine("Right-click to refund it or give it to someone else.", 1, 0.5, 0.5)
        end
        GameTooltip:Show()
      end)
      row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end,
    function(row, l)
      row.date:SetText(date("%b %d", l.t))
      row.item:SetText(l.item)
      row.winner:SetText(l.winner)
      row.dkp:SetText(l.roll and "|cff888888roll|r" or l.amount)
    end)
  P.lootList.frame:SetPoint("TOPLEFT", 4, -48)

  -- All changes view
  P.changeHeads = CreateFrame("Frame", nil, page)
  P.changeHeads:SetAllPoints()
  for _, h in ipairs({ { "Date", 8 }, { "DKP", 62 }, { "Who", 112 }, { "Reason", 218 } }) do
    UI.Label(P.changeHeads, h[1], "GameFontNormalSmall"):SetPoint("TOPLEFT", h[2], -32)
  end
  P.changeList = UI.List(page, 360, 330, 20,
    function(row)
      row.date = UI.Label(row, "", "GameFontDisableSmall")
      row.date:SetPoint("LEFT", 4, 0)
      row.amount = UI.Label(row, "", "GameFontHighlightSmall")
      row.amount:SetPoint("LEFT", 58, 0)
      row.who = UI.Label(row, "", "GameFontHighlightSmall")
      row.who:SetPoint("LEFT", 108, 0)
      row.who:SetWidth(102)
      row.who:SetWordWrap(false)
      row.reason = UI.Label(row, "", "GameFontHighlightSmall")
      row.reason:SetPoint("LEFT", 214, 0)
      row.reason:SetWidth(140)
      row.reason:SetWordWrap(false)
      row:RegisterForClicks("RightButtonUp")
      row:SetScript("OnClick", function(self, button)
        local c = self.item
        if button == "RightButton" and ns.IsAddonOfficer() and not c.undone then
          local e = c.entry
          StaticPopup_Show("IMPERIUM_UNDO_DKP", ("%s%d DKP for %s: %s"):format(e.amount >= 0 and "+" or "", e.amount,
            e.names:gsub(",", ", "), e.reason), nil, e)
        end
      end)
      row:SetScript("OnEnter", function(self)
        local c, e = self.item, self.item.entry
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(("%s%d DKP"):format(e.amount >= 0 and "+" or "", e.amount), 1, 1, 1)
        GameTooltip:AddLine(e.reason, 1, 0.82, 0, true)
        GameTooltip:AddLine(e.names:gsub(",", ", "), 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine(("%s, by %s"):format(date("%A %b %d, %H:%M", e.t), e.a), 0.6, 0.6, 0.6)
        if c.undone then
          GameTooltip:AddLine(("Undone by %s%s"):format(c.undone.a, c.undone.reason ~= "" and (": " .. c.undone.reason) or ""), 1, 0.4, 0.4, true)
        elseif ns.IsAddonOfficer() then
          GameTooltip:AddLine("Right-click to undo it.", 1, 0.5, 0.5)
        end
        GameTooltip:Show()
      end)
      row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end,
    function(row, c)
      local e = c.entry
      local dim = c.undone and 0.45 or 1
      row.date:SetText(date("%b %d", e.t))
      row.amount:SetText((e.amount >= 0 and "|cff40ff40+" or "|cffff6060") .. e.amount .. "|r")
      row.who:SetText(e.names:gsub(",", ", "))
      row.reason:SetText(c.undone and ("|cff888888(undone) " .. e.reason .. "|r") or e.reason)
      row.amount:SetAlpha(dim); row.who:SetAlpha(dim); row.date:SetAlpha(dim)
    end)
  P.changeList.frame:SetPoint("TOPLEFT", 4, -48)

  P.alts = UI.Button(page, "Alts", 80)
  P.alts:SetPoint("TOPRIGHT", -4, -2)
  P.alts:SetScript("OnClick", function() ns.ShowAltsWindow() end)
  UI.Tooltip(P.alts, "Alts", "Link your alts to your main so they share its DKP. A number in red means alts are waiting for you to confirm them.")

  P.list = UI.List(page, 360, 330, 20,
    function(row)
      row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
      row.check:SetSize(20, 20)
      row.check:SetPoint("LEFT", 4, 0)
      row.check:SetScript("OnClick", function(self)
        selected[row.item.key] = self:GetChecked() and true or nil
        ns.RefreshPanel()
      end)
      row.name = UI.Label(row, "", "GameFontHighlightSmall")
      row.name:SetPoint("LEFT", 30, 0)
      row.name:SetWidth(200)
      row.name:SetWordWrap(false)
      row.att = UI.Label(row, "", "GameFontHighlightSmall")
      row.att:SetPoint("LEFT", 234, 0)
      row.dkp = UI.Label(row, "", "GameFontHighlight")
      row.dkp:SetPoint("LEFT", 296, 0)
      row:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.item.name .. ": " .. self.item.dkp .. " DKP")
        if self.item.alts and #self.item.alts > 0 then
          GameTooltip:AddLine("Alts: " .. table.concat(self.item.alts, ", "), 0.7, 0.7, 1, true)
        end
        local attended, total, noShows = ns.Attendance(self.item.name)
        if total > 0 then
          GameTooltip:AddLine(("Attendance: %d of %d raids in the last 30 days (%d%%)"):format(attended, total,
            math.floor(attended / total * 100 + 0.5)), 0.4, 0.8, 1)
        end
        if #noShows > 0 then
          GameTooltip:AddLine(("No-shows: %d (%s)"):format(#noShows, table.concat(noShows, ", ")), 1, 0.4, 0.4, true)
        end
        GameTooltip:AddLine(" ")
        for i, e in ipairs(ns.DKPHistory(self.item.name)) do
          if i > 10 then break end
          GameTooltip:AddDoubleLine(date("%b %d", e.t) .. "  " .. e.reason, (e.amount >= 0 and "+" or "") .. e.amount,
            0.8, 0.8, 0.8, e.amount >= 0 and 0.25 or 1, e.amount >= 0 and 1 or 0.4, 0.25)
        end
        GameTooltip:Show()
      end)
      row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end,
    function(row, m)
      local officer = ns.IsAddonOfficer()
      row.check:SetShown(officer)
      row.check:SetChecked(selected[m.key] or false)
      row.name:SetText(m.name .. (m.left and " |cff888888(left guild)|r" or "")
        .. ((m.alts and #m.alts > 0) and (" |cff8888ff+" .. #m.alts .. " alt" .. (#m.alts > 1 and "s" or "") .. "|r") or ""))
      local r, g, b = UI.ClassColor(m.classFile)
      row.name:SetTextColor(r, g, b)
      row.name:SetAlpha(m.online == false and 0.6 or 1)
      row.dkp:SetText(m.dkp)
      local attended, total, noShows = ns.Attendance(m.name)
      if total > 0 then
        local pct = math.floor(attended / total * 100 + 0.5)
        local color = pct >= 75 and "|cff40ff40" or (pct >= 40 and "|cffffd200" or "|cffff6060")
        row.att:SetText(color .. pct .. "%|r" .. (#noShows > 0 and " |cffff6060!|r" or ""))
      else
        row.att:SetText("|cff888888-|r")
      end
    end)
  P.list.frame:SetPoint("TOPLEFT", 4, -48)

  local right = CreateFrame("Frame", nil, page)
  right:SetPoint("TOPLEFT", 400, 0)
  right:SetPoint("BOTTOMRIGHT", -4, 0)
  BuildOfficer(right)
  BuildMember(right)

  -- Shift-clicking an item puts its link in the auction box while it has focus.
  local function insert(link)
    if P.item and P.item:HasFocus() and link then P.item:SetText(link) end
  end
  if ChatEdit_InsertLink then hooksecurefunc("ChatEdit_InsertLink", insert) end
  if ChatFrameUtil and ChatFrameUtil.InsertLink then hooksecurefunc(ChatFrameUtil, "InsertLink", insert) end
end

------------------------------------------------------------------------
-- Export window: the text is selected, ready to copy with Ctrl+C.
------------------------------------------------------------------------
local exportWin

function ns.ShowExport(text)
  if not exportWin then
    local ok, f = pcall(CreateFrame, "Frame", "TheImperiumExport", UIParent, "BasicFrameTemplateWithInset")
    if not ok then f = CreateFrame("Frame", "TheImperiumExport", UIParent) end
    exportWin = f
    f:SetSize(560, 420)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    tinsert(UISpecialFrames, "TheImperiumExport")
    if f.TitleText then f.TitleText:SetText(ns.COLOR .. "The Imperium|r  -  DKP export") end
    local hint = UI.Label(f, "Press Ctrl+C to copy, then paste it into a text file or spreadsheet.", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", 16, -32)
    local sf = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 16, -52)
    sf:SetPoint("BOTTOMRIGHT", -34, 16)
    local box = CreateFrame("EditBox", nil, sf)
    box:SetMultiLine(true)
    box:SetFontObject(ChatFontNormal)
    box:SetWidth(500)
    box:SetAutoFocus(false)
    box:SetScript("OnEscapePressed", function() f:Hide() end)
    -- Keep the text as exported, even if someone types in the box.
    box:SetScript("OnTextChanged", function(self, userInput)
      if userInput then self:SetText(f.text or ""); self:HighlightText() end
    end)
    sf:SetScrollChild(box)
    f.box = box
  end
  exportWin.text = text
  exportWin.box:SetText(text)
  exportWin:Show()
  exportWin.box:SetFocus()
  exportWin.box:HighlightText()
end

UI.AddTab({ id = "dkp", title = "DKP", build = Build, refresh = Refresh })
