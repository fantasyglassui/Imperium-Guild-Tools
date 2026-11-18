--[[
  The Imperium
  Panel: the guild tools window and its Options entry.
]]

local _, ns = ...
local UI = ns.UI
local C = UI.C
local ICON = ns.PORTRAIT
local panel
local current = 1

local WIDTH, HEIGHT = 910, 520
local SIDEBAR = 150   -- width of the side menu
local HEADER = 52     -- height of the header above each tab

-- Icon and one-line description for each tab, by its id.
local TAB_INFO = {
  roster = { icon = "roster", text = "Members, notes and ranks" },
  raids = { icon = "raids", text = "Sign-ups, raid nights and invites" },
  dkp = { icon = "dkp", text = "Standings, loot and auctions" },
  kills = { icon = "kills", text = "PvP kills by guild members" },
  wanted = { icon = "wanted", text = "Enemy players who keep killing guild members" },
  settings = { icon = "settings", text = "Alerts for the whole guild, and just for you" },
  officers = { icon = "officers", text = "Guild changes seen while you're online" },
  addon = { icon = "addon", text = "Who has The Imperium installed" },
}

local function tabVisible(i)
  local t = UI.tabs[i]
  return not t.visible or t.visible()
end

-- Highlight the current tab's menu item.
local function paintNav()
  for i, b in ipairs(panel.navButtons) do
    local active = i == current
    b.active:SetShown(active)
    b.bar:SetShown(active)
    b.text:SetFontObject(active and UI.Fonts.NavActive or UI.Fonts.Nav)
    local c = active and C.accent or C.navText
    b.icon:SetVertexColor(c[1], c[2], c[3])
  end
end

local function setHeader()
  local t = UI.tabs[current]
  local info = TAB_INFO[t.id] or {}
  panel.heading:SetText(t.title)
  panel.subheading:SetText((t.subtitle and t.subtitle()) or info.text or "")
end

local function ShowTab(id)
  if not tabVisible(id) then id = 1 end
  current = id
  ns.db.lastTab = UI.tabs[id].id -- reopen here next time
  for i, t in ipairs(UI.tabs) do t.page:SetShown(i == id) end
  paintNav()
  ns.RefreshPanel()
end

-- Officer-only tabs come and go with your rank: lay out the menu again.
local function UpdateTabVisibility()
  local y = -64
  for i, b in ipairs(panel.navButtons) do
    local shown = tabVisible(i)
    b:SetShown(shown)
    if shown then
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", 10, y)
      y = y - 30
    end
  end
  if not tabVisible(current) then ShowTab(1) end
end

local function MakeNavButton(parent, id, tab)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(SIDEBAR - 20, 28)
  b.active = UI.Fill(b, C.accent, 0.12)
  b.bar = b:CreateTexture(nil, "BORDER")
  b.bar:SetPoint("TOPLEFT")
  b.bar:SetPoint("BOTTOMLEFT")
  b.bar:SetWidth(2)
  b.bar:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
  local hover = b:CreateTexture(nil, "HIGHLIGHT")
  hover:SetAllPoints()
  hover:SetColorTexture(1, 1, 1, 0.04)
  local info = TAB_INFO[tab.id] or {}
  b.icon = UI.Icon(b, info.icon or "addon", 14, C.navText)
  b.icon:SetPoint("LEFT", 11, 0)
  b.text = UI.Label(b, tab.title, "Nav")
  b.text:SetPoint("LEFT", b.icon, "RIGHT", 9, 0)
  b:SetScript("OnClick", function()
    PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
    ShowTab(id)
  end)
  return b
end

local function CreatePanel()
  panel = CreateFrame("Frame", "TheImperiumPanel", UIParent)
  panel:SetSize(WIDTH, HEIGHT)
  panel:SetPoint("CENTER")
  panel:SetFrameStrata("HIGH")
  panel:SetToplevel(true)
  panel:SetMovable(true)
  panel:EnableMouse(true)
  panel:SetClampedToScreen(true)
  panel:RegisterForDrag("LeftButton")
  panel:SetScript("OnDragStart", panel.StartMoving)
  panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
  panel:Hide()
  tinsert(UISpecialFrames, "TheImperiumPanel") -- Escape closes it
  UI.Fill(panel, C.window)
  UI.Border(panel, C.edge[1], C.edge[2], C.edge[3], 1)

  -- Side menu
  local side = CreateFrame("Frame", nil, panel)
  side:SetPoint("TOPLEFT")
  side:SetPoint("BOTTOMLEFT")
  side:SetWidth(SIDEBAR)
  UI.Fill(side, C.sidebar)
  local divider = side:CreateTexture(nil, "BORDER")
  divider:SetPoint("TOPRIGHT")
  divider:SetPoint("BOTTOMRIGHT")
  divider:SetWidth(1)
  divider:SetColorTexture(C.line[1], C.line[2], C.line[3], 1)

  local emblem = side:CreateTexture(nil, "ARTWORK")
  emblem:SetTexture(ICON)
  emblem:SetSize(30, 30)
  emblem:SetPoint("TOPLEFT", 14, -16)
  local brand = UI.Label(side, "The Imperium", "Brand")
  brand:SetPoint("TOPLEFT", emblem, "TOPRIGHT", 9, -1)
  local sub = UI.Label(side, "Guild Tools", "MutedSmall")
  sub:SetPoint("TOPLEFT", brand, "BOTTOMLEFT", 0, -3)

  panel.navButtons = {}
  for i, t in ipairs(UI.tabs) do
    panel.navButtons[i] = MakeNavButton(side, i, t)
  end

  local version = UI.Label(side, "v" .. (ns.version or "?"), "MutedSmall")
  version:SetPoint("BOTTOMLEFT", 16, 12)

  -- Header
  panel.heading = UI.Label(panel, "", "Title")
  panel.heading:SetPoint("TOPLEFT", SIDEBAR + 20, -12)
  panel.subheading = UI.Label(panel, "", "MutedSmall")
  panel.subheading:SetPoint("TOPLEFT", panel.heading, "BOTTOMLEFT", 0, -4)
  local rule = panel:CreateTexture(nil, "BORDER")
  rule:SetPoint("TOPLEFT", SIDEBAR, -HEADER)
  rule:SetPoint("TOPRIGHT", 0, -HEADER)
  rule:SetHeight(1)
  rule:SetColorTexture(C.line[1], C.line[2], C.line[3], 1)
  local close = UI.CloseButton(panel)
  close:SetSize(26, 26)
  close:SetPoint("TOPRIGHT", -12, -13)

  -- One page per tab, all the same size.
  for _, t in ipairs(UI.tabs) do
    local page = CreateFrame("Frame", nil, panel)
    page:SetPoint("TOPLEFT", SIDEBAR + 10, -HEADER - 8)
    page:SetPoint("BOTTOMRIGHT", -10, 10)
    page:Hide()
    t.page = page
    t.build(page)
  end

  panel:SetScript("OnShow", function()
    PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN)
    ns.RequestRoster()
    UpdateTabVisibility()
    ns.RefreshPanel()
  end)
  panel:SetScript("OnHide", function() PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE) end)

  -- Open on the tab used last time.
  local start = 1
  for i, t in ipairs(UI.tabs) do
    if t.id == ns.db.lastTab then start = i end
  end
  UpdateTabVisibility()
  ShowTab(start)
end

function ns.RefreshPanel()
  if not (panel and panel:IsShown()) then return end
  UpdateTabVisibility()
  setHeader()
  local t = UI.tabs[current]
  if t and t.refresh then t.refresh(t.page) end
end

-- The window holds secure buttons, so it can't be opened, moved or closed
-- during combat. It closes when combat starts and reopens afterwards.
local reopenAfterCombat = false

local function blockedByCombat()
  if InCombatLockdown() then
    ns.Say("Guild tools can't be opened during combat.")
    return true
  end
end

function ns.TogglePanel()
  if blockedByCombat() then return end
  if not panel then CreatePanel() end
  panel:SetShown(not panel:IsShown())
end

-- tab: a tab's position, or its id ("kills", "settings", ...).
function ns.OpenPanel(tab)
  if blockedByCombat() then return end
  if not panel then CreatePanel() end
  local index = tonumber(tab) or 1
  if type(tab) == "string" then
    for i, t in ipairs(UI.tabs) do
      if t.id == tab then index = i break end
    end
  end
  panel:Show()
  ShowTab(index)
end

ns.OnEvent("PLAYER_REGEN_DISABLED", function()
  if panel and panel:IsShown() then
    reopenAfterCombat = true
    panel:Hide()
  end
end)

ns.OnEvent("PLAYER_REGEN_ENABLED", function()
  if reopenAfterCombat and panel then
    reopenAfterCombat = false
    panel:Show()
  end
end)

------------------------------------------------------------------------
-- Entry in Esc > Options > AddOns
------------------------------------------------------------------------
ns.OnLoad(function()
  if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then
    return
  end
  local canvas = CreateFrame("Frame")

  local icon = canvas:CreateTexture(nil, "ARTWORK")
  icon:SetSize(56, 56)
  icon:SetPoint("TOPLEFT", 16, -16)
  icon:SetTexture(ICON)

  local title = UI.Label(canvas, ns.COLOR .. "The Imperium|r", "GameFontNormalHuge")
  title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 12, -2)
  local sub = UI.Label(canvas, "Official guild addon  -  version " .. (ns.version or "?"), "GameFontHighlightSmall")
  sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)

  local desc = UI.Label(canvas, "PvP kill and level-up alerts, raid sign-ups and DKP for the whole guild, plus roster tools "
    .. "and an activity log for officers. Everything lives in the guild tools window.", "GameFontHighlight")
  desc:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", 0, -20)
  desc:SetWidth(520)

  local open = UI.Button(canvas, "Open Guild Tools", 180)
  open:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -16)
  open:SetScript("OnClick", function()
    if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
    ns.OpenPanel("roster")
  end)

  local hint = UI.Label(canvas, "You can also type /imperium or click The Imperium in the addons menu by the minimap.",
    "GameFontDisableSmall")
  hint:SetPoint("TOPLEFT", open, "BOTTOMLEFT", 0, -10)

  local minimapCheck = CreateFrame("CheckButton", nil, canvas, "UICheckButtonTemplate")
  minimapCheck:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", -4, -8)
  local minimapLabel = UI.Label(minimapCheck, "Show the minimap button")
  minimapLabel:SetPoint("LEFT", minimapCheck, "RIGHT", 2, 0)
  minimapCheck:SetScript("OnClick", function(self)
    if ns.SetMinimapButtonShown then ns.SetMinimapButtonShown(self:GetChecked() and true or false) end
  end)
  canvas:SetScript("OnShow", function()
    minimapCheck:SetChecked(ns.IsMinimapButtonShown and ns.IsMinimapButtonShown())
  end)
  ns.OnMinimapButtonChanged = function()
    minimapCheck:SetChecked(ns.IsMinimapButtonShown and ns.IsMinimapButtonShown())
  end

  -- The guild artwork, with a thin gold frame.
  local frame = canvas:CreateTexture(nil, "BACKGROUND")
  frame:SetPoint("TOPLEFT", minimapCheck, "BOTTOMLEFT", 2, -10)
  frame:SetSize(324, 324)
  frame:SetColorTexture(0.83, 0.69, 0.22, 0.9)
  local art = canvas:CreateTexture(nil, "ARTWORK")
  art:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
  art:SetSize(320, 320)
  art:SetTexture(ns.ARTWORK)

  local category = Settings.RegisterCanvasLayoutCategory(canvas, "The Imperium")
  Settings.RegisterAddOnCategory(category)
  ns.optionsCategory = category
end)
