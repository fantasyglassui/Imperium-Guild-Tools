--[[
  Warcrest
  The help window: short answers about every part of Warcrest, by topic.
  Opened with /warcrest help, the ? in the guild window, or from the welcome.
]]

local _, ns = ...
local UI = ns.UI
local C = UI.C

local WIDTH, HEIGHT = 640, 460
local LIST_W = 170
local win
local current = 1

local function B(text) return UI.Code("accent") .. text .. "|r" end

local TOPICS = {
  { "Getting started", function() return table.concat({
    "Warcrest shares raids, DKP, kills and history between everyone in your guild who has it. There's nothing to set up for members: install it and it starts syncing.",
    "Open it with " .. B("/warcrest") .. " (or " .. B("/wc") .. "), the crest by your minimap, or Options > AddOns > Warcrest.",
    "The more guildmates who have it, the better it works: only players with Warcrest share what they see. The Addon tab shows who has it.",
    "Click any guild member's name, almost anywhere, to open their player card.",
    "Officers: the welcome window (" .. B("/warcrest welcome") .. ") sets who manages Warcrest and whether the guild uses DKP.",
  }, "\n\n") end },
  { "Raids and sign-ups", function() return table.concat({
    B("Signing up:") .. " pick a raid on the Raids tab, choose Tank, Healer or DPS, then Accept, Tentative or Decline. You can change your answer any time.",
    B("Reminders:") .. " you're reminded before raids you signed up for. Officers are warned when a raid is short of tanks or healers.",
    B("Calendar:") .. " the month's raids (gold), raid nights held (green) and bosses killed. Click a raid to open it.",
    B("Progress:") .. " the bosses the guild has killed in each raid, with first kills. A kill counts when 5 or more guild members, at least half the raid, kill a raid boss. The first kill of each boss is announced.",
    B("Officers:") .. " New raid schedules one. Start raid on raid night records who's there (and gives DKP, if the guild uses it). Invite sign-ups invites everyone who accepted.",
  }, "\n\n") end },
  { "DKP and loot", function()
    if not ns.UsesDKP() then
      return "Your guild doesn't use DKP, so the DKP tab and loot auctions are hidden. Officers can turn DKP on in Settings > Alerts (Use DKP for loot)."
    end
    return table.concat({
      B("Earning DKP:") .. " for being on time, each hour of a raid night and each boss killed, as your officers set it. Alts share their main's DKP.",
      B("Auctions:") .. " when an officer auctions an item, a window opens for everyone in the raid. Type a bid and click Bid. If nobody bids, there's a free roll.",
      B("Your DKP:") .. " the DKP tab shows your total and every change. Click a name in the standings for their player card.",
      B("Officers:") .. " award or remove DKP, run auctions, set decay, and start a new season on the DKP tab. Any change can be undone.",
    }, "\n\n")
  end },
  { "Wishlists", function() return table.concat({
    "Mark the loot you're after on the Wishlist tab: Shift-click an item into the box, pick " .. B("Need") .. " (a big upgrade) or " .. B("Want") .. " (nice to have), and click Add.",
    "Everyone sees the guild's wishlist. In my raid shows only the people in your raid right now.",
    "When an item on your wishlist is auctioned, you're told in chat, and the auction window shows who wants it.",
    "Click one of your items to switch Need and Want, or the X to remove it. Items you win are marked Won.",
  }, "\n\n") end },
  { "PvP and the Wanted list", function() return table.concat({
    B("Kills:") .. " when a guild member kills an enemy player, the guild hears about it, and it goes in the shared kill log. Grey kills never count.",
    B("Top Head Hunters:") .. " the monthly leaderboard on the Kills tab. The champion is announced on the 1st.",
    B("Streaks and revenge:") .. " the guild hears about kill streaks, when a big streak is ended, and when someone kills a guildmate's killer.",
    B("Wanted:") .. " enemy players who keep killing guild members. When anyone spots one, everyone is alerted and the spot is marked on the map.",
  }, "\n\n") end },
  { "Achievements and titles", function() return table.concat({
    "The Achievements tab shows what you've earned and your progress on the rest, for PvP, raids, bosses and loot. They come from the guild's shared history, so they count what you did before you installed Warcrest.",
    "Some achievements come with a " .. B("title") .. ". Pick yours at the top of the Achievements tab or in Settings > General. It shows after your name on your player card.",
    "The Guild view shows what's been earned lately and who has the most.",
  }, "\n\n") end },
  { "Alerts and settings", function() return table.concat({
    B("Alerts:") .. " the Settings tab lists every alert. The Guild column is set by officers for everyone; the You column is just for you.",
    B("Quiet mode:") .. " hold alerts in dungeons, raids or combat. Held alerts are listed in chat once you're out.",
    B("The window:") .. " drag the bottom-right corner to make it bigger, or use the Size slider in Settings > General.",
  }, "\n\n") end },
  { "For officers", function() return table.concat({
    B("Roster:") .. " notes, promote, demote and remove, invites and the Message of the Day. Warcrest can only do what your guild rank allows.",
    B("Officer log:") .. " promotions, joins, leaves and note changes, recorded while you're online.",
    B("Guild settings:") .. " which alerts the guild hears, who counts as an officer, and whether the guild uses DKP: Settings > Alerts, then Save for whole guild.",
    B("Addon tab:") .. " who has Warcrest, who's out of date, and Check now to ask everyone online.",
  }, "\n\n") end },
  { "Commands", function() return table.concat({
    B("/warcrest") .. " (or " .. B("/wc") .. ")  open Warcrest",
    B("/warcrest raids") .. ", " .. B("dkp") .. ", " .. B("kills") .. ", " .. B("wanted") .. ", " .. B("wishlist") .. ", " .. B("achievements") .. "  open that tab",
    B("/warcrest card Name") .. "  a guild member's player card",
    B("/warcrest auction [item] [min bid]") .. "  auction an item to your raid (officers)",
    B("/warcrest recap") .. "  last week's guild recap",
    B("/warcrest quiet") .. "  hold alerts during combat on or off",
    B("/warcrest test") .. "  show a test alert",
    B("/warcrest sync") .. "  fetch recent history from guildmates",
    B("/warcrest minimap") .. "  show or hide the minimap button",
    B("/warcrest welcome") .. "  the welcome and guild setup again",
    B("/warcrest updates") .. "  what's new",
    B("/warcrest bosses") .. "  the last raid bosses that died, and whether each counted",
    B("/warcrest debug") .. "  show error details (and boss checks) in chat",
  }, "\n") end },
}

local function show(i)
  current = i
  for n, b in ipairs(win.topics) do UI.SetRowSelected(b, n == i) end
  win.heading:SetText(TOPICS[i][1])
  win.text:SetText(TOPICS[i][2]())
  win.scroll:SetVerticalScroll(0)
  win.content:SetHeight(math.max(1, win.text:GetStringHeight() + 20))
end

local function Build()
  win = UI.Window("WarcrestHelp", WIDTH, HEIGHT, "Warcrest help")
  local side = win:CreateTexture(nil, "BACKGROUND", nil, 1)
  side:SetPoint("TOPLEFT", 0, -29)
  side:SetPoint("BOTTOMLEFT")
  side:SetWidth(LIST_W)
  side:SetColorTexture(C.sidebar[1], C.sidebar[2], C.sidebar[3], 1)

  win.topics = {}
  for i, t in ipairs(TOPICS) do
    local b = CreateFrame("Button", nil, win)
    b:SetPoint("TOPLEFT", 0, -40 - (i - 1) * 32)
    b:SetSize(LIST_W, 32)
    UI.RowSelection(b)
    local hover = b:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.06)
    local label = UI.Label(b, t[1], "Body")
    label:SetPoint("LEFT", 16, 0)
    b:SetScript("OnClick", function() show(i) end)
    win.topics[i] = b
  end

  win.heading = UI.Label(win, "", "Title")
  win.heading:SetPoint("TOPLEFT", LIST_W + 24, -44)
  local sf = CreateFrame("ScrollFrame", nil, win, "UIPanelScrollFrameTemplate")
  sf:SetPoint("TOPLEFT", LIST_W + 24, -80)
  sf:SetSize(WIDTH - LIST_W - 24 - 30, HEIGHT - 80 - 20)
  UI.SkinScrollBar(sf)
  local content = CreateFrame("Frame", nil, sf)
  content:SetSize(WIDTH - LIST_W - 24 - 34, 1)
  sf:SetScrollChild(content)
  win.text = UI.Label(content, "", "Body")
  win.text:SetPoint("TOPLEFT")
  win.text:SetWidth(WIDTH - LIST_W - 24 - 40)
  win.text:SetSpacing(4)
  win.scroll, win.content = sf, content
end

-- Open the help, on a topic (its number or its title) if given.
function ns.ShowHelp(topic)
  if not win then Build() end
  local i = tonumber(topic) or current
  if type(topic) == "string" then
    for n, t in ipairs(TOPICS) do if t[1]:lower():find(topic:lower(), 1, true) then i = n break end end
  end
  show(i)
  win:Show()
end
