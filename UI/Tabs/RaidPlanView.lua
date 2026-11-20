--[[
  Warcrest
  The Raids tab's Plan view: the selected raid's groups. Officers click a
  name, then a group (or the bench) to move them; Auto-fill fills the groups
  from the sign-ups, and Arrange raid moves the raid into its groups.
  Everyone else sees the plan, with their own name picked out.
]]

local _, ns = ...
local UI = ns.UI
local C = UI.C

local M = {}
UI.RaidPlanView = M

local W, H = 740, 450
local TOP = 44
local SIDE_W = 176
local GAP = 8
local SLOT_H = 28
local picked -- the name an officer clicked, waiting to be put somewhere
local eventId

local ROLE = { tank = "T", healer = "H", dps = "D" }
local ROLE_COLOR = { tank = "accent", healer = "good", dps = "muted" }

local function nameText(p)
  return UI.Code(ROLE_COLOR[p.role] or "muted") .. ROLE[p.role] .. "|r  " .. p.name
    .. (p.status == "tentative" and (UI.Code("faint") .. " ?|r") or "")
end

local function isMe(name) return ns.Key(name) == ns.Key(UnitName("player")) end

-- Clicking a name: pick it (officers), or put the picked name where this one is.
local function clickName(p, group)
  if not ns.IsAddonOfficer() then return end
  if picked and ns.Key(picked) == ns.Key(p.name) then
    picked = nil
  elseif picked and group ~= nil then
    ns.SetPlanGroup(eventId, picked, group)
    picked = nil
  else
    picked = p.name
  end
  ns.RefreshPanel()
end

-- Clicking a box: put the picked name in it.
local function clickBox(group)
  if not (picked and ns.IsAddonOfficer()) then return end
  ns.SetPlanGroup(eventId, picked, group)
  picked = nil
  ns.RefreshPanel()
end

local function styleName(fs, row, p)
  local m = ns.Member(p.name)
  fs:SetText(nameText(p))
  if m then
    local r, g, b = UI.ClassColor(m.classFile)
    fs:SetTextColor(r, g, b)
  end
  UI.SetRowSelected(row, (picked and ns.Key(picked) == ns.Key(p.name)) or (not ns.IsAddonOfficer() and isMe(p.name)))
end

local function SideList(parent, y, h, title, group)
  local box = CreateFrame("Button", nil, parent)
  box:SetPoint("TOPLEFT", 1, y - 1)
  box:SetSize(SIDE_W - 2, h)
  UI.Card(box, 1)
  box.title = UI.Label(box, title, "Label")
  box.title:SetPoint("TOPLEFT", 12, -11)
  box.count = UI.Label(box, "", "MutedSmall")
  box.count:SetPoint("TOPRIGHT", -12, -11)
  box:SetScript("OnClick", function() clickBox(group) end)
  box.list = UI.List(box, SIDE_W - 14, h - 32, 24,
    function(row)
      UI.RowSelection(row)
      row.name = UI.Label(row, "", "Small")
      row.name:SetPoint("LEFT", 10, 0)
      row.name:SetWidth(SIDE_W - 40)
      row.name:SetWordWrap(false)
      row:SetScript("OnClick", function(self) clickName(self.item, group) end)
    end,
    function(row, p) styleName(row.name, row, p) end, true)
  box.list.frame:SetPoint("TOPLEFT", box, "TOPLEFT", 0, -28)
  return box
end

local function GroupBox(parent, g)
  local box = CreateFrame("Button", nil, parent)
  box:SetScript("OnClick", function() clickBox(g) end)
  UI.Card(box, 1)
  box.title = UI.Label(box, "GROUP " .. g, "Label")
  box.title:SetPoint("TOPLEFT", 12, -11)
  box.count = UI.Label(box, "", "MutedSmall")
  box.count:SetPoint("TOPRIGHT", -12, -11)
  box.slots = {}
  for i = 1, ns.PLAN_SLOTS do
    local s = CreateFrame("Button", nil, box)
    s:SetPoint("TOPLEFT", 4, -30 - (i - 1) * SLOT_H)
    s:SetPoint("TOPRIGHT", -4, -30 - (i - 1) * SLOT_H)
    s:SetHeight(SLOT_H - 2)
    UI.RowSelection(s)
    local hover = s:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.08)
    s.name = UI.Label(s, "", "Small")
    s.name:SetPoint("LEFT", 8, 0)
    s.name:SetWordWrap(false)
    s.empty = UI.Label(s, "Empty", "MutedSmall")
    s.empty:SetPoint("LEFT", 8, 0)
    s.empty:SetAlpha(0.5)
    s:SetScript("OnClick", function(self)
      if self.item then clickName(self.item, g) else clickBox(g) end
    end)
    box.slots[i] = s
  end
  return box
end

local function layout(width, height)
  local gw = (width - SIDE_W - 12 - 3 * GAP) / 4
  local gh = (height - TOP - GAP) / 2
  for g, box in ipairs(M.groups) do
    local col, row = (g - 1) % 4, math.floor((g - 1) / 4)
    box:ClearAllPoints()
    box:SetPoint("TOPLEFT", M.frame, "TOPLEFT", SIDE_W + 12 + col * (gw + GAP) + 1, -TOP - row * (gh + GAP) - 1)
    box:SetSize(gw - 2, gh - 2)
    for _, s in ipairs(box.slots) do s.name:SetWidth(gw - 20) end
  end
end

function M.Build(page)
  local f = CreateFrame("Frame", nil, page)
  M.frame = f
  f:SetPoint("TOPLEFT")
  f:SetSize(W, H)

  -- Arrows to step between upcoming raids.
  local function step(d)
    local events = ns.RaidEvents()
    for i, e in ipairs(events) do
      if e.id == eventId and events[i + d] then ns.PickRaid(events[i + d].id) return end
    end
  end
  M.prev = UI.Button(f, "", 24)
  M.prev:SetHeight(24)
  M.prev:SetPoint("TOPLEFT", 0, -4)
  UI.Icon(M.prev, "chevron-left", 12, C.textSoft):SetPoint("CENTER")
  M.prev:SetScript("OnClick", function() step(-1) end)
  M.next = UI.Button(f, "", 24)
  M.next:SetHeight(24)
  M.next:SetPoint("LEFT", M.prev, "RIGHT", 4, 0)
  UI.Icon(M.next, "chevron-right", 12, C.textSoft):SetPoint("CENTER")
  M.next:SetScript("OnClick", function() step(1) end)
  UI.Tooltip(M.prev, "Earlier raid", "Plan the raid before this one.")
  UI.Tooltip(M.next, "Later raid", "Plan the raid after this one.")

  M.title = UI.Label(f, "", "Heading")
  M.title:SetPoint("TOPLEFT", 60, -6)
  M.title:SetWidth(250)
  M.title:SetWordWrap(false)
  M.hint = UI.Label(f, "", "MutedSmall")
  M.hint:SetPoint("TOPLEFT", 60, -26)
  M.hint:SetWidth(270)
  M.hint:SetWordWrap(false)

  M.arrange = UI.Button(f, "Arrange raid", 110, "primary")
  M.arrange:SetHeight(28)
  M.arrange:SetPoint("TOPRIGHT", 0, -4)
  M.arrange:SetScript("OnClick", function() if eventId then ns.ArrangeRaid(eventId) end end)
  UI.Tooltip(M.arrange, "Arrange raid", "Moves everyone in your raid into their planned group. You need to be raid leader or assistant.")
  M.clear = UI.Button(f, "Clear", 70)
  M.clear:SetHeight(28)
  M.clear:SetPoint("RIGHT", M.arrange, "LEFT", -8, 0)
  M.clear:SetScript("OnClick", function() if eventId then ns.ClearPlan(eventId) end end)
  UI.Tooltip(M.clear, "Clear", "Takes everyone out of the groups and off the bench.")
  M.fill = UI.Button(f, "Auto-fill", 84)
  M.fill:SetHeight(28)
  M.fill:SetPoint("RIGHT", M.clear, "LEFT", -8, 0)
  M.fill:SetScript("OnClick", function() if eventId then ns.AutoPlan(eventId, M.size.value) end end)
  UI.Tooltip(M.fill, "Auto-fill", "Places everyone who accepted and isn't placed yet: tanks in group 1, a healer in each group, "
    .. "then everyone else, up to the raid size. Tentative sign-ups and anyone over the size go on the bench.")
  M.size = UI.Cycle(f, 100, { { 10, "10 players" }, { 20, "20 players" }, { 25, "25 players" }, { 40, "40 players" } })
  M.size:SetHeight(28)
  M.size:SetPoint("RIGHT", M.fill, "LEFT", -8, 0)
  UI.Tooltip(M.size, "Raid size", "How many Auto-fill places in groups. Click to change it.")

  M.unplaced = SideList(f, -TOP, 200, "NOT PLACED", -1)
  M.bench = SideList(f, -TOP - 200 - GAP, H - TOP - 200 - GAP - 2, "BENCH", 0)
  M.groups = {}
  for g = 1, ns.PLAN_GROUPS do M.groups[g] = GroupBox(f, g) end
  layout(W, H)

  function M.Resize(w, h)
    f:SetSize(w, h)
    layout(w, h)
  end
  return f
end

function M.Refresh(event)
  eventId = event and event.id
  local officer = ns.IsAddonOfficer()
  for _, b in ipairs({ M.fill, M.clear, M.arrange, M.size }) do b:SetShown(officer and event ~= nil) end
  if not event then
    M.title:SetText("No raid picked")
    M.hint:SetText("Schedule a raid first, then plan its groups here.")
    M.unplaced.list:SetItems({})
    M.bench.list:SetItems({})
    for _, box in ipairs(M.groups) do
      for _, s in ipairs(box.slots) do s.item = nil; s.name:SetText(""); s.empty:Show(); UI.SetRowSelected(s, false) end
      box.count:SetText("")
    end
    return
  end
  M.title:SetText(event.title .. "  " .. UI.Code("muted") .. ns.Date("%a %b %d, %H:%M", event.start) .. "|r")
  M.hint:SetText(officer and (picked and ("Now click where " .. picked .. " goes.") or "Click a name, then a group or the bench.")
    or "Your officers' plan for this raid.")
  local groups, bench, unplaced = ns.RaidPlanGroups(event.id)
  M.unplaced.list:SetEmptyText("Everyone is placed.")
  M.unplaced.list:SetItems(unplaced)
  M.unplaced.count:SetText(#unplaced)
  M.bench.list:SetEmptyText("Nobody on the bench.")
  M.bench.list:SetItems(bench)
  M.bench.count:SetText(#bench)
  for g, box in ipairs(M.groups) do
    local list = groups[g]
    box.count:SetText(#list .. " / " .. ns.PLAN_SLOTS)
    for i, s in ipairs(box.slots) do
      local p = list[i]
      s.item = p
      s.empty:SetShown(p == nil)
      if p then styleName(s.name, s, p) else s.name:SetText(""); UI.SetRowSelected(s, false) end
    end
  end
end
