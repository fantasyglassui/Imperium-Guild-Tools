--[[
  Warcrest
  The raid assignments window: pick a raid and a boss, read the plan (your
  own name picked out, and your jobs at the top), and, for officers, write
  it, save it for the guild and post it to raid chat. Opened from the Raids
  tab (Progress view) or /warcrest assign.
]]

local _, ns = ...
local UI = ns.UI
local C = UI.C

local W, H = 720, 480
local LIST_W = 220
local RIGHT_X = 16 + LIST_W + 12
local RIGHT_W = W - RIGHT_X - 16
local win
local raid, boss
local dirty = false

local function raidOptions()
  local opts = {}
  for _, r in ipairs(ns.AssignmentRaids()) do opts[#opts + 1] = { r, r } end
  return opts
end

-- The plan with your name in gold.
local function highlight(text)
  local me = UnitName("player") or ""
  if me == "" then return text end
  local pattern = "%f[%w]" .. me:gsub("(%W)", "%%%1") .. "%f[%W]"
  return (text:gsub(pattern, UI.Code("accent") .. me .. "|r"))
end

local function Build()
  win = UI.Window("WarcrestAssignments", W, H, ns.T("Raid assignments"))

  -- Raid and bosses
  win.raid = UI.Cycle(win, LIST_W, raidOptions(), function(v)
    raid, boss, dirty = v, ns.WHOLE_RAID, false
    ns.RefreshAssignments(true)
  end)
  win.raid:SetHeight(26)
  win.raid:SetPoint("TOPLEFT", 16, -42)
  UI.Tooltip(win.raid, "Raid", "Click to change raid.")
  local listBox = CreateFrame("Frame", nil, win)
  listBox:SetPoint("TOPLEFT", 16, -76)
  listBox:SetSize(LIST_W, H - 76 - 16)
  UI.Card(listBox, 1)
  win.bosses = UI.List(listBox, LIST_W - 4, H - 76 - 16 - 8, 26,
    function(row)
      UI.RowSelection(row)
      row.icon = UI.Icon(row, "check", 11, C.good)
      row.icon:SetPoint("LEFT", 10, 0)
      row.name = UI.Label(row, "", "Small")
      row.name:SetPoint("LEFT", 28, 0)
      row.name:SetWidth(LIST_W - 44)
      row.name:SetWordWrap(false)
      UI.RowLine(row)
      row:SetScript("OnClick", function(self)
        boss, dirty = self.item.boss, false
        ns.RefreshAssignments(true)
      end)
    end,
    function(row, b)
      row.name:SetText(b.boss == ns.WHOLE_RAID and ns.T(ns.WHOLE_RAID) or b.boss)
      row.icon:SetShown(b.has)
      UI.SetRowSelected(row, b.boss == boss)
    end, true)
  win.bosses.frame:SetPoint("TOPLEFT", listBox, "TOPLEFT", 0, -4)

  -- The plan
  win.title = UI.Label(win, "", "Title")
  win.title:SetPoint("TOPLEFT", RIGHT_X, -44)
  win.title:SetWidth(RIGHT_W)
  win.title:SetWordWrap(false)
  win.by = UI.Label(win, "", "MutedSmall")
  win.by:SetPoint("TOPLEFT", RIGHT_X, -68)
  win.by:SetWidth(RIGHT_W)
  win.by:SetWordWrap(false)

  win.jobs = CreateFrame("Frame", nil, win)
  win.jobs:SetPoint("TOPLEFT", RIGHT_X, -88)
  win.jobs:SetSize(RIGHT_W, 64)
  UI.Card(win.jobs, 1)
  win.jobsLabel = UI.Label(win.jobs, "YOUR JOB", "Label")
  win.jobsLabel:SetPoint("TOPLEFT", 12, -10)
  win.jobsText = UI.Label(win.jobs, "", "Small")
  win.jobsText:SetPoint("TOPLEFT", 12, -26)
  win.jobsText:SetWidth(RIGHT_W - 24)
  win.jobsText:SetSpacing(2)

  local sf = CreateFrame("ScrollFrame", nil, win, "UIPanelScrollFrameTemplate")
  UI.SkinScrollBar(sf)
  UI.Card(sf, 4)
  win.scroll = sf
  local box = CreateFrame("EditBox", nil, sf)
  box:SetMultiLine(true)
  box:SetFontObject(UI.Fonts.Small)
  box:SetWidth(RIGHT_W - 30)
  box:SetAutoFocus(false)
  box:SetMaxLetters(1200)
  box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  box:SetScript("OnTextChanged", function(self, userInput)
    if not userInput then return end
    if not win.canEdit then self:SetText(win.shown or "") return end
    dirty = true
    win.hint:SetShown((self:GetText() or "") == "")
    win.save:SetText(ns.T("Save for the guild"))
  end)
  -- Members read the plan as text, with their name picked out.
  local holder = CreateFrame("Frame", nil, sf)
  holder:SetSize(RIGHT_W - 30, 400)
  box:SetParent(holder)
  box:SetPoint("TOPLEFT")
  win.read = UI.Label(holder, "", "Small")
  win.read:SetPoint("TOPLEFT", 6, -4)
  win.read:SetWidth(RIGHT_W - 44)
  win.read:SetSpacing(3)
  sf:SetScrollChild(holder)
  win.edit = box
  win.hint = UI.Label(sf, "Tanks: Thorne on the boss, Brakk on adds\nHealers: Mira on tanks, Lyra on groups 1-2\nInterrupts: ...", "MutedSmall")
  win.hint:SetPoint("TOPLEFT", 8, -6)
  win.hint:SetWidth(RIGHT_W - 40)
  win.hint:SetSpacing(2)

  win.save = UI.Button(win, "Save for the guild", 170, "primary")
  win.save:SetHeight(28)
  win.save:SetPoint("BOTTOMLEFT", RIGHT_X, 16)
  win.save:SetScript("OnClick", function()
    if ns.SaveAssignment(raid, boss, win.edit:GetText()) then
      dirty = false
      win.save:SetText(ns.T("Saved"))
      win.edit:ClearFocus()
    end
  end)
  win.post = UI.Button(win, "Post to raid chat", 160)
  win.post:SetHeight(28)
  win.post:SetPoint("LEFT", win.save, "RIGHT", 8, 0)
  win.post:SetScript("OnClick", function() ns.PostAssignment(raid, boss) end)
  UI.Tooltip(win.post, "Post to raid chat", "Posts this plan in raid chat, a line at a time (12 lines at most).")
  win.note = UI.Label(win, "", "MutedSmall")
  win.note:SetPoint("BOTTOMLEFT", RIGHT_X, 22)
  win.note:SetWidth(RIGHT_W)
end

-- reload: show the saved plan in the box (a new boss was picked).
function ns.RefreshAssignments(reload)
  if not (win and win:IsShown()) then return end
  local opts = raidOptions()
  win.raid.options = opts
  local found
  for i, o in ipairs(opts) do if o[1] == raid then win.raid.index, win.raid.value, found = i, o[1], true end end
  if not found then raid = opts[1][1]; win.raid.index, win.raid.value = 1, raid end
  win.raid:SetText(raid)

  local rows, valid = {}, false
  for _, b in ipairs(ns.AssignmentBosses(raid)) do
    rows[#rows + 1] = { boss = b, has = ns.Assignment(raid, b) ~= nil }
    if b == boss then valid = true end
  end
  if not valid then boss, reload = ns.WHOLE_RAID, true end
  win.bosses:SetItems(rows)

  local plan = ns.Assignment(raid, boss)
  local officer = ns.IsAddonOfficer()
  win.canEdit = officer
  win.title:SetText(boss == ns.WHOLE_RAID and (raid .. ": " .. ns.T("whole raid")) or boss)
  win.by:SetText(plan and ns.TF("Written by %s, %s", ns.Ambiguate(plan.by, "short"), ns.Date("%b %d", plan.t))
    or ns.T(officer and "No plan yet. Write one below: a line for each job, with the players' names."
      or "No plan for this boss yet. Officers write them."))

  -- Your jobs, from the saved plan.
  local jobs = plan and ns.JobsIn(plan.text, UnitName("player")) or {}
  win.jobs:SetShown(#jobs > 0)
  win.jobsText:SetText(table.concat(jobs, "\n"))
  local top = #jobs > 0 and -160 or -88
  win.scroll:ClearAllPoints()
  win.scroll:SetPoint("TOPLEFT", RIGHT_X, top)
  win.scroll:SetPoint("BOTTOMRIGHT", -34, officer and 56 or 16)

  if reload or not dirty then
    win.shown = plan and plan.text or ""
    -- Officers edit the plain text; members read it with their name picked out.
    win.edit:SetText(officer and win.shown or "")
    win.read:SetText(officer and "" or highlight(win.shown))
    dirty = false
  end
  win.edit:SetShown(officer)
  win.read:SetShown(not officer)
  win.hint:SetShown(officer and (win.edit:GetText() or "") == "")
  win.save:SetShown(officer)
  win.post:SetShown(officer and plan ~= nil)
  if not dirty then win.save:SetText(ns.T("Save for the guild")) end
  win.note:SetShown(false)
end

-- raidName: open on this raid (the one picked on the Progress view); bossName: on this boss.
function ns.ShowAssignments(raidName, bossName)
  if not win then Build() end
  if raidName and raidName ~= "" then raid, boss, dirty = raidName, bossName or ns.WHOLE_RAID, false end
  win:Show()
  ns.RefreshAssignments(true)
end

ns.OnLoad(function() ns.OnLedgerChanged(function() ns.RefreshAssignments(false) end) end)
