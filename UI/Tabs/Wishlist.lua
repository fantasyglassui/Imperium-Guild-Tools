--[[
  The Imperium
  Wishlist tab: the guild's loot wishlist (who wants which item, Need before
  Want) on the left; your own wishlist on the right, where you add items by
  Shift-clicking them.
]]

local _, ns = ...
local UI = ns.UI
local C = UI.C

local P = {}
local query = ""

local TABLE_W = 450
local SIDE_X = TABLE_W + 14
local SIDE_W = 740 - SIDE_X
local INNER = SIDE_W - 30
local ADD_H = 156

-- An item's name in its quality color when the game knows it, else in gold.
local function itemText(id, name)
  local getInfo = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo
  local ok, _, link = pcall(getInfo or error, tonumber(id) or 0)
  if not ok then return UI.Code("accent") .. name .. "|r" end
  if type(link) == "string" then
    local color = link:match("^(|c%x%x%x%x%x%x%x%x)")
    if color then return color .. name .. "|r" end
  end
  return UI.Code("accent") .. name .. "|r"
end

local function itemTooltip(owner, id)
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  local ok = pcall(GameTooltip.SetHyperlink, GameTooltip, "item:" .. id)
  if not ok then GameTooltip:SetText("Item " .. id) end
end

local function raidKeys()
  local set = {}
  for _, m in ipairs(ns.CurrentRaidMembers()) do set[ns.Key(m.name)] = true end
  return set
end

local function Refresh()
  local filter = P.filter.value
  local only = filter == "raid" and raidKeys() or nil
  local q = query:lower()
  local rows = {}
  for _, it in ipairs(ns.GuildWishlist(only)) do
    local match = q == "" or it.name:lower():find(q, 1, true)
    if not match then
      for _, w in ipairs(it.wishers) do
        if w.name:lower():find(q, 1, true) then match = true break end
      end
    end
    if match then rows[#rows + 1] = it end
  end
  P.list:SetEmptyText(q ~= "" and "Nothing matches your search."
    or (filter == "raid" and (IsInRaid() and "Nobody in your raid has a wishlist yet." or "You're not in a raid.")
    or "Nobody has a wishlist yet. Add the first item on the right."))
  P.list:SetItems(rows)
  P.count:SetText(#rows == 1 and "1 item" or (#rows .. " items"))

  local mine = ns.Wishes(UnitName("player"))
  P.mine:SetItems(mine)
  local open = 0
  for _, w in ipairs(mine) do if not w.won then open = open + 1 end end
  P.mineCount:SetText(#mine > 0 and (open .. " wanted" .. (#mine > open and (" · " .. (#mine - open) .. " won") or "")) or "")
end

local function BuildTable(page)
  P.search = UI.SearchBox(page, 260, "Search items or names", function(text)
    query = text
    ns.RefreshPanel()
  end)
  P.search:SetPoint("TOPLEFT", 1, -1)
  P.count = UI.Label(page, "", "MutedSmall")
  P.count:SetPoint("TOPRIGHT", page, "TOPLEFT", TABLE_W - 4, -8)
  P.count:SetJustifyH("RIGHT")

  local card = UI.Box(page, 0, -36, TABLE_W, 412)
  P.card = card
  local y = UI.TableHeads(card, { { "ITEM", 12 }, { "WANTED BY", 196 }, { "NEED", TABLE_W - 14, right = true } })
  P.list = UI.List(card, TABLE_W - 24, 412 + y - 2, 26,
    function(row)
      row.itemName = UI.Label(row, "", "Subheading")
      row.itemName:SetPoint("LEFT", 12, 0)
      row.itemName:SetWidth(176)
      row.itemName:SetWordWrap(false)
      row.who = UI.Label(row, "", "Small")
      row.who:SetPoint("LEFT", 196, 0)
      row.who:SetPoint("RIGHT", -44, 0)
      row.who:SetWordWrap(false)
      row.need = UI.Label(row, "", "Number")
      row.need:SetPoint("RIGHT", -10, 0)
      row.need:SetJustifyH("RIGHT")
      UI.RowLine(row)
      row:SetScript("OnEnter", function(self)
        local it = self.item
        itemTooltip(self, it.id)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("On wishlists:", C.accent[1], C.accent[2], C.accent[3])
        for _, w in ipairs(it.wishers) do
          GameTooltip:AddDoubleLine(w.name .. (w.prio == "need" and "  (Need)" or "  (Want)"), w.dkp .. " DKP", 1, 1, 1, 0.8, 0.8, 0.8)
        end
        GameTooltip:Show()
      end)
      row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end,
    function(row, it)
      row.itemName:SetText(itemText(it.id, it.name))
      local names = {}
      for _, w in ipairs(it.wishers) do
        names[#names + 1] = w.prio == "need" and (UI.Code("text") .. w.name .. "|r") or (UI.Code("muted") .. w.name .. "|r")
      end
      row.who:SetText(table.concat(names, ", "))
      row.need:SetText(it.need > 0 and it.need or (UI.Code("faint") .. "0|r"))
    end, true)
  P.list.frame:SetPoint("TOPLEFT", card, "TOPLEFT", 0, y - 1)
end

local function BuildAdd(side)
  local a = UI.Box(side, 0, 0, SIDE_W, ADD_H, "Add to your wishlist")
  P.item = UI.EditBox(a, INNER, 255)
  P.item:SetHeight(26)
  P.item:SetPoint("TOPLEFT", 14, -38)
  P.item.hint = UI.Label(P.item, "Shift-click an item to put it here", "MutedSmall")
  P.item.hint:SetPoint("LEFT", 8, 0)
  P.item:HookScript("OnTextChanged", function(self) self.hint:SetShown((self:GetText() or "") == "") end)
  P.item:SetScript("OnEnter", function(self)
    local id = ns.ItemID(self:GetText())
    if id then itemTooltip(self, id); GameTooltip:Show() end
  end)
  P.item:SetScript("OnLeave", function() GameTooltip:Hide() end)

  UI.FieldLabel(a, "How much you want it", 14, -76)
  P.prio = UI.Segmented(a, { { "need", "Need" }, { "want", "Want" } })
  P.prio:SetPoint("TOPLEFT", 14, -90)
  UI.Tooltip(P.prio, "Need or Want", "Need: a big upgrade you'd bid on. Want: nice to have. Officers see Need first when the item drops.")

  local add = UI.Button(a, "Add", INNER - P.prio:GetWidth() - 8, "primary")
  add:SetHeight(26)
  add:SetPoint("TOPRIGHT", -14, -90)
  add:SetScript("OnClick", function()
    if ns.WishlistAdd(P.item:GetText(), P.prio.value) then
      P.item:SetText("")
      P.item:ClearFocus()
    end
  end)
  UI.Tooltip(add, "Add to your wishlist", "Adds the item, or changes Need and Want if it's already on your list. Every guildmate sees your wishlist.")

  local tip = UI.Label(a, "Shift-click it in your bags, chat or a loot window.", "MutedSmall")
  tip:SetPoint("TOPLEFT", 14, -126)
  tip:SetWidth(INNER)
  tip:SetWordWrap(false)
end

local function BuildMine(side)
  local m = CreateFrame("Frame", nil, side)
  P.mineCard = m
  m:SetPoint("TOPLEFT", 1, -(ADD_H + 14))
  m:SetSize(SIDE_W - 2, 450 - ADD_H - 16)
  UI.Card(m, 1)
  UI.Label(m, "Your wishlist", "Heading"):SetPoint("TOPLEFT", 14, -12)
  P.mineCount = UI.Label(m, "", "MutedSmall")
  P.mineCount:SetPoint("TOPRIGHT", -14, -15)
  P.mineCount:SetJustifyH("RIGHT")

  P.mine = UI.List(m, SIDE_W - 26, 450 - ADD_H - 16 - 42, 26,
    function(row)
      row.name = UI.Label(row, "", "Small")
      row.name:SetPoint("LEFT", 12, 0)
      row.name:SetWidth(SIDE_W - 26 - 4 - 12 - 84)
      row.name:SetWordWrap(false)
      row.prio = UI.Label(row, "", "Small")
      row.prio:SetPoint("RIGHT", -34, 0)
      row.prio:SetJustifyH("RIGHT")
      row.remove = UI.Button(row, "", 20)
      row.remove:SetHeight(20)
      row.remove:SetPoint("RIGHT", -6, 0)
      local x = UI.Icon(row.remove, "close", 10, C.muted)
      x:SetPoint("CENTER")
      row.remove:SetScript("OnClick", function() ns.WishlistRemove(row.item.id) end)
      UI.Tooltip(row.remove, "Remove", "Takes it off your wishlist.")
      UI.RowLine(row)
      row:SetScript("OnClick", function(self)
        local w = self.item
        if not w.won then ns.WishlistAdd("|Hitem:" .. w.id .. "|h[" .. w.name .. "]|h", w.prio == "need" and "want" or "need") end
      end)
      row:SetScript("OnEnter", function(self)
        itemTooltip(self, self.item.id)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(self.item.won and "You've won this since adding it." or "Click to switch between Need and Want.", 0.7, 0.7, 0.7)
        GameTooltip:Show()
      end)
      row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end,
    function(row, w)
      if w.won then
        row.name:SetText(UI.Code("muted") .. w.name .. "|r")
        row.prio:SetText(UI.Code("good") .. "Won|r")
      else
        row.name:SetText(itemText(w.id, w.name))
        row.prio:SetText(w.prio == "need" and (UI.Code("accent") .. "Need|r") or (UI.Code("textSoft") .. "Want|r"))
      end
    end, true)
  P.mine.frame:SetPoint("TOPLEFT", m, "TOPLEFT", 0, -40)
  P.mine:SetEmptyText("Nothing yet. Shift-click an item into the box above, pick Need or Want, and click Add.")
end

local function Build(page)
  P.filter = UI.Segmented(page.headerBar, { { "all", "Everyone" }, { "raid", "In my raid" } }, ns.RefreshPanel)
  P.filter:SetPoint("RIGHT")
  UI.Tooltip(P.filter, "Whose wishes", "Everyone in the guild, or only the people in your raid right now: handy when loot drops.")

  BuildTable(page)
  local side = CreateFrame("Frame", nil, page)
  P.side = side
  side:SetPoint("TOPLEFT", SIDE_X, 0)
  side:SetSize(SIDE_W, 450)
  BuildAdd(side)
  BuildMine(side)

  UI.Grow(page, P.card, 1, 1)
  UI.Grow(page, P.list, 1, 1)
  UI.Follow(page, P.count, 1, 0)
  UI.Follow(page, side, 1, 0)
  UI.Grow(page, P.mineCard, 0, 1)
  UI.Grow(page, P.mine, 0, 1)

  -- Shift-clicking an item puts its link in the box while it has focus.
  local function insert(link)
    if P.item and P.item:HasFocus() and link then P.item:SetText(link) end
  end
  if ChatEdit_InsertLink then hooksecurefunc("ChatEdit_InsertLink", insert) end
  if ChatFrameUtil and ChatFrameUtil.InsertLink then hooksecurefunc(ChatFrameUtil, "InsertLink", insert) end
end

local function Subtitle()
  local list = ns.GuildWishlist()
  local mine = 0
  for _, w in ipairs(ns.Wishes(UnitName("player"))) do if not w.won then mine = mine + 1 end end
  if #list == 0 then return "The loot the guild wants, Need before Want" end
  return ("%d item%s wanted across the guild · %d on yours"):format(#list, #list == 1 and "" or "s", mine)
end

UI.AddTab({ id = "wishlist", title = "Wishlist", build = Build, refresh = Refresh, subtitle = Subtitle })
