--[[
  Warcrest
  Accessibility (Settings > Accessibility), all off until a player turns them on:
    - Text size: Warcrest's text at 100-120%, without scaling whole windows.
    - Colour-blind friendly colours: alert colours, and good/bad colours, that
      stay apart with red-green or blue-yellow colour blindness (Okabe-Ito).
      Every alert also names its kind in words, so colour is never the only cue.
    - High contrast: brighter secondary text, stronger borders and lines.
    - Alert banners: how long they stay (normal, longer, until dismissed), and
      no slide or fade.
  Colours are set before any window is built, so changing them in a session
  needs a /reload for windows already open; text size and banners change at once.
]]

local _, ns = ...
local UI = ns.UI
local C = UI.C

local function has(list, v)
  for _, x in ipairs(list) do if x == v then return true end end
end

local function hex(h)
  return tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255
end

ns.TEXT_SIZES = { 100, 110, 120 }
ns.BANNER_HOLDS = { "normal", "long", "sticky" }

-- Okabe-Ito colours, lightened a little where they'd be too dark on Warcrest's near-black.
local CB = {
  vermillion = "f0743a", orange = "e69f00", sky = "56b4e9", green = "2fb98f",
  yellow = "f0e442", purple = "cc79a7",
}
local CB_KINDS = {
  kill = "vermillion", death = "purple", wanted = "orange", streak = "yellow", revenge = "vermillion",
  champion = "yellow", bounty = "orange", boss = "yellow", raid = "sky", rival = "orange", event = "green",
  loot = "yellow", achievement = "yellow", celebrate = "sky",
}
-- The theme's own colours in each mode (only the ones that change).
local CB_THEME = { good = CB.sky, bad = CB.vermillion, warn = CB.orange }
local CONTRAST_THEME = {
  textSoft = "e6e9ef", muted = "b6bfcc", faint = "9ca6b6", navText = "ccd3de",
  edge = "434d5e", line = "333b48", cardEdge = "3a4352",
}
-- Chat colours for kills and deaths (normally green and red).
local CB_CHAT = { kill = CB.sky, death = CB.vermillion }

local original = {} -- the theme's colours as shipped, to go back to
for k, c in pairs(C) do original[k] = { c[1], c[2], c[3] } end

function ns.Access()
  local a = ns.db and ns.db.access
  if not a then return { textSize = 100, colorblind = false, contrast = false, bannerHold = "normal", reduceMotion = false } end
  return a
end

-- Text: every Warcrest font at the chosen size, in the theme's (current) colours.
function UI.ApplyFonts()
  local pct = ns.Access().textSize or 100
  for key, base in pairs(UI.FontBase) do
    local f = UI.Fonts[key]
    local size = math.floor(base.size * pct / 100 + 0.5)
    if f:SetFont(UI.FontFile(base.weight), size, "") == false then
      f:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size, "")
    end
    f:SetTextColor(base.color[1], base.color[2], base.color[3])
  end
end

-- Colours: the theme as shipped, then high contrast and colour-blind changes on top.
-- The colour tables are changed in place, so everything built afterwards uses them.
function UI.ApplyColors()
  local a = ns.Access()
  for k, c in pairs(original) do C[k][1], C[k][2], C[k][3] = c[1], c[2], c[3] end
  if a.contrast then
    for k, h in pairs(CONTRAST_THEME) do C[k][1], C[k][2], C[k][3] = hex(h) end
  end
  if a.colorblind then
    for k, h in pairs(CB_THEME) do C[k][1], C[k][2], C[k][3] = hex(h) end
  end
  UI.ApplyFonts()
end

-- An alert kind's colour ({ r, g, b }), or nil to use its usual one.
function ns.AccessKindColor(kind)
  local name = ns.Access().colorblind and CB_KINDS[kind]
  if name then return { hex(CB[name]) } end
end

-- A chat colour code for "kill" or "death", or nil for the usual one.
function ns.AccessChatColor(what)
  local h = ns.Access().colorblind and CB_CHAT[what]
  return h and ("|cff" .. h) or nil
end

-- How long a banner stays: its usual time, twice that, or until it's dismissed (nil).
function ns.BannerHold(seconds)
  local hold = ns.Access().bannerHold
  if hold == "sticky" then return nil end
  if hold == "long" then return seconds * 2 end
  return seconds
end

function ns.ReduceMotion() return ns.Access().reduceMotion == true end

-- Change a setting. Colours need a /reload for windows already built.
function ns.SetAccess(key, value)
  local a = ns.db.access
  if a[key] == value then return end
  a[key] = value
  if key == "textSize" then
    UI.ApplyFonts()
  elseif key == "colorblind" or key == "contrast" then
    UI.ApplyColors()
    ns.Say("Colours changed. Type /reload to see them in every window.")
  end
end

ns.OnLoad(function()
  local a = ns.db.access or {}
  ns.db.access = a
  if not has(ns.TEXT_SIZES, a.textSize) then a.textSize = 100 end
  if not has(ns.BANNER_HOLDS, a.bannerHold) then a.bannerHold = "normal" end
  a.colorblind, a.contrast, a.reduceMotion = a.colorblind == true, a.contrast == true, a.reduceMotion == true
  if a.colorblind or a.contrast or a.textSize ~= 100 then UI.ApplyColors() end
end)
