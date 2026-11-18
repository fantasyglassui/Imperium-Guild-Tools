--[[
  The Imperium
  DKP tools: the Alts window (linking alts to a main) and the Import window
  (officers setting starting balances).
]]

local _, ns = ...
local UI = ns.UI

local function Window(name, title, width, height)
  return UI.Window(name, width, height, title)
end

------------------------------------------------------------------------
-- Alts
------------------------------------------------------------------------
local alts

local function RefreshAlts()
  if not (alts and alts:IsShown()) then return end
  local me = UnitName("player")
  local main = ns.MainOf(me)
  local lines = {}

  if ns.Key(main) ~= ns.Key(me) then
    lines[#lines + 1] = ("This character is an alt of %s%s|r. Its DKP and attendance count toward %s."):format(ns.COLOR, main, main)
  else
    local mine = ns.AltsOf(me)
    lines[#lines + 1] = #mine > 0 and ("Your alts: " .. table.concat(mine, ", "))
      or "|cff8b95a7This character has no alts linked.|r"
  end
  local asked = ns.MyAltRequest()
  if asked then
    lines[#lines + 1] = ("|cffe0b94cWaiting for %s to confirm. Log in on %s and open this window.|r"):format(asked, asked)
  end
  alts.status:SetText(table.concat(lines, "\n\n"))

  local requests = ns.PendingAltRequests()
  alts.requestText:SetText(#requests > 0 and ("|cffe0b94c%s asked to be linked as your alt.|r"):format(requests[1]) or "")
  alts.confirm:SetShown(#requests > 0)
  alts.decline:SetShown(#requests > 0)
  alts.confirm.alt = requests[1]

  local isAlt = ns.Key(main) ~= ns.Key(me)
  alts.unlink:SetShown(isAlt)
  alts.officer:SetShown(ns.IsAddonOfficer())
end

ns.OnLedgerChanged(function() C_Timer.After(0.6, RefreshAlts) end)

function ns.ShowAltsWindow()
  if not alts then
    local f = Window("TheImperiumAlts", "Alts", 420, 330)
    alts = f

    f.status = UI.Label(f, "", "GameFontHighlight")
    f.status:SetPoint("TOPLEFT", 16, -34)
    f.status:SetWidth(388)

    UI.Label(f, "Link this character as an alt of:", "GameFontNormalSmall"):SetPoint("TOPLEFT", 16, -104)
    f.mainBox = UI.EditBox(f, 140, 40)
    f.mainBox:SetPoint("TOPLEFT", 22, -118)
    local ask = UI.Button(f, "Ask to link", 100)
    ask:SetPoint("LEFT", f.mainBox, "RIGHT", 8, 0)
    ask:SetScript("OnClick", function()
      ns.RequestAltLink(f.mainBox:GetText())
      f.mainBox:SetText("")
      f.mainBox:ClearFocus()
    end)
    local how = UI.Label(f, "Then log in on your main and confirm it here. Linking needs both characters, so only "
      .. "you can link your own alts.", "GameFontDisableSmall")
    how:SetPoint("TOPLEFT", 16, -142)
    how:SetWidth(388)

    f.requestText = UI.Label(f, "", "GameFontHighlight")
    f.requestText:SetPoint("TOPLEFT", 16, -174)
    f.confirm = UI.Button(f, "Confirm", 90, "primary")
    f.confirm:SetPoint("TOPLEFT", 16, -192)
    f.confirm:SetScript("OnClick", function(self) if self.alt then ns.ConfirmAlt(self.alt) end end)
    f.decline = UI.Button(f, "Decline", 90)
    f.decline:SetPoint("LEFT", f.confirm, "RIGHT", 6, 0)
    f.decline:SetScript("OnClick", function()
      if f.confirm.alt then ns.UnlinkAlt(f.confirm.alt) end
    end)

    f.unlink = UI.Button(f, "Unlink this alt", 120)
    f.unlink:SetPoint("TOPRIGHT", -16, -100)
    f.unlink:SetScript("OnClick", function() ns.UnlinkAlt(UnitName("player")) end)

    -- Officers can link or unlink any alt directly.
    local o = CreateFrame("Frame", nil, f)
    o:SetPoint("TOPLEFT", 0, -226)
    o:SetPoint("BOTTOMRIGHT")
    f.officer = o
    UI.Label(o, "Officers: link any alt", "GameFontNormalSmall"):SetPoint("TOPLEFT", 16, 0)
    UI.Label(o, "Alt", "GameFontDisableSmall"):SetPoint("TOPLEFT", 16, -18)
    local altBox = UI.EditBox(o, 110, 40)
    altBox:SetPoint("TOPLEFT", 22, -32)
    UI.Label(o, "Main", "GameFontDisableSmall"):SetPoint("TOPLEFT", 144, -18)
    local mainBox = UI.EditBox(o, 110, 40)
    mainBox:SetPoint("TOPLEFT", 150, -32)
    local link = UI.Button(o, "Link", 60)
    link:SetPoint("LEFT", mainBox, "RIGHT", 8, 0)
    link:SetScript("OnClick", function()
      ns.OfficerLinkAlt(altBox:GetText(), mainBox:GetText())
      altBox:SetText(""); mainBox:SetText("")
    end)
    local unlink = UI.Button(o, "Unlink", 64)
    unlink:SetPoint("LEFT", link, "RIGHT", 4, 0)
    unlink:SetScript("OnClick", function()
      local alt = strtrim(altBox:GetText() or "")
      if alt ~= "" then ns.UnlinkAlt(alt) end
      altBox:SetText(""); mainBox:SetText("")
    end)
  end
  alts:Show()
  RefreshAlts()
end

------------------------------------------------------------------------
-- Import starting balances
------------------------------------------------------------------------
local import

local function preview()
  local rows, bad = ns.ParseImport(import.box:GetText())
  local unknown = 0
  for _, r in ipairs(rows) do if not r.known then unknown = unknown + 1 end end
  local text = ("%d member%s found."):format(#rows, #rows == 1 and "" or "s")
  if unknown > 0 then text = text .. (" |cffe0b94c%d not in the guild (they'll still be set).|r"):format(unknown) end
  if #bad > 0 then text = text .. (" |cffff6b6b%d line%s couldn't be read, e.g. \"%s\".|r"):format(#bad, #bad == 1 and "" or "s", bad[1]) end
  import.preview:SetText(text)
  UI.SetEnabled(import.go, #rows > 0)
  return rows
end

StaticPopupDialogs["IMPERIUM_IMPORT"] = {
  text = "Set the DKP of %s members to the numbers you pasted? Each change is recorded as \"Starting balance\".",
  button1 = YES,
  button2 = NO,
  OnAccept = function(_, rows) if rows then ns.ImportBalances(rows); import:Hide() end end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
}

function ns.ShowImportWindow()
  if not import then
    local f = Window("TheImperiumImport", "Import balances", 460, 400)
    import = f
    local hint = UI.Label(f, "Paste one member per line: a name, then their DKP. For example \"Alice, 120\" or "
      .. "\"Alice 120\". Each member's balance is set to that number.", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", 16, -32)
    hint:SetWidth(428)

    local bg = f:CreateTexture(nil, "BORDER") -- the box to paste into
    bg:SetPoint("TOPLEFT", 14, -64)
    bg:SetPoint("BOTTOMRIGHT", -32, 76)
    bg:SetColorTexture(UI.C.control[1], UI.C.control[2], UI.C.control[3], 1)
    local sf = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    UI.SkinScrollBar(sf)
    sf:SetPoint("TOPLEFT", 18, -68)
    sf:SetPoint("BOTTOMRIGHT", -34, 80)
    local box = CreateFrame("EditBox", nil, sf)
    box:SetMultiLine(true)
    box:SetFontObject(UI.Fonts.Body)
    box:SetWidth(390)
    box:SetAutoFocus(false)
    box:SetScript("OnEscapePressed", box.ClearFocus)
    box:SetScript("OnTextChanged", preview)
    sf:SetScrollChild(box)
    sf:SetScript("OnMouseDown", function() box:SetFocus() end)
    f.box = box

    f.preview = UI.Label(f, "", "GameFontHighlightSmall")
    f.preview:SetPoint("BOTTOMLEFT", 16, 50)
    f.preview:SetWidth(428)

    f.go = UI.Button(f, "Import", 110, "primary")
    f.go:SetPoint("BOTTOM", 0, 14)
    f.go:SetScript("OnClick", function()
      local rows = preview()
      if #rows > 0 then StaticPopup_Show("IMPERIUM_IMPORT", #rows, nil, rows) end
    end)
  end
  import.box:SetText("")
  preview()
  import:Show()
  import.box:SetFocus()
end
