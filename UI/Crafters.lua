--[[
  Warcrest
  The crafters window: search what the guild can make, see who makes it
  (online first), and click to whisper them. Opened from the Roster tab or
  with /warcrest craft.
]]

local _, ns = ...
local UI = ns.UI

local W, H = 700, 460
local win
local query, prof = "", nil

local function profOptions()
  local opts = { { "", "All professions" } }
  for _, p in ipairs(ns.CraftProfessions()) do opts[#opts + 1] = { p, p } end
  return opts
end

local function craftersText(r)
  local names = {}
  for i, c in ipairs(r.crafters) do
    if i > 3 then
      names[#names + 1] = UI.Code("muted") .. ns.TF("+%d more", #r.crafters - 3) .. "|r"
      break
    end
    names[#names + 1] = (c.online and UI.Code("good") or UI.Code("muted")) .. c.name .. "|r"
  end
  return table.concat(names, ", ")
end

local function Build()
  win = UI.Window("WarcrestCrafters", W, H, ns.T("Guild crafters"))
  win.search = UI.EditBox(win, 260, 40)
  win.search:SetHeight(26)
  win.search:SetPoint("TOPLEFT", 16, -40)
  win.search.hint = UI.Label(win.search, "Search recipes", "MutedSmall")
  win.search.hint:SetPoint("LEFT", 8, 0)
  win.search:HookScript("OnTextChanged", function(self)
    self.hint:SetShown((self:GetText() or "") == "")
    query = self:GetText() or ""
    ns.RefreshCrafters()
  end)
  win.prof = UI.Cycle(win, 180, profOptions(), function(v)
    prof = v ~= "" and v or nil
    ns.RefreshCrafters()
  end)
  win.prof:SetHeight(26)
  win.prof:SetPoint("LEFT", win.search, "RIGHT", 8, 0)
  UI.Tooltip(win.prof, "Profession", "Click to show one profession's recipes.")
  win.info = UI.Label(win, "", "MutedSmall")
  win.info:SetPoint("BOTTOMRIGHT", -16, 18)
  win.info:SetJustifyH("RIGHT")

  local box = CreateFrame("Frame", nil, win)
  box:SetPoint("TOPLEFT", 16, -76)
  box:SetPoint("BOTTOMRIGHT", -16, 46)
  UI.Card(box, 1)
  local y = UI.TableHeads(box, { { "RECIPE", 12 }, { "PROFESSION", 300 }, { "CRAFTERS", 430 } })
  win.rows = UI.List(box, W - 32 - 4, H - 76 - 46 + y - 2, 24,
    function(row)
      row.name = UI.Label(row, "", "Subheading")
      row.name:SetPoint("LEFT", 12, 0)
      row.name:SetWidth(278)
      row.name:SetWordWrap(false)
      row.prof = UI.Label(row, "", "Small")
      row.prof:SetPoint("LEFT", 300, 0)
      row.prof:SetWidth(120)
      row.prof:SetWordWrap(false)
      row.who = UI.Label(row, "", "Small")
      row.who:SetPoint("LEFT", 430, 0)
      row.who:SetWidth(W - 32 - 430 - 30)
      row.who:SetWordWrap(false)
      UI.RowLine(row)
      row:SetScript("OnClick", function(self)
        local c = self.item.crafters[1]
        if c then ns.AskCrafter(c.name, self.item.id) end
      end)
      UI.Tooltip(row, function() return row.item.name end, function()
        local lines = {}
        for _, c in ipairs(row.item.crafters) do
          lines[#lines + 1] = (c.online and UI.Code("good") or UI.Code("muted")) .. c.name .. "|r"
            .. UI.Code("muted") .. "  (" .. c.rank .. ")" .. "|r"
        end
        lines[#lines + 1] = ""
        lines[#lines + 1] = ns.TF("Click to whisper %s.", row.item.crafters[1] and row.item.crafters[1].name or "")
        return table.concat(lines, "\n")
      end)
    end,
    function(row, r)
      row.name:SetText(r.name)
      row.prof:SetText(r.prof)
      row.who:SetText(craftersText(r))
    end, true)
  win.rows.frame:SetPoint("TOPLEFT", box, "TOPLEFT", 0, y - 1)

  win.hint = UI.Label(win, "Open your profession windows to share your recipes with the guild.", "MutedSmall")
  win.hint:SetPoint("BOTTOMLEFT", 16, 18)
  win.hint:SetWidth(W - 32 - 170)
  win.hint:SetWordWrap(false)
end

function ns.RefreshCrafters()
  if not (win and win:IsShown()) then return end
  -- The profession list grows as lists arrive.
  local opts = profOptions()
  win.prof.options = opts
  local found = false
  for i, o in ipairs(opts) do
    if o[1] == (prof or "") then win.prof.index, win.prof.value, found = i, o[1], true end
  end
  if not found then prof, win.prof.index, win.prof.value = nil, 1, "" end
  win.prof:SetText(win.prof.index == 1 and ns.T(opts[1][2]) or opts[win.prof.index][2])

  local list = ns.CraftSearch(query, prof)
  win.rows:SetEmptyText(ns.T(query ~= "" and "Nobody in the guild makes that yet."
    or "No recipes shared yet. They show up once guildmates open their profession windows."))
  win.rows:SetItems(list)
  local people, recipes = ns.CraftStats()
  win.info:SetText(ns.TF("%d crafters · %d recipes", people, recipes))
end

function ns.ShowCrafters(search)
  if not win then Build() end
  win:Show()
  if search and search ~= "" then win.search:SetText(search) end
  ns.RefreshCrafters()
end
