--[[
  Bannerhold
  Auction window: pops up for raid members when an officer auctions loot.
]]

local _, ns = ...
local UI = ns.UI

local win

local function itemIcon(link)
  local ok, icon = pcall(function()
    if C_Item and C_Item.GetItemIconByID then return C_Item.GetItemIconByID(link) end
    if GetItemIcon then return GetItemIcon(link) end
  end)
  return ok and icon or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function create()
  -- Escape doesn't close it: bidding shouldn't vanish by accident mid-raid.
  local f = UI.Window("BannerholdAuction", 340, 256, "Loot auction", true)
  win = f
  f:ClearAllPoints()
  f:SetPoint("TOP", 0, -140)

  f.icon = f:CreateTexture(nil, "ARTWORK")
  f.icon:SetSize(40, 40)
  f.icon:SetPoint("TOPLEFT", 16, -34)

  -- The item name; hover it for the item's tooltip.
  f.itemButton = CreateFrame("Button", nil, f)
  f.itemButton:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", 10, 0)
  f.itemButton:SetSize(260, 20)
  f.item = UI.Label(f.itemButton, "", "GameFontNormal")
  f.item:SetAllPoints()
  f.itemButton:SetScript("OnEnter", function(self)
    local a = ns.auction
    if not a then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    pcall(GameTooltip.SetHyperlink, GameTooltip, a.link:match("|H(.-)|h") or a.link)
    GameTooltip:Show()
  end)
  f.itemButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

  f.by = UI.Label(f, "", "GameFontDisableSmall")
  f.by:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", 10, -22)

  f.high = UI.Label(f, "", "GameFontHighlight")
  f.high:SetPoint("TOPLEFT", 16, -84)
  f.high:SetWidth(308)
  f.time = UI.Label(f, "", "GameFontHighlight")
  f.time:SetPoint("TOPRIGHT", -16, -66)
  f.wish = UI.Label(f, "", "MutedSmall")
  f.wish:SetPoint("TOPLEFT", 16, -101)
  f.wish:SetWidth(308)
  f.wish:SetWordWrap(false)
  f.mine = UI.Label(f, "", "GameFontHighlightSmall")
  f.mine:SetPoint("TOPLEFT", 16, -118)

  f.bid = UI.EditBox(f, 70, 6)
  f.bid:SetPoint("TOPLEFT", 22, -142)
  f.bid:SetNumeric(true)
  -- Bidding on gear your class can't use asks first.
  local function bid()
    local a = ns.auction
    if not a then return end
    if a.unusable and not a.confirmedUnusable then
      StaticPopup_Show("IMPERIUM_BID_UNUSABLE", nil, nil, f.bid:GetText())
      return
    end
    ns.PlaceBid(f.bid:GetText())
  end
  f.bid:SetScript("OnEnterPressed", function(self)
    bid()
    self:ClearFocus()
  end)
  f.bidButton = UI.Button(f, "Bid", 70, "primary")
  f.bidButton:SetPoint("LEFT", f.bid, "RIGHT", 8, 0)
  f.bidButton:SetScript("OnClick", bid)

  f.warn = UI.Label(f, "", "GameFontHighlightSmall")
  f.warn:SetPoint("TOPLEFT", 16, -170)
  f.warn:SetWidth(308)

  f.rollButton = UI.Button(f, "Roll (1-100)", 120, "primary")
  f.rollButton:SetPoint("TOPLEFT", 16, -140)
  f.rollButton:SetScript("OnClick", function(self)
    ns.RollForItem()
    self.rolled = true
    UI.SetEnabled(self, false)
  end)
  f.rollButton:Hide()

  local function raise(by)
    local a = ns.auction
    if not a then return end
    local base
    if a.hidden then base = a.myBid or (a.min - 1) else base = a.leader and a.high or (a.min - 1) end
    f.bid:SetText(base + by)
  end
  f.plus1 = UI.Button(f, "+1", 40)
  f.plus1:SetPoint("LEFT", f.bidButton, "RIGHT", 8, 0)
  f.plus1:SetScript("OnClick", function() raise(1) end)
  f.plus5 = UI.Button(f, "+5", 40)
  f.plus5:SetPoint("LEFT", f.plus1, "RIGHT", 4, 0)
  f.plus5:SetScript("OnClick", function() raise(5) end)
  f.plus10 = UI.Button(f, "+10", 44)
  f.plus10:SetPoint("LEFT", f.plus5, "RIGHT", 4, 0)
  f.plus10:SetScript("OnClick", function() raise(10) end)

  f.result = UI.Label(f, "", "GameFontNormal")
  f.result:SetPoint("BOTTOM", 0, 44)

  f.pass = UI.Button(f, "Pass", 90)
  f.pass:SetPoint("BOTTOM", 0, 14)
  f.pass:SetScript("OnClick", function() f:Hide() end)

  f:SetScript("OnUpdate", function(self, elapsed)
    self.acc = (self.acc or 0) + elapsed
    if self.acc < 0.2 then return end
    self.acc = 0
    local a = ns.auction
    if a and not a.done then
      self.time:SetText(("Time left: %ds"):format(math.max(0, math.ceil(a.ends - GetTime()))))
    end
  end)
  tinsert(UISpecialFrames, "BannerholdAuction")
end

StaticPopupDialogs["IMPERIUM_BID_UNUSABLE"] = {
  text = "Your class can't normally use this item. Bid on it anyway?",
  button1 = YES,
  button2 = NO,
  OnAccept = function(_, amount)
    if ns.auction then ns.auction.confirmedUnusable = true end
    ns.PlaceBid(amount)
  end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
}

function ns.RefreshAuctionWindow()
  local a = ns.auction
  if not (win and a) then return end
  if a.unusable == nil then
    local _, classFile = UnitClass("player")
    a.unusable = ns.CanUseItem(a.link, classFile) == false
  end
  win.warn:SetText(a.unusable and "|cffff6b6bYour class can't normally use this item.|r" or "")
  win.icon:SetTexture(itemIcon(a.link))
  win.item:SetText(a.link)
  win.by:SetText("Auctioned by " .. a.by)
  if a.hidden then
    win.high:SetText(("|cffe0b94cHidden bids|r - minimum %d. Highest wins, pays 2nd-highest + 1."):format(a.min))
    win.mine:SetText(("Your DKP: %d%s"):format(ns.Balance(UnitName("player")),
      a.myBid and ("     Your bid: |cff6fd08c%d|r (you can change it)"):format(a.myBid) or ""))
  else
    if a.leader then
      win.high:SetText(("Highest bid: |cffe0b94c%d|r by %s"):format(a.high, a.leader))
    else
      win.high:SetText(("No bids yet. Minimum: |cffe0b94c%d|r"):format(a.min))
    end
    win.mine:SetText(("Your DKP: %d"):format(ns.Balance(UnitName("player"))))
  end
  local open = not a.done and not a.rolling and not (a.result and a.result:find("Free roll"))
  for _, w in ipairs({ win.bid, win.bidButton, win.plus1, win.plus5, win.plus10 }) do
    UI.SetEnabled(w, open)
    w:SetShown(not a.rolling)
  end
  win.rollButton:SetShown(a.rolling == true)
  if a.rolling then
    win.high:SetText("|cffe0b94cNobody bid. Free roll!|r Roll if you'd like it; the highest roll wins it for free.")
    UI.SetEnabled(win.rollButton, not win.rollButton.rolled)
  end
  -- Who has it on their wishlist.
  local wishers, names = ns.WishersFor and ns.WishersFor(a.link) or {}, {}
  for _, w in ipairs(wishers) do
    names[#names + 1] = w.prio == "need" and (UI.Code("accent") .. w.name .. "|r") or w.name
  end
  local mineWish = ns.WishFor and ns.WishFor(UnitName("player"), a.link)
  if #names > 0 then
    win.wish:SetText((mineWish and (UI.Code("accent") .. "On your wishlist.|r  ") or "") .. "Wished for by " .. table.concat(names, ", "))
  else
    win.wish:SetText("")
  end
  win.result:SetText(a.result or "")
  if a.done then win.time:SetText("Finished") end
  win.pass:SetText(a.done and "Close" or "Pass")
end

function ns.ShowAuctionWindow()
  if not win then create() end
  win.bid:SetText("")
  win.rollButton.rolled = false
  ns.RefreshAuctionWindow()
  win:Show()
  PlaySound(SOUNDKIT.RAID_WARNING, "Master")
end

function ns.HideAuctionWindow()
  if win then win:Hide() end
end
