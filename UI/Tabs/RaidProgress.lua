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
    return UI.Code("good") .. "Cleared|r · " .. r.total .. (r.total == 1 and " boss" or " bosses")
  end
  return r.total and ("%d / %d bosses"):format(r.killed, r.total)
    or (r.killed == 1 and "1 boss" or (r.killed .. " bosses"))
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
  M.raids = UI.List(raids, LIST_W - 24, 450 - 40, 62,
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
      row.when:SetText(date("%b %d", r.last))
      local done = r.total and r.killed >= r.total
      local col = done and C.good or C.accent
      row.fill:SetColorTexture(col[1], col[2], col[3], 1)
      local frac = r.total and math.min(1, r.killed / r.total) or 1
      row.fill:SetWidth(math.max(1, (LIST_W - 60) * frac))
      UI.SetRowSelected(row, r.raid == selected)
    end, true)
  M.raids.frame:SetPoint("TOPLEFT", raids, "TOPLEFT", 0, -36)

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
  local y = UI.TableHeads(heads, { { "BOSS", 16 }, { "FIRST KILL", 210 }, { "KILLS", 318 }, { "LAST KILL", 372 } })
  M.bosses = UI.List(heads, TABLE_W - 24, 450 - 48 + y - 4, 30,
    function(row)
      row.icon = UI.Icon(row, "check", 12, C.good)
      row.icon:SetPoint("LEFT", 16, 0)
      row.name = UI.Label(row, "", "Subheading")
      row.name:SetPoint("LEFT", 36, 0)
      row.name:SetWidth(166)
      row.name:SetWordWrap(false)
      row.first = UI.Label(row, "", "Small")
      row.first:SetPoint("LEFT", 210, 0)
      row.kills = UI.Label(row, "", "Number")
      row.kills:SetPoint("LEFT", 318, 0)
      row.last = UI.Label(row, "", "MutedSmall")
      row.last:SetPoint("LEFT", 372, 0)
      UI.RowLine(row)
      UI.Tooltip(row, function() return row.item.name end, function()
        local b = row.item
        local lines = { ("First killed %s."):format(date("%A, %b %d, %Y at %H:%M", b.first)) }
        for _, k in ipairs(ns.BossKills()) do
          if k.boss == b.boss and k.t == b.first then
            lines[#lines + 1] = "There: " .. table.concat(k.names, ", ")
            break
          end
        end
        return table.concat(lines, "\n\n")
      end)
    end,
    function(row, b)
      row.name:SetText(b.name)
      row.first:SetText(date("%b %d, %Y", b.first))
      row.kills:SetText(b.kills)
      row.last:SetText(date("%b %d", b.last))
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
  local current
  for _, r in ipairs(progress) do if r.raid == selected then current = r end end
  current = current or progress[1]
  selected = current and current.raid
  M.raids:SetEmptyText("No raids yet.")
  M.raids:SetItems(progress)
  if current then
    M.raidName:SetText(current.raid)
    M.summary:SetText(progressText(current))
    M.bosses:SetItems(current.bosses)
  else
    M.raidName:SetText("Raid progress")
    M.summary:SetText("")
    M.bosses:SetItems({})
  end
end
