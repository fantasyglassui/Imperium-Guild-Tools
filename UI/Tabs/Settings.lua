--[[
  Bannerhold
  Settings tab. Two views, switched at the top:
    Alerts:  every alert type with a Guild column (set by officers for
             everyone) and a You column (your own choice), plus how alerts
             appear.
    General: quiet mode, the world map, the weekly recap, your title and the
             guild window's size.
]]

local _, ns = ...
local UI = ns.UI
local C = UI.C

local MAX_PIN_HOURS = 7 * 24
local P = { guildTypes = {}, myTypes = {}, views = {} }
local TAB

local TABLE_W = 460
local SIDE_X = TABLE_W + 14
local SIDE_W = 740 - SIDE_X
local INNER = SIDE_W - 30
local GUILD_R, YOU_R = -86, -30  -- the two checkbox columns, from the card's right edge
local ROW, GROUP = 24, 20

local function formatHours(h)
  if h < 24 then return h == 1 and "1 hour" or (h .. " hours") end
  local d, rest = math.floor(h / 24), h % 24
  local text = d == 1 and "1 day" or (d .. " days")
  if rest > 0 then text = text .. " " .. (rest == 1 and "1 hour" or (rest .. " hours")) end
  return text
end

local function RefreshAlerts()
  local c, db = ns.cfg, ns.db
  local officer = ns.IsAddonOfficer()
  local isGM = ns.MyRank() == 0

  P.enabled:SetChecked(c.enabled)
  UI.SetEnabled(P.enabled, officer)
  for key, cb in pairs(P.guildTypes) do
    cb:SetChecked(c.types[key])
    UI.SetEnabled(cb, officer and c.enabled)
  end
  P.rankValue = P.rankValue or c.officerRank
  if not P.rankDirty then P.rankValue = c.officerRank end
  P.rankText:SetText(UI.RankName(P.rankValue) .. " and higher")
  UI.SetEnabled(P.rankDown, isGM)
  UI.SetEnabled(P.rankUp, isGM)
  UI.SetEnabled(P.save, officer)

  local status = officer and "You can change the guild column."
    or ("Only " .. UI.RankName(c.officerRank) .. " and higher can change the guild column.")
  if c.stamp > 0 then
    status = status .. "\nLast saved by " .. c.by .. ", " .. date("%b %d at %H:%M", c.stamp) .. "."
  end
  P.status:SetText(status)

  for key, cb in pairs(P.myTypes) do
    local note
    if cb.filter then
      -- A filter: on for the guild means on for everyone; otherwise your choice.
      local guildOn = c.types[key]
      cb:SetChecked(guildOn or db.show[key])
      UI.SetEnabled(cb, not guildOn)
      note = guildOn and "on for everyone" or nil
    else
      local guildOn = c.enabled and c.types[key]
      cb:SetChecked(db.show[key])
      UI.SetEnabled(cb, guildOn)
      note = not guildOn and "off for the guild" or nil
    end
    cb.note:SetText(note or "")
    cb.rowLabel:SetAlpha(note and not cb.filter and 0.55 or 1)
  end

  P.sound:SetChecked(db.sound)
  P.warn:SetChecked(db.warning)
end

local function RefreshGeneral()
  local db = ns.db
  P.quietInstances:SetChecked(db.quietInstances)
  P.quietCombat:SetChecked(db.quietCombat)
  P.recap:SetChecked(db.weeklyRecap)
  local pct = math.floor((db.panelScale or 1) * 100 + 0.5)
  P.scaleSlider:SetQuietly(pct)
  P.scaleValue:SetText(pct .. "%")
  P.pins:SetChecked(db.mapPins)
  P.pinSlider:SetQuietly(db.pinHours)
  P.pinValue:SetText(formatHours(db.pinHours))
  UI.SetEnabled(P.pinSlider, db.mapPins)
  P.pinLabel:SetAlpha(db.mapPins and 1 or 0.5)
  P.pinValue:SetAlpha(db.mapPins and 1 or 0.5)
  if P.refreshTitle then P.refreshTitle() end
end

local function Refresh()
  local view = P.view.value
  for id, f in pairs(P.views) do f:SetShown(id == view) end
  if view == "alerts" then RefreshAlerts() else RefreshGeneral() end
end

------------------------------------------------------------------------
-- Alerts view
------------------------------------------------------------------------
local function BuildAlertTable(parent)
  local card = UI.Box(parent, 0, 0, TABLE_W, 448)
  P.table = card
  UI.TableHeads(card, { { "ALERT", 14 } })
  for _, h in ipairs({ { "GUILD", GUILD_R }, { "YOU", YOU_R } }) do
    local fs = UI.Label(card, h[1], "Label")
    fs:SetPoint("TOP", card, "TOPRIGHT", h[2], -9)
    fs:SetJustifyH("CENTER")
  end
  local y = -32
  local group
  for _, t in ipairs(ns.TYPES) do
    if not t.hidden then -- hidden: no longer a choice
      if t.group ~= group then
        group = t.group
        local g = UI.Label(card, ns.GROUP_LABELS[group]:upper(), "Label")
        g:SetPoint("TOPLEFT", 14, y - 6)
        g:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
        y = y - GROUP
      end
      local label = UI.Label(card, t.label, "Body")
      label:SetPoint("TOPLEFT", 14, y - 5)
      label:SetWidth(TABLE_W - 230)
      label:SetWordWrap(false)

      local g = UI.CheckBox(card, 16)
      g:SetPoint("TOP", card, "TOPRIGHT", GUILD_R, y - 4)
      UI.Tooltip(g, t.label, "Guild-wide: whether this is announced at all, for everyone. Officers set this and click Save for whole guild.")
      P.guildTypes[t.key] = g

      local me = UI.CheckBox(card, 16)
      me:SetPoint("TOP", card, "TOPRIGHT", YOU_R, y - 4)
      me.filter = t.filter
      me.rowLabel = label
      me.note = UI.Label(card, "", "MutedSmall")
      me.note:SetPoint("TOPRIGHT", card, "TOPRIGHT", GUILD_R - 22, y - 6)
      me.note:SetJustifyH("RIGHT")
      me:SetScript("OnClick", function(self)
        ns.db.show[t.key] = self:GetChecked() and true or false
        if t.filter and ns.OnHistoryChanged then ns.OnHistoryChanged() end
      end)
      UI.Tooltip(me, t.label, "Just for you: untick to stop seeing this alert yourself. Greyed out when the guild has turned it off.")
      P.myTypes[t.key] = me

      local line = card:CreateTexture(nil, "BORDER")
      line:SetPoint("TOPLEFT", 14, y - ROW)
      line:SetPoint("TOPRIGHT", -14, y - ROW)
      line:SetHeight(1)
      line:SetColorTexture(C.line[1], C.line[2], C.line[3], 1)
      y = y - ROW
    end
  end
end

local function BuildGuildCard(parent)
  local g = UI.Box(parent, SIDE_X, 0, SIDE_W, 226, "Guild-wide")
  P.guildCard = g
  local d = UI.Label(g, "Set by officers for everyone.", "MutedSmall")
  d:SetPoint("TOPLEFT", 14, -34)

  P.enabled = UI.Check(g, "Guild alerts on", 10, -50)
  P.enabled:SetScript("OnClick", function(self)
    for _, cb in pairs(P.guildTypes) do UI.SetEnabled(cb, self:GetChecked()) end
  end)
  UI.Tooltip(P.enabled, "Guild alerts on", "Turns every alert off or on for the whole guild at once. Click Save for whole guild to send it.")

  UI.FieldLabel(g, "Who can change these", 14, -86)
  P.rankDown = UI.Button(g, "<", 26)
  P.rankDown:SetHeight(24)
  P.rankDown:SetPoint("TOPLEFT", 14, -100)
  P.rankUp = UI.Button(g, ">", 26)
  P.rankUp:SetHeight(24)
  P.rankUp:SetPoint("TOPRIGHT", -14, -100)
  P.rankText = UI.Label(g, "", "Small")
  P.rankText:SetPoint("LEFT", P.rankDown, "RIGHT", 8, 0)
  P.rankText:SetPoint("RIGHT", P.rankUp, "LEFT", -8, 0)
  P.rankText:SetJustifyH("CENTER")
  P.rankText:SetWordWrap(false)
  local function step(delta)
    P.rankValue = math.max(0, math.min(UI.NumRanks() - 1, P.rankValue + delta))
    P.rankDirty = true
    P.rankText:SetText(UI.RankName(P.rankValue) .. " and higher")
  end
  P.rankDown:SetScript("OnClick", function() step(-1) end)
  P.rankUp:SetScript("OnClick", function() step(1) end)
  UI.Tooltip(P.rankDown, "Higher ranks only", "Only the Guild Master can change who may edit the guild settings.")
  UI.Tooltip(P.rankUp, "More ranks", "Only the Guild Master can change who may edit the guild settings.")

  P.save = UI.Button(g, "Save for whole guild", INNER, "primary")
  P.save:SetHeight(28)
  P.save:SetPoint("TOPLEFT", 14, -136)
  UI.Tooltip(P.save, "Save for whole guild", "Sends the Guild column to every guildmate's addon. Members who are offline get it when they next log in while an officer is online.")
  P.save:SetScript("OnClick", function()
    local types = {}
    for key, cb in pairs(P.guildTypes) do types[key] = cb:GetChecked() and true or false end
    P.rankDirty = nil
    ns.PushConfig({
      enabled = P.enabled:GetChecked() and true or false,
      types = types,
      officerRank = P.rankValue,
    })
  end)

  P.status = UI.Label(g, "", "MutedSmall")
  P.status:SetPoint("TOPLEFT", 14, -174)
  P.status:SetWidth(INNER)
  P.status:SetSpacing(2)
end

local function BuildAppearCard(parent)
  local a = CreateFrame("Frame", nil, parent)
  P.appear = a
  a:SetPoint("BOTTOMLEFT", SIDE_X + 1, 1)
  a:SetSize(SIDE_W - 2, 172)
  UI.Card(a, 1)
  UI.Label(a, "How alerts appear", "Heading"):SetPoint("TOPLEFT", 14, -12)
  P.sound = UI.Check(a, "Play a sound", 10, -36)
  P.sound:SetScript("OnClick", function(self) ns.db.sound = self:GetChecked() and true or false end)
  P.warn = UI.Check(a, "Show in the middle of the screen", 10, -62)
  P.warn:SetScript("OnClick", function(self) ns.db.warning = self:GetChecked() and true or false end)
  local chat = UI.Label(a, "Alerts always go to chat too.", "MutedSmall")
  chat:SetPoint("TOPLEFT", 42, -92)

  local test = UI.Button(a, "Show test alert", INNER)
  test:SetHeight(26)
  test:SetPoint("BOTTOMLEFT", 14, 14)
  test:SetScript("OnClick", ns.TestAlert)
  UI.Tooltip(test, "Show test alert", "Shows an example alert just for you, so you can see how alerts look and sound. A different kind each click. Nobody else sees it.")
end

local function BuildAlerts(page)
  local f = CreateFrame("Frame", nil, page)
  f:SetPoint("TOPLEFT")
  f:SetSize(740, 450)
  P.views.alerts = f
  BuildAlertTable(f)
  BuildGuildCard(f)
  BuildAppearCard(f)
  return f
end

------------------------------------------------------------------------
-- General view
------------------------------------------------------------------------
local COL_W = (740 - 14) / 2

local function BuildGeneral(page)
  local f = CreateFrame("Frame", nil, page)
  f:SetPoint("TOPLEFT")
  f:SetSize(740, 450)
  P.views.general = f
  local x2 = COL_W + 14
  local inner = COL_W - 30

  -- Quiet mode
  local q = UI.Box(f, 0, 0, COL_W, 138, "Quiet mode")
  P.quietInstances = UI.Check(q, "Hold alerts in dungeons and raids", 10, -36)
  P.quietInstances:SetScript("OnClick", function(self) ns.db.quietInstances = self:GetChecked() and true or false end)
  P.quietCombat = UI.Check(q, "Hold alerts during combat", 10, -62)
  P.quietCombat:SetScript("OnClick", function(self) ns.db.quietCombat = self:GetChecked() and true or false end)
  local qhint = UI.Label(q, "Held alerts are listed in chat once you're out.", "MutedSmall")
  qhint:SetPoint("TOPLEFT", 14, -100)
  qhint:SetWidth(inner)

  -- World map
  local m = UI.Box(f, 0, -152, COL_W, 130, "World map")
  P.pins = UI.Check(m, "Mark guild deaths on the world map", 10, -36)
  P.pins:SetScript("OnClick", function(self)
    ns.db.mapPins = self:GetChecked() and true or false
    if ns.RefreshMapPins then ns.RefreshMapPins() end
    ns.RefreshPanel()
  end)
  P.pinLabel = UI.FieldLabel(m, "Keep marks for", 14, -74)
  P.pinSlider = UI.Slider(m, inner - 110, 1, MAX_PIN_HOURS, 1, function(h)
    ns.db.pinHours = h
    P.pinValue:SetText(formatHours(h))
    if ns.RefreshMapPins then ns.RefreshMapPins() end
  end)
  P.pinSlider:SetPoint("TOPLEFT", 14, -94)
  P.pinValue = UI.Label(m, "", "Small")
  P.pinValue:SetPoint("LEFT", P.pinSlider, "RIGHT", 12, 0)
  UI.Tooltip(P.pinSlider, "How long a guild death stays marked on the map", "Drag, or use the mouse wheel. 1 hour to 7 days.")

  -- Weekly recap
  local r = UI.Box(f, 0, -296, COL_W, 154, "Weekly recap")
  P.recap = UI.Check(r, "Show it after the Tuesday reset", 10, -36)
  P.recap:SetScript("OnClick", function(self) ns.db.weeklyRecap = self:GetChecked() and true or false end)
  local rhint = UI.Label(r, "Kills, top head hunters, raids, bosses and loot from the guild's week, in chat.", "MutedSmall")
  rhint:SetPoint("TOPLEFT", 14, -68)
  rhint:SetWidth(inner)
  local half = (inner - 6) / 2
  local last = UI.Button(r, "Show last week", half)
  last:SetHeight(26)
  last:SetPoint("BOTTOMLEFT", 14, 14)
  last:SetScript("OnClick", function() ns.ShowRecap(-1) end)
  local this = UI.Button(r, "This week so far", half)
  this:SetHeight(26)
  this:SetPoint("LEFT", last, "RIGHT", 6, 0)
  this:SetScript("OnClick", function() ns.ShowRecap(0) end)

  -- Your title (filled in by Achievements, if loaded)
  local t = UI.Box(f, x2, 0, COL_W, 138, "Your title")
  P.titleCard = t

  -- Guild window
  local w = UI.Box(f, x2, -152, COL_W, 130, "Guild window")
  UI.FieldLabel(w, "Size", 14, -38)
  -- The new size applies when you let go, so the window doesn't shift under the mouse while dragging.
  local pending
  local function apply()
    if pending then ns.SetPanelScale(pending / 100); pending = nil end
  end
  P.scaleSlider = UI.Slider(w, inner - 60, 70, 150, 5, function(v)
    pending = v
    P.scaleValue:SetText(v .. "%")
  end)
  P.scaleSlider:SetPoint("TOPLEFT", 14, -58)
  P.scaleSlider:HookScript("OnMouseUp", apply)
  P.scaleSlider:HookScript("OnMouseWheel", apply)
  P.scaleValue = UI.Label(w, "", "Small")
  P.scaleValue:SetPoint("LEFT", P.scaleSlider, "RIGHT", 12, 0)
  UI.Tooltip(P.scaleSlider, "Window size", "Makes this window and its pop-ups bigger or smaller, text and all. Drag, or use the mouse wheel. To show more rows instead, drag the window's bottom-right corner.")
  local reset = UI.Button(w, "Reset size and position", inner)
  reset:SetHeight(26)
  reset:SetPoint("BOTTOMLEFT", 14, 14)
  reset:SetScript("OnClick", function() ns.ResetPanelSize(); ns.RefreshPanel() end)
  UI.Tooltip(reset, "Reset size and position", "Puts the window back to its normal size, in the middle of the screen.")

  -- Commands
  local h = UI.Box(f, x2, -296, COL_W, 154, "Good to know")
  local tips = UI.Label(h, "/bannerhold card Name opens a guild member's player card. /bannerhold wishlist and "
    .. "/bannerhold achievements open those tabs, and /bannerhold updates shows what's new. "
    .. "/bannerhold help lists every command in chat.", "Small")
  tips:SetPoint("TOPLEFT", 14, -38)
  tips:SetWidth(inner)
  tips:SetSpacing(3)
  return f
end

-- Lets the Achievements file put its title picker on the General view.
function ns.SettingsTitleCard() return P.titleCard end
function ns.SetSettingsTitleRefresh(fn) P.refreshTitle = fn end

local function Build(page)
  P.view = UI.Segmented(page.headerBar, { { "alerts", "Alerts" }, { "general", "General" } }, ns.RefreshPanel)
  P.view:SetPoint("RIGHT")
  TAB.view = P.view
  local alerts = BuildAlerts(page)
  local general = BuildGeneral(page)
  if ns.BuildTitlePicker then ns.BuildTitlePicker(P.titleCard) end

  -- A bigger window: the alert table gets the room; the side cards move right.
  UI.Grow(page, alerts, 1, 1)
  UI.Grow(page, general, 1, 1)
  UI.Grow(page, P.table, 1, 0)
  UI.FollowAll(page, { P.guildCard, P.appear }, 1, 0)
end

TAB = { id = "settings", title = "Settings", build = Build, refresh = Refresh,
  subtitle = function()
    if P.view and P.view.value == "general" then return "Quiet mode, the map, the weekly recap, your title and the window" end
    return "Alerts for the whole guild, and just for you"
  end }
UI.AddTab(TAB)
