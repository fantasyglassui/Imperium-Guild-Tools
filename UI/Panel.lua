--[[
  Warcrest
  Panel: the guild tools window and its Options entry.
]]

local _, ns = ...
local UI = ns.UI
local C = UI.C
local panel
local current = 1

local WIDTH, HEIGHT = 910, 520           -- the smallest the window can be
local MAX_WIDTH, MAX_HEIGHT = 1600, 1000
local SIDEBAR = 150   -- width of the side menu
local HEADER = 52     -- height of the header above each tab
local MIN_SCALE, MAX_SCALE = 0.7, 1.5

-- Icon and one-line description for each tab, by its id.
local TAB_INFO = {
  roster = { icon = "roster", text = "Members, notes and ranks" },
  raids = { icon = "raids", text = "Sign-ups, raid nights and invites" },
  events = { icon = "events", text = "PvP nights, world bosses, meetings and more" },
  recruit = { icon = "recruit", text = "Recruits, trials and the recruiting message" },
  dkp = { icon = "dkp", text = "Standings, loot and auctions" },
  wishlist = { icon = "wishlist", text = "The loot the guild wants" },
  kills = { icon = "kills", text = "PvP kills by guild members" },
  achievements = { icon = "trophy", text = "Achievements and titles" },
  wanted = { icon = "wanted", text = "Enemy players who keep killing guild members" },
  settings = { icon = "settings", text = "Alerts for the whole guild, and just for you" },
  officers = { icon = "officers", text = "Guild changes seen while you're online" },
  addon = { icon = "addon", text = "Who has Warcrest installed" },
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
  panel = CreateFrame("Frame", "WarcrestPanel", UIParent)
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
  -- Resizable from the corner, back to the size it was left at.
  panel:SetResizable(true)
  if panel.SetResizeBounds then
    panel:SetResizeBounds(WIDTH, HEIGHT, MAX_WIDTH, MAX_HEIGHT)
  elseif panel.SetMinResize then
    panel:SetMinResize(WIDTH, HEIGHT)
    panel:SetMaxResize(MAX_WIDTH, MAX_HEIGHT)
  end
  panel:SetSize(math.max(WIDTH, math.min(MAX_WIDTH, ns.db.panelWidth or WIDTH)),
    math.max(HEIGHT, math.min(MAX_HEIGHT, ns.db.panelHeight or HEIGHT)))
  panel:SetScale(ns.db.panelScale or 1)
  panel:Hide()
  tinsert(UISpecialFrames, "WarcrestPanel") -- Escape closes it
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
  ns.Emblem(emblem, "PORTRAIT")
  emblem:SetSize(30, 30)
  emblem:SetPoint("TOPLEFT", 14, -16)
  local brand = UI.Label(side, "", "Brand")
  brand:SetPoint("TOPLEFT", emblem, "TOPRIGHT", 9, -1)
  brand:SetWidth(100)
  brand:SetWordWrap(false)
  local sub = UI.Label(side, "", "MutedSmall")
  sub:SetPoint("TOPLEFT", brand, "BOTTOMLEFT", 0, -3)
  sub:SetWidth(100)
  sub:SetWordWrap(false)
  panel.brand, panel.brandSub = brand, sub
  -- The Imperium: its own name, as before. Other guilds: Warcrest, with the guild's name under it.
  ns.OnLook(function()
    brand:SetText(ns.BRAND)
    sub:SetText(ns.look == "imperium" and "Guild Tools" or (ns.GuildName() or "Guild tools"))
  end)

  panel.navButtons = {}
  for i, t in ipairs(UI.tabs) do
    panel.navButtons[i] = MakeNavButton(side, i, t)
  end

  local version = UI.Label(side, "v" .. (ns.version or "?"), "MutedSmall")
  version:SetPoint("BOTTOMLEFT", 16, 12)
  -- Help, at the bottom of the side menu.
  local help = CreateFrame("Button", nil, side)
  help:SetSize(SIDEBAR - 20, 30)
  help:SetPoint("BOTTOMLEFT", 10, 30)
  local hover = help:CreateTexture(nil, "HIGHLIGHT")
  hover:SetAllPoints()
  hover:SetColorTexture(1, 1, 1, 0.04)
  local q = UI.Label(help, "?", "Subheading")
  q:SetPoint("LEFT", 9, 0)
  q:SetTextColor(C.navText[1], C.navText[2], C.navText[3])
  local hl = UI.Label(help, "Help", "Nav")
  hl:SetPoint("LEFT", 32, 0)
  help:SetScript("OnClick", function() if ns.ShowHelp then ns.ShowHelp() end end)

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

  -- The corner handle for resizing.
  local grip = CreateFrame("Button", nil, panel)
  grip:SetSize(16, 16)
  grip:SetPoint("BOTTOMRIGHT", -3, 3)
  grip:SetFrameLevel(panel:GetFrameLevel() + 20)
  local gripIcon = UI.Icon(grip, "grip", 16, C.faint)
  gripIcon:SetAllPoints()
  grip:SetScript("OnEnter", function() gripIcon:SetVertexColor(C.accent[1], C.accent[2], C.accent[3]) end)
  grip:SetScript("OnLeave", function() gripIcon:SetVertexColor(C.faint[1], C.faint[2], C.faint[3]) end)
  grip:SetScript("OnMouseDown", function() panel:StartSizing("BOTTOMRIGHT") end)
  grip:SetScript("OnMouseUp", function()
    panel:StopMovingOrSizing()
    ns.db.panelWidth, ns.db.panelHeight = math.floor(panel:GetWidth() + 0.5), math.floor(panel:GetHeight() + 0.5)
  end)

  -- One page per tab, all the same size.
  for _, t in ipairs(UI.tabs) do
    local page = CreateFrame("Frame", nil, panel)
    page:SetPoint("TOPLEFT", SIDEBAR + 10, -HEADER - 8)
    page:SetPoint("BOTTOMRIGHT", -10, 10)
    page:Hide()
    -- Room in the header, left of the close button, for the tab's own controls
    -- (shown and hidden with the tab). Anchor them to its right edge.
    page.headerBar = CreateFrame("Frame", nil, page)
    page.headerBar:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -46, -13)
    page.headerBar:SetSize(520, 26)
    t.page = page
    t.build(page)
    -- A bigger window: the tab's lists stretch and what's below them moves down.
    page:SetScript("OnSizeChanged", function(self, w, h) UI.ApplyGrowth(self, w, h) end)
    UI.ApplyGrowth(page, panel:GetWidth() - SIDEBAR - 20, panel:GetHeight() - HEADER - 18)
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

-- Window size setting: scales the guild window and its pop-ups (text and all).
function ns.SetPanelScale(scale)
  scale = math.max(MIN_SCALE, math.min(MAX_SCALE, scale or 1))
  ns.db.panelScale = scale
  if panel then panel:SetScale(scale) end
  for _, w in ipairs(UI.windows) do w:SetScale(scale) end
end

-- Back to the normal size, in the middle of the screen.
function ns.ResetPanelSize()
  ns.db.panelWidth, ns.db.panelHeight = nil, nil
  ns.SetPanelScale(1)
  if panel then
    panel:SetSize(WIDTH, HEIGHT)
    panel:ClearAllPoints()
    panel:SetPoint("CENTER")
  end
end

function ns.RefreshPanel()
  if ns.RefreshPlayerCard then ns.RefreshPlayerCard() end
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
    ns.Say("Warcrest can't be opened during combat.")
    return true
  end
end

function ns.TogglePanel()
  if blockedByCombat() then return end
  if not panel then CreatePanel() end
  panel:SetShown(not panel:IsShown())
end

-- tab: a tab's position, or its id ("kills", "settings", ...).
-- tab: a tab's id or number. view: for tabs with views switched at the top
-- (a UI.Segmented saved as tab.view once built), which one to show.
function ns.OpenPanel(tab, view)
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
  local t = UI.tabs[index]
  if view and t and t.view then
    t.view:SetValue(view)
    ns.RefreshPanel()
  end
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
  ns.Emblem(icon, "PORTRAIT")

  local title = UI.Label(canvas, "", "GameFontNormalHuge")
  ns.OnLook(function() title:SetText(ns.COLOR .. ns.BRAND .. "|r") end)
  title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 12, -2)
  local sub = UI.Label(canvas, "Guild tools  -  version " .. (ns.version or "?"), "GameFontHighlightSmall")
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

  local hint = UI.Label(canvas, "You can also type /warcrest (or /wc) or click Warcrest in the addons menu by the minimap.",
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

  -- The artwork, with a thin gold frame.
  local frame = canvas:CreateTexture(nil, "BACKGROUND")
  frame:SetPoint("TOPLEFT", minimapCheck, "BOTTOMLEFT", 2, -10)
  frame:SetSize(324, 324)
  frame:SetColorTexture(0.83, 0.69, 0.22, 0.9)
  local art = canvas:CreateTexture(nil, "ARTWORK")
  art:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
  art:SetSize(320, 320)
  ns.Emblem(art, "ARTWORK")

  local category = Settings.RegisterCanvasLayoutCategory(canvas, "Warcrest")
  Settings.RegisterAddOnCategory(category)
  ns.optionsCategory = category
end)
