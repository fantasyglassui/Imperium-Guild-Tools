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
end

local function Build(page)
  local desc = UI.Label(page, "Promotions, demotions, removals, joins, leaves, note edits, Message of the Day "
    .. "and alert settings changes, recorded while you're online.", "GameFontHighlightSmall")
  desc:SetPoint("TOPLEFT", 8, -8)
  desc:SetWidth(540)

  local clear = UI.Button(page, "Clear log", 90)
  P.clear = clear
  clear:SetPoint("TOPRIGHT", -4, -2)
  clear:SetScript("OnClick", function() StaticPopup_Show("IMPERIUM_CLEAR_AUDIT") end)
  UI.Tooltip(clear, "Clear the officer log", "Clears the officer log for the whole guild. Only the Guild Master can do this, and you'll be asked to confirm.")

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
  UI.Grow(page, P.list, 1, 1)
  P.list:SetEmptyText("Nothing recorded yet. Promotions, demotions, joins, leaves and kicks show here once they happen while you're online.")
end

UI.AddTab({ id = "officers", title = "Officers", build = Build, refresh = Refresh, visible = ns.CanSeeOfficerTools })
