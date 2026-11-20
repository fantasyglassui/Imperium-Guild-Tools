--[[
  Warcrest
  Map pins: marks guild deaths on the world map with an X (a skull for PvP),
  for as long as the "Keep marks for" setting says (1 hour to 7 days), and
  wanted player sightings with a purple diamond for 30 minutes.

  Where the guild fights: circles where guild members killed enemy players or
  died to them in the last 7 days, grouped into areas of the map shown.
  Bigger for more fights; gold where we won more, red where we lost more.

  Pins use Blizzard's own world map pin system, so they show on the normal
  world map and inside map addons built on it, such as OpenMap. Hover a pin
  for details; click it to set a TomTom waypoint if TomTom is installed.
]]

local _, ns = ...
local Ambiguate = ns.Ambiguate

local TEMPLATE = "WarcrestDeathPinTemplate"
local MAX_PINS = 100
local SIGHTING_AGE = 30 * 60 -- wanted sightings stay on the map for 30 minutes
local X_ICON = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_7"
local SKULL_ICON = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8"
local SIGHTING_ICON = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_3"
local FIGHT_ICON = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask" -- a plain round spot
local FIGHT_DAYS = 7
local GRID_X, GRID_Y = 18, 12 -- areas of the map fights are grouped into

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
  self.Icon:SetVertexColor(1, 1, 1, 1)
  self:SetSize(18, 18)
  if entry.fights then
    -- An area where the guild fought: size by how many fights, colour by who won.
    local n = entry.kills + entry.deaths
    local size = math.min(44, 14 + n * 3)
    self:SetSize(size, size)
    self.Icon:SetTexture(FIGHT_ICON)
    if entry.kills > entry.deaths then
      self.Icon:SetVertexColor(0.88, 0.73, 0.3, 0.6)
    elseif entry.deaths > entry.kills then
      self.Icon:SetVertexColor(0.95, 0.3, 0.3, 0.6)
    else
      self.Icon:SetVertexColor(1, 0.55, 0.23, 0.6)
    end
    self:SetPosition(x, y)
    return
  end
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
  if e.fights then
    GameTooltip:AddLine(ns.TF("Guild fights here, last %d days:", FIGHT_DAYS), 1, 1, 1)
    GameTooltip:AddLine(ns.TF("We killed %d; we lost %d.", e.kills, e.deaths), 0.9, 0.8, 0.5)
    if e.topName then GameTooltip:AddLine(ns.TF("Most killed here: %s (%d)", e.topName, e.topN), 0.7, 0.7, 0.7) end
    if e.worstName then GameTooltip:AddLine(ns.TF("Killed us most here: %s (%d)", e.worstName, e.worstN), 0.7, 0.7, 0.7) end
    GameTooltip:Show()
    return
  end
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
  if e and not e.fights and TomTom and TomTom.AddWaypoint then
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
    -- Where the guild fights: kills and PvP deaths, grouped into areas of this map.
    if ns.db.fightMap then
      local since, cells = time() - FIGHT_DAYS * 86400, {}
      local function add(e, isKill, enemy)
        local x, y = positionOn(e, mapID)
        if not x then return end
        local cx, cy = math.min(GRID_X - 1, math.floor(x * GRID_X)), math.min(GRID_Y - 1, math.floor(y * GRID_Y))
        local id = cx .. ":" .. cy
        local c = cells[id]
        if not c then
          c = { fights = true, kills = 0, deaths = 0, sx = 0, sy = 0, killed = {}, killers = {} }
          cells[id] = c
        end
        c.sx, c.sy = c.sx + x, c.sy + y
        if isKill then
          c.kills = c.kills + 1
          c.killed[enemy] = (c.killed[enemy] or 0) + 1
        else
          c.deaths = c.deaths + 1
          c.killers[enemy] = (c.killers[enemy] or 0) + 1
        end
      end
      for _, k in ipairs(ns.db.killLog or {}) do
        if k.t < since then break end -- newest first
        if k.mapID and not ns.KillHidden(k) then add(k, true, k.victim) end
      end
      for _, d in ipairs(ns.db.deathLog) do
        if d.t < since then break end
        if d.mapID and d.kind == "pvp" and d.killer and d.killer ~= "" then add(d, false, Ambiguate(d.killer, "short")) end
      end
      local function most(t)
        local name, n = nil, 0
        for k, v in pairs(t) do if v > n then name, n = k, v end end
        return name, n
      end
      for _, c in pairs(cells) do
        local n = c.kills + c.deaths
        c.topName, c.topN = most(c.killed)
        c.worstName, c.worstN = most(c.killers)
        self:GetMap():AcquirePin(TEMPLATE, c, c.sx / n, c.sy / n)
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
