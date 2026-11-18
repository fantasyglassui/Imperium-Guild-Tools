--[[
  The Imperium
  Raids tab: scheduled raids with sign-ups, the current raid group, and
  (for officers) creating raids and running raid sessions for attendance DKP.
]]

local _, ns = ...
local UI = ns.UI

local P = {}
local selectedId
local view = "event"          -- "event", "group" or "new"
local myRole = "dps"
local newDay = 0               -- days from today for a new raid

local STATUS_TEXT = { accept = "|cff6fd08cAccepted|r", tentative = "|cffe0b94cTentative|r",
  decline = "|cffff6b6bDeclined|r" }
local ROLE_TEXT = { tank = "Tank", healer = "Healer", dps = "DPS" }

local function when(t) return date("%a %b %d  %H:%M", t) end

-- Midnight of today + n days, local time.
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

------------------------------------------------------------------------
-- Refresh
------------------------------------------------------------------------
local function RefreshEvent(event)
  local d = P.event
  if not event then
    d.title:SetText("No raid selected")
    d.when:SetText(#ns.RaidEvents() == 0 and "No raids are scheduled yet." or "Pick a raid on the left.")
    d.notes:SetText("")
    d.counts:SetText("")
    d.classes:SetText("")
    d.gaps:SetText("")
    P.signups:SetItems({})
    for _, b in ipairs(d.statusButtons) do UI.SetEnabled(b, false) end
    UI.SetEnabled(d.role, false)
    d.invite:Hide()
    d.noShows:SetText("")
    return
  end
  d.title:SetText(event.title)
  d.when:SetText(when(event.start) .. "   |cff8b95a7scheduled by " .. event.a .. "|r")
  d.notes:SetText(event.notes ~= "" and event.notes or "|cff8b95a7No notes.|r")
  local c = ns.SignupCounts(event.id)
  d.counts:SetText(("|cff6fd08c%d accepted|r  (%d tank, %d healer, %d DPS)   |cffe0b94c%d tentative|r   |cffff6b6b%d declined|r")
    :format(c.accept, c.tank, c.healer, c.dps, c.tentative, c.decline))
  -- Who's coming by class, and what the raid is short of.
  local mk = ns.RaidMakeup(event.id)
  local parts = {}
  for _, cl in ipairs(mk.classes) do
    local r, g, b = UI.ClassColor(cl.classFile)
    parts[#parts + 1] = ("|cff%02x%02x%02x%s %d|r"):format(math.floor(r * 255), math.floor(g * 255),
      math.floor(b * 255), cl.name, cl.count)
  end
  d.classes:SetText(table.concat(parts, "  "))
  if mk.accept == 0 then
    d.gaps:SetText("")
  elseif #mk.warnings > 0 then
    d.gaps:SetText("|cffffad33! " .. table.concat(mk.warnings, ".  ") .. ".|r")
  else
    d.gaps:SetText("|cff6fd08cTanks and healers covered.|r")
  end
  -- After the raid night, mark accepted sign-ups who never came.
  local noShows, attended = ns.NoShows(event.id)
  local rows = {}
  for _, su in ipairs((ns.Signups(event.id))) do
    rows[#rows + 1] = { name = su.name, role = su.role, status = su.status, classFile = mk.classOf[ns.Key(su.name)],
      noShow = attended ~= nil and su.status == "accept" and not attended[ns.Key(su.name)] }
  end
  P.signups:SetEmptyText("Nobody has signed up yet.")
  P.signups:SetItems(rows)
  if noShows then
    d.noShows:SetText(#noShows > 0 and ("|cffff6b6bNo-shows:|r " .. table.concat(noShows, ", "))
      or "|cff6fd08cEveryone who accepted showed up.|r")
  else
    d.noShows:SetText("")
  end
  d.invite:SetShown(ns.IsAddonOfficer())

  local mine = ns.MySignup(event.id)
  if mine then myRole = mine.role end
  d.role:SetText("Role: " .. ROLE_TEXT[myRole])
  UI.SetEnabled(d.role, true)
  for _, b in ipairs(d.statusButtons) do
    UI.SetEnabled(b, true)
    -- Your current answer is shown in gold.
    b:SetStyle(mine and mine.status == b.status and "primary" or nil)
  end
end

local function RefreshGroup(event)
  local members = ns.CurrentRaidMembers()
  local byKey = {}
  if event then
    local _, signups = ns.Signups(event.id)
    byKey = signups
  end
  for _, m in ipairs(members) do
    m.signup = byKey[ns.Key(m.name)]
    m.dkp = ns.Balance(m.name)
  end
  P.group:SetEmptyText("You're not in a raid group. When you are, everyone in it shows here with their sign-up and DKP.")
  P.group:SetItems(members)
  local inGuild = 0
  for _, m in ipairs(members) do if m.inGuild then inGuild = inGuild + 1 end end
  P.groupInfo:SetText(IsInRaid()
    and ("%d in your raid, %d of them guild members.%s"):format(#members, inGuild,
      event and (" Sign-ups shown for " .. event.title .. ".") or "")
    or "You're not in a raid group.")

  local session = ns.ActiveSession()
  local standby = session and ns.StandbyList(session.id) or {}
  if session then
    P.standbyText:SetText(#standby > 0 and table.concat(standby, ", ")
      or "|cff8b95a7Nobody. Standby members earn the same DKP as the raid.|r")
  else
    P.standbyText:SetText("|cff8b95a7Start the raid to add standby members.|r")
  end
  local officer = ns.IsAddonOfficer()
  for _, w in ipairs({ P.standbyName, P.standbyAdd, P.standbyRemove }) do
    w:SetShown(officer)
    UI.SetEnabled(w, session ~= nil)
  end
end

local function RefreshSession()
  local s = ns.ActiveSession()
  local officer = ns.IsAddonOfficer()
  if s then
    local text = ("|cff6fd08cRaid in progress:|r %s, started %s by %s. %d DKP per hour%s.")
      :format(s.title, date("%H:%M", s.t), s.a, s.hourly, (s.boss or 0) > 0 and (", " .. s.boss .. " per boss") or "")
    local mine = ns.db.session
    if mine and mine.id == s.id then
      text = text .. ("\nNext hourly award in %d min."):format(math.max(0, math.ceil((mine.nextTick - GetServerTime()) / 60)))
    end
    P.sessionText:SetText(text)
    P.sessionButton:SetText("End raid")
    P.sessionButton:SetStyle(nil)
  else
    P.sessionText:SetText(officer and "Start a raid to award on-time and hourly DKP to everyone in the raid."
      or "No raid in progress.")
    P.sessionButton:SetText("Start raid")
    P.sessionButton:SetStyle("primary")
  end
  for _, w in ipairs({ P.onTime, P.hourly, P.boss, P.sessionButton }) do
    UI.SetEnabled(w, officer)
    w:SetShown(officer)
  end
  P.onTimeLabel:SetShown(officer)
  P.hourlyLabel:SetShown(officer)
  P.bossLabel:SetShown(officer)
end

local function Refresh()
  local events = ns.RaidEvents()
  if selectedId and not ns.RaidEvent(selectedId) then selectedId = nil end
  if not selectedId and events[1] then selectedId = events[1].id end
  P.list:SetItems(events)
  local event = ns.RaidEvent(selectedId)

  local officer = ns.IsAddonOfficer()
  P.newButton:SetShown(officer)
  P.cancelButton:SetShown(officer)
  UI.SetEnabled(P.cancelButton, officer and event ~= nil)

  P.event:SetShown(view == "event")
  P.groupFrame:SetShown(view == "group")
  P.newFrame:SetShown(view == "new")
  P.viewButton:SetText(view == "group" and "Show selected raid" or "Show current raid group")

  if view == "event" then RefreshEvent(event)
  elseif view == "group" then RefreshGroup(event)
  else
    P.newDayText:SetText(date("%a %b %d", dayStart(newDay)))
  end
  RefreshSession()
end

------------------------------------------------------------------------
-- Build
------------------------------------------------------------------------
StaticPopupDialogs["IMPERIUM_CANCEL_RAID"] = {
  text = "Cancel %s for everyone?",
  button1 = YES,
  button2 = NO,
  OnAccept = function(_, id) ns.CancelRaid(id) end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
}

local function BuildEventView(parent)
  local d = CreateFrame("Frame", nil, parent)
  d:SetAllPoints()
  P.event = d

  d.title = UI.Label(d, "", "GameFontNormalLarge")
  d.title:SetPoint("TOPLEFT", 0, -30)
  d.when = UI.Label(d, "", "GameFontHighlight")
  d.when:SetPoint("TOPLEFT", 0, -52)
  d.notes = UI.Label(d, "", "GameFontHighlightSmall")
  d.notes:SetPoint("TOPLEFT", 0, -70)
  d.notes:SetWidth(410)
  d.counts = UI.Label(d, "", "GameFontHighlightSmall")
  d.counts:SetPoint("TOPLEFT", 0, -100)
  d.classes = UI.Label(d, "", "GameFontHighlightSmall")
  d.classes:SetPoint("TOPLEFT", 0, -114)
  d.classes:SetWidth(410)
  d.classes:SetWordWrap(false)
  d.gaps = UI.Label(d, "", "GameFontHighlightSmall")
  d.gaps:SetPoint("TOPLEFT", 0, -128)
  d.gaps:SetWidth(410)
  d.gaps:SetWordWrap(false)
  local hover = CreateFrame("Frame", nil, d) -- text can't take the mouse, so a frame over it does
  hover:SetPoint("TOPLEFT", d.gaps, "TOPLEFT")
  hover:SetSize(410, 14)
  hover:SetScript("OnEnter", function(self)
    if not selectedId then return end
    local mk = ns.RaidMakeup(selectedId)
    if mk.accept == 0 then return end
    local tanks, healers = ns.RolesWanted(mk.accept)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Raid makeup")
    GameTooltip:AddLine(("For %d players: about %d tank%s and %d healer%s (one healer per five players)."):format(
      mk.accept, tanks, tanks == 1 and "" or "s", healers, healers == 1 and "" or "s"), 1, 1, 1, true)
    GameTooltip:AddLine(("Signed up: %d tank, %d healer, %d DPS. Tentative: %d tank, %d healer, %d DPS."):format(
      mk.roles.tank, mk.roles.healer, mk.roles.dps, mk.maybe.tank, mk.maybe.healer, mk.maybe.dps), 1, 1, 1, true)
    GameTooltip:AddLine("Once 10 have accepted, classes in the guild that nobody has signed up with are listed too.",
      0.7, 0.7, 0.7, true)
    GameTooltip:Show()
  end)
  hover:SetScript("OnLeave", function() GameTooltip:Hide() end)

  -- Your sign-up
  d.role = UI.Button(d, "Role: DPS", 100)
  d.role:SetPoint("TOPLEFT", 0, -146)
  UI.Tooltip(d.role, "Your role", "Click to switch between Tank, Healer and DPS. If you've already signed up, your sign-up changes too.")
  d.role:SetScript("OnClick", function()
    myRole = (myRole == "tank" and "healer") or (myRole == "healer" and "dps") or "tank"
    local mine = selectedId and ns.MySignup(selectedId)
    if mine then ns.SignUp(selectedId, mine.status, myRole) end
    ns.RefreshPanel()
  end)
  d.statusButtons = {}
  local prev = d.role
  for _, s in ipairs({ { "accept", "Accept" }, { "tentative", "Tentative" }, { "decline", "Decline" } }) do
    local b = UI.Button(d, s[2], 90)
    b.status = s[1]
    b:SetPoint("LEFT", prev, "RIGHT", 6, 0)
    b:SetScript("OnClick", function() if selectedId then ns.SignUp(selectedId, s[1], myRole) end end)
    d.statusButtons[#d.statusButtons + 1] = b
    prev = b
  end

  P.signups = UI.List(d, 410, 126, 18,
    function(row)
      row.name = UI.Label(row, "", "GameFontHighlightSmall")
      row.name:SetPoint("LEFT", 4, 0)
      row.name:SetWidth(170)
      row.role = UI.Label(row, "", "GameFontHighlightSmall")
      row.role:SetPoint("LEFT", 180, 0)
      row.status = UI.Label(row, "", "GameFontHighlightSmall")
      row.status:SetPoint("LEFT", 260, 0)
    end,
    function(row, s)
      row.name:SetText(Ambiguate(s.name, "short"))
      row.name:SetTextColor(UI.ClassColor(s.classFile))
      row.role:SetText(ROLE_TEXT[s.role])
      row.status:SetText(s.noShow and "|cffff6b6bNo-show|r" or STATUS_TEXT[s.status])
    end)
  P.signups.frame:SetPoint("TOPLEFT", 0, -174)

  d.invite = UI.Button(d, "Invite sign-ups", 130)
  d.invite:SetPoint("TOPLEFT", 0, -306)
  d.invite:SetScript("OnClick", function() if selectedId then ns.InviteSignups(selectedId) end end)
  d.invite:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Invite everyone who signed up")
    GameTooltip:AddLine("Invites every online guild member who accepted or is tentative and isn't in your group yet. A party is turned into a raid automatically.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  d.invite:SetScript("OnLeave", function() GameTooltip:Hide() end)
  d.noShows = UI.Label(d, "", "GameFontHighlightSmall")
  d.noShows:SetPoint("TOPLEFT", 0, -336)
  d.noShows:SetWidth(410)

  local page = parent:GetParent()
  UI.Grow(page, P.signups, 1, 1)
  UI.FollowAll(page, { d.invite, d.noShows }, 0, 1)
end

local function BuildGroupView(parent)
  local g = CreateFrame("Frame", nil, parent)
  g:SetAllPoints()
  P.groupFrame = g
  UI.Label(g, "Current raid group", "GameFontNormalLarge"):SetPoint("TOPLEFT", 0, -30)
  P.groupInfo = UI.Label(g, "", "GameFontHighlightSmall")
  P.groupInfo:SetPoint("TOPLEFT", 0, -52)
  P.groupInfo:SetWidth(410)

  local heads = { { "Name", 4 }, { "Role", 150 }, { "Signed up", 220 }, { "DKP", 330 } }
  for _, h in ipairs(heads) do UI.Label(g, h[1], "GameFontNormalSmall"):SetPoint("TOPLEFT", h[2], -72) end

  P.group = UI.List(g, 410, 220, 18,
    function(row)
      row.cols = {}
      for i, h in ipairs(heads) do
        local fs = UI.Label(row, "", "GameFontHighlightSmall")
        fs:SetPoint("LEFT", h[2], 0)
        row.cols[i] = fs
      end
    end,
    function(row, m)
      local r, gg, b = UI.ClassColor(m.classFile)
      row.cols[1]:SetText(Ambiguate(m.name, "short") .. (m.inGuild and "" or " |cff8b95a7(not in guild)|r"))
      row.cols[1]:SetTextColor(r, gg, b)
      row.cols[1]:SetAlpha(m.online and 1 or 0.5)
      row.cols[2]:SetText(m.role and ROLE_TEXT[m.role] or "|cff8b95a7-|r")
      row.cols[3]:SetText(m.signup and STATUS_TEXT[m.signup.status] or "|cff8b95a7Not signed up|r")
      row.cols[4]:SetText(m.inGuild and m.dkp or "")
    end)
  P.group.frame:SetPoint("TOPLEFT", 0, -88)
  P.group.frame:SetHeight(200)
  P.group.height = 200

  local standbyLabel = UI.Label(g, "Standby", "GameFontNormal")
  standbyLabel:SetPoint("TOPLEFT", 0, -296)
  P.standbyText = UI.Label(g, "", "GameFontHighlightSmall")
  P.standbyText:SetPoint("TOPLEFT", 0, -314)
  P.standbyText:SetWidth(410)
  P.standbyName = UI.EditBox(g, 140, 40)
  P.standbyName:SetPoint("TOPLEFT", 6, -346)
  local page = parent:GetParent()
  UI.Grow(page, P.group, 1, 1)
  UI.FollowAll(page, { standbyLabel, P.standbyText, P.standbyName }, 0, 1)
  P.standbyAdd = UI.Button(g, "Add to standby", 120)
  P.standbyAdd:SetPoint("LEFT", P.standbyName, "RIGHT", 8, 0)
  UI.Tooltip(P.standbyAdd, "Add to standby", "Puts the guild member named in the box on standby for tonight's raid night. They earn the same DKP as the raid, and count as attending.")
  P.standbyAdd:SetScript("OnClick", function()
    ns.AddStandby(P.standbyName:GetText())
    P.standbyName:SetText("")
    ns.RefreshPanel()
  end)
  P.standbyRemove = UI.Button(g, "Remove", 80)
  P.standbyRemove:SetPoint("LEFT", P.standbyAdd, "RIGHT", 4, 0)
  UI.Tooltip(P.standbyRemove, "Remove from standby", "Takes the guild member named in the box off standby.")
  P.standbyRemove:SetScript("OnClick", function()
    ns.RemoveStandby(P.standbyName:GetText())
    P.standbyName:SetText("")
    ns.RefreshPanel()
  end)
end

local function BuildNewView(parent)
  local n = CreateFrame("Frame", nil, parent)
  n:SetAllPoints()
  P.newFrame = n
  UI.Label(n, "Schedule a raid", "GameFontNormalLarge"):SetPoint("TOPLEFT", 0, -30)

  UI.Label(n, "Raid", "GameFontNormalSmall"):SetPoint("TOPLEFT", 0, -60)
  P.newTitle = UI.EditBox(n, 260, 40)
  P.newTitle:SetPoint("TOPLEFT", 6, -74)

  UI.Label(n, "Day", "GameFontNormalSmall"):SetPoint("TOPLEFT", 0, -102)
  local prev = UI.Button(n, "<", 24)
  prev:SetPoint("TOPLEFT", 0, -116)
  P.newDayText = UI.Label(n, "")
  P.newDayText:SetPoint("LEFT", prev, "RIGHT", 8, 0)
  P.newDayText:SetWidth(110)
  local nextB = UI.Button(n, ">", 24)
  nextB:SetPoint("LEFT", prev, "RIGHT", 124, 0)
  prev:SetScript("OnClick", function() newDay = math.max(0, newDay - 1); ns.RefreshPanel() end)
  nextB:SetScript("OnClick", function() newDay = math.min(60, newDay + 1); ns.RefreshPanel() end)

  UI.Label(n, "Start time (24-hour, your time)", "GameFontNormalSmall"):SetPoint("TOPLEFT", 0, -146)
  P.newTime = UI.EditBox(n, 60, 5)
  P.newTime:SetPoint("TOPLEFT", 6, -160)
  P.newTime:SetText("20:00")

  UI.Label(n, "Notes (optional)", "GameFontNormalSmall"):SetPoint("TOPLEFT", 0, -188)
  P.newNotes = UI.EditBox(n, 400, 120)
  P.newNotes:SetPoint("TOPLEFT", 6, -202)

  local create = UI.Button(n, "Create raid", 120, "primary")
  create:SetPoint("TOPLEFT", 0, -234)
  create:SetScript("OnClick", function()
    local seconds = parseTime(P.newTime:GetText())
    if not seconds then ns.Say("Enter the start time like 20:00.") return end
    local e = ns.CreateRaid(strtrim(P.newTitle:GetText() or ""), dayStart(newDay) + seconds,
      strtrim(P.newNotes:GetText() or ""))
    if e then
      selectedId, view = e.id, "event"
      P.newTitle:SetText("")
      P.newNotes:SetText("")
      ns.RefreshPanel()
    end
  end)
  local back = UI.Button(n, "Cancel", 80)
  back:SetPoint("LEFT", create, "RIGHT", 6, 0)
  back:SetScript("OnClick", function() view = "event"; ns.RefreshPanel() end)
end

local function Build(page)
  UI.Label(page, "Upcoming raids", "GameFontNormalLarge"):SetPoint("TOPLEFT", 8, -4)

  P.list = UI.List(page, 290, 200, 20,
    function(row)
      row.sel = row:CreateTexture(nil, "BACKGROUND")
      row.sel:SetAllPoints()
      row.sel:SetColorTexture(UI.C.accent[1], UI.C.accent[2], UI.C.accent[3], 0.14)
      row.when = UI.Label(row, "", "GameFontHighlightSmall")
      row.when:SetPoint("LEFT", 4, 0)
      row.title = UI.Label(row, "", "GameFontHighlightSmall")
      row.title:SetPoint("LEFT", 110, 0)
      row.title:SetWidth(110)
      row.title:SetWordWrap(false)
      row.count = UI.Label(row, "", "GameFontHighlightSmall")
      row.count:SetPoint("RIGHT", -4, 0)
      row:SetScript("OnClick", function(self)
        selectedId = self.item.id
        if view == "new" then view = "event" end
        ns.RefreshPanel()
      end)
    end,
    function(row, e)
      row.sel:SetShown(e.id == selectedId)
      row.when:SetText(date("%a %d  %H:%M", e.start))
      row.title:SetText(e.title)
      local c = ns.SignupCounts(e.id)
      local mine = ns.MySignup(e.id)
      local short = c.accept > 0 and #ns.RaidMakeup(e.id).warnings > 0
      row.count:SetText(("%s|cff6fd08c%d|r%s"):format(short and "|cffffad33!|r " or "", c.accept,
        mine and (" " .. STATUS_TEXT[mine.status]) or ""))
    end)
  P.list.frame:SetPoint("TOPLEFT", 4, -28)
  P.list:SetEmptyText("No raids scheduled.")

  P.newButton = UI.Button(page, "New raid", 100)
  P.newButton:SetPoint("TOPLEFT", 4, -234)
  UI.Tooltip(P.newButton, "Schedule a raid", "Adds a raid to the calendar for guild members to sign up to. They get a reminder before it starts.")
  P.newButton:SetScript("OnClick", function() view = "new"; ns.RefreshPanel() end)
  P.cancelButton = UI.Button(page, "Cancel raid", 100)
  P.cancelButton:SetPoint("LEFT", P.newButton, "RIGHT", 6, 0)
  UI.Tooltip(P.cancelButton, "Cancel raid", "Cancels the selected raid for everyone. You'll be asked to confirm first.")
  P.cancelButton:SetScript("OnClick", function()
    local e = ns.RaidEvent(selectedId)
    if e then StaticPopup_Show("IMPERIUM_CANCEL_RAID", e.title, nil, e.id) end
  end)

  -- Raid session (attendance DKP)
  local nightLabel = UI.Label(page, "Raid night", "GameFontNormalLarge")
  nightLabel:SetPoint("TOPLEFT", 8, -268)
  P.sessionText = UI.Label(page, "", "GameFontHighlightSmall")
  P.sessionText:SetPoint("TOPLEFT", 8, -292)
  P.sessionText:SetWidth(300)
  P.onTimeLabel = UI.Label(page, "On time", "GameFontNormalSmall")
  P.onTimeLabel:SetPoint("TOPLEFT", 8, -350)
  P.onTime = UI.EditBox(page, 50, 4)
  P.onTime:SetPoint("TOPLEFT", 8, -364)
  P.onTime:SetNumeric(true)
  P.onTime:SetText("10")
  P.hourlyLabel = UI.Label(page, "Per hour", "GameFontNormalSmall")
  P.hourlyLabel:SetPoint("TOPLEFT", 66, -350)
  P.hourly = UI.EditBox(page, 50, 4)
  P.hourly:SetPoint("TOPLEFT", 66, -364)
  P.hourly:SetNumeric(true)
  P.hourly:SetText("10")
  P.bossLabel = UI.Label(page, "Per boss", "GameFontNormalSmall")
  P.bossLabel:SetPoint("TOPLEFT", 124, -350)
  P.boss = UI.EditBox(page, 50, 4)
  P.boss:SetPoint("TOPLEFT", 124, -364)
  P.boss:SetNumeric(true)
  P.boss:SetText("0")
  P.sessionButton = UI.Button(page, "Start raid", 100, "primary")
  P.sessionButton:SetPoint("TOPLEFT", 190, -364)
  UI.Tooltip(P.sessionButton, function() return ns.ActiveSession() and "End raid" or "Start raid" end, function()
    if ns.ActiveSession() then return "Stops awarding DKP for tonight's raid night." end
    return "Starts tonight's raid night. Everyone in your raid gets the On time DKP now, Per hour DKP every hour, and Per boss DKP for each boss killed. Attendance is recorded."
  end)
  P.sessionButton:SetScript("OnClick", function()
    if ns.ActiveSession() then
      ns.EndRaidSession()
    else
      local e = ns.RaidEvent(selectedId)
      local title = e and e.title or ("Raid " .. date("%b %d"))
      ns.StartRaidSession(e and e.id or "", title, P.onTime:GetText(), P.hourly:GetText(), P.boss:GetText())
    end
    ns.RefreshPanel()
  end)

  -- Right side
  local right = CreateFrame("Frame", nil, page)
  right:SetPoint("TOPLEFT", 320, 0)
  right:SetPoint("BOTTOMRIGHT", -4, 0)
  P.viewButton = UI.Button(right, "Show current raid group", 190)
  P.viewButton:SetPoint("TOPRIGHT", 0, -2)
  UI.Tooltip(P.viewButton, "Switch view", "Switches between the selected raid's sign-ups and everyone in your raid group right now.")
  P.viewButton:SetScript("OnClick", function()
    view = (view == "group") and "event" or "group"
    ns.RefreshPanel()
  end)
  BuildEventView(right)
  BuildGroupView(right)
  BuildNewView(right)

  -- A bigger window: more upcoming raids show, and the raid night controls move down.
  UI.Grow(page, P.list, 0, 1)
  UI.FollowAll(page, { P.newButton, nightLabel, P.sessionText, P.onTimeLabel, P.onTime, P.hourlyLabel, P.hourly,
    P.bossLabel, P.boss, P.sessionButton }, 0, 1)
end

UI.AddTab({ id = "raids", title = "Raids", build = Build, refresh = Refresh })
