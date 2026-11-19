--[[
  Warcrest
  The Raids tab's Calendar view: a month at a glance. Raids scheduled (gold),
  raid nights held (green), bosses killed and guild events (in their own
  colours), day by day. Click a scheduled raid or an event to open it.
]]

local _, ns = ...
local UI = ns.UI
local C = UI.C

local M = {}
UI.RaidCalendar = M

local W, H = 740, 450
local TOP = 44          -- the month and its buttons
local HEAD = 22         -- the day names
local COLS, ROWS = 7, 6
local LINES = 3         -- lines of text a day has room for
local DAY_NAMES = { "SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT" }

local offset = 0        -- months from this one
local cells = {}

-- The first second of a month, offset months from this one.
local function monthStart(n)
  local d = date("*t")
  local m = d.month - 1 + n
  return time({ year = d.year + math.floor(m / 12), month = m % 12 + 1, day = 1, hour = 0 })
end

local function dayKey(t) return date("%Y-%m-%d", t) end

-- What happened (or will) each day: key -> { { kind, text, tip, event }, ... }.
local function collect(fromT, toT)
  local days = {}
  local function add(t, item)
    local k = dayKey(t)
    days[k] = days[k] or {}
    table.insert(days[k], item)
  end
  local nights = {}
  for _, s in ipairs(ns.LedgerEntries("RS")) do
    if s.t >= fromT and s.t < toT then nights[dayKey(s.t)] = s end
  end
  local bosses = {}
  for _, k in ipairs(ns.BossKills(fromT, toT)) do
    local key = dayKey(k.t)
    bosses[key] = bosses[key] or {}
    table.insert(bosses[key], 1, k) -- oldest first
  end
  local now = time()
  for _, e in ipairs(ns.AllRaidEvents()) do
    if e.start >= fromT and e.start < toT and (e.start >= now or not nights[dayKey(e.start)]) then
      local past = e.start < now
      add(e.start, { kind = past and "past" or "raid", time = e.start, event = e,
        text = e.title, sub = date("%H:%M", e.start) })
    end
  end
  -- Guild events (not raids), in their own colours.
  for _, e in ipairs(ns.AllGuildEvents and ns.AllGuildEvents() or {}) do
    if e.start >= fromT and e.start < toT then
      add(e.start, { kind = "gevent", time = e.start, gevent = e, code = "|cff" .. ns.EventType(e.etype).color,
        text = e.title, sub = date("%H:%M", e.start) })
    end
  end
  for key, s in pairs(nights) do
    local killed = bosses[key] or {}
    local text = s.title ~= "" and s.title or "Raid night"
    local tip = { date("%A, %b %d at %H:%M", s.t), "Raid night: " .. text }
    for _, k in ipairs(killed) do tip[#tip + 1] = "Killed " .. k.name .. " (" .. date("%H:%M", k.t) .. ")" end
    add(s.t, { kind = "night", time = s.t, text = text,
      sub = #killed > 0 and (#killed .. " boss" .. (#killed == 1 and "" or "es") .. " killed") or "Raid night",
      tip = table.concat(tip, "\n") })
    bosses[key] = nil
  end
  -- Boss kills on a day with no raid night recorded.
  for _, list in pairs(bosses) do
    local tip = {}
    for _, k in ipairs(list) do tip[#tip + 1] = "Killed " .. k.name .. " in " .. k.raid .. " (" .. date("%H:%M", k.t) .. ")" end
    add(list[1].t, { kind = "night", time = list[1].t, text = list[1].raid,
      sub = #list .. " boss" .. (#list == 1 and "" or "es") .. " killed", tip = table.concat(tip, "\n") })
  end
  for _, list in pairs(days) do table.sort(list, function(a, b) return a.time < b.time end) end
  return days
end

local KIND_COLOR = { raid = "accent", night = "good", past = "muted" }

local function Cell(parent, i, w, h)
  local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
  local c = CreateFrame("Button", nil, parent)
  c:SetPoint("TOPLEFT", col * w, -(TOP + HEAD) - row * h)
  c:SetSize(w, h)
  c.bg = c:CreateTexture(nil, "BACKGROUND")
  c.bg:SetPoint("TOPLEFT", 1, -1)
  c.bg:SetPoint("BOTTOMRIGHT", -1, 1)
  c.bg:SetColorTexture(C.card[1], C.card[2], C.card[3], 1)
  local hover = c:CreateTexture(nil, "HIGHLIGHT")
  hover:SetAllPoints(c.bg)
  hover:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.06)
  c.today = UI.Border(c, C.accent[1], C.accent[2], C.accent[3], 0.9, 0)
  c.num = UI.Label(c, "", "Small")
  c.num:SetPoint("TOPLEFT", 8, -6)
  c.lines = {}
  for l = 1, LINES do
    local fs = UI.Label(c, "", "MutedSmall")
    fs:SetPoint("TOPLEFT", 8, -8 - l * 14)
    fs:SetWidth(w - 14)
    fs:SetWordWrap(false)
    c.lines[l] = fs
  end
  c:SetScript("OnClick", function(self)
    for _, item in ipairs(self.items or {}) do
      if item.kind == "raid" and ns.SelectRaid then ns.SelectRaid(item.event.id) return end
      if item.kind == "gevent" and ns.SelectGuildEvent then ns.SelectGuildEvent(item.gevent.id) return end
    end
  end)
  c:SetScript("OnEnter", function(self)
    if not self.items or #self.items == 0 then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(date("%A, %B %d", self.t))
    for _, item in ipairs(self.items) do
      if item.kind == "night" then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(item.tip, 0.55, 0.85, 0.55, true)
      elseif item.kind == "gevent" then
        local e = item.gevent
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(item.code .. ns.T(ns.EventType(e.etype).label) .. "|r: " .. e.title .. "  " .. date("%H:%M", e.start), 1, 1, 1)
        local c = ns.EventCounts(e.id)
        GameTooltip:AddLine(ns.T("%d going, %d maybe"):format(c.going, c.maybe), 0.8, 0.8, 0.8)
        if e.notes and e.notes ~= "" then GameTooltip:AddLine(e.notes, 0.7, 0.7, 0.7, true) end
        GameTooltip:AddLine(ns.T("Click to open this event."), 0.6, 0.6, 0.6)
      else
        local e = item.event
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(e.title .. "  " .. date("%H:%M", e.start), 1, 0.82, 0.3)
        local counts = ns.SignupCounts and ns.SignupCounts(e.id)
        if counts then
          GameTooltip:AddLine(("%d accepted, %d tentative"):format(counts.accept or 0, counts.tentative or 0), 0.8, 0.8, 0.8)
        end
        if e.notes and e.notes ~= "" then GameTooltip:AddLine(e.notes, 0.7, 0.7, 0.7, true) end
        if item.kind == "raid" then GameTooltip:AddLine("Click to open this raid.", 0.6, 0.6, 0.6) end
      end
    end
    GameTooltip:Show()
  end)
  c:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return c
end

local function layout(frame, width, height)
  local w = width / COLS
  local h = (height - TOP - HEAD) / ROWS
  for i, c in ipairs(cells) do
    local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
    c:ClearAllPoints()
    c:SetPoint("TOPLEFT", frame, "TOPLEFT", col * w, -(TOP + HEAD) - row * h)
    c:SetSize(w, h)
    for _, fs in ipairs(c.lines) do fs:SetWidth(w - 14) end
  end
  for i, fs in ipairs(M.heads) do
    fs:ClearAllPoints()
    fs:SetPoint("TOPLEFT", frame, "TOPLEFT", (i - 1) * w + 8, -TOP - 4)
  end
end

function M.Build(parent)
  local f = CreateFrame("Frame", nil, parent)
  M.frame = f
  f:SetPoint("TOPLEFT")
  f:SetSize(W, H)

  local prev = UI.Button(f, "", 30)
  prev:SetHeight(28)
  prev:SetPoint("TOPLEFT", 0, -4)
  UI.Icon(prev, "chevron-left", 14, C.textSoft):SetPoint("CENTER")
  prev:SetScript("OnClick", function() offset = offset - 1; ns.RefreshPanel() end)
  local nextB = UI.Button(f, "", 30)
  nextB:SetHeight(28)
  nextB:SetPoint("LEFT", prev, "RIGHT", 6, 0)
  UI.Icon(nextB, "chevron-right", 14, C.textSoft):SetPoint("CENTER")
  nextB:SetScript("OnClick", function() offset = offset + 1; ns.RefreshPanel() end)
  M.title = UI.Label(f, "", "Title")
  M.title:SetPoint("LEFT", nextB, "RIGHT", 14, 0)
  M.todayButton = UI.Button(f, "Today", 70)
  M.todayButton:SetHeight(28)
  M.todayButton:SetPoint("LEFT", M.title, "RIGHT", 14, 0)
  M.todayButton:SetScript("OnClick", function() offset = 0; ns.RefreshPanel() end)

  -- Legend: a colored square for each kind of entry.
  local x = 0
  for i = 4, 1, -1 do
    local key = ({ { "accent", "Raid scheduled" }, { "good", "Raid night held" }, { "muted", "Past raid" },
      { "event", "Guild event" } })[i]
    local fs = UI.Label(f, key[2], "MutedSmall")
    fs:SetPoint("TOPRIGHT", -x, -13)
    local sq = f:CreateTexture(nil, "ARTWORK")
    sq:SetSize(8, 8)
    sq:SetPoint("RIGHT", fs, "LEFT", -6, 0)
    local col = key[1] == "event" and { 0.31, 0.82, 0.77 } or C[key[1]]
    sq:SetColorTexture(col[1], col[2], col[3], 1)
    x = x + fs:GetStringWidth() + 26
  end

  M.heads = {}
  for i, name in ipairs(DAY_NAMES) do
    local fs = UI.Label(f, name, "Label")
    M.heads[i] = fs
  end
  for i = 1, COLS * ROWS do cells[i] = Cell(f, i, W / COLS, (H - TOP - HEAD) / ROWS) end
  layout(f, W, H)

  -- A bigger window: bigger days.
  function M.Resize(w, h)
    f:SetSize(w, h)
    layout(f, w, h)
  end
  return f
end

function M.Refresh()
  local fromT = monthStart(offset)
  M.title:SetText(date("%B %Y", fromT))
  M.todayButton:SetShown(offset ~= 0)
  local firstDay = tonumber(date("%w", fromT)) -- 0 = Sunday
  local gridStart = fromT - firstDay * 86400 + 3600 -- (an hour in, so daylight saving can't slip a day)
  local days = collect(gridStart - 3600, gridStart + COLS * ROWS * 86400)
  local today = dayKey(time())
  local month = date("%m", fromT)
  for i, c in ipairs(cells) do
    local t = gridStart + (i - 1) * 86400
    local key = dayKey(t)
    c.t = t
    local inMonth = date("%m", t) == month
    c.num:SetText(tonumber(date("%d", t)))
    local nc = key == today and C.accent or (inMonth and C.textSoft or C.faint)
    c.num:SetTextColor(nc[1], nc[2], nc[3])
    c.today:SetColor(C.accent[1], C.accent[2], C.accent[3], key == today and 0.9 or 0)
    c.bg:SetAlpha(inMonth and 1 or 0.4)
    local items = days[key] or {}
    c.items = items
    -- Each entry: its name, then a detail line if there's room; "+N more" if not all fit.
    local text = {}
    for n, item in ipairs(items) do
      local left = LINES - #text
      local remaining = #items - n + 1
      if left == 1 and remaining > 1 then
        text[#text + 1] = UI.Code("muted") .. "+" .. remaining .. " more|r"
        break
      end
      if left < 1 then break end
      text[#text + 1] = (item.code or UI.Code(KIND_COLOR[item.kind])) .. item.text .. "|r"
      if item.sub and #items == 1 then text[#text + 1] = UI.Code("muted") .. item.sub .. "|r" end
    end
    for l, fs in ipairs(c.lines) do fs:SetText(text[l] or "") end
  end
end
