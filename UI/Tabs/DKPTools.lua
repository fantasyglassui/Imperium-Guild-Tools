--[[
  Warcrest
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
local W = 440
local INNER = W - 32

local function RefreshAlts()
  if not (alts and alts:IsShown()) then return end
  local me = UnitName("player")
  local main = ns.MainOf(me)
  local isAlt = ns.Key(main) ~= ns.Key(me)
  local lines = {}

  if isAlt then
    lines[#lines + 1] = ns.TF("This character is an alt of %s. Its DKP and attendance count toward %s.",
      ns.COLOR .. main .. "|r", main)
  else
    local mine = ns.AltsOf(me)
    lines[#lines + 1] = #mine > 0 and ns.TF("Your alts: %s", table.concat(mine, ", "))
      or (UI.Code("muted") .. ns.T("This character has no alts linked.") .. "|r")
  end
  local asked = ns.MyAltRequest()
  if asked then
    lines[#lines + 1] = UI.Code("accent") .. ns.TF("Waiting for %s to confirm. Log in on %s and open this window.", asked, asked) .. "|r"
  end
  alts.status:SetText(table.concat(lines, "\n"))

  -- An alt can unlink itself; a main (or unlinked character) can ask to link.
  alts.mainLabel:SetShown(not isAlt)
  alts.mainBox:SetShown(not isAlt)
  alts.ask:SetShown(not isAlt)
  alts.how:SetShown(not isAlt)
  alts.unlink:SetShown(isAlt)

  local requests = ns.PendingAltRequests()
  local y = -186
  alts.request:SetShown(#requests > 0)
  if #requests > 0 then
    alts.requestText:SetText(ns.TF("%s asked to be linked as your alt.", requests[1]))
    alts.confirm.alt = requests[1]
    alts.request:ClearAllPoints()
    alts.request:SetPoint("TOPLEFT", 16, y)
    y = y - 76
  end
  local officer = ns.IsAddonOfficer()
  alts.officer:SetShown(officer)
  if officer then
    alts.officer:ClearAllPoints()
    alts.officer:SetPoint("TOPLEFT", 16, y)
    y = y - 96
  end
  alts:SetHeight(-y + 4)
end

ns.OnLedgerChanged(function() C_Timer.After(0.6, RefreshAlts) end)

function ns.ShowAltsWindow()
  if not alts then
    local f = Window("WarcrestAlts", "Alts", W, 300)
    alts = f

    local intro = UI.Label(f, "Link your alts to your main so they share its DKP and attendance.", "MutedSmall")
    intro:SetPoint("TOPLEFT", 16, -42)
    intro:SetWidth(INNER)
    f.status = UI.Label(f, "", "Body")
    f.status:SetPoint("TOPLEFT", 16, -64)
    f.status:SetWidth(INNER)
    f.status:SetSpacing(3)

    f.mainLabel = UI.FieldLabel(f, "Link this character as an alt of", 16, -104)
    f.mainBox = UI.EditBox(f, INNER - 128, 40)
    f.mainBox:SetHeight(28)
    f.mainBox:SetPoint("TOPLEFT", 16, -120)
    f.mainBox.hint = UI.Label(f.mainBox, "Your main's name", "MutedSmall")
    f.mainBox.hint:SetPoint("LEFT", 8, 0)
    f.mainBox:HookScript("OnTextChanged", function(self) self.hint:SetShown((self:GetText() or "") == "") end)
    f.ask = UI.Button(f, "Ask to link", 120, "primary")
    f.ask:SetHeight(28)
    f.ask:SetPoint("LEFT", f.mainBox, "RIGHT", 8, 0)
    f.ask:SetScript("OnClick", function()
      ns.RequestAltLink(f.mainBox:GetText())
      f.mainBox:SetText("")
      f.mainBox:ClearFocus()
    end)
    f.how = UI.Label(f, "Then log in on your main and confirm it here. Linking needs both characters, so only "
      .. "you can link your own alts.", "MutedSmall")
    f.how:SetPoint("TOPLEFT", 16, -154)
    f.how:SetWidth(INNER)

    f.unlink = UI.Button(f, "Unlink this alt", 160)
    f.unlink:SetHeight(28)
    f.unlink:SetPoint("TOPLEFT", 16, -110)
    f.unlink:SetScript("OnClick", function() ns.UnlinkAlt(UnitName("player")) end)

    -- Someone asked to be this character's alt.
    local r = CreateFrame("Frame", nil, f)
    r:SetSize(INNER, 66)
    UI.Card(r, 1)
    f.request = r
    f.requestText = UI.Label(r, "", "Subheading")
    f.requestText:SetPoint("TOPLEFT", 12, -10)
    f.requestText:SetWidth(INNER - 24)
    f.confirm = UI.Button(r, "Confirm", 100, "primary")
    f.confirm:SetHeight(26)
    f.confirm:SetPoint("TOPLEFT", 12, -30)
    f.confirm:SetScript("OnClick", function(self) if self.alt then ns.ConfirmAlt(self.alt) end end)
    f.decline = UI.Button(r, "Decline", 100)
    f.decline:SetHeight(26)
    f.decline:SetPoint("LEFT", f.confirm, "RIGHT", 8, 0)
    f.decline:SetScript("OnClick", function()
      if f.confirm.alt then ns.UnlinkAlt(f.confirm.alt) end
    end)

    -- Officers can link or unlink any alt directly.
    local o = CreateFrame("Frame", nil, f)
    o:SetSize(INNER, 86)
    f.officer = o
    local line = o:CreateTexture(nil, "ARTWORK")
    line:SetPoint("TOPLEFT")
    line:SetSize(INNER, 1)
    line:SetColorTexture(UI.C.edge[1], UI.C.edge[2], UI.C.edge[3], 1)
    local head = UI.Label(o, "Officers: link any alt", "Subheading")
    head:SetPoint("TOPLEFT", 0, -14)
    local boxW = math.floor((INNER - 16 - 150) / 2)
    UI.FieldLabel(o, "Alt", 0, -38)
    local altBox = UI.EditBox(o, boxW, 40)
    altBox:SetHeight(28)
    altBox:SetPoint("TOPLEFT", 0, -54)
    UI.FieldLabel(o, "Main", boxW + 8, -38)
    local mainBox = UI.EditBox(o, boxW, 40)
    mainBox:SetHeight(28)
    mainBox:SetPoint("TOPLEFT", boxW + 8, -54)
    local link = UI.Button(o, "Link", 70)
    link:SetHeight(28)
    link:SetPoint("LEFT", mainBox, "RIGHT", 8, 0)
    link:SetScript("OnClick", function()
      ns.OfficerLinkAlt(altBox:GetText(), mainBox:GetText())
      altBox:SetText(""); mainBox:SetText("")
    end)
    local unlink = UI.Button(o, "Unlink", 70)
    unlink:SetHeight(28)
    unlink:SetPoint("LEFT", link, "RIGHT", 8, 0)
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
    local f = Window("WarcrestImport", "Import balances", 460, 400)
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
