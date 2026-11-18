--[[
  The Imperium
  Roster tab: member list, notes, rank changes, invites, MOTD, addon versions.
]]

local _, ns = ...
local UI = ns.UI

local P = {}          -- widgets on this page
local selected
local filterText = ""

-- The game's own guild commands (localized names when available).
local CMD = {
  promote = _G.SLASH_GUILD_PROMOTE1 or "/gpromote",
  demote  = _G.SLASH_GUILD_DEMOTE1 or "/gdemote",
  remove  = _G.SLASH_GUILD_UNINVITE1 or "/gremove",
  invite  = _G.SLASH_GUILD_INVITE1 or "/ginvite",
  motd    = _G.SLASH_GUILD_MOTD1 or "/gmotd",
}

-- Name as the slash commands expect it: no realm for your own realm.
local function cmdName(m) return Ambiguate(m.name, "none") end

local function hideRemoveConfirm()
  if P.detail and P.detail.confirm and not InCombatLockdown() then
    P.detail.confirm:Hide()
    P.detail.cancel:Hide()
  end
end

local function addonVersionText(m)
  local v = ns.versions[m.full]
  if not v then
    return m.online and "|cff8b95a7Addon not detected|r" or ""
  end
  if ns.CompareVersions(v, ns.NewestVersion()) < 0 then
    return "|cffff6b6bAddon v" .. v .. " (out of date)|r"
  end
  return "|cff6fd08cAddon v" .. v .. "|r"
end

local function UpdateDetail()
  local d = P.detail
  local p = ns.Perms()
  local m = selected

  for _, w in ipairs({ d.pub, d.off, d.save, d.promote, d.demote, d.remove }) do
    UI.SetEnabled(w, false)
  end

  if not m then
    hideRemoveConfirm()
    d.name:SetText(IsInGuild() and "Select a member" or "You're not in a guild")
    d.name:SetTextColor(UI.C.accent[1], UI.C.accent[2], UI.C.accent[3])
    d.info:SetText("")
    d.zone:SetText("")
    d.addon:SetText("")
    d.pub:SetText("")
    d.off:SetText("")
    d.offHidden:Hide()
    return
  end

  local myRank = ns.MyRank() or 99
  local isMe = ns.IsMe(m.name)

  UI.SetCommand(d.promote, CMD.promote .. " " .. cmdName(m))
  UI.SetCommand(d.demote, CMD.demote .. " " .. cmdName(m))
  UI.SetCommand(d.confirm, CMD.remove .. " " .. cmdName(m))

  d.name:SetText(Ambiguate(m.name, "guild"))
  d.name:SetTextColor(UI.ClassColor(m.classFile))
  d.info:SetText(("Level %d %s  -  %s"):format(m.level, m.className, m.rankName))
  if m.online then
    d.zone:SetText("Online in " .. (m.zone ~= "" and m.zone or "unknown zone"))
  else
    d.zone:SetText(m.mobile and "On mobile" or "Offline")
  end
  d.addon:SetText(addonVersionText(m))

  if not d.pub:HasFocus() then d.pub:SetText(m.publicNote) end
  if not d.off:HasFocus() then d.off:SetText(p.viewOfficerNote and m.officerNote or "") end
  d.offHidden:SetShown(not p.viewOfficerNote)

  UI.SetEnabled(d.pub, p.publicNote)
  UI.SetEnabled(d.off, p.officerNote)
  UI.SetEnabled(d.save, p.publicNote or p.officerNote)
  -- You can only act on ranks below your own; the server enforces this too.
  UI.SetEnabled(d.promote, p.promote and not isMe and m.rankIndex > myRank + 1)
  UI.SetEnabled(d.demote, p.demote and not isMe and m.rankIndex > myRank and m.rankIndex < UI.NumRanks() - 1)
  UI.SetEnabled(d.remove, p.remove and not isMe and m.rankIndex > myRank)
end

local function Refresh()
  local roster = ns.GetRoster()
  local showOffline = P.offline:GetChecked()
  local q = filterText:lower()
  local shown = {}

  for _, m in ipairs(roster) do
    local match = q == "" or m.name:lower():find(q, 1, true) or m.rankName:lower():find(q, 1, true)
    if (showOffline or m.online) and match then shown[#shown + 1] = m end
  end
  table.sort(shown, function(a, b)
    if a.rankIndex ~= b.rankIndex then return a.rankIndex < b.rankIndex end
    return a.name < b.name
  end)

  if selected then
    local fresh
    for _, m in ipairs(roster) do
      if m.full == selected.full then fresh = m break end
    end
    selected = fresh
  end

  P.list:SetEmptyText(q ~= "" and "Nobody matches your search." or "The guild roster is still loading.")
  P.list:SetItems(shown)

  local online, with, outdated = ns.VersionSummary(roster)
  local summary = ("%d shown  |  %d of %d online have the addon"):format(#shown, with, online)
  if outdated > 0 then summary = summary .. ("  |  |cffff6b6b%d out of date|r"):format(outdated) end
  P.count:SetText(summary)

  UpdateDetail()

  local p = ns.Perms()
  UI.SetEnabled(P.inviteBox, p.invite)
  UI.SetEnabled(P.inviteBtn, p.invite)
  UI.SetEnabled(P.motdBox, p.motd)
  UI.SetEnabled(P.motdBtn, p.motd)
  if not P.motdBox:HasFocus() then
    P.motdBox:SetText((GetGuildRosterMOTD and GetGuildRosterMOTD()) or "")
  end
end

local function Build(page)
  local search = UI.EditBox(page, 170, 40)
  search:SetPoint("TOPLEFT", 10, -4)
  search.hint = UI.Label(search, "Search name or rank", "GameFontDisableSmall")
  search.hint:SetPoint("LEFT", 2, 0)
  search:SetScript("OnTextChanged", function(self)
    filterText = self:GetText() or ""
    self.hint:SetShown(filterText == "")
    ns.RefreshPanel()
  end)

  P.offline = UI.Check(page, "Show offline", 190, 0)
  P.offline:SetScript("OnClick", ns.RefreshPanel)

  local check = UI.Button(page, "Check addon versions", 170)
  check:SetPoint("TOPRIGHT", -4, -2)
  check:SetScript("OnClick", ns.CheckVersions)
  UI.Tooltip(check, "Check addon versions", "Asks every online guildmate which version of The Imperium they have. The list and the Addon tab update as they answer.")

  P.list = UI.List(page, 290, 240, 20,
    function(row)
      row.sel = row:CreateTexture(nil, "BACKGROUND")
      row.sel:SetAllPoints()
      row.sel:SetColorTexture(UI.C.accent[1], UI.C.accent[2], UI.C.accent[3], 0.14)
      row.name = UI.Label(row, "", "GameFontHighlightSmall")
      row.name:SetPoint("LEFT", 4, 0)
      row.name:SetWidth(135)
      row.info = UI.Label(row, "", "GameFontHighlightSmall")
      row.info:SetPoint("RIGHT", -4, 0)
      row.info:SetWidth(140)
      row.info:SetJustifyH("RIGHT")
      row:SetScript("OnClick", function(self)
        selected = self.item
        hideRemoveConfirm()
        ns.RefreshPanel()
      end)
    end,
    function(row, m)
      local r, g, b = UI.ClassColor(m.classFile)
      local dim = m.online and 1 or 0.5
      row.name:SetText(Ambiguate(m.name, "guild"))
      row.name:SetTextColor(r * dim, g * dim, b * dim)
      row.info:SetText(m.level .. "   " .. m.rankName)
      row.info:SetTextColor(dim, dim, dim)
      row.sel:SetShown(selected ~= nil and selected.full == m.full)
    end)
  P.list.frame:SetPoint("TOPLEFT", 4, -32)

  P.count = UI.Label(page, "", "GameFontDisableSmall")
  P.count:SetPoint("TOPLEFT", 8, -278)

  -- Member details
  local d = CreateFrame("Frame", nil, page)
  d:SetPoint("TOPLEFT", 330, -34)
  d:SetSize(340, 240)
  P.detail = d

  d.name = UI.Label(d, "", "GameFontNormalLarge")
  d.name:SetPoint("TOPLEFT", 0, 0)
  d.info = UI.Label(d, "", "GameFontHighlightSmall")
  d.info:SetPoint("TOPLEFT", 0, -24)
  d.zone = UI.Label(d, "", "GameFontDisableSmall")
  d.zone:SetPoint("TOPLEFT", 0, -40)
  d.addon = UI.Label(d, "", "GameFontHighlightSmall")
  d.addon:SetPoint("TOPLEFT", 0, -54)

  UI.Label(d, "Public note", "GameFontNormalSmall"):SetPoint("TOPLEFT", 0, -76)
  d.pub = UI.EditBox(d, 300, 31)
  d.pub:SetPoint("TOPLEFT", 6, -90)

  UI.Label(d, "Officer note", "GameFontNormalSmall"):SetPoint("TOPLEFT", 0, -116)
  d.off = UI.EditBox(d, 300, 31)
  d.off:SetPoint("TOPLEFT", 6, -130)
  d.offHidden = UI.Label(d, "(your rank can't see officer notes)", "GameFontDisableSmall")
  d.offHidden:SetPoint("LEFT", d.off, "LEFT", 2, 0)

  d.save = UI.Button(d, "Save notes", 110)
  d.save:SetPoint("TOPLEFT", 0, -158)
  UI.Tooltip(d.save, "Save notes", "Saves the public and officer notes typed above. Each one needs your rank to have permission to edit it.")
  d.save:SetScript("OnClick", function()
    local m = selected
    if not m then return end
    local p = ns.Perms()
    d.pub:ClearFocus()
    d.off:ClearFocus()
    if p.publicNote and d.pub:GetText() ~= m.publicNote then ns.SetNote(m, d.pub:GetText(), true) end
    if p.officerNote and d.off:GetText() ~= m.officerNote then ns.SetNote(m, d.off:GetText(), false) end
  end)

  local function afterAction() C_Timer.After(1, ns.RequestRoster) end

  d.promote = UI.SecureButton(d, "Promote", 95)
  d.promote:SetPoint("TOPLEFT", 0, -196)
  d.promote:HookScript("PostClick", afterAction)
  UI.Tooltip(d.promote, "Promote", "Moves this member up one guild rank. Your rank needs permission to promote, and it can't be done in combat.")

  d.demote = UI.SecureButton(d, "Demote", 95)
  d.demote:SetPoint("LEFT", d.promote, "RIGHT", 4, 0)
  d.demote:HookScript("PostClick", afterAction)
  UI.Tooltip(d.demote, "Demote", "Moves this member down one guild rank. Your rank needs permission to demote, and it can't be done in combat.")

  -- Remove asks for confirmation: the first click shows a confirm button.
  d.remove = UI.Button(d, "Remove", 95)
  d.remove:SetPoint("LEFT", d.demote, "RIGHT", 4, 0)
  UI.Tooltip(d.remove, "Remove from guild", "Removes this member from the guild. You'll be asked to confirm first.")
  d.remove:SetScript("OnClick", function()
    if selected and not InCombatLockdown() then
      d.confirm:SetText("Remove " .. Ambiguate(selected.name, "guild") .. "?")
      d.confirm:Show()
      d.cancel:Show()
    end
  end)

  d.confirm = UI.SecureButton(d, "Confirm", 200)
  d.confirm:SetPoint("TOPLEFT", 0, -222)
  d.confirm:Hide()
  d.confirm:HookScript("PostClick", function()
    hideRemoveConfirm()
    afterAction()
  end)
  d.cancel = UI.Button(d, "Cancel", 80)
  d.cancel:SetPoint("LEFT", d.confirm, "RIGHT", 4, 0)
  d.cancel:Hide()
  d.cancel:SetScript("OnClick", hideRemoveConfirm)

  -- Invite
  UI.Label(page, "Invite player", "GameFontNormalSmall"):SetPoint("TOPLEFT", 8, -304)
  P.inviteBox = UI.EditBox(page, 180, 60)
  P.inviteBox:SetPoint("TOPLEFT", 14, -318)
  P.inviteBtn = UI.SecureButton(page, "Invite", 80)
  P.inviteBtn:SetPoint("LEFT", P.inviteBox, "RIGHT", 8, 0)
  UI.Tooltip(P.inviteBtn, "Invite to guild", "Invites the player named in the box to the guild.")
  P.inviteBox:SetScript("OnTextChanged", function(self)
    local name = strtrim(self:GetText() or "")
    UI.SetCommand(P.inviteBtn, name ~= "" and (CMD.invite .. " " .. name) or "")
  end)
  P.inviteBtn:HookScript("PostClick", function()
    P.inviteBox:SetText("")
    P.inviteBox:ClearFocus()
  end)

  -- Message of the day
  UI.Label(page, "Message of the day", "GameFontNormalSmall"):SetPoint("TOPLEFT", 8, -348)
  P.motdBox = UI.EditBox(page, 540, 128)
  P.motdBox:SetPoint("TOPLEFT", 14, -362)
  P.motdBtn = UI.SecureButton(page, "Save", 80)
  P.motdBtn:SetPoint("LEFT", P.motdBox, "RIGHT", 8, 0)
  UI.Tooltip(P.motdBtn, "Save message of the day", "Sets the guild's message of the day to this text, for everyone.")
  P.motdBox:SetScript("OnTextChanged", function(self)
    local text = (self:GetText() or ""):gsub("[\r\n]", " ")
    UI.SetCommand(P.motdBtn, CMD.motd .. " " .. text)
  end)
  P.motdBtn:HookScript("PostClick", function()
    P.motdBox:ClearFocus()
    if ns.LogAction then ns.LogAction("motd") end
    C_Timer.After(1, ns.RequestRoster)
  end)
end

UI.AddTab({ id = "roster", title = "Roster", build = Build, refresh = Refresh })
