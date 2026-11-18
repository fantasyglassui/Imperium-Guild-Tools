--[[
  Bannerhold
  Updates panel: after the addon is updated, shows what changed since the
  version you last used. Reopen it any time with /bannerhold updates.

  To add a release: put a new entry at the TOP of CHANGES.
]]

local _, ns = ...
local UI = ns.UI

-- Newest first. Players see every entry newer than the version they last used.
local CHANGES = {
  { version = "3.0.0", date = "Nov 18, 2026", items = {
    "The Imperium is now Bannerhold, guild tools for any guild. Members of <The Imperium> keep the Imperium emblem; your settings and history came with you.",
    "Commands start with /bannerhold, or /bh for short. /imperium still works.",
  } },
  { version = "2.14.0", date = "Nov 18, 2026", items = {
    "Loot wishlists: mark the items you Need or Want on the new Wishlist tab. When one is auctioned, you're told, and the auction window shows who wants it.",
    "Achievements and titles: 21 achievements for kills, streaks, revenge, bounties, raids and loot on the new Achievements tab. Some come with a title to show after your name.",
    "The Wanted, Settings, Officers and Addon tabs are redesigned in the new look.",
    "New commands: /bannerhold wishlist and /bannerhold achievements.",
  } },
  { version = "2.13.0", date = "Nov 18, 2026", items = {
    "Player cards: click a guild member's name on the Roster, Kills, DKP or Raids tab to see their kills, deaths, nemesis, best streak, DKP, attendance and loot in one place. Or type /bannerhold card Name.",
    "Kill streaks: the guild hears when someone gets 3, 5, 10 or more kills in a row, and when a big streak is ended. The Kills tab shows the period's best streak.",
    "Revenge: the guild hears when someone kills an enemy player who just killed a guildmate.",
    "The DKP, Raids and Roster tabs are redesigned in the new look.",
  } },
  { version = "2.12.0", date = "Nov 17, 2026", items = {
    "A new look: the guild panel and its windows are redesigned, dark and flat with Imperium gold, a new font, and a side menu with icons.",
    "The Kills tab is redesigned: a kill table, this month's leader, and Top Head Hunters with bars. Pick the period at the top, and drag the borders between column headings to see long names in full.",
    "Resize the window: drag its bottom-right corner to show more rows, or set its size in Settings > Guild window.",
    "Every list says something when it's empty, and the panel opens on the tab you used last.",
    "Tooltips on buttons that didn't explain themselves. They show even when a button is greyed out.",
  } },
  { version = "2.11.1", date = "Nov 17, 2026", items = {
    "Fixed: kills of grey-level players were still being logged. Grey kills are now never announced or logged, and any already in your Kills tab are cleared out.",
  } },
  { version = "2.11.0", date = "Nov 17, 2026", items = {
    "Raid makeup: the Raids tab shows who's coming by class and warns when a raid is short of tanks or healers, or has a class nobody signed up with. Raids with gaps get an orange ! in the list.",
    "Officers get a heads-up an hour before a raid if its makeup has gaps.",
    "Weekly recap: after the Tuesday reset you get a summary of the guild's week in chat: kills, top head hunters, raids, bosses and loot. Turn it off in Settings, or type /bannerhold recap to see it again.",
  } },
  { version = "2.10.0", date = "Nov 16, 2026", items = {
    "Top Head Hunters now starts fresh on the 1st of each month. Switch to Last month or All time on the Kills tab to see earlier standings.",
    "On reset day (the 1st), the guild hears last month's top three head hunters. Last month's champion is also shown under the board.",
    "Fixed: Top Head Hunters could credit a different killing blow on different guildmates' screens for some older kills.",
  } },
  { version = "2.9.0", date = "Nov 15, 2026", items = {
    "DKP seasons: officers can start a new season from the DKP tab. Everyone keeps their DKP, and older history is archived so the addon stays fast.",
    "DKP, raids and attendance are worked out much faster, especially with a lot of history.",
  } },
  { version = "2.8.0", date = "Nov 15, 2026", items = {
    "Alts: link your alts to your main on the DKP tab (Alts). They share your DKP and attendance. Linking needs both characters, so only you can link your own alts.",
    "Boss DKP: officers can set DKP per boss kill when starting a raid. It's awarded automatically each time the raid kills a boss.",
    "Free rolls: if nobody bids on an item, the raid gets a free roll for it instead.",
    "Class check: you're warned before bidding on gear your class can't use.",
    "Officers can undo any DKP change, refund loot or give it to someone else, and import starting balances.",
  } },
  { version = "2.7.0", date = "Nov 15, 2026", items = {
    "Attendance: the DKP tab shows each member's raid attendance over the last 30 days. Hover a name for details.",
    "Standby: officers can put members on standby during a raid. They earn the same DKP as the raid and count as attending.",
    "No-shows: after a raid night, anyone who accepted but didn't come is marked on the Raids tab and in their attendance.",
    "Raid invites: officers can invite everyone who signed up with one click. If a raid starts without you, you get a reminder.",
    "DKP decay: officers can take a percentage off everyone's DKP, now or automatically each week.",
    "Hidden bids: officers can switch auctions to hidden bids, where the winner pays the second-highest bid + 1.",
  } },
  { version = "2.6.0", date = "Nov 15, 2026", items = {
    "Loot history: on the DKP tab, switch to Loot history to see every item won in an auction, who won it, for how much, and on which raid night. Hover an item for its tooltip.",
    "Officers can export DKP as a text backup of standings, loot and every DKP change.",
    "More reliable on busy nights: messages are now paced to stay within the game's limits, so kills and loot bids are no longer lost when lots is happening at once.",
  } },
  { version = "2.5.0", date = "Nov 15, 2026", items = {
    "Killing blows and assists: the guild member who hit an enemy last gets the killing blow, everyone else who helped gets an assist. Top Head Hunters now ranks by killing blows, with assists shown alongside.",
    "Honor kills only: grey kills (much lower level, no honor) no longer count, on by default for the guild. Officers can change it in Settings.",
    "Officers can right-click a kill on the Kills tab to remove it for the whole guild.",
  } },
  { version = "2.4.1", date = "Nov 15, 2026", items = {
    "Fixed: guildmates' Kills tabs and Top Head Hunters could show different kills. Kill logs now compare with each other every 15 minutes and fill in anything missing, both ways, so everyone ends up with the same kills.",
    "Fixed: killing the same player again within 2 minutes (camping) only counted once. Kills are now only combined when they're within 30 seconds of each other.",
  } },
  { version = "2.4.0", date = "Nov 15, 2026", items = {
    "New Addon tab: see which guild members have The Imperium installed, which version, and when their addon was last seen. Filter by who has it, who doesn't, or who needs to update.",
    "Click Check now to ask everyone online. Open it with /bannerhold addon.",
  } },
  { version = "2.3.0", date = "Nov 15, 2026", items = {
    "New: when a guild member kills a wanted player, the bounty is claimed and they drop off the Wanted list. Their count starts over, so they come back if they keep ganking.",
    "Kill alerts say \"Wanted bounty claimed!\" when the victim was on the Wanted list.",
    "You can turn this off with the new checkbox at the bottom of the Wanted tab.",
  } },
  { version = "2.2.0", date = "Nov 14, 2026", items = {
    "New: this Updates panel. It appears after each update with what changed. Reopen it with /bannerhold updates.",
  } },
  { version = "2.1.1", date = "Nov 14, 2026", items = {
    "Fixed: deaths to damage over time were announced as falling to death. A death now only counts as a fall if you dropped for at least a second, died as you landed, and weren't in combat.",
  } },
  { version = "2.1.0", date = "Nov 13, 2026", items = {
    "Release! Test data from before launch was cleared so the guild starts fresh. Your settings were kept.",
    "PvP kill alerts with the Top Head Hunters board, a Wanted list of gankers, raid sign-ups, and DKP with live loot auctions.",
  } },
}

local MAX_SHOWN = 6
local win

-- Entries newer than `since` (all of them if since is nil), newest first.
local function changesSince(since)
  local out = {}
  for _, c in ipairs(CHANGES) do
    if since and ns.CompareVersions(c.version, since) <= 0 then break end
    out[#out + 1] = c
    if #out >= MAX_SHOWN then break end
  end
  return out
end

local function buildText(entries)
  local lines = {}
  for _, c in ipairs(entries) do
    lines[#lines + 1] = ("%sVersion %s|r  |cff8b95a7%s|r"):format(ns.COLOR, c.version, c.date)
    for _, item in ipairs(c.items) do lines[#lines + 1] = "  |cffe0b94c•|r  " .. item end
    lines[#lines + 1] = " "
  end
  return table.concat(lines, "\n")
end

local function create()
  local f = UI.Window("BannerholdUpdates", 460, 380, "What's new")
  win = f
  f:ClearAllPoints()
  f:SetPoint("CENTER", 0, 40)

  local icon = f:CreateTexture(nil, "ARTWORK")
  icon:SetSize(48, 48)
  icon:SetPoint("TOPLEFT", 16, -32)
  ns.Emblem(icon, "PORTRAIT")

  f.heading = UI.Label(f, "", "GameFontNormalLarge")
  f.heading:SetPoint("TOPLEFT", icon, "TOPRIGHT", 12, -4)
  f.sub = UI.Label(f, "", "GameFontHighlightSmall")
  f.sub:SetPoint("TOPLEFT", f.heading, "BOTTOMLEFT", 0, -6)

  local sf = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")

  UI.SkinScrollBar(sf)
  sf:SetPoint("TOPLEFT", 16, -92)
  sf:SetPoint("BOTTOMRIGHT", -34, 50)
  local content = CreateFrame("Frame", nil, sf)
  content:SetSize(400, 10)
  sf:SetScrollChild(content)
  f.body = UI.Label(content, "", "GameFontHighlight")
  f.body:SetPoint("TOPLEFT", 0, 0)
  f.body:SetWidth(400)
  f.body:SetSpacing(3)
  f.content = content

  local close = UI.Button(f, "Got it", 110, "primary")
  close:SetPoint("BOTTOM", 0, 14)
  close:SetScript("OnClick", function() f:Hide() end)
end

-- since: the version you last used, or nil to show recent changes.
function ns.ShowUpdates(since)
  if InCombatLockdown() then
    ns.Say("The Updates panel will open after combat.")
    ns.pendingUpdates = since or false
    return
  end
  local entries = changesSince(since)
  if #entries == 0 then entries = changesSince(nil) end
  if not win then create() end
  win.heading:SetText(since and ("Updated to version " .. ns.version) or ("Version " .. ns.version))
  win.sub:SetText(since and ("Here's what changed since version " .. since .. ".") or "Recent changes to Bannerhold.")
  win.body:SetText(buildText(entries))
  win.content:SetHeight(math.max(10, win.body:GetStringHeight() + 10))
  win:Show()
end

ns.OnEvent("PLAYER_REGEN_ENABLED", function()
  if ns.pendingUpdates ~= nil then
    local since = ns.pendingUpdates or nil
    ns.pendingUpdates = nil
    C_Timer.After(1, function() ns.ShowUpdates(since) end)
  end
end)

-- After login, show the panel once if the addon was updated since last time.
ns.OnEvent("PLAYER_ENTERING_WORLD", function(isLogin, isReload)
  if not (isLogin or isReload) then return end
  local last = ns.db.lastSeenVersion
  ns.db.lastSeenVersion = ns.version
  if last == nil then
    -- Brand-new installs see nothing. Players who had the addon before this
    -- panel existed were on 2.1.1 or earlier.
    if ns.isNewInstall then return end
    last = "2.1.1"
  end
  if ns.CompareVersions(ns.version, last) <= 0 then return end
  C_Timer.After(6, function() ns.ShowUpdates(last) end)
end)
