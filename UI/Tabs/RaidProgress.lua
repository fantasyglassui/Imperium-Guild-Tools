--[[
  Warcrest
  The Raids tab's Progress view: how far the guild has got in each raid.
  Raids on the left with a progress bar; the bosses of the one you pick on
  the right, with the guild's first kill, how many times, and the last.
]]

local _, ns = ...
local UI = ns.UI
local C = UI.C

local M = {}
UI.RaidProgress = M

local LIST_W = 260
local TABLE_X = LIST_W + 14
local TABLE_W = 740 - TABLE_X
local selected -- raid name

local function progressText(r)
  if r.total and r.killed >= r.total then
    return UI.Code("good") .. ns.T("Cleared") .. "|r · " .. ns.TP(r.total, "1 boss", "%d bosses", r.total)
  end
  return r.total and ns.TF("%d / %d bosses", r.killed, r.total)
    or ns.TP(r.killed, "1 boss", "%d bosses", r.killed)
end

function M.Build(parent)
  local f = CreateFrame("Frame", nil, parent)
  M.frame = f
  f:SetPoint("TOPLEFT")
  f:SetSize(740, 450)

  -- Raids
  local raids = UI.Box(f, 0, 0, LIST_W, 450)
  M.raidsCard = raids
  UI.Label(raids, "RAIDS", "Label"):SetPoint("TOPLEFT", 14, -13)
  M.raids = UI.List(raids, LIST_W - 24, 450 - 40 - 72, 62,
    function(row)
      UI.RowSelection(row)
      row.name = UI.Label(row, "", "Subheading")
      row.name:SetPoint("TOPLEFT", 12, -10)
      row.name:SetWidth(LIST_W - 50)
      row.name:SetWordWrap(false)
      row.count = UI.Label(row, "", "Small")
      row.count:SetPoint("TOPLEFT", 12, -28)
      row.when = UI.Label(row, "", "MutedSmall")
      row.when:SetPoint("TOPRIGHT", -12, -29)
      row.when:SetJustifyH("RIGHT")
      row.track = row:CreateTexture(nil, "BORDER")
      row.track:SetPoint("BOTTOMLEFT", 12, 10)
      row.track:SetSize(LIST_W - 60, 3)
      row.track:SetColorTexture(C.line[1], C.line[2], C.line[3], 1)
      row.fill = row:CreateTexture(nil, "ARTWORK")
      row.fill:SetPoint("BOTTOMLEFT", 12, 10)
      row.fill:SetHeight(3)
      UI.RowLine(row)
      row:SetScript("OnClick", function(self) selected = self.item.raid; ns.RefreshPanel() end)
    end,
    function(row, r)
      row.name:SetText(r.raid)
      row.count:SetText(progressText(r))
      row.when:SetText(ns.Date("%b %d", r.last))
      local done = r.total and r.killed >= r.total
      local col = done and C.good or C.accent
      row.fill:SetColorTexture(col[1], col[2], col[3], 1)
      local frac = r.total and math.min(1, r.killed / r.total) or 1
      row.fill:SetWidth(math.max(1, (LIST_W - 60) * frac))
      row.fill:SetShown(frac > 0)
      UI.SetRowSelected(row, r.raid == selected)
    end, true)
  M.raids.frame:SetPoint("TOPLEFT", raids, "TOPLEFT", 0, -36)

  -- Who can come, and who does what.
  M.attune = UI.Button(raids, "Attunements", LIST_W - 28)
  M.attune:SetHeight(26)
  M.attune:SetPoint("BOTTOMLEFT", 14, 46)
  M.attune:SetScript("OnClick", function() ns.ShowAttunements() end)
  UI.Tooltip(M.attune, "Attunements", "Who in the guild is attuned for each raid, and has the Upper Blackrock Spire and Scholomance keys. Also /warcrest attune.")
  M.assign = UI.Button(raids, "Assignments", LIST_W - 28)
  M.assign:SetHeight(26)
  M.assign:SetPoint("BOTTOMLEFT", 14, 14)
  M.assign:SetScript("OnClick", function() ns.ShowAssignments(selected) end)
  UI.Tooltip(M.assign, "Raid assignments", "Who does what on each boss: tanks, healers, interrupts. Officers write them; everyone sees their own job. Also /warcrest assign.")

  -- Bosses of the selected raid
  local card = UI.Box(f, TABLE_X, 0, TABLE_W, 450)
  M.card = card
  M.raidName = UI.Label(card, "", "Title")
  M.raidName:SetPoint("TOPLEFT", 16, -14)
  M.raidName:SetWidth(TABLE_W - 200)
  M.raidName:SetWordWrap(false)
  M.summary = UI.Label(card, "", "Small")
  M.summary:SetPoint("TOPRIGHT", -16, -20)
  M.summary:SetJustifyH("RIGHT")

  local heads = CreateFrame("Frame", nil, card)
  heads:SetPoint("TOPLEFT", 0, -48)
  heads:SetPoint("TOPRIGHT", 0, -48)
  heads:SetHeight(400)
  local y = UI.TableHeads(heads, { { "BOSS", 16 }, { "FIRST KILL", 180 }, { "KILLED", 290 }, { "WIPES", 358 }, { "BEST", 410 } })
  M.bosses = UI.List(heads, TABLE_W - 24, 450 - 48 + y - 4, 30,
    function(row)
      row.icon = UI.Icon(row, "check", 12, C.good)
      row.icon:SetPoint("LEFT", 16, 0)
      row.name = UI.Label(row, "", "Subheading")
      row.name:SetPoint("LEFT", 36, 0)
      row.name:SetWidth(138)
      row.name:SetWordWrap(false)
      row.first = UI.Label(row, "", "Small")
      row.first:SetPoint("LEFT", 180, 0)
      row.kills = UI.Label(row, "", "Number")
      row.kills:SetPoint("LEFT", 290, 0)
      row.wipes = UI.Label(row, "", "Number")
      row.wipes:SetPoint("LEFT", 358, 0)
      row.best = UI.Label(row, "", "Small")
      row.best:SetPoint("LEFT", 410, 0)
      UI.RowLine(row)
      UI.Tooltip(row, function() return row.item.name end, function()
        local b = row.item
        local lines = {}
        if b.first then
          lines[#lines + 1] = ns.TF("First killed %s.", ns.Date("%A, %b %d, %Y at %H:%M", b.first))
          if b.last then lines[#lines + 1] = ns.TF("Last killed %s.", ns.Date("%b %d", b.last)) end
        else
          lines[#lines + 1] = ns.T("Not killed yet.")
        end
        local p = b.pulls
        if p then
          lines[#lines + 1] = ns.TF("Pulls: %d (%d kills, %d wipes).", p.pulls, p.kills, p.wipes)
          if p.wipesBeforeFirst and p.wipesBeforeFirst > 0 then
            lines[#lines + 1] = ns.TF("Wipes before the first recorded kill: %d.", p.wipesBeforeFirst)
          end
          if p.best then lines[#lines + 1] = ns.TF("Best kill time: %s (%s).", ns.FightTime(p.best), ns.Date("%b %d", p.bestAt)) end
          if p.lastKill then lines[#lines + 1] = ns.TF("Last kill took %s.", ns.FightTime(p.lastKill)) end
        end
        for _, k in ipairs(ns.BossKills()) do
          if b.first and k.boss == b.boss and k.t == b.first then
            lines[#lines + 1] = ns.TF("There: %s", table.concat(k.names, ", "))
            break
          end
        end
        return table.concat(lines, "\n")
      end)
    end,
    function(row, b)
      row.name:SetText(b.name)
      row.icon:SetShown(b.first ~= nil)
      row.first:SetText(b.first and ns.Date("%b %d, %Y", b.first) or (UI.Code("muted") .. ns.T("Not yet") .. "|r"))
      row.kills:SetText(b.kills or 0)
      local p = b.pulls
      row.wipes:SetText(p and p.wipes or "-")
      row.best:SetText(p and p.best and ns.FightTime(p.best) or (UI.Code("faint") .. "-|r"))
    end, true)
  M.bosses.frame:SetPoint("TOPLEFT", heads, "TOPLEFT", 0, y - 1)
  M.bosses:SetEmptyText("No boss kills recorded yet. When 5 or more guild members (at least half the raid) "
    .. "kill a raid boss, it's recorded here for everyone, and the first kill of each boss is announced.")

  function M.Resize(dw, dh)
    f:SetSize(740 + dw, 450 + dh)
  end
  return f
end

function M.Refresh()
  local progress = ns.RaidProgress()
  -- Raids the guild has only wiped in so far.
  local listed = {}
  for _, r in ipairs(progress) do listed[r.raid] = true end
  for raid, t in pairs(ns.PulledRaids()) do
    if not listed[raid] then
      progress[#progress + 1] = { raid = raid, total = ns.RAID_BOSSES[raid], bosses = {}, killed = 0, last = t }
    end
  end
  local current
  for _, r in ipairs(progress) do if r.raid == selected then current = r end end
  current = current or progress[1]
  selected = current and current.raid
  M.raids:SetEmptyText("No raids yet.")
  M.raids:SetItems(progress)
  if current then
    M.raidName:SetText(current.raid)
    M.summary:SetText(progressText(current))
    -- Bosses killed, then ones the guild has only wiped on; pulls from the wipe tracking.
    local rows, seen = {}, {}
    for _, b in ipairs(current.bosses) do
      local r = { boss = b.boss, name = b.name, first = b.first, kills = b.kills, last = b.last,
        pulls = ns.BossPulls(current.raid, b.name) }
      rows[#rows + 1] = r
      seen[b.name] = true
    end
    for _, p in ipairs(ns.RaidPulls(current.raid)) do
      if not seen[p.boss] then rows[#rows + 1] = { boss = p.boss, name = p.boss, kills = 0, pulls = p } end
    end
    M.bosses:SetItems(rows)
  else
    M.raidName:SetText("Raid progress")
    M.summary:SetText("")
    M.bosses:SetItems({})
  end
end
