--[[
  Warcrest
  Getting started: five things for a new member, each ticked off by itself
  once it's done (open Warcrest, sign up for a raid, fill in your profile,
  share your recipes, pick a title). Officers also get the guild setup.
  Opens by itself the first time Warcrest loads for a character in a guild;
  /warcrest start (or the Help window) opens it again.
]]

local _, ns = ...
local UI = ns.UI
local C = UI.C

local WIDTH, HEIGHT = 560, 472
local ROW_H, ROW_GAP = 50, 6
local win

local function me() return UnitName("player") end

local function signedUp()
  for _, e in ipairs(ns.LedgerEntries("SU")) do
    if ns.IsMe(e.a) then return true end
  end
end

-- The steps: what to do, how to tell it's done, and the button that helps.
local STEPS = {
  { id = "open", title = "Open Warcrest", hint = "/warcrest, /wc or the crest by your minimap",
    button = "Open", done = function() return ns.db.started.open end,
    go = function() if win then win:Hide() end; ns.OpenPanel("home") end },
  { id = "signup", title = "Sign up for a raid", hint = "Pick your role and Accept on the Raids tab",
    button = "Raids", done = signedUp,
    go = function() if win then win:Hide() end; ns.OpenPanel("raids") end },
  { id = "profile", title = "Fill in your profile", hint = "Spec, role and when you play: it shows on your player card",
    button = "Edit profile", done = function() return ns.MemberProfile(me()) ~= nil end,
    go = function() ns.ShowProfileEditor() end },
  { id = "recipes", title = "Share your recipes", hint = "Open each profession window once, so the guild can order",
    button = "Crafters", done = function() return next(ns.db.myCrafts or {}) ~= nil end,
    go = function() ns.ShowCrafters() end },
  { id = "title", title = "Pick a title", hint = "Earned titles show after your name, in chat and in alerts",
    button = "Titles", done = function() return ns.TitleOf(me()) ~= nil end,
    go = function() ns.ShowTitleChooser() end },
}

-- Which steps are done. Once done, a step stays done.
function ns.StartedSteps()
  local db = ns.db.started
  local out, n = {}, 0
  for _, s in ipairs(STEPS) do
    local ok = db[s.id] or (IsInGuild() and s.done() and true)
    if ok then db[s.id] = true; n = n + 1 end
    out[s.id] = ok and true or false
  end
  return out, n, #STEPS
end

-- The first step not done yet ({ id, title, hint, button, go }), or nil when all are.
function ns.NextStartedStep()
  local done = ns.StartedSteps()
  for _, s in ipairs(STEPS) do
    if not done[s.id] then return s end
  end
end

-- Something a step watches for happened (Warcrest was opened, say).
function ns.NoteStarted(id)
  if ns.db and ns.db.started then ns.db.started[id] = true end
  if win and win:IsShown() then ns.RefreshGettingStarted() end
end

local function Row(parent, i, step)
  local r = CreateFrame("Frame", nil, parent)
  r:SetPoint("TOPLEFT", 24, -(114 + (i - 1) * (ROW_H + ROW_GAP)))
  r:SetSize(WIDTH - 48, ROW_H)
  r.bg = UI.Fill(r, C.card)
  r.edge = UI.Border(r, C.cardEdge[1], C.cardEdge[2], C.cardEdge[3], 1)

  r.ring = r:CreateTexture(nil, "ARTWORK")
  r.ring:SetSize(24, 24)
  r.ring:SetPoint("LEFT", 14, 0)
  r.ring:SetColorTexture(C.control[1], C.control[2], C.control[3], 1)
  r.num = UI.Label(r, tostring(i), "Subheading")
  r.num:SetPoint("CENTER", r.ring, "CENTER", 0, 0)
  r.check = UI.Icon(r, "check", 14, C.good)
  r.check:SetPoint("CENTER", r.ring, "CENTER", 0, 0)

  r.title = UI.Label(r, step.title, "Subheading")
  r.title:SetPoint("TOPLEFT", 52, -9)
  r.hint = UI.Label(r, step.hint, "MutedSmall")
  r.hint:SetPoint("TOPLEFT", 52, -28)
  r.hint:SetWidth(WIDTH - 48 - 52 - 130)
  r.hint:SetWordWrap(false)

  r.button = UI.Button(r, step.button, 104)
  r.button:SetHeight(26)
  r.button:SetPoint("RIGHT", -12, 0)
  r.button:SetScript("OnClick", step.go)
  r.primary = UI.Button(r, step.button, 104, "primary")
  r.primary:SetHeight(26)
  r.primary:SetPoint("RIGHT", -12, 0)
  r.primary:SetScript("OnClick", step.go)
  r.done = UI.Label(r, "Done", "Body")
  r.done:SetPoint("RIGHT", -20, 0)
  r.done:SetTextColor(C.good[1], C.good[2], C.good[3])
  return r
end

local function Build()
  win = UI.Window("WarcrestGettingStarted", WIDTH, HEIGHT, "Getting started")
  win.heading = UI.Label(win, "", "Title")
  win.heading:SetPoint("TOPLEFT", 24, -48)
  win.sub = UI.Label(win, "Five quick things so the guild sees you, and you see the guild.", "Small")
  win.sub:SetPoint("TOPLEFT", 24, -76)
  win.sub:SetWidth(WIDTH - 48 - 110)
  win.count = UI.Label(win, "", "Body")
  win.count:SetPoint("TOPRIGHT", -24, -76)

  -- The progress bar.
  win.bar = win:CreateTexture(nil, "ARTWORK")
  win.bar:SetPoint("TOPLEFT", 24, -96)
  win.bar:SetSize(WIDTH - 48, 5)
  win.bar:SetColorTexture(C.control[1], C.control[2], C.control[3], 1)
  win.fill = win:CreateTexture(nil, "OVERLAY")
  win.fill:SetPoint("TOPLEFT", win.bar, "TOPLEFT")
  win.fill:SetHeight(5)
  win.fill:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)

  win.rows = {}
  for i, s in ipairs(STEPS) do win.rows[i] = Row(win, i, s) end

  -- The footer: officers' guild setup, and hiding it.
  local rule = win:CreateTexture(nil, "BORDER")
  rule:SetPoint("BOTTOMLEFT", 0, 56)
  rule:SetPoint("BOTTOMRIGHT", 0, 56)
  rule:SetHeight(1)
  rule:SetColorTexture(C.line[1], C.line[2], C.line[3], 1)
  win.hide = UI.Button(win, "Hide this", 96)
  win.hide:SetHeight(28)
  win.hide:SetPoint("BOTTOMRIGHT", -24, 14)
  -- Hiding it takes it off Home and the side menu too (/warcrest start brings it back).
  win.hide:SetScript("OnClick", function()
    ns.db.started.dismissed = true
    win:Hide()
    if ns.RefreshPanel then ns.RefreshPanel() end
  end)
  win.setup = UI.Button(win, "Guild setup", 120)
  win.setup:SetHeight(28)
  win.setup:SetPoint("RIGHT", win.hide, "LEFT", -8, 0)
  win.setup:SetScript("OnClick", function() win:Hide(); ns.ShowWelcome(2) end)
  win.footer = UI.Label(win, "", "Small")
  win.footer:SetPoint("BOTTOMLEFT", 24, 22)
  win.footer:SetWidth(WIDTH - 48 - 240)
  win.footer:SetWordWrap(false)

  win.acc = 0
  win:SetScript("OnUpdate", function(self, elapsed)
    self.acc = self.acc + elapsed
    if self.acc < 1 then return end
    self.acc = 0
    ns.RefreshGettingStarted()
  end)
  tinsert(UISpecialFrames, "WarcrestGettingStarted")
end

function ns.RefreshGettingStarted()
  if not win then return end
  local done, n, total = ns.StartedSteps()
  win.heading:SetText(n == total and ns.T("You're all set") or ns.TF("Welcome, %s", me()))
  win.sub:SetText(n == total and ns.T("The guild can see you, and you can see the guild. Have fun out there.")
    or ns.T("Five quick things so the guild sees you, and you see the guild."))
  win.count:SetText(ns.TF("%d of %d done", n, total))
  win.fill:SetShown(n > 0)
  win.fill:SetWidth(math.max(1, (WIDTH - 48) * n / total))
  local nextStep
  for i, s in ipairs(STEPS) do
    if not done[s.id] then nextStep = nextStep or i end
  end
  for i, s in ipairs(STEPS) do
    local r, ok, isNext = win.rows[i], done[s.id], i == nextStep
    r.check:SetShown(ok)
    r.num:SetShown(not ok)
    r.done:SetShown(ok)
    r.button:SetShown(not ok and not isNext)
    r.primary:SetShown(isNext)
    local col = ok and C.muted or C.text
    r.title:SetTextColor(col[1], col[2], col[3])
    local edge = isNext and C.accent or C.cardEdge
    r.edge:SetColor(edge[1], edge[2], edge[3], isNext and 0.6 or 1)
  end
  local officer = ns.IsAddonOfficer()
  win.setup:SetShown(officer)
  if officer then
    win.footer:SetText((ns.cfg.stamp or 0) > 0 and ns.T("Officer? The guild's setup: who manages Warcrest, DKP and alerts.")
      or (UI.Code("accent") .. ns.T("Nobody has set Warcrest up for your guild yet.") .. "|r"))
  else
    win.footer:SetText(ns.T("Your officers look after the guild's settings."))
  end
end

function ns.ShowGettingStarted()
  if not win then Build() end
  ns.db.started.dismissed = nil
  ns.db.welcomed = true
  ns.RefreshGettingStarted()
  win:Show()
end

ns.OnLoad(function()
  ns.db.started = ns.db.started or {}
end)
