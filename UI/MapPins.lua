--[[
  Warcrest
  Map pins: marks guild deaths on the world map with an X (a skull for PvP),
  for as long as the "Keep marks for" setting says (1 hour to 7 days), and
  wanted player sightings with a purple diamond for 30 minutes.

  Pins use Blizzard's own world map pin system, so they show on the normal
  world map and inside map addons built on it, such as OpenMap. Hover a pin
  for details; click it to set a TomTom waypoint if TomTom is installed.
]]

local _, ns = ...

local TEMPLATE = "WarcrestDeathPinTemplate"
local MAX_PINS = 100
local SIGHTING_AGE = 30 * 60 -- wanted sightings stay on the map for 30 minutes
local X_ICON = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_7"
local SKULL_ICON = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8"
local SIGHTING_ICON = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_3"

-- The pin template (UI\MapPins.xml) names this mixin. Blizzard's base pin
-- code is mixed in once the world map has loaded.
WarcrestDeathPinMixin = WarcrestDeathPinMixin or {}
local pinMethods = {}
local provider

------------------------------------------------------------------------
-- Positions across maps
------------------------------------------------------------------------
-- Where a death sits on another map (its zone, the continent, the world).
local function positionOn(e, mapID)
  if e.mapID == mapID then return e.x, e.y end
  if not (C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D) then return end
  local ok, continent, worldPos = pcall(C_Map.GetWorldPosFromMapPos, e.mapID, CreateVector2D(e.x, e.y))
  if not (ok and continent and worldPos) then return end
  local ok2, _, mapPos = pcall(C_Map.GetMapPosFromWorldPos, continent, worldPos, mapID)
  if not (ok2 and mapPos) then return end
  local x, y = mapPos:GetXY()
  if x and y and x >= 0 and x <= 1 and y >= 0 and y <= 1 then return x, y end
end

------------------------------------------------------------------------
-- The pin
------------------------------------------------------------------------
function pinMethods:OnLoad()
  self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")
  self:SetScalingLimits(1, 1.0, 1.25)
end

function pinMethods:OnAcquired(entry, x, y)
  self.entry = entry
  if entry.by then
    self.Icon:SetTexture(SIGHTING_ICON) -- a wanted player sighting
  else
    self.Icon:SetTexture(ns.PVP_TYPES[entry.kind] and SKULL_ICON or X_ICON)
  end
  self:SetPosition(x, y)
end

function pinMethods:OnMouseEnter()
  local e = self.entry
  if not e then return end
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:SetText(ns.ICON_TEXT .. " " .. ns.COLOR .. ns.BRAND .. "|r")
  if e.by then
    GameTooltip:AddLine(ns.DescribeSighting(e), 1, 0.4, 1, true)
  else
    GameTooltip:AddLine(ns.DeathIcon(e) .. ns.DescribeDeath(e), 1, 1, 1, true)
  end
  GameTooltip:AddLine(ns.Date("%b %d %H:%M", e.t), 0.7, 0.7, 0.7)
  if TomTom and TomTom.AddWaypoint then
    GameTooltip:AddLine("Click to set a TomTom waypoint.", 0.5, 0.8, 1)
  end
  GameTooltip:Show()
end

function pinMethods:OnMouseLeave()
  GameTooltip:Hide()
end

function pinMethods:OnMouseUp(button)
  if button ~= "LeftButton" then return end
  local e = self.entry
  if e and TomTom and TomTom.AddWaypoint then
    local title = e.by and ns.DescribeSighting(e) or ns.DescribeDeath(e)
    pcall(TomTom.AddWaypoint, TomTom, e.mapID, e.x, e.y, {
      title = ns.BRAND .. ": " .. title, persistent = false, minimap = true, world = true,
    })
  end
end

------------------------------------------------------------------------
-- The data provider that places the pins
------------------------------------------------------------------------
local function setUp()
  if provider or not (WorldMapFrame and MapCanvasPinMixin and MapCanvasDataProviderMixin) then return end
  Mixin(WarcrestDeathPinMixin, MapCanvasPinMixin, pinMethods)

  provider = CreateFromMixins(MapCanvasDataProviderMixin)

  function provider:RemoveAllData()
    self:GetMap():RemoveAllPinsByTemplate(TEMPLATE)
  end

  function provider:RefreshAllData()
    self:RemoveAllData()
    if not (ns.db and ns.db.mapPins) then return end
    local mapID = self:GetMap():GetMapID()
    if not mapID then return end
    local cutoff, count = time() - (ns.db.pinHours or 24) * 3600, 0
    for _, e in ipairs(ns.db.deathLog) do
      if e.t < cutoff or count >= MAX_PINS then break end -- the log is newest first
      if e.mapID then
        local x, y = positionOn(e, mapID)
        if x then
          self:GetMap():AcquirePin(TEMPLATE, e, x, y)
          count = count + 1
        end
      end
    end
    -- Recent wanted sightings, newest first, one mark per player.
    local recent, shown = time() - SIGHTING_AGE, {}
    for _, s in ipairs(ns.db.spotted or {}) do
      if s.t < recent then break end
      local k = ns.Key(s.name)
      if s.mapID and not shown[k] then
        local x, y = positionOn(s, mapID)
        if x then
          shown[k] = true
          self:GetMap():AcquirePin(TEMPLATE, s, x, y)
        end
      end
    end
  end

  WorldMapFrame:AddDataProvider(provider)
end

function ns.RefreshMapPins()
  if provider and WorldMapFrame and WorldMapFrame:IsShown() then provider:RefreshAllData() end
end

ns.OnLoad(setUp)
ns.OnEvent("ADDON_LOADED", function(name)
  if name == "Blizzard_WorldMap" or name == "Blizzard_MapCanvas" then setUp() end
end)
ns.OnEvent("PLAYER_LOGIN", setUp)

-- Open the world map at a death's location.
function ns.ShowDeathOnMap(e)
  if not e.mapID then return false end
  if InCombatLockdown() then
    ns.Say("The map can't be opened from here during combat.")
    return false
  end
  if OpenWorldMap then
    OpenWorldMap(e.mapID)
  elseif WorldMapFrame then
    ShowUIPanel(WorldMapFrame)
    WorldMapFrame:SetMapID(e.mapID)
  end
  ns.RefreshMapPins()
  return true
end
