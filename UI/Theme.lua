--[[
  Warcrest
  Theme: the "Nightwatch" look. Colors, fonts and icons shared by every
  window. Dark and flat, with one gold accent.

  Text styles: labels ask for the game's usual styles (GameFontNormalLarge
  and so on) and get the matching Warcrest style instead, so tabs don't
  need to know about the theme.
]]

local _, ns = ...
local UI = ns.UI or {}
ns.UI = UI

local MEDIA = "Interface\\AddOns\\Warcrest\\Media\\"

local function hex(h)
  return tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255
end

-- Colors as { r, g, b }.
UI.C = {
  window    = { hex("0d1118") }, -- the panel
  sidebar   = { hex("090c12") }, -- the side menu
  card      = { hex("11161e") }, -- lists and grouped controls
  cardEdge  = { hex("1f2632") },
  control   = { hex("151a23") }, -- buttons and inputs
  controlHi = { hex("1c2230") }, -- a control under the mouse
  edge      = { hex("232a36") }, -- borders of controls and the window
  line      = { hex("1c222c") }, -- dividers
  text      = { hex("f2f4f8") }, -- headings and values
  textSoft  = { hex("c9cfda") }, -- body text
  muted     = { hex("8b95a7") }, -- secondary text
  faint     = { hex("6b7587") }, -- labels and hints
  navText   = { hex("a3acbc") }, -- side menu items
  accent    = { hex("e0b94c") }, -- Warcrest gold
  onAccent  = { hex("14110a") }, -- text on gold
  good      = { hex("6fd08c") },
  warn      = { hex("ffad33") },
  bad       = { hex("ff6b6b") },
}
UI.GOLD = UI.C.accent

-- Color codes for text: UI.Code("accent") .. "Gold text|r"
function UI.Code(name)
  local c = UI.C[name]
  return ("|cff%02x%02x%02x"):format(math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5))
end

------------------------------------------------------------------------
-- Fonts
------------------------------------------------------------------------
local FONT = {
  regular = MEDIA .. "Fonts\\Inter-Regular.ttf",
  semibold = MEDIA .. "Fonts\\Inter-SemiBold.ttf",
  bold = MEDIA .. "Fonts\\Inter-Bold.ttf",
}

UI.Fonts = {}
local function makeFont(key, weight, size, color)
  local f = CreateFont("WarcrestFont_" .. key)
  -- If the font file can't be loaded, fall back to the game's font. (Newer
  -- clients return false on failure; older ones return nothing either way.)
  if f:SetFont(FONT[weight], size, "") == false then
    f:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size, "")
  end
  f:SetTextColor(color[1], color[2], color[3])
  f:SetShadowOffset(0, 0)
  UI.Fonts[key] = f
  return f
end

makeFont("Title", "bold", 17, UI.C.text)        -- the header of the panel
makeFont("Display", "bold", 22, UI.C.text)      -- big figures, like this month's leader
makeFont("Brand", "bold", 13, UI.C.text)        -- the addon's name in the side menu
makeFont("Heading", "bold", 13, UI.C.text)      -- section headings
makeFont("Subheading", "semibold", 12, UI.C.text)
makeFont("Body", "regular", 12, UI.C.textSoft)
makeFont("Small", "regular", 11, UI.C.textSoft)
makeFont("Label", "semibold", 10, UI.C.faint)   -- names of fields and columns
makeFont("Muted", "regular", 12, UI.C.muted)
makeFont("MutedSmall", "regular", 10, UI.C.muted)
makeFont("Button", "semibold", 11, UI.C.text)
makeFont("ButtonDisabled", "semibold", 11, UI.C.faint)
makeFont("ButtonAccent", "bold", 11, UI.C.onAccent)
makeFont("Nav", "semibold", 12, UI.C.navText)
makeFont("NavActive", "semibold", 12, UI.C.accent)
makeFont("Number", "bold", 12, UI.C.text)

-- The game's text styles, and the Warcrest style each one becomes.
UI.FONT_FOR = {
  GameFontNormalHuge = "Title",
  GameFontNormalLarge = "Heading",
  GameFontNormalMed3 = "Heading",
  GameFontNormal = "Subheading",
  GameFontNormalSmall = "Label",
  GameFontHighlightLarge = "Heading",
  GameFontHighlight = "Body",
  GameFontHighlightMedium = "Body",
  GameFontHighlightSmall = "Small",
  GameFontDisable = "Muted",
  GameFontDisableSmall = "MutedSmall",
  GameFontDisableLarge = "Muted",
}

-- A font object for a style name (Warcrest or game).
function UI.Font(name)
  return UI.Fonts[name] or UI.Fonts[UI.FONT_FOR[name] or ""] or UI.Fonts.Body
end

------------------------------------------------------------------------
-- Icons: white shapes, tinted with SetVertexColor
------------------------------------------------------------------------
function UI.IconPath(name) return MEDIA .. "Icons\\" .. name end

function UI.Icon(parent, name, size, color)
  local t = parent:CreateTexture(nil, "ARTWORK")
  t:SetTexture(UI.IconPath(name))
  t:SetSize(size or 14, size or 14)
  color = color or UI.C.text
  t:SetVertexColor(color[1], color[2], color[3])
  return t
end

------------------------------------------------------------------------
-- Painting frames
------------------------------------------------------------------------
-- A solid fill behind a frame's other textures.
function UI.Fill(frame, color, alpha, layer)
  local t = frame:CreateTexture(nil, layer or "BACKGROUND")
  t:SetAllPoints()
  t:SetColorTexture(color[1], color[2], color[3], alpha or 1)
  return t
end

-- A 1-pixel border, outside the frame's edges by pad. Returns an object
-- whose SetColor(r, g, b, a) recolors all four sides.
function UI.Border(frame, r, g, b, a, pad)
  pad = pad or 0
  local o = pad + 1
  -- Each side: two corners along one edge, and 1 pixel thick the other way.
  local edges = {
    { "TOPLEFT", -o, o, "TOPRIGHT", o, o, "height" },             -- top
    { "BOTTOMLEFT", -o, -o, "BOTTOMRIGHT", o, -o, "height" },     -- bottom
    { "TOPLEFT", -o, pad, "BOTTOMLEFT", -o, -pad, "width" },      -- left
    { "TOPRIGHT", o, pad, "BOTTOMRIGHT", o, -pad, "width" },      -- right
  }
  local border = { sides = {} }
  for i, e in ipairs(edges) do
    local t = frame:CreateTexture(nil, "BORDER")
    t:SetPoint(e[1], frame, e[1], e[2], e[3])
    t:SetPoint(e[4], frame, e[4], e[5], e[6])
    if e[7] == "height" then t:SetHeight(1) else t:SetWidth(1) end
    t:SetColorTexture(r, g, b, a)
    border.sides[i] = t
  end
  function border:SetColor(r2, g2, b2, a2)
    for _, t in ipairs(self.sides) do t:SetColorTexture(r2, g2, b2, a2 or 1) end
  end
  return border
end

-- A card: the dark grouped background used for lists and sections.
function UI.Card(frame, pad)
  local bg = frame:CreateTexture(nil, "BACKGROUND")
  bg:SetPoint("TOPLEFT", -(pad or 0), pad or 0)
  bg:SetPoint("BOTTOMRIGHT", pad or 0, -(pad or 0))
  bg:SetColorTexture(UI.C.card[1], UI.C.card[2], UI.C.card[3], 1)
  local c = UI.C.cardEdge
  return UI.Border(frame, c[1], c[2], c[3], 1, pad or 0)
end
