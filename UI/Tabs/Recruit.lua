--[[
  Warcrest
  Recruit tab (officers): the guild's recruits and where each is up to, the
  players who whispered about joining, and the recruiting message to post.
]]

local _, ns = ...
local UI = ns.UI
local C = UI.C

local P = {}
local selected      -- the selected recruit's name
local LEFT_W = 430
local RIGHT_X = LEFT_W + 14
local RIGHT_W = 740 - RIGHT_X
local TRIAL_LENGTHS = { { 7, "7 days" }, { 14, "14 days" }, { 21, "21 days" }, { 30, "30 days" } }

local function statusText(key)
  local s = ns.RecruitStatus(key)
  return "|cff" .. s.color .. ns.T(s.label) .. "|r"
end

local function statusOptions()
  local opts = {}
  for _, s in ipairs(ns.RECRUIT_STATUSES) do
    if not s.hidden then opts[#opts + 1] = { s.key, statusText(s.key) } end
  end
  return opts
end

local function classText(r)
  local parts = {}
  if r.level and r.level > 0 then parts[#parts + 1] = ns.TF("Level %d", r.level) end
  if r.class and r.class ~= "" then
    local name = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[r.class]) or r.class
    local cr, cg, cb = UI.ClassColor(r.class)
    parts[#parts + 1] = ("|cff%02x%02x%02x%s|r"):format(math.floor(cr * 255), math.floor(cg * 255), math.floor(cb * 255), name)
  end
  return table.concat(parts, " ")
end

------------------------------------------------------------------------
-- Refresh
------------------------------------------------------------------------
local function RefreshDetail(r)
  local d = P.detail
  local has = r ~= nil
  for _, w in ipairs({ d.status, d.note, d.saveNote, d.invite, d.whisper, d.remove, d.noteLabel, d.statusLabel }) do
    w:SetShown(has)
  end
  d.info:SetWordWrap(not r) -- the hint may need two lines
  if not r then
    d.name:SetText(ns.T("No recruit selected"))
    d.info:SetText(#ns.Recruits() == 0 and ns.T("Add a player by name to start the list.") or ns.T("Pick a recruit on the left."))
    d.trial:SetText("")
    return
  end
  d.name:SetText(Ambiguate(r.name, "short"))
  local info = { classText(r) }
  info[#info + 1] = ns.TF("added %s by %s", date("%b %d", r.added), Ambiguate(r.by, "short"))
  if r.inGuild then info[#info + 1] = UI.Code("good") .. ns.T("in the guild") .. "|r" end
  d.info:SetText((table.concat(info, "  ·  "):gsub("^  ·  ", "")))

  local opts = statusOptions()
  d.status.options = opts
  for i, o in ipairs(opts) do
    if o[1] == r.status then d.status.index, d.status.value = i, o[1] end
  end
  d.status:SetText(statusText(r.status))
  if not d.note:HasFocus() then d.note:SetText(r.note or "") end

  local p = ns.TrialProgress(r)
  if p then
    local col = p.over and "warn" or "text"
    d.trial:SetText(UI.Code(col) .. ns.TF("Trial: day %d of %d", math.min(p.days, p.length), p.length) .. "|r  ·  "
      .. ns.TF("%d raid nights, %d events attended", p.nights, p.events)
      .. (p.over and ("\n" .. UI.Code("warn") .. ns.T("The trial is over: set them to Joined or Declined.") .. "|r") or ""))
  else
    d.trial:SetText(r.status == "trial" and "" or UI.Code("muted") .. ns.T("Set them to Trial when they join, to track their trial.") .. "|r")
  end
  UI.SetEnabled(d.invite, not r.inGuild)
end

local function Refresh()
  local list = ns.Recruits()
  local found = false
  for _, r in ipairs(list) do if selected and ns.Key(r.name) == ns.Key(selected) then found = true end end
  if not found then selected = list[1] and list[1].name or nil end
  P.list:SetItems(list)
  RefreshDetail(selected and ns.Recruit(selected) or nil)

  P.whispers:SetItems(ns.recruitWhispers)

  if not P.message:HasFocus() then P.message:SetText(ns.RecruitMessage()) end
  local chans = ns.ChatChannels()
  local opts = {}
  for _, c in ipairs(chans) do opts[#opts + 1] = { c.id, c.id .. ". " .. c.name } end
  if #opts == 0 then opts = { { 0, ns.T("No channels") } } end
  P.channel.options = opts
  local pick = 1
  for i, o in ipairs(opts) do
    if tostring(o[1]) == tostring(ns.db.recruitChannel) then pick = i end
    if ns.db.recruitChannel == "" and o[2]:lower():find("trade") then pick = i end
  end
  P.channel.index, P.channel.value = pick, opts[pick][1]
  P.channel:SetText(opts[pick][2])
  UI.SetEnabled(P.post, #chans > 0)
  P.posted:SetText(ns.db.recruitPostedAt and ns.TF("Last posted %s", date("%b %d, %H:%M", ns.db.recruitPostedAt)) or "")

  for i, o in ipairs(TRIAL_LENGTHS) do
    if o[1] == ns.db.trialDays then P.trialLength.index, P.trialLength.value = i, o[1] end
  end
  P.trialLength:SetText(ns.TF("Trials: %s", ns.T(TRIAL_LENGTHS[P.trialLength.index][2])))
end

------------------------------------------------------------------------
-- Build
------------------------------------------------------------------------
local function Build(page)
  -- Recruits.
  local card = CreateFrame("Frame", nil, page)
  card:SetPoint("TOPLEFT", 1, -1)
  card:SetSize(LEFT_W - 2, 300)
  UI.Card(card, 1)
  P.card = card
  local y = UI.TableHeads(card, { { "RECRUIT", 14 }, { "LEVEL AND CLASS", 150 }, { "STATUS", 300 } })
  P.list = UI.List(card, LEFT_W - 6, 300 + y - 46, 26,
    function(row)
      UI.RowSelection(row)
      row.name = UI.Label(row, "", "Subheading")
      row.name:SetPoint("LEFT", 14, 0)
      row.name:SetWidth(130)
      row.name:SetWordWrap(false)
      row.class = UI.Label(row, "", "Small")
      row.class:SetPoint("LEFT", 150, 0)
      row.class:SetWidth(140)
      row.class:SetWordWrap(false)
      row.status = UI.Label(row, "", "Small")
      row.status:SetPoint("LEFT", 300, 0)
      UI.RowLine(row)
      row:SetScript("OnClick", function(self) selected = self.item.name; ns.RefreshPanel() end)
    end,
    function(row, r)
      UI.SetRowSelected(row, selected and ns.Key(r.name) == ns.Key(selected))
      row.name:SetText(Ambiguate(r.name, "short"))
      row.class:SetText(classText(r))
      row.status:SetText(statusText(r.status) .. (r.inGuild and (UI.Code("muted") .. "  (" .. ns.T("in guild") .. ")|r") or ""))
    end, true)
  P.list.frame:SetPoint("TOPLEFT", card, "TOPLEFT", 0, y - 1)
  P.list:SetEmptyText("No recruits yet.")

  P.addName = UI.EditBox(card, 180, 40)
  P.addName:SetHeight(26)
  P.addName:SetPoint("BOTTOMLEFT", 14, 10)
  P.addName.hint = UI.Label(P.addName, "Player name", "MutedSmall")
  P.addName.hint:SetPoint("LEFT", 8, 0)
  P.addName:HookScript("OnTextChanged", function(self) self.hint:SetShown((self:GetText() or "") == "") end)
  local add = UI.Button(card, "Add recruit", 110, "primary")
  add:SetHeight(26)
  add:SetPoint("LEFT", P.addName, "RIGHT", 6, 0)
  local function addRecruit(name)
    -- Level and class from your target, if it's them.
    local fields = {}
    local ok, tname = pcall(UnitName, "target")
    if ok and tname and ns.Key(tname) == ns.Key(name) then
      fields.level = tonumber(ns.Usable(UnitLevel("target"))) or nil
      fields.class = select(2, UnitClass("target"))
    end
    if ns.SetRecruit(name, fields) then
      selected = name
      P.addName:SetText("")
      ns.RefreshPanel()
    end
  end
  add:SetScript("OnClick", function() addRecruit(P.addName:GetText()) end)
  UI.Tooltip(add, "Add recruit", "Adds the player to the guild's recruit list, shared with every officer. Target them first to fill in their level and class.")
  local fromTarget = UI.Button(card, "Add target", 100)
  fromTarget:SetHeight(26)
  fromTarget:SetPoint("LEFT", add, "RIGHT", 6, 0)
  fromTarget:SetScript("OnClick", function()
    local ok, tname = pcall(UnitName, "target")
    local isPlayer = ok and tname and UnitIsPlayer("target")
    if not isPlayer then ns.Say("Target the player first.") return end
    addRecruit(tname)
  end)
  UI.Tooltip(fromTarget, "Add your target", "Adds the player you're targeting, with their level and class.")

  -- Whispers about joining.
  local wcard = CreateFrame("Frame", nil, page)
  wcard:SetPoint("TOPLEFT", 1, -313)
  wcard:SetSize(LEFT_W - 2, 136)
  UI.Card(wcard, 1)
  P.wcard = wcard
  UI.Label(wcard, "WHISPERED ABOUT JOINING", "Label"):SetPoint("TOPLEFT", 14, -12)
  P.whispers = UI.List(wcard, LEFT_W - 6, 136 - 34, 26,
    function(row)
      row.name = UI.Label(row, "", "Subheading")
      row.name:SetPoint("LEFT", 14, 0)
      row.name:SetWidth(100)
      row.name:SetWordWrap(false)
      row.text = UI.Label(row, "", "MutedSmall")
      row.text:SetPoint("LEFT", 120, 0)
      row.text:SetWidth(LEFT_W - 6 - 120 - 100)
      row.text:SetWordWrap(false)
      row.add = UI.Button(row, "Add", 60)
      row.add:SetHeight(20)
      row.add:SetPoint("RIGHT", -30, 0)
      row.add:SetScript("OnClick", function() addRecruit(row.item.name) end)
      UI.RowLine(row)
    end,
    function(row, w)
      row.name:SetText(Ambiguate(w.name, "short"))
      row.text:SetText(date("%H:%M", w.t) .. "  " .. w.text)
      row.add:SetShown(ns.Recruit(w.name) == nil)
    end, true)
  P.whispers.frame:SetPoint("TOPLEFT", wcard, "TOPLEFT", 0, -32)
  P.whispers:SetEmptyText("Players outside the guild who whisper you about joining show here.")

  -- The selected recruit.
  local d = CreateFrame("Frame", nil, page)
  d:SetPoint("TOPLEFT", RIGHT_X + 1, -1)
  d:SetSize(RIGHT_W - 2, 252)
  UI.Card(d, 1)
  P.detail = d
  local inner = RIGHT_W - 30
  d.name = UI.Label(d, "", "Title")
  d.name:SetPoint("TOPLEFT", 14, -14)
  d.name:SetWidth(inner)
  d.name:SetWordWrap(false)
  d.info = UI.Label(d, "", "Small")
  d.info:SetPoint("TOPLEFT", 14, -38)
  d.info:SetWidth(inner)
  d.info:SetWordWrap(false)
  d.statusLabel = UI.FieldLabel(d, "Status", 14, -60)
  d.status = UI.Cycle(d, 130, statusOptions(), function(v)
    if selected then ns.SetRecruit(selected, { status = v }) end
  end)
  d.status:SetHeight(26)
  d.status:SetPoint("TOPLEFT", 14, -72)
  UI.Tooltip(d.status, "Status", "Click to move them on: New, Contacted, Trial, Joined or Declined. Every officer sees the change.")
  P.trialLength = UI.Cycle(d, 130, TRIAL_LENGTHS, function(v) ns.db.trialDays = v; ns.RefreshPanel() end)
  P.trialLength:SetHeight(26)
  P.trialLength:SetPoint("LEFT", d.status, "RIGHT", 6, 0)
  UI.Tooltip(P.trialLength, "Trial length", "How long a trial lasts. You're told when a recruit's trial is over, with how many raid nights and events they came to.")
  d.trial = UI.Label(d, "", "Small")
  d.trial:SetPoint("TOPLEFT", 14, -106)
  d.trial:SetWidth(inner)
  d.trial:SetSpacing(3)
  d.noteLabel = UI.FieldLabel(d, "Note", 14, -142)
  d.note = UI.EditBox(d, inner - 66, 80)
  d.note:SetHeight(26)
  d.note:SetPoint("TOPLEFT", 14, -154)
  d.saveNote = UI.Button(d, "Save", 60)
  d.saveNote:SetHeight(26)
  d.saveNote:SetPoint("LEFT", d.note, "RIGHT", 6, 0)
  d.saveNote:SetScript("OnClick", function()
    if selected then ns.SetRecruit(selected, { note = d.note:GetText() or "" }) end
    d.note:ClearFocus()
  end)
  local third = (inner - 12) / 3
  d.invite = UI.Button(d, "Guild invite", third, "primary")
  d.invite:SetHeight(26)
  d.invite:SetPoint("BOTTOMLEFT", 14, 14)
  d.invite:SetScript("OnClick", function() if selected then ns.InviteRecruit(selected) end end)
  UI.Tooltip(d.invite, "Guild invite", "Invites them to the guild (if your rank can), and sets them to Contacted if they were New.")
  d.whisper = UI.Button(d, "Whisper", third)
  d.whisper:SetHeight(26)
  d.whisper:SetPoint("LEFT", d.invite, "RIGHT", 6, 0)
  d.whisper:SetScript("OnClick", function()
    if not selected then return end
    if ChatFrameUtil and ChatFrameUtil.SendTell then ChatFrameUtil.SendTell(selected)
    elseif ChatFrame_SendTell then ChatFrame_SendTell(selected) end
  end)
  d.remove = UI.Button(d, "Remove", third)
  d.remove:SetHeight(26)
  d.remove:SetPoint("LEFT", d.whisper, "RIGHT", 6, 0)
  d.remove:SetScript("OnClick", function() if selected then ns.RemoveRecruit(selected) end end)
  UI.Tooltip(d.remove, "Remove", "Takes them off the recruit list for every officer.")

  -- The recruiting message.
  local m = CreateFrame("Frame", nil, page)
  m:SetPoint("TOPLEFT", RIGHT_X + 1, -265)
  m:SetSize(RIGHT_W - 2, 184)
  UI.Card(m, 1)
  P.msgCard = m
  UI.Label(m, "Recruiting message", "Heading"):SetPoint("TOPLEFT", 14, -12)
  local bg = m:CreateTexture(nil, "BORDER")
  bg:SetPoint("TOPLEFT", 14, -34)
  bg:SetSize(inner, 64)
  bg:SetColorTexture(C.control[1], C.control[2], C.control[3], 1)
  P.message = CreateFrame("EditBox", nil, m)
  P.message:SetMultiLine(true)
  P.message:SetFontObject(UI.Fonts.Small)
  P.message:SetTextColor(C.text[1], C.text[2], C.text[3])
  P.message:SetPoint("TOPLEFT", 20, -38)
  P.message:SetSize(inner - 12, 56)
  P.message:SetMaxLetters(170)
  P.message:SetAutoFocus(false)
  P.message:SetScript("OnEscapePressed", P.message.ClearFocus)
  local saveMsg = UI.Button(m, "Save message", 120)
  saveMsg:SetHeight(24)
  saveMsg:SetPoint("TOPLEFT", 14, -104)
  saveMsg:SetScript("OnClick", function()
    ns.SetRecruitMessage(P.message:GetText())
    P.message:ClearFocus()
  end)
  UI.Tooltip(saveMsg, "Save message", "Saves the recruiting message for every officer.")
  P.posted = UI.Label(m, "", "MutedSmall")
  P.posted:SetPoint("LEFT", saveMsg, "RIGHT", 10, 0)
  P.channel = UI.Cycle(m, inner - 100 - 6, { { 0, "" } }, function(v) ns.db.recruitChannel = tostring(v) end)
  P.channel:SetHeight(26)
  P.channel:SetPoint("BOTTOMLEFT", 14, 14)
  UI.Tooltip(P.channel, "Channel", "Click to pick the chat channel to post in (Trade or General, say).")
  P.post = UI.Button(m, "Post", 100, "primary")
  P.post:SetHeight(26)
  P.post:SetPoint("LEFT", P.channel, "RIGHT", 6, 0)
  P.post:SetScript("OnClick", function()
    if P.message:HasFocus() then ns.SetRecruitMessage(P.message:GetText()) end
    if ns.PostRecruitMessage(P.channel.value) then ns.RefreshPanel() end
  end)
  UI.Tooltip(P.post, "Post", "Posts the recruiting message in the chosen channel.")

  UI.Grow(page, card, 0, 1)
  UI.Grow(page, P.list, 0, 1)
  UI.Follow(page, wcard, 0, 1)
  UI.Grow(page, d, 1, 1)
  UI.Follow(page, m, 0, 1)
  UI.Grow(page, m, 1, 0)
end

local function Subtitle()
  local n, trials = 0, 0
  for _, r in ipairs(ns.Recruits()) do
    if r.status ~= "joined" and r.status ~= "declined" then n = n + 1 end
    if r.status == "trial" then trials = trials + 1 end
  end
  return ns.TF("%d open recruits · %d on trial", n, trials)
end

UI.AddTab({ id = "recruit", title = "Recruit", build = Build, refresh = Refresh, subtitle = Subtitle,
  visible = ns.IsAddonOfficer })
