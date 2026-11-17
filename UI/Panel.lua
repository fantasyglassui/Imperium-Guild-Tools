--[[
  The Imperium
  Panel: the guild tools window and its Options entry.
]]

local _, ns = ...
local UI = ns.UI
local ICON = ns.PORTRAIT
local panel
local current = 1

local function tabVisible(i)
  local t = UI.tabs[i]
  return not t.visible or t.visible()
end

local function ShowTab(id)
  if not tabVisible(id) then id = 1 end
  current = id
  for i, t in ipairs(UI.tabs) do t.page:SetShown(i == id) end
  if panel.realTabs and PanelTemplates_SetTab then
    PanelTemplates_SetTab(panel, id)
  else
    for i, tab in ipairs(panel.tabButtons) do tab:SetEnabled(i ~= id) end
  end
  ns.RefreshPanel()
end

local function UpdateTabVisibility()
  for i, tab in ipairs(panel.tabButtons) do tab:SetShown(tabVisible(i)) end
  if not tabVisible(current) then ShowTab(1) end
end

local function MakeTab(id, text)
  local ok, tab = pcall(CreateFrame, "Button", "TheImperiumPanelTab" .. id, panel, "PanelTabButtonTemplate")
  if not ok then tab = UI.Button(panel, text, 120) end
  tab:SetID(id)
  tab:SetText(text)
  if ok and PanelTemplates_TabResize then PanelTemplates_TabResize(tab, 0) end
  tab:SetScript("OnClick", function()
    PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
    ShowTab(id)
  end)
  return tab, ok
end

local function CreatePanel()
  local ok, f = pcall(CreateFrame, "Frame", "TheImperiumPanel", UIParent, "ButtonFrameTemplate")
  if not ok then
    f = CreateFrame("Frame", "TheImperiumPanel", UIParent, "BasicFrameTemplateWithInset")
  end
  panel = f
  panel:SetSize(760, 520)
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

  local title = ns.COLOR .. "The Imperium|r  -  Guild Tools"
  if panel.SetTitle then
    panel:SetTitle(title)
  elseif panel.TitleText then
    panel.TitleText:SetText(title)
  end
  if panel.SetPortraitToAsset then
    panel:SetPortraitToAsset(ICON)
  elseif panel.SetPortraitTextureRaw then
    panel:SetPortraitTextureRaw(ICON)
  end

  panel.tabButtons = {}
  for i, t in ipairs(UI.tabs) do
    local page = CreateFrame("Frame", nil, panel)
    page:SetPoint("TOPLEFT", 10, -66)
    page:SetPoint("BOTTOMRIGHT", -10, 28)
    page:Hide()
    t.page = page
    t.build(page)

    local tab, real = MakeTab(i, t.title)
    panel.tabButtons[i] = tab
    panel.realTabs = real
    if real then
      if i == 1 then
        tab:SetPoint("TOPLEFT", panel, "BOTTOMLEFT", 12, 2)
      else
        tab:SetPoint("LEFT", panel.tabButtons[i - 1], "RIGHT", -16, 0)
      end
    else
      if i == 1 then
        tab:SetPoint("TOPLEFT", 70, -32)
      else
        tab:SetPoint("LEFT", panel.tabButtons[i - 1], "RIGHT", 6, 0)
      end
    end
  end
  if panel.realTabs then
    panel.Tabs = panel.tabButtons
    if PanelTemplates_SetNumTabs then PanelTemplates_SetNumTabs(panel, #UI.tabs) end
  end

  local version = UI.Label(panel, "v" .. (ns.version or "?"), "GameFontDisableSmall")
  version:SetPoint("BOTTOMRIGHT", -12, 8)

  panel:SetScript("OnShow", function()
    PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN)
    ns.RequestRoster()
    UpdateTabVisibility()
    ns.RefreshPanel()
  end)
  panel:SetScript("OnHide", function() PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE) end)
  ShowTab(1)
end

function ns.RefreshPanel()
  if not (panel and panel:IsShown()) then return end
  UpdateTabVisibility()
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
