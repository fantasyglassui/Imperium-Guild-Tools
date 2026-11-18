--[[
  The Imperium
  UI widgets: shared helpers for building the guild tools window, drawn in
  the Nightwatch theme (UI/Theme.lua).
]]

local _, ns = ...
local UI = ns.UI or {}
ns.UI = UI
local C = UI.C

UI.tabs = {} -- registered by each tab file: { id, title, build(page), refresh(page), visible(), subtitle() }

function UI.AddTab(tab) UI.tabs[#UI.tabs + 1] = tab end

-- Text. template: one of the game's text styles (GameFontHighlight, ...) or an
-- Imperium style name (Body, Heading, ...); either way the Imperium font is used.
function UI.Label(parent, text, template)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  fs:SetFontObject(UI.Font(template or "Body"))
  fs:SetText(text or "")
  fs:SetJustifyH("LEFT")
  return fs
end

------------------------------------------------------------------------
-- Buttons
------------------------------------------------------------------------
-- Flat button look. style "primary": gold, for the main action on a screen.
local function skinButton(b, text, width, style)
  b:SetSize(width or 100, 22)
  b.bg = b:CreateTexture(nil, "BACKGROUND")
  b.bg:SetAllPoints()
  b.border = UI.Border(b, C.edge[1], C.edge[2], C.edge[3], 1)
  local hover = b:CreateTexture(nil, "HIGHLIGHT")
  hover:SetAllPoints()
  hover:SetColorTexture(1, 1, 1, 0.06)

  local fs = b:CreateFontString(nil, "OVERLAY")
  fs:SetPoint("CENTER")
  fs:SetFontObject(UI.Fonts.Button)
  b:SetFontString(fs)
  b:SetPushedTextOffset(0, -1)

  function b:SetStyle(s)
    self.style = s
    local primary = s == "primary"
    local bg = primary and C.accent or C.control
    local edge = primary and C.accent or C.edge
    self.bg:SetColorTexture(bg[1], bg[2], bg[3], 1)
    self.border:SetColor(edge[1], edge[2], edge[3], 1)
    local font = primary and UI.Fonts.ButtonAccent or UI.Fonts.Button
    self:SetNormalFontObject(font)
    self:SetHighlightFontObject(font)
    self:SetDisabledFontObject(UI.Fonts.ButtonDisabled)
  end
  b:SetStyle(style)
  -- Greyed out: dim the fill so it reads as unavailable.
  b:HookScript("OnDisable", function(self) self.bg:SetAlpha(0.45) end)
  b:HookScript("OnEnable", function(self) self.bg:SetAlpha(1) end)
  b:SetText(text or "")
  return b
end

function UI.Button(parent, text, width, style)
  return skinButton(CreateFrame("Button", nil, parent), text, width, style)
end

-- A button that runs a game slash command (like /gpromote) when clicked.
-- Guild actions are protected, so addons have to go through the game's own
-- commands on a secure button instead of calling them directly.
function UI.SecureButton(parent, text, width, style)
  local b = skinButton(CreateFrame("Button", nil, parent, "SecureActionButtonTemplate"), text, width, style)
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

-- A button that cycles through options: { { value, label }, ... }
function UI.Cycle(parent, width, options, onChange)
  local b = UI.Button(parent, options[1][2], width)
  b:GetFontString():ClearAllPoints()
  b:GetFontString():SetPoint("CENTER", -6, 0)
  local chevron = UI.Icon(b, "chevron", 10, C.accent)
  chevron:SetPoint("RIGHT", -7, 0)
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

------------------------------------------------------------------------
-- Inputs
------------------------------------------------------------------------
function UI.EditBox(parent, width, maxLetters)
  local e = CreateFrame("EditBox", nil, parent)
  e:SetSize(width, 22)
  e:SetFontObject(UI.Fonts.Body)
  e:SetTextColor(C.text[1], C.text[2], C.text[3])
  e:SetTextInsets(7, 7, 0, 0)
  e:SetAutoFocus(false)
  e:SetMaxLetters(maxLetters or 0)
  UI.Fill(e, C.control)
  e.border = UI.Border(e, C.edge[1], C.edge[2], C.edge[3], 1)
  -- Gold edge while typing.
  e:HookScript("OnEditFocusGained", function(self) self.border:SetColor(C.accent[1], C.accent[2], C.accent[3], 0.8) end)
  e:HookScript("OnEditFocusLost", function(self) self.border:SetColor(C.edge[1], C.edge[2], C.edge[3], 1) end)
  e:SetScript("OnEscapePressed", e.ClearFocus)
  e:SetScript("OnEnterPressed", e.ClearFocus)
  return e
end

-- A bare checkbox (no label), for list rows.
function UI.CheckBox(parent, size)
  size = size or 14
  local cb = CreateFrame("CheckButton", nil, parent)
  cb:SetSize(size, size)
  UI.Fill(cb, C.control)
  cb.border = UI.Border(cb, C.edge[1], C.edge[2], C.edge[3], 1)
  local mark = cb:CreateTexture(nil, "ARTWORK")
  mark:SetTexture(UI.IconPath("check"))
  mark:SetPoint("CENTER")
  mark:SetSize(size, size)
  mark:SetVertexColor(C.accent[1], C.accent[2], C.accent[3])
  cb:SetCheckedTexture(mark)
  local greyMark = cb:CreateTexture(nil, "ARTWORK")
  greyMark:SetTexture(UI.IconPath("check"))
  greyMark:SetPoint("CENTER")
  greyMark:SetSize(size, size)
  greyMark:SetVertexColor(C.faint[1], C.faint[2], C.faint[3])
  cb:SetDisabledCheckedTexture(greyMark)
  local hover = cb:CreateTexture(nil, "HIGHLIGHT")
  hover:SetAllPoints()
  hover:SetColorTexture(1, 1, 1, 0.08)
  return cb
end

-- A checkbox with a label. x, y: where the old 26-pixel game checkbox sat, so
-- layouts built for it still line up (this one is centred on the same spot).
function UI.Check(parent, text, x, y)
  local cb = UI.CheckBox(parent, 16)
  cb:SetPoint("TOPLEFT", x + 5, y - 5)
  cb.label = UI.Label(cb, text, "Body")
  cb.label:SetPoint("LEFT", cb, "RIGHT", 7, 0)
  -- Clicking the words ticks the box too.
  cb:SetHitRectInsets(0, -(cb.label:GetStringWidth() + 10), -3, -3)
  return cb
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

  local track = s:CreateTexture(nil, "BACKGROUND")
  track:SetPoint("LEFT", 0, 0)
  track:SetPoint("RIGHT", 0, 0)
  track:SetHeight(4)
  track:SetColorTexture(C.edge[1], C.edge[2], C.edge[3], 1)

  -- The handle: the game's plain white texture, tinted gold.
  s:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
  local thumb = s:GetThumbTexture()
  if thumb then
    thumb:SetSize(8, 16)
    thumb:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 1)
  end

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

------------------------------------------------------------------------
-- Tooltips and enabling
------------------------------------------------------------------------
-- A tooltip for a button or other control. title and text can be functions,
-- for controls whose meaning changes. Also shows while the control is greyed
-- out, so people can see what it does and why they can't use it.
function UI.Tooltip(w, title, text)
  if w.SetMotionScriptsWhileDisabled then w:SetMotionScriptsWhileDisabled(true) end
  w.hasTooltip = true
  w:HookScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(type(title) == "function" and title() or title)
    local body = type(text) == "function" and text() or text
    if body then GameTooltip:AddLine(body, 1, 1, 1, true) end
    GameTooltip:Show()
  end)
  w:HookScript("OnLeave", function() GameTooltip:Hide() end)
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

------------------------------------------------------------------------
-- Guild helpers
------------------------------------------------------------------------
function UI.ClassColor(classFile)
  local c
  if classFile then
    c = (C_ClassColor and C_ClassColor.GetClassColor(classFile)) or RAID_CLASS_COLORS[classFile]
  end
  if c then return c.r, c.g, c.b end
  return C.text[1], C.text[2], C.text[3]
end

function UI.RankName(index)
  local name = GuildControlGetRankName and GuildControlGetRankName(index + 1)
  return (name and name ~= "") and name or ("Rank " .. index)
end

function UI.NumRanks()
  return (GuildControlGetNumRanks and GuildControlGetNumRanks()) or 10
end

function UI.FormatTime(t)
  return date("%b %d %H:%M", t)
end

------------------------------------------------------------------------
-- Lists
------------------------------------------------------------------------
-- A scrolling list on a dark card. makeRow(row) sets up a new row; fill(row,
-- item) shows an item. list:SetEmptyText(text) sets what it says when empty.
function UI.List(parent, width, height, rowHeight, makeRow, fill)
  local sf = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
  sf:SetSize(width, height)
  local content = CreateFrame("Frame", nil, sf)
  content:SetSize(width - 4, 1)
  sf:SetScrollChild(content)
  UI.Card(sf, 2)

  local empty = sf:CreateFontString(nil, "OVERLAY")
  empty:SetFontObject(UI.Fonts.Muted)
  empty:SetPoint("TOPLEFT", 10, -12)
  empty:SetWidth(width - 24)
  empty:SetJustifyH("LEFT")
  empty:Hide()

  local list = { frame = sf, rows = {}, empty = empty }
  function list:SetEmptyText(text) self.emptyText = text end
  function list:SetItems(items)
    for i, item in ipairs(items) do
      local row = self.rows[i]
      if not row then
        row = CreateFrame("Button", nil, content)
        row:SetSize(width - 4, rowHeight)
        row:SetPoint("TOPLEFT", 0, -(i - 1) * rowHeight)
        if i % 2 == 0 then -- every other row slightly lighter, to follow a row across
          local stripe = row:CreateTexture(nil, "BACKGROUND")
          stripe:SetAllPoints()
          stripe:SetColorTexture(1, 1, 1, 0.025)
        end
        local hover = row:CreateTexture(nil, "HIGHLIGHT")
        hover:SetAllPoints()
        hover:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.08)
        makeRow(row)
        self.rows[i] = row
      end
      row.item = item
      fill(row, item)
      row:Show()
    end
    for i = #items + 1, #self.rows do self.rows[i]:Hide() end
    content:SetHeight(math.max(#items * rowHeight, 1))
    empty:SetText(self.emptyText or "")
    empty:SetShown(#items == 0 and (self.emptyText or "") ~= "")
  end
  return list
end

------------------------------------------------------------------------
-- Windows
------------------------------------------------------------------------
-- A themed pop-up window with a title bar and a close button. Escape closes it
-- unless keepOnEscape. Returns the frame, hidden; content goes below the title
-- bar (from 32 pixels down).
function UI.Window(name, width, height, title, keepOnEscape)
  local f = CreateFrame("Frame", name, UIParent)
  f:SetSize(width, height)
  f:SetPoint("CENTER")
  f:SetFrameStrata("DIALOG")
  f:SetToplevel(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:SetClampedToScreen(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  UI.Fill(f, C.window)
  UI.Border(f, C.edge[1], C.edge[2], C.edge[3], 1)

  local bar = f:CreateTexture(nil, "BORDER") -- the title bar
  bar:SetPoint("TOPLEFT")
  bar:SetPoint("TOPRIGHT")
  bar:SetHeight(28)
  bar:SetColorTexture(C.sidebar[1], C.sidebar[2], C.sidebar[3], 1)
  local rule = f:CreateTexture(nil, "BORDER")
  rule:SetHeight(1)
  rule:SetPoint("TOPLEFT", 0, -28)
  rule:SetPoint("TOPRIGHT", 0, -28)
  rule:SetColorTexture(C.line[1], C.line[2], C.line[3], 1)

  local emblem = f:CreateTexture(nil, "ARTWORK")
  emblem:SetTexture(ns.PORTRAIT)
  emblem:SetSize(18, 18)
  emblem:SetPoint("TOPLEFT", 8, -5)
  f.title = UI.Label(f, title or "", "Subheading")
  f.title:SetPoint("LEFT", emblem, "RIGHT", 8, 0)
  f.close = UI.CloseButton(f)
  f.close:SetSize(20, 20)
  f.close:SetPoint("TOPRIGHT", -4, -4)
  if name and not keepOnEscape then tinsert(UISpecialFrames, name) end
  f:Hide()
  return f
end

-- A small square close button with an X.
function UI.CloseButton(parent)
  local b = UI.Button(parent, "", 22)
  local x = UI.Icon(b, "close", 12, C.muted)
  x:SetPoint("CENTER")
  b:SetScript("OnClick", function() parent:Hide() end)
  return b
end
