--[[
  The Imperium
  Officer Log tab: guild changes recorded while you're online.
  Only shown to addon officers and ranks that can promote, demote or remove.
]]

local _, ns = ...
local UI = ns.UI

local P = {}

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

local function Refresh()
  P.clear:SetShown(ns.IsGuildMaster()) -- only the Guild Master can clear logs
  local entries = ns.db.audit
  P.list:SetItems(entries)
  P.empty:SetShown(#entries == 0)
end

local function Build(page)
  UI.Label(page, "Officer Log", "GameFontNormalLarge"):SetPoint("TOPLEFT", 8, -4)
  local desc = UI.Label(page, "Promotions, demotions, removals, joins, leaves, note edits, Message of the Day "
    .. "and alert settings changes, recorded while you're online.", "GameFontHighlightSmall")
  desc:SetPoint("TOPLEFT", 8, -26)
  desc:SetWidth(540)

  local clear = UI.Button(page, "Clear log", 90)
  P.clear = clear
  clear:SetPoint("TOPRIGHT", -4, -2)
  clear:SetScript("OnClick", function() StaticPopup_Show("IMPERIUM_CLEAR_AUDIT") end)

  P.list = UI.List(page, 640, 330, 18,
    function(row)
      row.time = UI.Label(row, "", "GameFontDisableSmall")
      row.time:SetPoint("LEFT", 4, 0)
      row.time:SetWidth(90)
      row.text = UI.Label(row, "", "GameFontHighlightSmall")
      row.text:SetPoint("LEFT", 98, 0)
      row.text:SetPoint("RIGHT", -4, 0)
      row.text:SetWordWrap(false)
    end,
    function(row, e)
      row.time:SetText(UI.FormatTime(e.t))
      row.text:SetText(ns.DescribeAction(e))
    end)
  P.list.frame:SetPoint("TOPLEFT", 4, -56)

  P.empty = UI.Label(page, "Nothing recorded yet.", "GameFontDisable")
  P.empty:SetPoint("TOPLEFT", 12, -66)
end

UI.AddTab({ id = "officers", title = "Officers", build = Build, refresh = Refresh, visible = ns.CanSeeOfficerTools })
