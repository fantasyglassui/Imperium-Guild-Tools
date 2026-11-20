--[[
  Warcrest
  Events tab: guild events that aren't raids (PvP nights, world bosses,
  dungeons, meetings, get-togethers). The list of upcoming events on the
  left; the selected event, or the form for a new one, on the right.
]]

local _, ns = ...
local Ambiguate = ns.Ambiguate
local UI = ns.UI
local C = UI.C

local P = {}
local selectedId
local view = "event"   -- "event" or "new"
local tabView = "events" -- "events" or "polls"
local TAB
local newDay, newType, newMins = 0, "pvp", 120

local LEFT_W = 280
local RIGHT_X = LEFT_W + 14
local RIGHT_W = 740 - RIGHT_X
local SCROLL_ROOM = 26

local LENGTHS = { { 30, "30 min" }, { 60, "1 hour" }, { 90, "1.5 hours" }, { 120, "2 hours" }, { 180, "3 hours" },
  { 240, "4 hours" } }
local ANSWER_TEXT = { going = "Going", maybe = "Maybe", no = "Can't go" }

local function dayStart(n)
  local d = date("*t")
  d.hour, d.min, d.sec = 0, 0, 0
  return time(d) + n * 86400
end

local function parseTime(text)
  local h, m = (text or ""):match("^%s*(%d%d?):(%d%d)%s*$")
  h, m = tonumber(h), tonumber(m)
  if not h or h > 23 or m > 59 then return nil end
  return h * 3600 + m * 60
end

local function typeCode(e) return "|cff" .. ns.EventType(e.etype).color end

local function answerText(status)
  local col = status == "going" and "good" or (status == "maybe" and "accent" or "muted")
  return UI.Code(col) .. ns.T(ANSWER_TEXT[status]) .. "|r"
end

local function lengthText(mins)
  mins = tonumber(mins) or 120
  if mins < 60 then return mins .. " min" end
  local h = mins / 60
  return (h == math.floor(h) and ("%d h"):format(h) or ("%.1f h"):format(h))
end

------------------------------------------------------------------------
-- Refresh
------------------------------------------------------------------------
local function RefreshEvent(e)
  local d = P.event
  local has = e ~= nil
  for _, b in ipairs(d.answerButtons) do b:SetShown(has) end
  d.box:SetShown(has)
  for _, stat in pairs(d.stats) do stat:SetShown(has) end
  d.title:SetWidth(RIGHT_W - 36 - (e and 190 or 0))
  if not e then
    d.tag:SetText("")
    d.title:SetText(ns.T("No event selected"))
    d.when:SetText(#ns.GuildEvents() == 0 and ns.T("No events planned yet. Anyone in the guild can make one.")
      or ns.T("Pick an event on the left."))
    d.notes:SetText("")
    d.attend:SetText("")
    d.invite:Hide()
    d.take:Hide()
    return
  end
  local t = ns.EventType(e.etype)
  d.tag:SetText(typeCode(e) .. ns.Upper(ns.T(t.label)) .. "|r")
  d.title:SetText(e.title)
  d.when:SetText(("%s - %s (%s)  ·  %s %s"):format(ns.Date("%a %b %d, %H:%M", e.start), date("%H:%M", ns.EventEnds(e)),
    lengthText(e.mins), ns.T("by"), Ambiguate(e.a, "short")))
  d.notes:SetText(e.notes ~= "" and e.notes or ns.T("No notes."))

  local c = ns.EventCounts(e.id)
  for key, stat in pairs(d.stats) do
    local n = c[key]
    stat.number:SetText(n)
    local col = n == 0 and C.faint or (key == "going" and C.good or (key == "maybe" and C.text or C.muted))
    stat.number:SetTextColor(col[1], col[2], col[3])
  end

  local attended = ns.EventAttended(e.id)
  local rows, byKey = {}, {}
  for _, s in ipairs((ns.EventSignups(e.id))) do
    local m = ns.Member(s.name)
    local row = { name = s.name, status = s.status, classFile = m and m.classFile,
      came = attended and attended[ns.Key(s.name)] ~= nil }
    rows[#rows + 1] = row
    byKey[ns.Key(s.name)] = row
  end
  -- People who came without answering.
  for k, name in pairs(attended or {}) do
    if not byKey[k] then
      local m = ns.Member(name)
      rows[#rows + 1] = { name = name, classFile = m and m.classFile, came = true }
    end
  end
  P.signups:SetEmptyText(ns.T("Nobody has answered yet."))
  P.signups:SetItems(rows)

  if attended then
    local n = 0
    for _ in pairs(attended) do n = n + 1 end
    d.attend:SetText(UI.Code("good") .. (n == 1 and ns.T("1 member came.") or (ns.T("%d members came."):format(n))) .. "|r")
  else
    d.attend:SetText(UI.Code("muted") .. ns.T("Attendance not taken yet.") .. "|r")
  end
  local manage = ns.CanManageEvent(e)
  d.invite:SetShown(manage)
  d.take:SetShown(manage)

  local mine = ns.MyEventSignup(e.id)
  for _, b in ipairs(d.answerButtons) do b:SetStyle(mine and mine.status == b.status and "primary" or nil) end
end

local function Refresh()
  tabView = P.tabView.value or tabView
  P.card:SetShown(tabView == "events")
  P.right:SetShown(tabView == "events")
  UI.PollsView.frame:SetShown(tabView == "polls")
  if tabView == "polls" then UI.PollsView.Refresh() return end
  local events = ns.GuildEvents()
  if selectedId and not ns.GuildEvent(selectedId) then selectedId = nil end
  local stillListed = false
  for _, e in ipairs(events) do if e.id == selectedId then stillListed = true end end
  if not stillListed then selectedId = events[1] and events[1].id or nil end
  P.list:SetItems(events)
  local e = ns.GuildEvent(selectedId)
  UI.SetEnabled(P.cancelButton, ns.CanManageEvent(e))
  P.newsCheck:SetChecked(ns.db.eventNews and true or false)
  P.event:SetShown(view == "event")
  P.newFrame:SetShown(view == "new")
  if view == "event" then
    RefreshEvent(e)
  else
    P.newDayText:SetText(ns.Date("%A, %b %d", dayStart(newDay)))
  end
end

------------------------------------------------------------------------
-- Build
------------------------------------------------------------------------
StaticPopupDialogs["WARCREST_CANCEL_EVENT"] = {
  text = "Cancel %s for everyone?",
  button1 = YES,
  button2 = NO,
  OnAccept = function(_, id) ns.CancelGuildEvent(id) end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
}

local function TableBox(parent, heads)
  local box = CreateFrame("Frame", nil, parent)
  UI.Border(box, C.cardEdge[1], C.cardEdge[2], C.cardEdge[3], 1)
  local headBg = box:CreateTexture(nil, "BACKGROUND")
  headBg:SetPoint("TOPLEFT")
  headBg:SetPoint("TOPRIGHT")
  headBg:SetHeight(24)
  headBg:SetColorTexture(C.window[1], C.window[2], C.window[3], 1)
  local rule = box:CreateTexture(nil, "BORDER")
  rule:SetPoint("TOPLEFT", 0, -24)
  rule:SetPoint("TOPRIGHT", 0, -24)
  rule:SetHeight(1)
  rule:SetColorTexture(C.cardEdge[1], C.cardEdge[2], C.cardEdge[3], 1)
  for _, h in ipairs(heads) do
    local fs = UI.Label(box, h[1], "Label")
    if h[3] then
      fs:SetPoint("TOPRIGHT", h[2] - SCROLL_ROOM, -8)
      fs:SetJustifyH("RIGHT")
    else
      fs:SetPoint("TOPLEFT", h[2], -8)
    end
  end
  return box
end

local function BuildEventView(parent)
  local d = CreateFrame("Frame", nil, parent)
  d:SetAllPoints()
  P.event = d

  d.tag = UI.Label(d, "", "Label")
  d.tag:SetPoint("TOPLEFT", 18, -14)
  d.title = UI.Label(d, "", "Title")
  d.title:SetPoint("TOPLEFT", 18, -28)
  d.title:SetWidth(RIGHT_W - 36 - 190)
  d.title:SetWordWrap(false)
  d.when = UI.Label(d, "", "Small")
  d.when:SetPoint("TOPLEFT", 18, -52)
  d.when:SetWidth(RIGHT_W - 36)
  d.when:SetWordWrap(false)
  d.notes = UI.Label(d, "", "MutedSmall")
  d.notes:SetPoint("TOPLEFT", 18, -70)
  d.notes:SetWidth(RIGHT_W - 36)
  d.notes:SetWordWrap(false)

  -- Going / maybe / can't go, top right.
  d.stats = {}
  local x = -18
  for _, s in ipairs({ { "no", "can't go" }, { "maybe", "maybe" }, { "going", "going" } }) do
    local stat = CreateFrame("Frame", nil, d)
    stat:SetSize(58, 38)
    stat:SetPoint("TOPRIGHT", x, -14)
    stat.number = UI.Label(stat, "", "Heading")
    stat.number:SetPoint("TOP", 0, 0)
    stat.number:SetJustifyH("CENTER")
    local word = UI.Label(stat, s[2], "MutedSmall")
    word:SetPoint("TOP", 0, -20)
    word:SetJustifyH("CENTER")
    d.stats[s[1]] = stat
    x = x - 60
  end

  -- Your answer.
  local yours = UI.Label(d, "Your answer", "Subheading")
  yours:SetPoint("TOPLEFT", 18, -104)
  d.answerButtons = {}
  local prev
  for i = 3, 1, -1 do
    local s = ({ { "going", "Going" }, { "maybe", "Maybe" }, { "no", "Can't go" } })[i]
    local b = UI.Button(d, s[2], 80)
    b:SetHeight(26)
    b.status = s[1]
    if prev then b:SetPoint("RIGHT", prev, "LEFT", -6, 0) else b:SetPoint("TOPRIGHT", -18, -98) end
    b:SetScript("OnClick", function() if selectedId then ns.EventSignUp(selectedId, s[1]) end end)
    d.answerButtons[i] = b
    prev = b
  end

  d.box = TableBox(d, { { "NAME", 12 }, { "ANSWER", 200 }, { "CAME", -12, true } })
  d.box:SetPoint("TOPLEFT", 18, -136)
  d.box:SetPoint("BOTTOMRIGHT", -18, 50)
  P.signups = UI.List(d.box, RIGHT_W - 36 - 4, 448 - 136 - 50 - 26, 24,
    function(row)
      row.name = UI.Label(row, "", "Subheading")
      row.name:SetPoint("LEFT", 12, 0)
      row.name:SetWidth(180)
      row.name:SetWordWrap(false)
      row.answer = UI.Label(row, "", "Small")
      row.answer:SetPoint("LEFT", 200, 0)
      row.came = UI.Icon(row, "check", 14, C.good)
      row.came:SetPoint("RIGHT", -16, 0)
      UI.RowLine(row)
      row:SetScript("OnClick", function(self) ns.ShowPlayerCard(self.item.name) end)
      UI.Tooltip(row, function() return Ambiguate(row.item.name, "short") end, "Click for their player card.")
    end,
    function(row, s)
      row.name:SetText(Ambiguate(s.name, "short"))
      row.name:SetTextColor(UI.ClassColor(s.classFile))
      row.answer:SetText(s.status and answerText(s.status) or (UI.Code("muted") .. ns.T("Didn't answer") .. "|r"))
      row.came:SetShown(s.came)
    end, true)
  P.signups.frame:SetPoint("TOPLEFT", d.box, "TOPLEFT", 0, -25)

  d.attend = UI.Label(d, "", "Small")
  d.attend:SetPoint("BOTTOMLEFT", 18, 14)
  d.attend:SetSize(RIGHT_W - 36 - 250, 28)
  d.attend:SetJustifyV("MIDDLE")
  d.attend:SetWordWrap(true) -- two lines in longer languages, beside the buttons
  d.take = UI.Button(d, "Take attendance", 124)
  d.take:SetHeight(26)
  d.take:SetPoint("BOTTOMRIGHT", -18, 14)
  d.take:SetScript("OnClick", function() if selectedId then ns.TakeEventAttendance(selectedId) end end)
  UI.Tooltip(d.take, "Take attendance", "Records everyone in your group (party or raid) as having come. Group up with everyone at the event first.")
  d.invite = UI.Button(d, "Invite going", 110)
  d.invite:SetHeight(26)
  d.invite:SetPoint("RIGHT", d.take, "LEFT", -6, 0)
  d.invite:SetScript("OnClick", function() if selectedId then ns.InviteEventGoing(selectedId) end end)
  UI.Tooltip(d.invite, "Invite everyone going", "Invites every online guild member who answered Going or Maybe and isn't in your group yet.")

  local page = parent:GetParent()
  UI.Grow(page, P.signups, 1, 1)
end

local function BuildNewView(parent)
  local n = CreateFrame("Frame", nil, parent)
  n:SetAllPoints()
  P.newFrame = n
  UI.Label(n, "Plan a guild event", "Title"):SetPoint("TOPLEFT", 18, -16)
  local intro = UI.Label(n, "Guildmates hear about it and can answer straight away. Anyone going gets a reminder.", "MutedSmall")
  intro:SetPoint("TOPLEFT", 18, -40)
  intro:SetWidth(RIGHT_W - 36)
  intro:SetWordWrap(false)

  UI.FieldLabel(n, "Kind of event", 18, -66)
  local opts = {}
  for _, t in ipairs(ns.EVENT_TYPES) do opts[#opts + 1] = { t.key, t.label } end
  P.newType = UI.Segmented(n, opts, function(v) newType = v end)
  P.newType:SetPoint("TOPLEFT", 18, -78)

  UI.FieldLabel(n, "Name", 18, -114)
  P.newTitle = UI.EditBox(n, RIGHT_W - 36, 40)
  P.newTitle:SetHeight(26)
  P.newTitle:SetPoint("TOPLEFT", 18, -126)

  UI.FieldLabel(n, "Day", 18, -162)
  local prev = UI.Button(n, "<", 26)
  prev:SetHeight(26)
  prev:SetPoint("TOPLEFT", 18, -174)
  P.newDayText = UI.Label(n, "", "Subheading")
  P.newDayText:SetPoint("LEFT", prev, "RIGHT", 10, 0)
  P.newDayText:SetWidth(150)
  local nextB = UI.Button(n, ">", 26)
  nextB:SetHeight(26)
  nextB:SetPoint("LEFT", prev, "RIGHT", 170, 0)
  prev:SetScript("OnClick", function() newDay = math.max(0, newDay - 1); ns.RefreshPanel() end)
  nextB:SetScript("OnClick", function() newDay = math.min(60, newDay + 1); ns.RefreshPanel() end)

  UI.FieldLabel(n, "Start (24-hour, your time)", 250, -162)
  P.newTime = UI.EditBox(n, 70, 5)
  P.newTime:SetHeight(26)
  P.newTime:SetPoint("TOPLEFT", 250, -174)
  P.newTime:SetText("20:00")
  P.newLength = UI.Cycle(n, 100, LENGTHS, function(v) newMins = v end)
  P.newLength:SetHeight(26)
  P.newLength:SetPoint("LEFT", P.newTime, "RIGHT", 8, 0)
  P.newLength.index = 4
  P.newLength.value = 120
  P.newLength:SetText(LENGTHS[4][2])
  UI.Tooltip(P.newLength, "How long", "Click to change how long the event lasts.")

  UI.FieldLabel(n, "Notes (optional)", 18, -212)
  P.newNotes = UI.EditBox(n, RIGHT_W - 36, 100)
  P.newNotes:SetHeight(26)
  P.newNotes:SetPoint("TOPLEFT", 18, -224)

  local create = UI.Button(n, "Create event", 120, "primary")
  create:SetHeight(28)
  create:SetPoint("TOPLEFT", 18, -270)
  create:SetScript("OnClick", function()
    local seconds = parseTime(P.newTime:GetText())
    if not seconds then ns.Say("Enter the start time like 20:00.") return end
    local e = ns.CreateGuildEvent(newType, P.newTitle:GetText(), dayStart(newDay) + seconds,
      strtrim(P.newNotes:GetText() or ""), newMins)
    if e then
      selectedId, view = e.id, "event"
      P.newTitle:SetText("")
      P.newNotes:SetText("")
      ns.RefreshPanel()
    end
  end)
  local back = UI.Button(n, "Cancel", 90)
  back:SetHeight(28)
  back:SetPoint("LEFT", create, "RIGHT", 6, 0)
  back:SetScript("OnClick", function() view = "event"; ns.RefreshPanel() end)
end

local function Build(page)
  -- Events or polls.
  P.tabView = UI.Segmented(page.headerBar, { { "events", "Events" }, { "polls", "Polls" } },
    function(v) tabView = v; ns.RefreshPanel() end)
  P.tabView:SetPoint("RIGHT")
  TAB.view = P.tabView
  UI.PollsView.Build(page)

  -- Upcoming events.
  local card = CreateFrame("Frame", nil, page)
  P.card = card
  card:SetPoint("TOPLEFT", 1, -1)
  card:SetSize(LEFT_W - 2, 448)
  UI.Card(card, 1)
  UI.Label(card, "UPCOMING EVENTS", "Label"):SetPoint("TOPLEFT", 14, -13)
  local rule = card:CreateTexture(nil, "BORDER")
  rule:SetPoint("TOPLEFT", 0, -32)
  rule:SetPoint("TOPRIGHT", 0, -32)
  rule:SetHeight(1)
  rule:SetColorTexture(C.cardEdge[1], C.cardEdge[2], C.cardEdge[3], 1)

  P.list = UI.List(card, LEFT_W - 24, 448 - 33 - 82, 46,
    function(row)
      UI.RowSelection(row)
      row.tag = UI.Label(row, "", "Label")
      row.tag:SetPoint("TOPLEFT", 14, -6)
      row.title = UI.Label(row, "", "Subheading")
      row.title:SetPoint("TOPLEFT", 14, -18)
      row.title:SetPoint("RIGHT", -50, 0)
      row.title:SetWordWrap(false)
      row.when = UI.Label(row, "", "MutedSmall")
      row.when:SetPoint("TOPLEFT", 14, -32)
      row.count = UI.Label(row, "", "Heading")
      row.count:SetPoint("RIGHT", -12, 4)
      row.count:SetJustifyH("RIGHT")
      row.mine = UI.Label(row, "", "MutedSmall")
      row.mine:SetPoint("TOPRIGHT", -12, -30)
      row.mine:SetJustifyH("RIGHT")
      UI.RowLine(row)
      row:SetScript("OnClick", function(self)
        selectedId, view = self.item.id, "event"
        ns.RefreshPanel()
      end)
    end,
    function(row, e)
      UI.SetRowSelected(row, e.id == selectedId)
      row.tag:SetText(typeCode(e) .. ns.Upper(ns.T(ns.EventType(e.etype).label)) .. "|r")
      row.title:SetText(e.title)
      row.when:SetText(ns.Date("%a %b %d · %H:%M", e.start))
      local c = ns.EventCounts(e.id)
      row.count:SetText(c.going)
      local cc = c.going > 0 and C.good or C.faint
      row.count:SetTextColor(cc[1], cc[2], cc[3])
      local mine = ns.MyEventSignup(e.id)
      row.mine:SetText(mine and answerText(mine.status) or "")
    end, true)
  P.list.frame:SetPoint("TOPLEFT", card, "TOPLEFT", 0, -33)
  P.list:SetEmptyText("No events planned.")

  P.newsCheck = UI.Check(card, "Tell me about new events", 9, -(448 - 76))
  P.newsCheck:SetScript("OnClick", function(self) ns.db.eventNews = self:GetChecked() and true or false end)
  UI.Tooltip(P.newsCheck, "New events", "Shows an alert when a guildmate plans a new event. Reminders before events you're going to come either way.")

  local half = (LEFT_W - 2 - 34) / 2
  local newButton = UI.Button(card, "New event", half, "primary")
  newButton:SetHeight(26)
  newButton:SetPoint("BOTTOMLEFT", 14, 12)
  UI.Tooltip(newButton, "Plan an event", "Puts an event on the guild calendar for guildmates to answer. Anyone in the guild can.")
  newButton:SetScript("OnClick", function() view = "new"; ns.RefreshPanel() end)
  P.cancelButton = UI.Button(card, "Cancel event", half)
  P.cancelButton:SetHeight(26)
  P.cancelButton:SetPoint("LEFT", newButton, "RIGHT", 6, 0)
  UI.Tooltip(P.cancelButton, "Cancel event", "Cancels the selected event for everyone. Only whoever made it, or an officer, can.")
  P.cancelButton:SetScript("OnClick", function()
    local e = ns.GuildEvent(selectedId)
    if e then StaticPopup_Show("WARCREST_CANCEL_EVENT", e.title, nil, e.id) end
  end)

  local right = CreateFrame("Frame", nil, page)
  P.right = right
  right:SetPoint("TOPLEFT", RIGHT_X + 1, -1)
  right:SetSize(RIGHT_W - 2, 448)
  UI.Card(right, 1)
  BuildEventView(right)
  BuildNewView(right)

  UI.Grow(page, card, 0, 1)
  UI.Grow(page, P.list, 0, 1)
  UI.Follow(page, P.newsCheck, 0, 1)
  UI.Grow(page, right, 1, 1)
end

local function Subtitle()
  tabView = P.tabView and P.tabView.value or tabView
  if tabView == "polls" then
    local open = 0
    for _, p in ipairs(ns.Polls()) do if p.open then open = open + 1 end end
    return open == 0 and ns.T("No open polls") or ns.TP(open, "1 open poll", "%d open polls", open)
  end
  local n = #ns.GuildEvents()
  return n == 0 and ns.T("No events planned") or (n == 1 and ns.T("1 event planned") or (ns.T("%d events planned"):format(n)))
end

-- Open the form for a new event.
function UI.NewGuildEvent()
  view, tabView = "new", "events"
  if P.tabView then P.tabView:SetValue("events") end
  ns.OpenPanel("events")
end

-- Open an event (from the calendar, say).
function UI.ShowGuildEvent(id)
  selectedId, view, tabView = id, "event", "events"
  if P.tabView then P.tabView:SetValue("events") end
  ns.OpenPanel("events")
end

TAB = { id = "events", title = "Events", build = Build, refresh = Refresh, subtitle = Subtitle }
UI.AddTab(TAB)
