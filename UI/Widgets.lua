--[[
  The Imperium
  UI widgets: shared helpers for building the guild tools window.
]]

local _, ns = ...
local UI = {}
ns.UI = UI

UI.tabs = {} -- registered by each tab file: { title, build(page), refresh(page), visible() }

function UI.AddTab(tab) UI.tabs[#UI.tabs + 1] = tab end

function UI.Label(parent, text, template)
  local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlight")
  fs:SetText(text or "")
  fs:SetJustifyH("LEFT")
  return fs
end

function UI.Button(parent, text, width)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(width or 100, 22)
  b:SetText(text)
  return b
end

function UI.EditBox(parent, width, maxLetters)
  local e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
  e:SetSize(width, 20)
  e:SetAutoFocus(false)
  e:SetMaxLetters(maxLetters or 0)
  e:SetScript("OnEscapePressed", e.ClearFocus)
  e:SetScript("OnEnterPressed", e.ClearFocus)
  return e
end

function UI.Check(parent, text, x, y)
  local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  cb:SetPoint("TOPLEFT", x, y)
  cb.label = UI.Label(cb, text)
  cb.label:SetPoint("LEFT", cb, "RIGHT", 2, 0)
  return cb
end

-- A button that runs a game slash command (like /gpromote) when clicked.
-- Guild actions are protected, so addons have to go through the game's own
-- commands on a secure button instead of calling them directly.
function UI.SecureButton(parent, text, width)
  local b = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate, UIPanelButtonTemplate")
  b:SetSize(width or 100, 22)
  b:SetText(text)
  b:RegisterForClicks("AnyUp", "AnyDown")
  b:SetAttribute("type", "macro")
  b:SetAttribute("macrotext", "")
  return b
end

-- Set the command a secure button runs. Not allowed during combat.
function UI.SetCommand(b, text)
  if InCombatLockdown() then return false end
  b:SetAttribute("macrotext", text or "")
  return true
end

function UI.SetEnabled(w, on)
  -- Secure buttons can't be changed during combat.
  if InCombatLockdown() and w.IsProtected and w:IsProtected() then return end
  on = on and true or false
  if w.SetEnabled then
    w:SetEnabled(on)
  elseif on and w.Enable then
    w:Enable()
  elseif w.Disable then
    w:Disable()
  end
  if w:GetObjectType() == "EditBox" or w:GetObjectType() == "Slider" then
    w:SetAlpha(on and 1 or 0.5)
    w:EnableMouse(on)
    if not on and w.ClearFocus then w:ClearFocus() end
  elseif w.label then
    w.label:SetAlpha(on and 1 or 0.5)
  end
end

function UI.ClassColor(classFile)
  local c
  if classFile then
    c = (C_ClassColor and C_ClassColor.GetClassColor(classFile)) or RAID_CLASS_COLORS[classFile]
  end
  if c then return c.r, c.g, c.b end
  return 1, 1, 1
end

function UI.RankName(index)
  local name = GuildControlGetRankName and GuildControlGetRankName(index + 1)
  return (name and name ~= "") and name or ("Rank " .. index)
end

function UI.NumRanks()
  return (GuildControlGetNumRanks and GuildControlGetNumRanks()) or 10
end

-- A scrolling list. makeRow(row) sets up a new row; fill(row, item) shows an item.
function UI.List(parent, width, height, rowHeight, makeRow, fill)
  local sf = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
  sf:SetSize(width, height)
  local content = CreateFrame("Frame", nil, sf)
  content:SetSize(width - 4, 1)
  sf:SetScrollChild(content)

  local list = { frame = sf, rows = {} }
  function list:SetItems(items)
    for i, item in ipairs(items) do
      local row = self.rows[i]
      if not row then
        row = CreateFrame("Button", nil, content)
        row:SetSize(width - 4, rowHeight)
        row:SetPoint("TOPLEFT", 0, -(i - 1) * rowHeight)
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        makeRow(row)
        self.rows[i] = row
      end
      row.item = item
      fill(row, item)
      row:Show()
    end
    for i = #items + 1, #self.rows do self.rows[i]:Hide() end
    content:SetHeight(math.max(#items * rowHeight, 1))
  end
  return list
end

-- A horizontal slider. onChange(value) is called with the stepped value.
function UI.Slider(parent, width, minValue, maxValue, step, onChange)
  local s = CreateFrame("Slider", nil, parent)
  s:SetOrientation("HORIZONTAL")
  s:SetSize(width, 18)
  s:SetMinMaxValues(minValue, maxValue)
  s:SetValueStep(step)
  if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
  s:EnableMouseWheel(true)

  local border = s:CreateTexture(nil, "BACKGROUND")
  border:SetPoint("LEFT", -1, 0)
  border:SetPoint("RIGHT", 1, 0)
  border:SetHeight(8)
  border:SetColorTexture(0.83, 0.69, 0.22, 0.8) -- Imperium gold
  local track = s:CreateTexture(nil, "BORDER")
  track:SetPoint("LEFT", 0, 0)
  track:SetPoint("RIGHT", 0, 0)
  track:SetHeight(6)
  track:SetColorTexture(0.08, 0.08, 0.12, 1)

  s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
  local thumb = s:GetThumbTexture()
  if thumb then thumb:SetSize(28, 28) end

  local function stepped(v) return math.floor(v / step + 0.5) * step end
  s:SetScript("OnValueChanged", function(self, v)
    if self.updating then return end
    onChange(stepped(v))
  end)
  s:SetScript("OnMouseWheel", function(self, delta)
    if not self:IsEnabled() then return end
    local lo, hi = self:GetMinMaxValues()
    self:SetValue(math.max(lo, math.min(hi, stepped(self:GetValue()) + delta * step)))
  end)

  -- Set the value without calling onChange.
  function s:SetQuietly(v)
    self.updating = true
    self:SetValue(v)
    self.updating = false
  end
  return s
end

-- A button that cycles through options: { { value, label }, ... }
function UI.Cycle(parent, width, options, onChange)
  local b = UI.Button(parent, options[1][2], width)
  b.index = 1
  b.value = options[1][1]
  b:SetScript("OnClick", function(self)
    self.index = self.index % #options + 1
    self.value = options[self.index][1]
    self:SetText(options[self.index][2])
    if onChange then onChange(self.value) end
  end)
  return b
end

function UI.FormatTime(t)
  return date("%b %d %H:%M", t)
end
