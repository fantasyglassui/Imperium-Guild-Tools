--[[
  Warcrest
  The Calendar tab: the month at a glance. Raids scheduled, raid nights held,
  bosses killed and guild events, day by day (see RaidCalendar.lua). Click a
  raid or an event to open it.
]]

local _, ns = ...
local UI = ns.UI

local function Build(page)
  local cal = UI.RaidCalendar.Build(page)
  UI.Grow(page, cal, 1, 1)
  table.insert(page.growth, function(dw, dh) UI.RaidCalendar.Resize(740 + dw, 450 + dh) end)
end

local function Refresh()
  UI.RaidCalendar.Refresh()
end

local function Subtitle()
  return ns.T("Raids, raid nights, boss kills and guild events")
end

UI.AddTab({ id = "calendar", title = "Calendar", build = Build, refresh = Refresh, subtitle = Subtitle })
