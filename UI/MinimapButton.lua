--[[
  Bannerhold
  Minimap button: the guild emblem on the edge of the minimap.
    Left-click   open or close guild tools
    Right-click  open Settings
    Shift-click  open Kills
    Drag         move it around the minimap
  Hide it with /bannerhold minimap or on the Options page.
]]

local _, ns = ...

local SETTINGS_TAB = "settings"
local KILLS_TAB = "kills"
local button

local atan2 = math.atan2 or math.atan

local function settings()
  ns.db.minimap = ns.db.minimap or {}
  local m = ns.db.minimap
  if m.angle == nil then m.angle = 210 end
  if m.hide == nil then m.hide = false end
  return m
end

-- Place the button on the edge of the minimap, round or square.
local function place()
  local angle = math.rad(settings().angle)
  local x, y = math.cos(angle), math.sin(angle)
  local shape = GetMinimapShape and GetMinimapShape() or "ROUND"
  local radius = Minimap:GetWidth() / 2 + 5
  if shape == "SQUARE" then
    local m = math.max(math.abs(x), math.abs(y))
    x, y = x / m, y / m
    radius = Minimap:GetWidth() / 2 + 2
  end
  button:ClearAllPoints()
  button:SetPoint("CENTER", Minimap, "CENTER", x * radius, y * radius)
end

local function onDragUpdate()
  local mx, my = Minimap:GetCenter()
  local px, py = GetCursorPosition()
  local scale = Minimap:GetEffectiveScale()
  px, py = px / scale, py / scale
  settings().angle = math.deg(atan2(py - my, px - mx)) % 360
  place()
end

local function showTooltip(self)
  GameTooltip:SetOwner(self, "ANCHOR_LEFT")
  GameTooltip:SetText(ns.ICON_TEXT .. " " .. ns.COLOR .. ns.BRAND .. "|r")
  GameTooltip:AddLine("Left-click: guild tools", 1, 1, 1)
  GameTooltip:AddLine("Right-click: alert settings", 1, 1, 1)
  GameTooltip:AddLine("Shift-click: kills", 1, 1, 1)
  GameTooltip:AddLine("Drag to move", 0.6, 0.6, 0.6)
  GameTooltip:Show()
end

local function create()
  if button or not Minimap then return end
  button = CreateFrame("Button", "BannerholdMinimapButton", Minimap)
  button:SetSize(31, 31)
  button:SetFrameStrata("MEDIUM")
  button:SetFrameLevel(8)
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:RegisterForDrag("LeftButton")
  button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  -- The standard round minimap button look, with the guild emblem inside.
  local background = button:CreateTexture(nil, "BACKGROUND")
  background:SetSize(20, 20)
  background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  background:SetPoint("TOPLEFT", 7, -5)

  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetSize(19, 19)
  ns.Emblem(icon, "ICON")
  icon:SetPoint("TOPLEFT", 6, -5)
  button.icon = icon

  local border = button:CreateTexture(nil, "OVERLAY")
  border:SetSize(53, 53)
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetPoint("TOPLEFT")

  button:SetScript("OnClick", function(_, mouseButton)
    if mouseButton == "RightButton" then
      ns.OpenPanel(SETTINGS_TAB)
    elseif IsShiftKeyDown() then
      ns.OpenPanel(KILLS_TAB)
    else
      ns.TogglePanel()
    end
  end)
  button:SetScript("OnMouseDown", function() icon:SetPoint("TOPLEFT", 7, -6) end)
  button:SetScript("OnMouseUp", function() icon:SetPoint("TOPLEFT", 6, -5) end)
  button:SetScript("OnDragStart", function(self)
    GameTooltip:Hide()
    self:SetScript("OnUpdate", onDragUpdate)
  end)
  button:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
    icon:SetPoint("TOPLEFT", 6, -5)
  end)
  button:SetScript("OnEnter", showTooltip)
  button:SetScript("OnLeave", function() GameTooltip:Hide() end)

  place()
  button:SetShown(not settings().hide)
end

function ns.SetMinimapButtonShown(show)
  settings().hide = not show
  create()
  if button then button:SetShown(show) end
  if ns.OnMinimapButtonChanged then ns.OnMinimapButtonChanged() end
end

function ns.IsMinimapButtonShown()
  return not settings().hide
end

ns.OnLoad(create)
ns.OnEvent("PLAYER_LOGIN", function()
  create()
  if button then place() end -- the minimap may have changed size or shape since load
end)
