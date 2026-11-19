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
local T, TF = ns.T, ns.TF
-- A paragraph that starts with a highlighted heading: "Heading: the rest."
local function P(head, body) return B(T(head)) .. " " .. T(body) end
-- A command and what it does.
local function CMD(cmd, what) return B(cmd) .. "  " .. T(what) end
local function join(list, sep) return table.concat(list, sep or "\n\n") end

local TOPICS = {
  { "Getting started", function() return join({
    T("Warcrest shares raids, DKP, kills and history between everyone in your guild who has it. There's nothing to set up for members: install it and it starts syncing."),
    TF("Open it with %s (or %s), the crest by your minimap, or Options > AddOns > Warcrest.", B("/warcrest"), B("/wc")),
    T("The more guildmates who have it, the better it works: only players with Warcrest share what they see. The Addon tab shows who has it."),
    T("Click any guild member's name, almost anywhere, to open their player card."),
    TF("Officers: the welcome window (%s) sets who manages Warcrest and whether the guild uses DKP.", B("/warcrest welcome")),
  }) end },
  { "Raids and sign-ups", function() return join({
    P("Signing up:", "pick a raid on the Raids tab, choose Tank, Healer or DPS, then Accept, Tentative or Decline. You can change your answer any time."),
    P("Reminders:", "you're reminded before raids you signed up for. Officers are warned when a raid is short of tanks or healers."),
    P("Calendar:", "the month's raids (gold), raid nights held (green) and bosses killed. Click a raid to open it."),
    P("Progress:", "the bosses the guild has killed in each raid, with first kills. A kill counts when 5 or more guild members, at least half the raid, kill a raid boss. The first kill of each boss is announced."),
    P("Plan:", "officers put the sign-ups into groups 1 to 8 or on the bench, by clicking a name and then a group, or with Auto-fill (tanks in group 1, a healer in each group). Everyone can see the plan. At raid time, Invite sign-ups invites only the planned groups, and Arrange raid moves everyone into their group (raid leader or assistant)."),
    P("Raid night recap:", "when an officer clicks End raid, the whole guild gets a summary in chat: the bosses killed, the loot and who won it, how many attended, and the DKP you earned. /warcrest raidrecap shows the last one again."),
    P("Officers:", "New raid schedules one. Start raid on raid night records who's there (and gives DKP, if the guild uses it). Invite sign-ups invites everyone who accepted."),
  }) end },
  { "Loot council", function() return join({
    T("A way to hand out loot by vote instead of DKP, and it works whether or not the guild uses DKP."),
    B(T("Starting a vote:")) .. " " .. TF("an officer in the raid opens %s (or the Loot council button on the Wishlist tab), Shift-clicks the item in, and clicks Start vote.", B("/warcrest council")),
    P("Everyone in the raid:", "a small window asks Need, Greed or Pass. You can change your answer until time runs out."),
    P("Officers:", "see everyone who said Need or Greed, with their wishlist, raid attendance, items won lately and DKP, and click a name to vote. The officer who started it awards the item; it's recorded in the loot history, free of charge."),
  }) end },
  { "DKP and loot", function()
    if not ns.UsesDKP() then
      return T("Your guild doesn't use DKP, so the DKP tab and loot auctions are hidden. Officers can turn DKP on in Settings > Alerts (Use DKP for loot).")
    end
    return join({
      P("Earning DKP:", "for being on time, each hour of a raid night and each boss killed, as your officers set it. Alts share their main's DKP."),
      P("Auctions:", "when an officer auctions an item, a window opens for everyone in the raid. Type a bid and click Bid. If nobody bids, there's a free roll."),
      P("Your DKP:", "the DKP tab shows your total and every change. Click a name in the standings for their player card."),
      P("Officers:", "award or remove DKP, run auctions, set decay, and start a new season on the DKP tab. Any change can be undone."),
    })
  end },
  { "Wishlists", function() return join({
    TF("Mark the loot you're after on the Wishlist tab: Shift-click an item into the box, pick %s (a big upgrade) or %s (nice to have), and click Add.", B(T("Need")), B(T("Want"))),
    T("Everyone sees the guild's wishlist. In my raid shows only the people in your raid right now."),
    T("When an item on your wishlist is auctioned, you're told in chat, and the auction window shows who wants it."),
    T("Click one of your items to switch Need and Want, or the X to remove it. Items you win are marked Won."),
  }) end },
  { "PvP and the Wanted list", function() return join({
    P("Kills:", "when a guild member kills an enemy player, the guild hears about it, and it goes in the shared kill log. Grey kills never count."),
    P("Top Head Hunters:", "the monthly leaderboard on the Kills tab. The champion is announced on the 1st."),
    P("Streaks and revenge:", "the guild hears about kill streaks, when a big streak is ended, and when someone kills a guildmate's killer."),
    P("Wanted:", "enemy players who keep killing guild members. When anyone spots one, everyone is alerted and the spot is marked on the map."),
    P("Bounties:", "off until an officer turns them on (Settings > Alerts > Bounties). Then officers can put a reward on an enemy player's head on the Wanted tab, and the first guild member to kill them in 30 days claims it, paid in DKP if the guild uses it."),
  }) end },
  { "Achievements and titles", function() return join({
    T("The Achievements tab shows what you've earned and your progress on the rest, for PvP, raids, bosses and loot. They come from the guild's shared history, so they count what you did before you installed Warcrest."),
    TF("Some achievements come with a %s. Pick yours at the top of the Achievements tab or in Settings > General. It shows after your name on your player card.", B(T("title"))),
    T("The Guild view shows what's been earned lately and who has the most."),
  }) end },
  { "Alerts and settings", function() return join({
    P("Alerts:", "the Settings tab lists every alert. The Guild column is set by officers for everyone; the You column is just for you."),
    P("On screen:", "alerts drop in as a banner at the top of the screen, with a colour and icon for each kind. Click one to open its tab, right-click to dismiss it, Shift-drag to move them. Settings > Alerts can switch to the game's raid warning text, or chat only."),
    P("Sounds:", "each kind of alert has its own sound. Settings > Sounds lets you pick another for any of them, from Warcrest's sounds, the game's, SharedMedia's or your own (put .ogg or .mp3 files in Interface\\AddOns\\WarcrestSounds and restart the game)."),
    P("Quiet mode:", "hold alerts in dungeons, raids or combat. Held alerts are listed in chat once you're out."),
    P("Language:", "Warcrest follows your game's language (English, German, French or Spanish). Pick another in Settings > General, then /reload."),
    P("The window:", "drag the bottom-right corner to make it bigger, or use the Size slider in Settings > General."),
  }) end },
  { "For officers", function() return join({
    P("Roster:", "notes, promote, demote and remove, invites and the Message of the Day. Warcrest can only do what your guild rank allows."),
    P("Officer log:", "promotions, joins, leaves and note changes, recorded while you're online."),
    P("Guild settings:", "which alerts the guild hears, who counts as an officer, and whether the guild uses DKP: Settings > Alerts, then Save for whole guild."),
    P("Addon tab:", "who has Warcrest, who's out of date, and Check now to ask everyone online."),
  }) end },
  { "Commands", function() return join({
    CMD("/warcrest  /wc", "open Warcrest"),
    B("/warcrest raids") .. ", " .. B("dkp") .. ", " .. B("kills") .. ", " .. B("wanted") .. ", " .. B("wishlist") .. ", " .. B("achievements") .. "  " .. T("open that tab"),
    CMD("/warcrest card Name", "a guild member's player card"),
    CMD("/warcrest auction [item] [min bid]", "auction an item to your raid (officers)"),
    CMD("/warcrest council  /warcrest lc", "the loot council vote"),
    CMD("/warcrest raidrecap", "the last raid night's recap"),
    CMD("/warcrest recap", "last week's guild recap"),
    CMD("/warcrest quiet", "hold alerts during combat on or off"),
    CMD("/warcrest test", "show a test alert"),
    CMD("/warcrest sync", "fetch recent history from guildmates"),
    CMD("/warcrest minimap", "show or hide the minimap button"),
    CMD("/warcrest welcome", "the welcome and guild setup again"),
    CMD("/warcrest updates", "what's new"),
    CMD("/warcrest bosses", "the last raid bosses that died, and whether each counted"),
    CMD("/warcrest debug", "show error details (and boss checks) in chat"),
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
    label:SetWidth(LIST_W - 24)
    label:SetWordWrap(false)
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
