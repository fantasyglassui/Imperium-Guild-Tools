--[[
  The Imperium
  Settings tab: guild-wide settings (officers) and personal choices.
  The page scrolls, since the list of alert types is long.
]]

local _, ns = ...
local UI = ns.UI

local ROW = 22
local MAX_PIN_HOURS = 7 * 24
local P = { guildTypes = {}, myTypes = {} }

local function formatHours(h)
  if h < 24 then return h == 1 and "1 hour" or (h .. " hours") end
  local d, rest = math.floor(h / 24), h % 24
  local text = d == 1 and "1 day" or (d .. " days")
  if rest > 0 then text = text .. " " .. (rest == 1 and "1 hour" or (rest .. " hours")) end
  return text
end

local function Refresh()
  local c, db = ns.cfg, ns.db
  local officer = ns.IsAddonOfficer()
  local isGM = ns.MyRank() == 0

  -- Guild-wide column
  P.enabled:SetChecked(c.enabled)
  UI.SetEnabled(P.enabled, officer)
  for key, cb in pairs(P.guildTypes) do
    cb:SetChecked(c.types[key])
    UI.SetEnabled(cb, officer and c.enabled)
  end
  P.rankValue = c.officerRank
  P.rankText:SetText(UI.RankName(P.rankValue) .. " and higher")
  UI.SetEnabled(P.rankDown, isGM)
  UI.SetEnabled(P.rankUp, isGM)
  UI.SetEnabled(P.save, officer)

  local status = officer and "You can change the guild settings."
    or ("Only " .. UI.RankName(c.officerRank) .. " and higher can change these.")
  if c.stamp > 0 then
    status = status .. "\nLast changed by " .. c.by .. " on " .. date("%b %d at %H:%M", c.stamp) .. "."
  end
  P.status:SetText(status)

  -- Personal column
  for key, cb in pairs(P.myTypes) do
    if cb.filter then
      -- A filter: on for the guild means on for everyone; otherwise your choice.
      local guildOn = c.types[key]
      cb:SetChecked(guildOn or db.show[key])
      UI.SetEnabled(cb, not guildOn)
      cb.label:SetText(cb.baseLabel .. (guildOn and "  |cff888888(on for guild)|r" or ""))
    else
      local guildOn = c.enabled and c.types[key]
      cb:SetChecked(db.show[key])
      UI.SetEnabled(cb, guildOn)
      cb.label:SetText(cb.baseLabel .. (guildOn and "" or "  |cff888888(off for guild)|r"))
    end
  end
  P.sound:SetChecked(db.sound)
  P.warn:SetChecked(db.warning)
  P.quietInstances:SetChecked(db.quietInstances)
  P.quietCombat:SetChecked(db.quietCombat)
  P.pins:SetChecked(db.mapPins)
  P.pinSlider:SetQuietly(db.pinHours)
  P.pinValue:SetText(formatHours(db.pinHours))
  UI.SetEnabled(P.pinSlider, db.mapPins)
  P.pinLabel:SetAlpha(db.mapPins and 1 or 0.5)
  P.pinValue:SetAlpha(db.mapPins and 1 or 0.5)
end

-- Every alert type as a checkbox, with a small heading per group.
local function TypeList(page, x, y, makeCheck)
  local group
  for _, t in ipairs(ns.TYPES) do
    if t.group ~= group then
      group = t.group
      UI.Label(page, ns.GROUP_LABELS[group], "GameFontNormalSmall"):SetPoint("TOPLEFT", x + 4, y - 4)
      y = y - 18
    end
    makeCheck(t, x, y)
    y = y - ROW
  end
  return y
end

local function Section(page, text, x, y)
  UI.Label(page, text, "GameFontNormal"):SetPoint("TOPLEFT", x, y)
  return y - 20
end

local function Build(page)
  -- Scrolling content
  local sf = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate")
  sf:SetPoint("TOPLEFT", 0, 0)
  sf:SetPoint("BOTTOMRIGHT", -24, 0)
  local content = CreateFrame("Frame", nil, sf)
  content:SetSize(650, 10)
  sf:SetScrollChild(content)

  ----------------------------------------------------------------- guild-wide
  UI.Label(content, "Guild-wide", "GameFontNormalLarge"):SetPoint("TOPLEFT", 8, -4)
  local d1 = UI.Label(content, "What gets announced at all. Set by officers.", "GameFontHighlightSmall")
  d1:SetPoint("TOPLEFT", 8, -26)

  P.enabled = UI.Check(content, "Guild alerts on", 8, -40)
  P.enabled:SetScript("OnClick", function(self)
    for _, cb in pairs(P.guildTypes) do UI.SetEnabled(cb, self:GetChecked()) end
  end)

  local y = TypeList(content, 20, -64, function(t, x, ty)
    P.guildTypes[t.key] = UI.Check(content, t.label, x, ty)
  end)

  local who = UI.Label(content, "Who can change these:", "GameFontNormalSmall")
  who:SetPoint("TOPLEFT", 12, y - 10)
  P.rankDown = UI.Button(content, "<", 24)
  P.rankDown:SetPoint("LEFT", who, "RIGHT", 8, 0)
  P.rankText = UI.Label(content, "")
  P.rankText:SetPoint("LEFT", P.rankDown, "RIGHT", 6, 0)
  P.rankUp = UI.Button(content, ">", 24)
  P.rankUp:SetPoint("LEFT", P.rankDown, "RIGHT", 140, 0)
  local function step(delta)
    P.rankValue = math.max(0, math.min(UI.NumRanks() - 1, P.rankValue + delta))
    P.rankText:SetText(UI.RankName(P.rankValue) .. " and higher")
  end
  P.rankDown:SetScript("OnClick", function() step(-1) end)
  P.rankUp:SetScript("OnClick", function() step(1) end)

  P.save = UI.Button(content, "Save for whole guild", 170)
  P.save:SetPoint("TOPLEFT", 8, y - 32)
  P.save:SetScript("OnClick", function()
    local types = {}
    for key, cb in pairs(P.guildTypes) do types[key] = cb:GetChecked() and true or false end
    ns.PushConfig({
      enabled = P.enabled:GetChecked() and true or false,
      types = types,
      officerRank = P.rankValue,
    })
  end)

  P.status = UI.Label(content, "", "GameFontDisableSmall")
  P.status:SetPoint("TOPLEFT", 8, y - 60)
  P.status:SetWidth(320)
  local leftBottom = y - 100

  ----------------------------------------------------------------- personal
  local x = 340
  UI.Label(content, "Just for you", "GameFontNormalLarge"):SetPoint("TOPLEFT", x, -4)
  local d2 = UI.Label(content, "Which alerts you want to see, and how.", "GameFontHighlightSmall")
  d2:SetPoint("TOPLEFT", x, -26)

  y = TypeList(content, x, -40, function(t, cx, ty)
    local cb = UI.Check(content, t.label, cx, ty)
    cb.baseLabel = t.label
    cb.filter = t.filter
    cb:SetScript("OnClick", function(self)
      ns.db.show[t.key] = self:GetChecked() and true or false
      if t.filter and ns.OnHistoryChanged then ns.OnHistoryChanged() end
    end)
    P.myTypes[t.key] = cb
  end)

  y = Section(content, "How alerts appear", x + 4, y - 10)
  P.sound = UI.Check(content, "Play a sound", x, y)
  P.sound:SetScript("OnClick", function(self) ns.db.sound = self:GetChecked() and true or false end)
  y = y - ROW
  P.warn = UI.Check(content, "Show in the middle of the screen", x, y)
  P.warn:SetScript("OnClick", function(self) ns.db.warning = self:GetChecked() and true or false end)
  y = y - ROW - 8

  y = Section(content, "Quiet mode", x + 4, y)
  P.quietInstances = UI.Check(content, "Hold alerts in dungeons and raids", x, y)
  P.quietInstances:SetScript("OnClick", function(self) ns.db.quietInstances = self:GetChecked() and true or false end)
  y = y - ROW
  P.quietCombat = UI.Check(content, "Hold alerts during combat", x, y)
  P.quietCombat:SetScript("OnClick", function(self) ns.db.quietCombat = self:GetChecked() and true or false end)
  y = y - ROW
  local qhint = UI.Label(content, "Held alerts are listed in chat once you're out.", "GameFontDisableSmall")
  qhint:SetPoint("TOPLEFT", x + 30, y - 2)
  y = y - 26

  y = Section(content, "World map", x + 4, y)
  P.pins = UI.Check(content, "Mark guild deaths on the world map", x, y)
  P.pins:SetScript("OnClick", function(self)
    ns.db.mapPins = self:GetChecked() and true or false
    if ns.RefreshMapPins then ns.RefreshMapPins() end
    ns.RefreshPanel()
  end)
  y = y - ROW

  P.pinLabel = UI.Label(content, "Keep marks for", "GameFontHighlightSmall")
  P.pinLabel:SetPoint("TOPLEFT", x + 30, y - 4)
  P.pinSlider = UI.Slider(content, 100, 1, MAX_PIN_HOURS, 1, function(h)
    ns.db.pinHours = h
    P.pinValue:SetText(formatHours(h))
    if ns.RefreshMapPins then ns.RefreshMapPins() end
  end)
  P.pinSlider:SetPoint("LEFT", P.pinLabel, "RIGHT", 8, 0)
  P.pinValue = UI.Label(content, "", "GameFontHighlightSmall")
  P.pinValue:SetPoint("LEFT", P.pinSlider, "RIGHT", 8, 0)
  P.pinSlider:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("How long a guild death stays marked on the map")
    GameTooltip:AddLine("Drag, or use the mouse wheel. 1 hour to 7 days.", 1, 1, 1)
    GameTooltip:Show()
  end)
  P.pinSlider:SetScript("OnLeave", function() GameTooltip:Hide() end)
  y = y - 34

  local test = UI.Button(content, "Show test alert", 130)
  test:SetPoint("TOPLEFT", x, y)
  test:SetScript("OnClick", ns.TestAlert)
  local hint = UI.Label(content, "A different alert type each click.", "GameFontDisableSmall")
  hint:SetPoint("LEFT", test, "RIGHT", 8, 0)
  y = y - 34

  content:SetHeight(math.max(-y, -leftBottom) + 10)
end

UI.AddTab({ id = "settings", title = "Settings", build = Build, refresh = Refresh })
