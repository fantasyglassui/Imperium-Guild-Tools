--[[
  Warcrest
  The Wanted tab's Bounties view (when the guild has bounties on): every
  bounty, open ones first, on the left; on the right, officers place a new
  one or withdraw the one picked, and everyone sees how bounties work.
]]

local _, ns = ...
local UI = ns.UI

local M = {}
UI.BountyView = M

local TABLE_W = 470
local SIDE_X = TABLE_W + 14
local SIDE_W = 740 - SIDE_X
local INNER = SIDE_W - 30
local ORANGE = "|cffffb347"
local selected

local STATE = {
  open = { "Open", "accent" },
  claimed = { "Claimed", "good" },
  withdrawn = { "Withdrawn", "muted" },
  expired = { "Expired", "muted" },
}

local function sorted()
  local list = ns.Bounties()
  table.sort(list, function(a, b)
    if (a.state == "open") ~= (b.state == "open") then return a.state == "open" end
    return a.t > b.t
  end)
  return list
end

function M.Build(page)
  local f = CreateFrame("Frame", nil, page)
  M.frame = f
  f:SetPoint("TOPLEFT")
  f:SetSize(740, 450)

  local card = UI.Box(f, 0, 0, TABLE_W, 450)
  M.card = card
  local y = UI.TableHeads(card, { { "TARGET", 12 }, { "REWARD", 170 }, { "STATUS", 250 }, { "PLACED", 380 } })
  M.list = UI.List(card, TABLE_W - 24, 450 + y - 2, 26,
    function(row)
      UI.RowSelection(row)
      row.target = UI.Label(row, "", "Subheading")
      row.target:SetPoint("LEFT", 12, 0)
      row.target:SetWidth(150)
      row.target:SetWordWrap(false)
      row.reward = UI.Label(row, "", "Number")
      row.reward:SetPoint("LEFT", 170, 0)
      row.state = UI.Label(row, "", "Small")
      row.state:SetPoint("LEFT", 250, 0)
      row.state:SetWidth(124)
      row.state:SetWordWrap(false)
      row.placed = UI.Label(row, "", "MutedSmall")
      row.placed:SetPoint("LEFT", 380, 0)
      UI.RowLine(row)
      row:SetScript("OnClick", function(self) selected = self.item.id; ns.RefreshPanel() end)
      UI.Tooltip(row, function() return ORANGE .. row.item.target .. "|r" end, function()
        local b = row.item
        local lines = { ("Placed by %s on %s."):format(b.by, ns.Date("%b %d at %H:%M", b.t)) }
        if b.note ~= "" then lines[#lines + 1] = "\"" .. b.note .. "\"" end
        if b.state == "claimed" then
          lines[#lines + 1] = ("Claimed by %s on %s."):format(b.killer, ns.Date("%b %d at %H:%M", b.claimedAt))
        elseif b.state == "open" then
          lines[#lines + 1] = ("Open until %s."):format(ns.Date("%b %d", b.expires))
        end
        return table.concat(lines, "\n")
      end)
    end,
    function(row, b)
      row.target:SetText(ORANGE .. b.target .. "|r")
      row.reward:SetText(b.amount > 0 and (b.amount .. " DKP") or (UI.Code("muted") .. "glory|r"))
      local st = STATE[b.state]
      row.state:SetText(UI.Code(st[2]) .. st[1] .. "|r" .. (b.state == "claimed" and (" by " .. b.killer) or ""))
      row.placed:SetText(ns.Date("%b %d", b.t))
      UI.SetRowSelected(row, b.id == selected)
    end, true)
  M.list.frame:SetPoint("TOPLEFT", card, "TOPLEFT", 0, y - 1)
  M.list:SetEmptyText("No bounties yet. Officers can place one on the right.")

  -- Right: place a bounty (officers), and the picked bounty.
  local side = CreateFrame("Frame", nil, f)
  M.side = side
  side:SetPoint("TOPLEFT", SIDE_X, 0)
  side:SetSize(SIDE_W, 450)

  local place = UI.Box(side, 0, 0, SIDE_W, 236, "Place a bounty")
  M.place = place
  UI.FieldLabel(place, "Enemy player", 14, -40)
  M.target = UI.EditBox(place, INNER, 24)
  M.target:SetHeight(26)
  M.target:SetPoint("TOPLEFT", 14, -54)
  M.rewardLabel = UI.FieldLabel(place, "Reward (DKP)", 14, -90)
  M.amount = UI.EditBox(place, 90, 4)
  M.amount:SetHeight(26)
  M.amount:SetPoint("TOPLEFT", 14, -104)
  M.amount:SetNumeric(true)
  M.amount:SetText("25")
  UI.FieldLabel(place, "Note (optional)", 14, -140)
  M.note = UI.EditBox(place, INNER, 60)
  M.note:SetHeight(26)
  M.note:SetPoint("TOPLEFT", 14, -154)
  M.placeButton = UI.Button(place, "Place bounty", INNER, "primary")
  M.placeButton:SetHeight(28)
  M.placeButton:SetPoint("BOTTOMLEFT", 14, 14)
  M.placeButton:SetScript("OnClick", function()
    if ns.PlaceBounty(M.target:GetText(), M.amount:GetText(), M.note:GetText()) then
      M.target:SetText("")
      M.note:SetText("")
      M.target:ClearFocus()
    end
  end)
  UI.Tooltip(M.placeButton, "Place bounty", "The whole guild is told. The first guild member to land the killing blow on them "
    .. "in the next 30 days claims it, and is paid automatically.")

  local info = CreateFrame("Frame", nil, side)
  M.info = info
  info:SetPoint("BOTTOMLEFT", 1, 1)
  info:SetSize(SIDE_W - 2, 200)
  UI.Card(info, 1)
  M.infoTitle = UI.Label(info, "How bounties work", "Heading")
  M.infoTitle:SetPoint("TOPLEFT", 14, -12)
  M.infoText = UI.Label(info, "", "Small")
  M.infoText:SetPoint("TOPLEFT", 14, -38)
  M.infoText:SetWidth(INNER)
  M.infoText:SetSpacing(3)
  M.withdraw = UI.Button(info, "Withdraw bounty", INNER)
  M.withdraw:SetHeight(26)
  M.withdraw:SetPoint("BOTTOMLEFT", 14, 14)
  M.withdraw:SetScript("OnClick", function() if selected then ns.WithdrawBounty(selected) end end)
  UI.Tooltip(M.withdraw, "Withdraw bounty", "Takes the bounty back. Nobody can claim it after this.")
  return f
end

function M.Refresh()
  local list = sorted()
  local current
  for _, b in ipairs(list) do if b.id == selected then current = b end end
  M.list:SetItems(list)

  local officer = ns.IsAddonOfficer()
  local dkp = ns.UsesDKP()
  M.place:SetShown(officer)
  M.amount:SetShown(dkp)
  M.rewardLabel:SetShown(dkp)
  -- Members get the explanation card full height.
  M.info:SetHeight(officer and 200 or 448)

  if current and officer and current.state == "open" then
    M.infoTitle:SetText(current.target)
    M.infoText:SetText(("%s, placed by %s on %s. Open until %s.%s"):format(
      current.amount > 0 and (current.amount .. " DKP") or "For the glory", current.by, ns.Date("%b %d", current.t),
      ns.Date("%b %d", current.expires), current.note ~= "" and ("\n\n\"" .. current.note .. "\"") or ""))
    M.withdraw:Show()
  else
    M.infoTitle:SetText("How bounties work")
    M.infoText:SetText("Officers put a reward on an enemy player's head. The first guild member to land the killing blow "
      .. "on them in the next 30 days claims it" .. (dkp and ", and the DKP is paid automatically." or ".")
      .. " Kills count the same way as on the Kills tab.\n\nThe guild hears when a bounty is placed and when it's claimed.")
    M.withdraw:Hide()
  end
end
