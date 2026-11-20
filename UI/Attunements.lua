--[[
  Warcrest
  The attunements window: who in the guild is attuned for each raid and has
  which keys. Opened from the Raids tab (Progress view) or /warcrest attune.
]]

local _, ns = ...
local UI = ns.UI
local C = UI.C

local W, H = 640, 470
local NAME_W = 190
local COL_W = 66
local win
local maxOnly = true
local query = ""

local function Build()
  win = UI.Window("WarcrestAttunements", W, H, ns.T("Attunements"))
  win.sub = UI.Label(win, "", "MutedSmall")
  win.sub:SetPoint("TOPLEFT", 16, -40)
  win.sub:SetWidth(W - 32)
  win.sub:SetWordWrap(false)

  win.search = UI.SearchBox(win, 200, "Find a member", function(text) query = (text or ""):lower(); ns.RefreshAttunements() end)
  win.search:SetPoint("TOPLEFT", 16, -60)
  win.max = UI.Check(win, "Level 60 only", 228, -60)
  win.max:SetChecked(true)
  win.max:HookScript("OnClick", function(self) maxOnly = self:GetChecked() and true or false; ns.RefreshAttunements() end)

  local box = CreateFrame("Frame", nil, win)
  box:SetPoint("TOPLEFT", 16, -96)
  box:SetPoint("BOTTOMRIGHT", -16, 40)
  UI.Card(box, 1)
  local heads = { { "MEMBER", 12 } }
  for i, a in ipairs(ns.ATTUNEMENTS) do heads[#heads + 1] = { a.short:upper(), NAME_W + (i - 1) * COL_W } end
  local y = UI.TableHeads(box, heads)
  win.heads = heads
  win.list = UI.List(box, W - 32 - 4, H - 96 - 40 + y - 2, 24,
    function(row)
      row.name = UI.Label(row, "", "Subheading")
      row.name:SetPoint("LEFT", 12, 0)
      row.name:SetWidth(NAME_W - 20)
      row.name:SetWordWrap(false)
      row.marks, row.dashes = {}, {}
      for i = 1, #ns.ATTUNEMENTS do
        local mark = UI.Icon(row, "check", 13, C.good)
        mark:SetPoint("LEFT", NAME_W + (i - 1) * COL_W + 4, 0)
        row.marks[i] = mark
        local dash = UI.Label(row, "-", "MutedSmall")
        dash:SetPoint("LEFT", NAME_W + (i - 1) * COL_W + 6, 0)
        row.dashes[i] = dash
      end
      row.unknown = UI.Label(row, "", "MutedSmall")
      row.unknown:SetPoint("LEFT", NAME_W, 0)
      UI.RowLine(row)
      row:SetScript("OnClick", function(self) if ns.ShowPlayerCard then ns.ShowPlayerCard(self.item.name) end end)
    end,
    function(row, r)
      local cr, cg, cb = UI.ClassColor(r.classFile)
      row.name:SetText(r.name)
      row.name:SetTextColor(cr, cg, cb)
      row.name:SetAlpha(r.online and 1 or 0.7)
      for i, a in ipairs(ns.ATTUNEMENTS) do
        local have = r.known and r.set[a.key]
        row.marks[i]:SetShown(have and true or false)
        row.dashes[i]:SetShown(r.known and not have)
      end
      row.unknown:SetText(r.known and "" or ns.T("No Warcrest, or not shared yet"))
    end, true)
  win.list.frame:SetPoint("TOPLEFT", box, "TOPLEFT", 0, y - 1)

  win.hint = UI.Label(win, "Warcrest checks the attunement quests each member has finished. Click a name for their player card.", "MutedSmall")
  win.hint:SetPoint("BOTTOMLEFT", 16, 16)
  win.hint:SetWidth(W - 32)
  win.hint:SetWordWrap(false)
end

function ns.RefreshAttunements()
  if not (win and win:IsShown()) then return end
  local rows = {}
  for _, r in ipairs(ns.GuildAttunements(maxOnly)) do
    if query == "" or r.name:lower():find(query, 1, true) then rows[#rows + 1] = r end
  end
  win.list:SetEmptyText(ns.T(maxOnly and "No level 60 members found." or "No members found."))
  win.list:SetItems(rows)
  local counts, known = ns.AttunementCounts(maxOnly)
  local parts = {}
  for _, a in ipairs(ns.ATTUNEMENTS) do
    if not a.key or not a.raid then break end
    parts[#parts + 1] = a.short .. " " .. UI.Code("text") .. (counts[a.key] or 0) .. "|r"
  end
  win.sub:SetText(ns.TF("Attuned, of %d who shared: %s", known, table.concat(parts, "  ·  ")))
end

function ns.ShowAttunements()
  if not win then Build() end
  win:Show()
  ns.RefreshAttunements()
end

ns.OnLoad(function() ns.OnLedgerChanged(function() ns.RefreshAttunements() end) end)
