--[[
  The Imperium
  Addon tab: which guild members have The Imperium installed, and which
  version. Built from every message their addon has sent while you were
  online, remembered between sessions. "Check now" asks everyone online.
]]

local _, ns = ...
local UI = ns.UI

local P = {}
local filter = "all"

local function ago(t)
  local s = time() - t
  if s < 120 then return "just now" end
  if s < 3600 then return math.floor(s / 60) .. " min ago" end
  if s < 86400 then return math.floor(s / 3600) .. " h ago" end
  return math.floor(s / 86400) .. " d ago"
end

-- Every guild member with their addon status.
local function rows()
  local newest = ns.NewestVersion()
  local users = ns.db.addonUsers or {}
  local out = {}
  for _, m in ipairs(ns.GetRoster()) do
    local u = users[ns.Key(m.name)]
    local live = ns.versions[m.full]               -- confirmed this session
    local version = live or (u and u.version)
    local status
    if live or u then
      status = (version and ns.CompareVersions(version, newest) < 0) and "old" or "yes"
    else
      status = "no"
    end
    out[#out + 1] = { m = m, version = version, seen = u and u.t, status = status, live = live ~= nil }
  end
  return out, newest
end

local ORDER = { yes = 1, old = 2, no = 3 }

local function Refresh()
  local all, newest = rows()
  local shown, counts = {}, { yes = 0, old = 0, no = 0, onlineWith = 0, online = 0 }
  for _, r in ipairs(all) do
    counts[r.status] = counts[r.status] + 1
    if r.m.online then
      counts.online = counts.online + 1
      if r.status ~= "no" then counts.onlineWith = counts.onlineWith + 1 end
    end
    local keep = filter == "all" or (filter == "with" and r.status ~= "no")
      or (filter == "without" and r.status == "no") or (filter == "old" and r.status == "old")
    if keep then shown[#shown + 1] = r end
  end
  table.sort(shown, function(a, b)
    if a.m.online ~= b.m.online then return a.m.online end
    if ORDER[a.status] ~= ORDER[b.status] then return ORDER[a.status] < ORDER[b.status] end
    return a.m.name < b.m.name
  end)
  P.list:SetEmptyText(#all == 0 and "The guild roster is still loading." or "Nobody matches this filter.")
  P.list:SetItems(shown)

  local total = #all
  P.summary:SetText(("|cff6fd08c%d|r of %d members have the addon%s.   Online now: %d of %d."):format(
    counts.yes + counts.old, total,
    counts.old > 0 and (" (|cffff6b6b%d out of date|r)"):format(counts.old) or "",
    counts.onlineWith, counts.online))
  P.newest:SetText("Newest version: " .. ns.COLOR .. newest .. "|r")
end

local function Build(page)
  P.summary = UI.Label(page, "", "GameFontHighlight")
  P.summary:SetPoint("TOPLEFT", 8, -8)
  P.newest = UI.Label(page, "", "GameFontHighlightSmall")
  P.newest:SetPoint("TOPLEFT", 8, -26)

  local check = UI.Button(page, "Check now", 110)
  check:SetPoint("TOPRIGHT", -4, -2)
  UI.Tooltip(check, "Check now", "Asks every online guildmate which version of The Imperium they have.")
  check:SetScript("OnClick", function()
    ns.CheckVersions()
    C_Timer.After(8, ns.RefreshPanel)
  end)
  local f = UI.Cycle(page, 170, {
    { "all", "All members" }, { "with", "Has the addon" }, { "without", "Doesn't have it" },
    { "old", "Out of date" },
  }, function(v) filter = v; ns.RefreshPanel() end)
  UI.Tooltip(f, "Show", "Click to switch between everyone, members with the addon, members without it, and members on an old version.")
  f:SetPoint("TOPRIGHT", check, "TOPLEFT", -6, 0)

  local heads = { { "Member", 8 }, { "Rank", 200 }, { "Status", 330 }, { "Addon", 430 }, { "Last seen with addon", 560 } }
  for _, h in ipairs(heads) do UI.Label(page, h[1], "GameFontNormalSmall"):SetPoint("TOPLEFT", h[2], -70) end

  P.list = UI.List(page, 720, 280, 18,
    function(row)
      row.cols = {}
      for i, h in ipairs(heads) do
        local fs = UI.Label(row, "", "GameFontHighlightSmall")
        fs:SetPoint("LEFT", h[2] - 4, 0)
        fs:SetWidth(i == 1 and 185 or 125)
        fs:SetWordWrap(false)
        row.cols[i] = fs
      end
    end,
    function(row, r)
      local m = r.m
      local cr, cg, cb = UI.ClassColor(m.classFile)
      local dim = m.online and 1 or 0.55
      row.cols[1]:SetText(Ambiguate(m.name, "guild"))
      row.cols[1]:SetTextColor(cr * dim, cg * dim, cb * dim)
      row.cols[2]:SetText(m.rankName)
      row.cols[2]:SetTextColor(dim, dim, dim)
      row.cols[3]:SetText(m.online and "|cff6fd08cOnline|r" or "|cff8b95a7Offline|r")
      if r.status == "yes" then
        row.cols[4]:SetText("|cff6fd08cv" .. (r.version or "?") .. "|r")
      elseif r.status == "old" then
        row.cols[4]:SetText("|cffff6b6bv" .. r.version .. " (update)|r")
      else
        row.cols[4]:SetText("|cff8b95a7Not detected|r")
      end
      row.cols[5]:SetText(r.live and "|cff6fd08cNow|r" or (r.seen and ago(r.seen)) or "|cff8b95a7-|r")
    end)
  P.list.frame:SetPoint("TOPLEFT", 4, -86)

  local note = UI.Label(page, "\"Not detected\" means their addon hasn't been seen while you were online. "
    .. "Click Check now while they're online to ask.", "GameFontDisableSmall")
  note:SetPoint("TOPLEFT", 8, -378)
  note:SetWidth(700)
end

UI.AddTab({ id = "addon", title = "Addon", build = Build, refresh = Refresh })
