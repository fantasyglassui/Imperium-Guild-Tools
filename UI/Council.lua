--[[
  Warcrest
  The loot council window. Opens for everyone in the raid when an officer
  starts a vote: answer Need, Greed or Pass. Officers see who wants it, with
  their wishlist, attendance, recent loot and DKP, and click a name to vote.
  The officer who started it awards the item. With no vote open, officers
  can start one here (/warcrest council).
]]

local _, ns = ...
local Ambiguate = ns.Ambiguate
local UI = ns.UI

local WIDTH, HEIGHT = 640, 420
local INNER = WIDTH - 32
local win
local picked -- the candidate the loot master has picked to award

local CHOICE_TEXT = { need = "Need", greed = "Greed", pass = "Pass" }
local CHOICE_COLOR = { need = "accent", greed = "textSoft", pass = "muted" }

local COLS = {
  { "NAME", 14, 140 }, { "ANSWER", 156, 60 }, { "WISHLIST", 220, 70 }, { "ATTENDED", 296, 80 },
  { "ITEMS (30 DAYS)", 380, 100 }, { "DKP", 486, 50 }, { "VOTES", 548, 40 },
}

local function Build()
  win = UI.Window("WarcrestCouncil", WIDTH, HEIGHT, "Loot council")

  -- Start form (officers, when no vote is open).
  local start = CreateFrame("Frame", nil, win)
  win.start = start
  start:SetPoint("TOPLEFT", 0, -28)
  start:SetSize(WIDTH, HEIGHT - 28)
  local st = UI.Label(start, "Start a loot council vote", "Title")
  st:SetPoint("TOPLEFT", 16, -16)
  local sd = UI.Label(start, "Everyone in the raid says Need, Greed or Pass. Officers in the raid vote, and you award the item. "
    .. "It works whether or not the guild uses DKP; the winner pays nothing.", "Small")
  sd:SetPoint("TOPLEFT", 16, -46)
  sd:SetWidth(INNER)
  sd:SetSpacing(3)
  UI.FieldLabel(start, "Item", 16, -100)
  win.item = UI.EditBox(start, INNER, 255)
  win.item:SetHeight(28)
  win.item:SetPoint("TOPLEFT", 16, -116)
  win.item.hint = UI.Label(win.item, "Shift-click an item to put it here", "MutedSmall")
  win.item.hint:SetPoint("LEFT", 8, 0)
  win.item:HookScript("OnTextChanged", function(self) self.hint:SetShown((self:GetText() or "") == "") end)
  UI.FieldLabel(start, "Time to answer", 16, -160)
  win.seconds = UI.Cycle(start, 140, { { 60, "60 seconds" }, { 90, "90 seconds" }, { 120, "2 minutes" }, { 30, "30 seconds" } })
  win.seconds:SetHeight(26)
  win.seconds:SetPoint("TOPLEFT", 16, -176)
  local go = UI.Button(start, "Start vote", 160, "primary")
  go:SetHeight(28)
  go:SetPoint("TOPLEFT", 16, -222)
  go:SetScript("OnClick", function()
    if ns.StartCouncil(win.item:GetText(), win.seconds.value) then win.item:SetText("") end
  end)
  local function insert(link)
    if win.item:HasFocus() and link then win.item:SetText(link) end
  end
  if ChatEdit_InsertLink then hooksecurefunc("ChatEdit_InsertLink", insert) end
  if ChatFrameUtil and ChatFrameUtil.InsertLink then hooksecurefunc(ChatFrameUtil, "InsertLink", insert) end

  -- The vote.
  local vote = CreateFrame("Frame", nil, win)
  win.vote = vote
  vote:SetPoint("TOPLEFT", 0, -28)
  vote:SetSize(WIDTH, HEIGHT - 28)
  win.link = UI.Label(vote, "", "Title")
  win.link:SetPoint("TOPLEFT", 16, -14)
  win.link:SetWidth(INNER - 230)
  win.link:SetWordWrap(false)
  win.by = UI.Label(vote, "", "MutedSmall")
  win.by:SetPoint("TOPLEFT", 16, -40)
  win.timer = UI.Label(vote, "", "Small")
  win.timer:SetPoint("TOPRIGHT", -16, -44)
  win.timer:SetJustifyH("RIGHT")
  win.answer = UI.Segmented(vote, { { "need", "Need" }, { "greed", "Greed" }, { "pass", "Pass" } },
    function(v) ns.CouncilAnswer(v) end)
  win.answer:SetPoint("TOPRIGHT", -16, -12)
  UI.Tooltip(win.answer, "Your answer", "Need: you'd use it now. Greed: you'd take it if nobody needs it. Pass: not for you. You can change it until time runs out.")

  win.table = UI.Box(vote, 16, -64, INNER, 270)
  local y = UI.TableHeads(win.table, (function()
    local heads = {}
    for _, c in ipairs(COLS) do heads[#heads + 1] = { c[1], c[2] } end
    return heads
  end)())
  win.list = UI.List(win.table, INNER - 24, 270 + y - 2, 26,
    function(row)
      UI.RowSelection(row)
      row.cols = {}
      for i, c in ipairs(COLS) do
        local fs = UI.Label(row, "", i == 1 and "Subheading" or "Small")
        fs:SetPoint("LEFT", c[2], 0)
        fs:SetWidth(c[3])
        fs:SetWordWrap(false)
        row.cols[i] = fs
      end
      UI.RowLine(row)
      row:SetScript("OnClick", function(self)
        if ns.IsLootMaster() then picked = self.item.name end
        ns.CouncilVote(self.item.name)
        ns.RefreshCouncilWindow()
      end)
      UI.Tooltip(row, function() return row.item.name end, "Click to vote for them (click again to take your vote back). "
        .. "Wishlist: what they marked it as. Attended: raid nights in the last 30 days. Items: what they've won lately.")
    end,
    function(row, cand)
      local m = ns.Member(cand.name)
      row.cols[1]:SetText(cand.name)
      row.cols[1]:SetTextColor(UI.ClassColor(m and m.classFile))
      row.cols[2]:SetText(UI.Code(CHOICE_COLOR[cand.choice]) .. CHOICE_TEXT[cand.choice] .. "|r")
      row.cols[3]:SetText(cand.wish == "need" and (UI.Code("accent") .. "Need|r") or (cand.wish == "want" and "Want" or (UI.Code("faint") .. "-|r")))
      row.cols[4]:SetText(cand.raids > 0 and (cand.attended .. " / " .. cand.raids) or (UI.Code("faint") .. "-|r"))
      row.cols[5]:SetText(cand.items)
      row.cols[6]:SetText(ns.UsesDKP() and cand.dkp or (UI.Code("faint") .. "-|r"))
      row.cols[7]:SetText(cand.votes > 0 and (UI.Code("accent") .. cand.votes .. "|r") or (UI.Code("faint") .. "0|r"))
      local mine = ns.council and ns.council.votes[Ambiguate(UnitName("player"), "short")]
      UI.SetRowSelected(row, (ns.IsLootMaster() and picked and ns.Key(picked) == ns.Key(cand.name))
        or (not ns.IsLootMaster() and mine ~= nil and ns.Key(mine) == ns.Key(cand.name)))
    end, true)
  win.list.frame:SetPoint("TOPLEFT", win.table, "TOPLEFT", 0, y - 1)

  win.memberNote = UI.Label(vote, "", "Body")
  win.memberNote:SetPoint("TOPLEFT", 16, -80)
  win.memberNote:SetWidth(INNER)
  win.memberNote:SetSpacing(4)

  win.result = UI.Label(vote, "", "Subheading")
  win.result:SetPoint("BOTTOMLEFT", 16, 22)
  win.result:SetWidth(INNER - 330)
  win.award = UI.Button(vote, "Award", 200, "primary")
  win.award:SetHeight(28)
  win.award:SetPoint("BOTTOMRIGHT", -16, 14)
  win.award:SetScript("OnClick", function() if picked then ns.CouncilAward(picked) end end)
  win.cancel = UI.Button(vote, "Cancel vote", 110)
  win.cancel:SetHeight(28)
  win.cancel:SetPoint("RIGHT", win.award, "LEFT", -8, 0)
  win.cancel:SetScript("OnClick", ns.CancelCouncil)

  C_Timer.NewTicker(1, function()
    if win:IsShown() and ns.council and not ns.council.done then ns.RefreshCouncilWindow() end
  end)
end

function ns.RefreshCouncilWindow()
  if not win then return end
  local c = ns.council
  local active = c ~= nil
  win.start:SetShown(not active)
  win.vote:SetShown(active)
  if not active then return end

  win.link:SetText(c.link)
  win.by:SetText("Loot council run by " .. c.by)
  local left = math.ceil(c.ends - GetTime())
  local open = not c.done and left > 0
  win.timer:SetText(c.done and "" or (open and ("Answers close in " .. left .. "s") or "Answers closed"))
  win.answer:SetShown(open)
  local me = c.answers[Ambiguate(UnitName("player"), "short")]
  win.answer:SetValue(me) -- nothing highlighted until you answer

  local officer = ns.IsAddonOfficer()
  local cands = ns.CouncilCandidates()
  -- Members only need the answer buttons and the result: a smaller window.
  win:SetHeight(officer and HEIGHT or 230)
  win.table:SetShown(officer)
  win.memberNote:SetShown(not officer)
  win.timer:ClearAllPoints()
  win.timer:SetPoint("TOPRIGHT", -16, open and -44 or -18)
  if officer then
    win.list:SetEmptyText(open and "Waiting for answers. Names show here as raid members say Need or Greed." or "Nobody said Need or Greed.")
    win.list:SetItems(cands)
  else
    win.memberNote:SetText(open and ("Say Need, Greed or Pass at the top right. Your officers then decide who gets it, "
      .. "and you'll see the result here." .. (me and ("\n\nYou said " .. UI.Code("accent") .. CHOICE_TEXT[me] .. "|r.") or ""))
      or "Your officers are deciding.")
  end

  local lm = ns.IsLootMaster()
  if picked then
    local still = false
    for _, cand in ipairs(cands) do if ns.Key(cand.name) == ns.Key(picked) then still = true end end
    if not still then picked = nil end
  end
  if lm and not picked and cands[1] and cands[1].votes > 0 then picked = cands[1].name end -- most votes, ready to award
  win.award:SetShown(lm and not c.done)
  win.cancel:SetShown(lm and not c.done)
  UI.SetEnabled(win.award, picked ~= nil)
  win.award:SetText(picked and ("Award to " .. picked) or "Pick someone to award")

  if c.done then
    win.result:SetText(c.winner and (UI.Code("good") .. c.winner .. " gets it.|r") or (UI.Code("muted") .. "Cancelled.|r"))
  else
    win.result:SetText(lm and "Click a name to pick (and vote for) them." or "")
  end
end

function ns.ShowCouncilWindow()
  if not win then Build() end
  picked = nil
  win:Show()
  ns.RefreshCouncilWindow()
end

function ns.HideCouncilWindow()
  if win then win:Hide() end
end

-- /warcrest council: the open vote, or (officers) the form to start one.
function ns.OpenCouncil()
  if not ns.council or ns.council.done then
    if not ns.IsAddonOfficer() then ns.Say("No loot council vote is open.") return end
    ns.council = nil
  end
  ns.ShowCouncilWindow()
end
