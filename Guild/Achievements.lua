--[[
  Warcrest
  Achievements and titles.

  Achievements are worked out from the guild's shared history (the kill log,
  the death history and the ledger), so every guildmate sees the same ones
  without anything extra being sent. Once earned, an achievement is also
  remembered on your own computer, so it stays even if old history is
  archived or a log is cleared.

  Some achievements come with a title. Members pick one to show (or none);
  the choice is a ledger entry (kind TI) written by the member themselves,
  and a title only shows if its owner has earned it.

  When someone earns an achievement while you're online, the guild hears
  about it (alert type "achievement").
]]

local _, ns = ...
local Ambiguate = ns.Ambiguate

local REVENGE_WINDOW = 30 * 60
local WANTED_WINDOW = 30 * 86400
local WANTED_KILLS = 3
local NEMESIS_KILLS = 3
local ANNOUNCE_WITHIN = 60 * 60   -- only announce achievements earned in the last hour (a kill can arrive late)
local MAX_LEVEL = 60
local DOUBLE_KILL = 10            -- seconds between two killing blows for a Double Kill
local GRUDGE_KILLS = 5            -- kills of one enemy for Grudge Match
local PERFECT_MIN = 4             -- raid nights a month needs for Perfect Attendance
local WEEK = 7 * 86400
local TRIPLE_KILL = 20            -- seconds for three killing blows
local QUAD_KILL = 30              -- seconds for four

------------------------------------------------------------------------
-- The achievements. goal: how many of stat it takes. stat(s) returns the
-- player's list of times (sorted), or a time / nil for one-off ones.
------------------------------------------------------------------------
local LIST = {
  -- PvP: killing blows
  { id = "kill1", cat = "pvp", name = "First Blood", desc = "Land a killing blow on an enemy player.", stat = "kills", goal = 1 },
  { id = "kill5", cat = "pvp", name = "Blooded", desc = "5 killing blows on enemy players.", stat = "kills", goal = 5 },
  { id = "kill10", cat = "pvp", name = "Skirmisher", desc = "10 killing blows on enemy players.", stat = "kills", goal = 10 },
  { id = "kill25", cat = "pvp", name = "Head Hunter", desc = "25 killing blows on enemy players.", stat = "kills", goal = 25 },
  { id = "kill50", cat = "pvp", name = "Bloodthirsty", desc = "50 killing blows.", stat = "kills", goal = 50 },
  { id = "kill100", cat = "pvp", name = "Executioner", desc = "100 killing blows.", stat = "kills", goal = 100, title = "the Executioner" },
  { id = "kill250", cat = "pvp", name = "Warlord", desc = "250 killing blows.", stat = "kills", goal = 250, title = "the Warlord" },
  { id = "kill500", cat = "pvp", name = "Legend", desc = "500 killing blows.", stat = "kills", goal = 500, title = "the Legend" },
  { id = "kill750", cat = "pvp", name = "Warmonger", desc = "750 killing blows.", stat = "kills", goal = 750, title = "the Warmonger" },
  { id = "kill1000", cat = "pvp", name = "Thousand Cuts", desc = "1,000 killing blows.", stat = "kills", goal = 1000, title = "the Merciless" },
  -- PvP: assists
  { id = "assist1", cat = "pvp", name = "Lending a Hand", desc = "Help a guildmate with a kill.", stat = "assists", goal = 1 },
  { id = "assist10", cat = "pvp", name = "Backup", desc = "Help guildmates with 10 kills.", stat = "assists", goal = 10 },
  { id = "assist25", cat = "pvp", name = "Wingman", desc = "Help guildmates with 25 kills.", stat = "assists", goal = 25 },
  { id = "assist50", cat = "pvp", name = "Brothers in Arms", desc = "Help guildmates with 50 kills.", stat = "assists", goal = 50 },
  { id = "assist100", cat = "pvp", name = "Shield Brother", desc = "Help guildmates with 100 kills.", stat = "assists", goal = 100 },
  { id = "assist250", cat = "pvp", name = "War Band", desc = "Help guildmates with 250 kills.", stat = "assists", goal = 250, title = "the Steadfast" },
  { id = "assist500", cat = "pvp", name = "Unbreakable Line", desc = "Help guildmates with 500 kills.", stat = "assists", goal = 500, title = "the Shieldwall" },
  -- PvP: streaks and quick kills
  { id = "streak3", cat = "pvp", name = "On a Roll", desc = "3 killing blows in a row without dying.", stat = "streak3", goal = 1 },
  { id = "streak5", cat = "pvp", name = "Rampage", desc = "A 5-kill streak.", stat = "streak5", goal = 1 },
  { id = "streak10", cat = "pvp", name = "Unstoppable", desc = "A 10-kill streak.", stat = "streak10", goal = 1, title = "the Unstoppable" },
  { id = "streak15", cat = "pvp", name = "Godlike", desc = "A 15-kill streak.", stat = "streak15", goal = 1, title = "the Godlike" },
  { id = "streak20", cat = "pvp", name = "Massacre", desc = "A 20-kill streak.", stat = "streak20", goal = 1, title = "the Butcher" },
  { id = "streak25", cat = "pvp", name = "Wrath Incarnate", desc = "A 25-kill streak.", stat = "streak25", goal = 1, title = "the Wrathful" },
  { id = "double", cat = "pvp", name = "Double Kill", desc = "Two killing blows within 10 seconds.", stat = "double", goal = 1 },
  { id = "triple", cat = "pvp", name = "Triple Kill", desc = "Three killing blows within 20 seconds.", stat = "triple", goal = 1 },
  { id = "quad", cat = "pvp", name = "Quad Kill", desc = "Four killing blows within 30 seconds.", stat = "quad", goal = 1, title = "the Whirlwind" },
  { id = "day10", cat = "pvp", name = "Busy Day", desc = "10 killing blows in one day.", stat = "day10", goal = 1 },
  { id = "day20", cat = "pvp", name = "Day of Reckoning", desc = "20 killing blows in one day.", stat = "day20", goal = 1, title = "the Reckoner" },
  -- PvP: when and where
  { id = "night", cat = "pvp", name = "Night Owl", desc = "A killing blow between midnight and 5 in the morning.", stat = "night", goal = 1 },
  { id = "night10", cat = "pvp", name = "Creature of the Night", desc = "10 killing blows between midnight and 5 in the morning.", stat = "night", goal = 10 },
  { id = "night50", cat = "pvp", name = "Nightstalker", desc = "50 killing blows between midnight and 5 in the morning.", stat = "night", goal = 50, title = "the Nightstalker" },
  { id = "morning", cat = "pvp", name = "Early Bird", desc = "A killing blow between 5 and 8 in the morning.", stat = "morning", goal = 1 },
  { id = "weekend", cat = "pvp", name = "Weekend Warrior", desc = "25 killing blows on Saturdays and Sundays.", stat = "weekend", goal = 25 },
  { id = "zones5", cat = "pvp", name = "Wanderer", desc = "Killing blows in 5 different zones.", stat = "zones", goal = 5 },
  { id = "zones", cat = "pvp", name = "Globetrotter", desc = "Killing blows in 10 different zones.", stat = "zones", goal = 10 },
  { id = "zones20", cat = "pvp", name = "World Warrior", desc = "Killing blows in 20 different zones.", stat = "zones", goal = 20 },
  { id = "zones30", cat = "pvp", name = "No Safe Place", desc = "Killing blows in 30 different zones.", stat = "zones", goal = 30, title = "the Wayfarer" },
  { id = "bg1", cat = "pvp", name = "Battleground Blood", desc = "A killing blow in a battleground.", stat = "bg", goal = 1 },
  { id = "bg50", cat = "pvp", name = "Battle Hardened", desc = "50 killing blows in battlegrounds.", stat = "bg", goal = 50 },
  { id = "bg250", cat = "pvp", name = "Warmaster", desc = "250 killing blows in battlegrounds.", stat = "bg", goal = 250, title = "the Warmaster" },
  -- PvP: who
  { id = "victims10", cat = "pvp", name = "Making Enemies", desc = "Killing blows on 10 different enemy players.", stat = "victims", goal = 10 },
  { id = "victims50", cat = "pvp", name = "Infamous", desc = "Killing blows on 50 different enemy players.", stat = "victims", goal = 50 },
  { id = "victims100", cat = "pvp", name = "Most Wanted", desc = "Killing blows on 100 different enemy players.", stat = "victims", goal = 100, title = "the Infamous" },
  { id = "victims250", cat = "pvp", name = "Dread", desc = "Killing blows on 250 different enemy players.", stat = "victims", goal = 250, title = "the Dread" },
  { id = "skull1", cat = "pvp", name = "Giant Slayer", desc = "A killing blow on an enemy whose level shows as ??.", stat = "skull", goal = 1 },
  { id = "skull10", cat = "pvp", name = "Kingslayer", desc = "10 killing blows on enemies whose level shows as ??.", stat = "skull", goal = 10, title = "the Giant Slayer" },
  { id = "rival10", cat = "pvp", name = "Bad Blood", desc = "10 killing blows on players of rival guilds.", stat = "rivalKills", goal = 10 },
  { id = "rival50", cat = "pvp", name = "Blood Feud", desc = "50 killing blows on players of rival guilds.", stat = "rivalKills", goal = 50, title = "the Feudbringer" },
  { id = "guilds5", cat = "pvp", name = "Equal Opportunity", desc = "Killing blows on players of 5 different enemy guilds.", stat = "guilds", goal = 5 },
  { id = "guilds15", cat = "pvp", name = "Guild Breaker", desc = "Killing blows on players of 15 different enemy guilds.", stat = "guilds", goal = 15 },
  -- Hunts: revenge, bounties, grudges and the monthly crown
  { id = "revenge1", cat = "hunt", name = "Payback", desc = "Kill an enemy who killed a guildmate in the last 30 minutes.", stat = "revenge", goal = 1 },
  { id = "revenge3", cat = "hunt", name = "Vengeful", desc = "3 revenge kills.", stat = "revenge", goal = 3 },
  { id = "revenge10", cat = "hunt", name = "Avenger", desc = "10 revenge kills.", stat = "revenge", goal = 10, title = "the Avenger" },
  { id = "revenge25", cat = "hunt", name = "Retribution", desc = "25 revenge kills.", stat = "revenge", goal = 25 },
  { id = "revenge50", cat = "hunt", name = "Wrath of the Guild", desc = "50 revenge kills.", stat = "revenge", goal = 50, title = "the Vengeful" },
  { id = "vendetta", cat = "hunt", name = "Personal Vendetta", desc = "Kill an enemy within 30 minutes of them killing you.", stat = "vendetta", goal = 1 },
  { id = "avenge5", cat = "hunt", name = "Guardian", desc = "Avenge 5 different guildmates.", stat = "avenged", goal = 5 },
  { id = "avenge20", cat = "hunt", name = "Protector of the Guild", desc = "Avenge 20 different guildmates.", stat = "avenged", goal = 20, title = "the Protector" },
  { id = "bounty", cat = "hunt", name = "Bounty Hunter", desc = "Kill an enemy who killed guild members 3 times in 30 days.", stat = "bounty", goal = 1, title = "the Bounty Hunter" },
  { id = "bounty5", cat = "hunt", name = "Manhunter", desc = "5 kills of wanted enemies.", stat = "bounty", goal = 5, title = "the Manhunter" },
  { id = "bounty10", cat = "hunt", name = "Tracker", desc = "10 kills of wanted enemies.", stat = "bounty", goal = 10 },
  { id = "bounty25", cat = "hunt", name = "Apex Predator", desc = "25 kills of wanted enemies.", stat = "bounty", goal = 25, title = "the Apex Predator" },
  { id = "claim1", cat = "hunt", name = "Collector", desc = "Claim a bounty an officer placed.", stat = "claims", goal = 1, title = "the Collector" },
  { id = "claim3", cat = "hunt", name = "Paid in Full", desc = "Claim 3 bounties.", stat = "claims", goal = 3 },
  { id = "claim10", cat = "hunt", name = "Mercenary", desc = "Claim 10 bounties.", stat = "claims", goal = 10, title = "the Mercenary" },
  { id = "nemesis", cat = "hunt", name = "Nemesis Slayer", desc = "Kill an enemy who has killed you 3 times.", stat = "nemesis", goal = 1, title = "the Nemesis Slayer" },
  { id = "nemesis3", cat = "hunt", name = "Turning the Tables", desc = "Kill enemies who had killed you 3 times, 3 times over.", stat = "nemesis", goal = 3 },
  { id = "grudge", cat = "hunt", name = "Grudge Match", desc = "Kill the same enemy player 5 times.", stat = "grudge", goal = 1, title = "the Relentless" },
  { id = "grudge10", cat = "hunt", name = "Obsessed", desc = "Kill the same enemy player 10 times.", stat = "grudge10", goal = 1 },
  { id = "champion", cat = "hunt", name = "Champion", desc = "Finish a month top of Top Head Hunters.", stat = "champion", goal = 1, title = "the Champion" },
  { id = "champion3", cat = "hunt", name = "Dynasty", desc = "Finish 3 months top of Top Head Hunters.", stat = "champion", goal = 3, title = "the Undisputed" },
  { id = "champion6", cat = "hunt", name = "Reign", desc = "Finish 6 months top of Top Head Hunters.", stat = "champion", goal = 6, title = "the Sovereign" },
  { id = "champion12", cat = "hunt", name = "Eternal", desc = "Finish 12 months top of Top Head Hunters.", stat = "champion", goal = 12, title = "the Eternal" },
  -- Hunts: the other side of it
  { id = "death1", cat = "hunt", name = "Welcome to the War", desc = "Die to an enemy player.", stat = "pvpDeaths", goal = 1 },
  { id = "death50", cat = "hunt", name = "Battle Scarred", desc = "Die to enemy players 50 times.", stat = "pvpDeaths", goal = 50 },
  { id = "death100", cat = "hunt", name = "Punching Bag", desc = "Die to enemy players 100 times.", stat = "pvpDeaths", goal = 100, title = "the Undaunted" },
  { id = "hunted", cat = "hunt", name = "Marked", desc = "Be killed by the same enemy player 5 times.", stat = "hunted", goal = 1 },
  { id = "fall", cat = "hunt", name = "Gravity Wins", desc = "Die from falling.", stat = "falls", goal = 1 },
  { id = "drown", cat = "hunt", name = "Sleeps with the Fishes", desc = "Drown.", stat = "drowns", goal = 1 },
  { id = "fatigue", cat = "hunt", name = "Too Far Out", desc = "Die of fatigue in deep water.", stat = "fatigue", goal = 1 },
  -- Raids: attendance
  { id = "raid1", cat = "raid", name = "Raider", desc = "Attend a raid night.", stat = "raids", goal = 1 },
  { id = "raid10", cat = "raid", name = "Veteran Raider", desc = "Attend 10 raid nights.", stat = "raids", goal = 10 },
  { id = "raid25", cat = "raid", name = "Iron Raider", desc = "Attend 25 raid nights.", stat = "raids", goal = 25, title = "the Iron Raider" },
  { id = "raid50", cat = "raid", name = "Stalwart", desc = "Attend 50 raid nights.", stat = "raids", goal = 50, title = "the Stalwart" },
  { id = "raid75", cat = "raid", name = "Raid Machine", desc = "Attend 75 raid nights.", stat = "raids", goal = 75 },
  { id = "raid100", cat = "raid", name = "Centurion", desc = "Attend 100 raid nights.", stat = "raids", goal = 100, title = "the Centurion" },
  { id = "perfect", cat = "raid", name = "Perfect Attendance", desc = "Attend every raid night in a month (at least 4).", stat = "perfect", goal = 1, title = "the Dependable" },
  { id = "perfect3", cat = "raid", name = "Reliable", desc = "Perfect attendance for 3 months.", stat = "perfect", goal = 3 },
  { id = "perfect6", cat = "raid", name = "Rock Solid", desc = "Perfect attendance for 6 months.", stat = "perfect", goal = 6, title = "the Rock" },
  { id = "signup10", cat = "raid", name = "Ready and Willing", desc = "Accept 10 raid sign-ups.", stat = "signups", goal = 10 },
  { id = "signup25", cat = "raid", name = "Always There", desc = "Accept 25 raid sign-ups.", stat = "signups", goal = 25 },
  { id = "signup50", cat = "raid", name = "Raid Regular", desc = "Accept 50 raid sign-ups.", stat = "signups", goal = 50 },
  { id = "standby1", cat = "raid", name = "On the Bench", desc = "Be on standby for a raid night.", stat = "standby", goal = 1 },
  { id = "standby5", cat = "raid", name = "Team Player", desc = "Be on standby for 5 raid nights.", stat = "standby", goal = 5, title = "the Selfless" },
  { id = "lead1", cat = "raid", name = "Raid Leader", desc = "Start a raid night.", stat = "raidsLed", goal = 1 },
  { id = "lead10", cat = "raid", name = "Commander", desc = "Start 10 raid nights.", stat = "raidsLed", goal = 10, title = "the Commander" },
  -- Raids: bosses
  { id = "boss1", cat = "raid", name = "Boss Down", desc = "Be there when the guild kills a raid boss.", stat = "bosses", goal = 1 },
  { id = "boss10", cat = "raid", name = "Boss Hunter", desc = "Be there for 10 guild boss kills.", stat = "bosses", goal = 10 },
  { id = "boss25", cat = "raid", name = "Boss Slayer", desc = "Be there for 25 guild boss kills.", stat = "bosses", goal = 25, title = "the Slayer" },
  { id = "boss50", cat = "raid", name = "Bane of Bosses", desc = "Be there for 50 guild boss kills.", stat = "bosses", goal = 50 },
  { id = "boss100", cat = "raid", name = "Raidbreaker", desc = "Be there for 100 guild boss kills.", stat = "bosses", goal = 100, title = "the Raidbreaker" },
  { id = "boss250", cat = "raid", name = "Godslayer", desc = "Be there for 250 guild boss kills.", stat = "bosses", goal = 250, title = "the Godslayer" },
  { id = "bigNight", cat = "raid", name = "Big Night", desc = "Be there for 5 boss kills in one day.", stat = "bigNight", goal = 1 },
  { id = "bigNight10", cat = "raid", name = "Clean Sweep", desc = "Be there for 10 boss kills in one day.", stat = "bigNight10", goal = 1 },
  { id = "pioneer", cat = "raid", name = "Pioneer", desc = "Be there for the guild's first kill of a boss.", stat = "bossFirsts", goal = 1, title = "the Pioneer" },
  { id = "pioneer5", cat = "raid", name = "Trailblazer", desc = "Be there for the guild's first kill of 5 bosses.", stat = "bossFirsts", goal = 5, title = "the Trailblazer" },
  { id = "pioneer10", cat = "raid", name = "Pathfinder", desc = "Be there for the guild's first kill of 10 bosses.", stat = "bossFirsts", goal = 10 },
  { id = "pioneer20", cat = "raid", name = "Vanguard", desc = "Be there for the guild's first kill of 20 bosses.", stat = "bossFirsts", goal = 20, title = "the Vanguard" },
  { id = "clear", cat = "raid", name = "Full Clear", desc = "Kill every boss of a raid within one week.", stat = "fullClear", goal = 1, title = "the Conqueror" },
  { id = "clear3", cat = "raid", name = "Raid Conqueror", desc = "Full clears of 3 different raids.", stat = "fullClear", goal = 3 },
  { id = "clear5", cat = "raid", name = "World Conqueror", desc = "Full clears of 5 different raids.", stat = "fullClear", goal = 5, title = "the Invincible" },
  -- Loot
  { id = "loot1", cat = "loot", name = "Lucky", desc = "Win an item at a loot auction or roll.", stat = "loot", goal = 1 },
  { id = "loot10", cat = "loot", name = "Geared Up", desc = "Win 10 items.", stat = "loot", goal = 10 },
  { id = "loot25", cat = "loot", name = "Well Equipped", desc = "Win 25 items.", stat = "loot", goal = 25 },
  { id = "loot50", cat = "loot", name = "Treasure Hunter", desc = "Win 50 items.", stat = "loot", goal = 50 },
  { id = "loot100", cat = "loot", name = "Hoarder", desc = "Win 100 items.", stat = "loot", goal = 100, title = "the Hoarder" },
  { id = "lootNight", cat = "loot", name = "Jackpot", desc = "Win 5 items in one day of raiding.", stat = "lootNight", goal = 1 },
  { id = "roll", cat = "loot", name = "Lucky Roll", desc = "Win an item in a free roll.", stat = "rolls", goal = 1 },
  { id = "roll5", cat = "loot", name = "Dice Roller", desc = "Win 5 items in free rolls.", stat = "rolls", goal = 5 },
  { id = "roll10", cat = "loot", name = "Lady Luck", desc = "Win 10 items in free rolls.", stat = "rolls", goal = 10, title = "the Lucky" },
  { id = "council1", cat = "loot", name = "Council's Choice", desc = "Win an item from the loot council.", stat = "council", goal = 1 },
  { id = "council10", cat = "loot", name = "Council Favorite", desc = "Win 10 items from the loot council.", stat = "council", goal = 10 },
  { id = "spender", cat = "loot", name = "Big Spender", desc = "Spend 100 DKP or more on one item.", stat = "bigBuy", goal = 1, title = "the Big Spender" },
  { id = "spend200", cat = "loot", name = "High Roller", desc = "Spend 200 DKP or more on one item.", stat = "bigBuy200", goal = 1 },
  { id = "spend500", cat = "loot", name = "All In", desc = "Spend 500 DKP or more on one item.", stat = "bigBuy500", goal = 1, title = "the Extravagant" },
  { id = "spent1000", cat = "loot", name = "Investor", desc = "Spend 1,000 DKP on items in all.", stat = "spent1000", goal = 1 },
  { id = "dkp500", cat = "loot", name = "Saver", desc = "Have 500 DKP.", stat = "dkp500", goal = 1 },
  { id = "dkp1000", cat = "loot", name = "Bank of the Guild", desc = "Have 1,000 DKP.", stat = "dkp1000", goal = 1, title = "the Wealthy" },
  { id = "wish", cat = "loot", name = "Wish Granted", desc = "Win an item that was on your wishlist.", stat = "wish", goal = 1 },
  { id = "wish5", cat = "loot", name = "Fortunate", desc = "Win 5 items that were on your wishlist.", stat = "wish", goal = 5, title = "the Fortunate" },
  { id = "wish10", cat = "loot", name = "Dreams Come True", desc = "Win 10 items that were on your wishlist.", stat = "wish", goal = 10 },
  -- Social: events, profiles, crafting and the guild
  { id = "event1", cat = "social", name = "Joining In", desc = "Attend a guild event.", stat = "events", goal = 1 },
  { id = "event10", cat = "social", name = "Regular", desc = "Attend 10 guild events.", stat = "events", goal = 10 },
  { id = "event25", cat = "social", name = "Life of the Party", desc = "Attend 25 guild events.", stat = "events", goal = 25, title = "the Life of the Party" },
  { id = "event50", cat = "social", name = "Pillar of the Guild", desc = "Attend 50 guild events.", stat = "events", goal = 50, title = "the Pillar" },
  { id = "eventKinds", cat = "social", name = "Jack of All Trades", desc = "Attend 5 different kinds of guild event.", stat = "eventKinds", goal = 5 },
  { id = "plan1", cat = "social", name = "Organizer", desc = "Plan a guild event.", stat = "planned", goal = 1 },
  { id = "plan10", cat = "social", name = "Event Master", desc = "Plan 10 guild events.", stat = "planned", goal = 10, title = "the Host" },
  { id = "profile", cat = "social", name = "Open Book", desc = "Share your profile.", stat = "profile", goal = 1 },
  { id = "titled", cat = "social", name = "Show Off", desc = "Show a title by your name.", stat = "titled", goal = 1 },
  { id = "alt1", cat = "social", name = "Second Character", desc = "Link an alt to your main.", stat = "alt1", goal = 1 },
  { id = "alts", cat = "social", name = "Altoholic", desc = "Link 3 alts to your main.", stat = "alts", goal = 1 },
  { id = "level10", cat = "social", name = "Getting Started", desc = "Reach level 10.", stat = "level10", goal = 1 },
  { id = "level20", cat = "social", name = "Adventurer", desc = "Reach level 20.", stat = "level20", goal = 1 },
  { id = "level30", cat = "social", name = "Seasoned", desc = "Reach level 30.", stat = "level30", goal = 1 },
  { id = "level40", cat = "social", name = "Mounted Up", desc = "Reach level 40.", stat = "level40", goal = 1 },
  { id = "level50", cat = "social", name = "Almost There", desc = "Reach level 50.", stat = "level50", goal = 1 },
  { id = "level", cat = "social", name = "Max Level", desc = "Reach level " .. MAX_LEVEL .. ".", stat = "maxLevel", goal = 1 },
  { id = "prof1", cat = "social", name = "Apprentice Crafter", desc = "Share a profession's recipes with the guild.", stat = "profs", goal = 1 },
  { id = "prof2", cat = "social", name = "Two Trades", desc = "Share two professions with the guild.", stat = "profs", goal = 2 },
  { id = "rank300", cat = "social", name = "Master Crafter", desc = "Reach 300 in a profession.", stat = "rank300", goal = 1, title = "the Artisan" },
  { id = "recipes50", cat = "social", name = "Recipe Collector", desc = "Know 50 recipes between your professions.", stat = "recipes", goal = 50 },
  { id = "recipes100", cat = "social", name = "Well Read", desc = "Know 100 recipes between your professions.", stat = "recipes", goal = 100 },
  { id = "recipes200", cat = "social", name = "Grand Master Crafter", desc = "Know 200 recipes between your professions.", stat = "recipes", goal = 200, title = "the Grand Crafter" },
  { id = "recruit1", cat = "social", name = "Recruiter", desc = "Add a recruit who goes on to join the guild.", stat = "recruits", goal = 1 },
  { id = "recruit5", cat = "social", name = "Headhunter", desc = "Add 5 recruits who go on to join the guild.", stat = "recruits", goal = 5, title = "the Recruiter" },
  { id = "decorated", cat = "social", name = "Decorated", desc = "Earn 10 other achievements.", stat = "others", goal = 10, title = "the Decorated" },
  { id = "hero", cat = "social", name = "Guild Hero", desc = "Earn 25 other achievements.", stat = "others", goal = 25, title = "the Hero" },
  { id = "meta50", cat = "social", name = "Overachiever", desc = "Earn 50 other achievements.", stat = "others", goal = 50, title = "the Overachiever" },
  { id = "meta75", cat = "social", name = "Living Legend", desc = "Earn 75 other achievements.", stat = "others", goal = 75, title = "the Living Legend" },
  { id = "meta100", cat = "social", name = "Paragon", desc = "Earn 100 other achievements.", stat = "others", goal = 100, title = "the Paragon" },
}
ns.ACHIEVEMENTS = LIST
local BY_ID = {}
for i, a in ipairs(LIST) do a.order = i; BY_ID[a.id] = a end
function ns.Achievement(id) return BY_ID[id] end

------------------------------------------------------------------------
-- Stats from the shared history, for everyone at once
------------------------------------------------------------------------
local index -- built once per change

local function push(t, key, value)
  local list = t[key]
  if not list then list = {}; t[key] = list end
  list[#list + 1] = value
end

local function sortAll(t)
  for _, list in pairs(t) do table.sort(list) end
end

-- The PvP half comes only from the kill and death logs (and kills officers
-- removed), so it's kept until one of those changes.
local pvpIndex, pvpStamp
local historyVersion = 0

local function buildPvP()
  local kills, assists = {}, {}
  local deathsByKiller = {} -- enemy key -> times they killed a guild member
  local victimsOf = {}      -- enemy key -> { { t, member key } }: who they killed
  local deathsOf = {}       -- member key -> { enemy key -> sorted times }
  local pvpDeaths, falls, drowns, fatigue, hunted = {}, {}, {}, {}, {}
  for _, d in ipairs(ns.db.deathLog or {}) do
    local who = ns.Key(d.who or "")
    if d.kind == "pvp" and d.killer and d.killer ~= "" then
      local enemy = ns.Key(d.killer)
      push(deathsByKiller, enemy, d.t)
      push(victimsOf, enemy, { d.t, who })
      deathsOf[who] = deathsOf[who] or {}
      push(deathsOf[who], enemy, d.t)
      push(pvpDeaths, who, d.t)
    elseif d.kind == "environment" then
      if d.sub == "falling" then push(falls, who, d.t)
      elseif d.sub == "drowning" then push(drowns, who, d.t)
      elseif d.sub == "fatigue" then push(fatigue, who, d.t) end
    end
  end
  sortAll(deathsByKiller)
  for who, byEnemy in pairs(deathsOf) do
    sortAll(byEnemy)
    -- The same enemy, a 5th time.
    for _, times in pairs(byEnemy) do
      if times[5] then push(hunted, who, times[5]) end
    end
  end

  -- How many times in a sorted list fall in [fromT, toT): two binary searches.
  local function firstAtOrAfter(list, t)
    local lo, hi = 1, #list + 1
    while lo < hi do
      local mid = math.floor((lo + hi) / 2)
      if list[mid] < t then lo = mid + 1 else hi = mid end
    end
    return lo
  end
  local function countIn(list, fromT, toT)
    if not list then return 0 end
    return firstAtOrAfter(list, toT) - firstAtOrAfter(list, fromT)
  end

  local revenge, bounty, nemesis = {}, {}, {}
  local double, night, zones, grudge = {}, {}, {}, {}
  local zoneSeen, victimCount, lastKill = {}, {}, {}
  local triple, quad, morning, weekend, day10, day20 = {}, {}, {}, {}, {}, {}
  local victims, skull, bg, rivalKills, guilds, grudge10, vendetta, avenged = {}, {}, {}, {}, {}, {}, {}, {}
  local recent, perDay, guildSeen, avengedSeen = {}, {}, {}, {}
  -- Oldest first, so "the 10th zone" and "the 5th time" happen in order.
  -- (The kill log is kept newest first, so reading it backwards is enough; sort
  -- only if something put it out of order.)
  local log, src, sorted = {}, ns.db.killLog or {}, true
  for i = #src, 1, -1 do
    log[#log + 1] = src[i]
    if #log > 1 and log[#log].t < log[#log - 1].t then sorted = false end
  end
  if not sorted then table.sort(log, function(a, b) return a.t < b.t end) end
  for _, k in ipairs(log) do
    if not ns.KillHidden(k) then
      local kb = ns.KillingBlow(k)
      if kb then
        local me, enemy = ns.Key(kb), ns.Key(k.victim)
        push(kills, me, k.t)
        local theirs = deathsByKiller[enemy]
        if theirs then
          if countIn(theirs, k.t - REVENGE_WINDOW, k.t + 1) > 0 then
            push(revenge, me, k.t)
            -- Which guildmates this avenged (each one counts once).
            avengedSeen[me] = avengedSeen[me] or {}
            for _, v in ipairs(victimsOf[enemy]) do
              local mate = v[2]
              if mate ~= me and v[1] >= k.t - REVENGE_WINDOW and v[1] <= k.t and not avengedSeen[me][mate] then
                avengedSeen[me][mate] = true
                push(avenged, me, k.t)
              end
            end
          end
          if countIn(theirs, k.t - WANTED_WINDOW, k.t) >= WANTED_KILLS then push(bounty, me, k.t) end
        end
        local mine = deathsOf[me] and deathsOf[me][enemy]
        if mine and countIn(mine, 0, k.t) >= NEMESIS_KILLS then push(nemesis, me, k.t) end
        if mine and countIn(mine, k.t - REVENGE_WINDOW, k.t + 1) > 0 then push(vendetta, me, k.t) end
        -- Three within 20 seconds, four within 30.
        local r = recent[me] or {}
        recent[me] = r
        r[#r + 1] = k.t
        if #r > 4 then table.remove(r, 1) end
        if #r >= 3 and k.t - r[#r - 2] <= TRIPLE_KILL then push(triple, me, k.t) end
        if #r >= 4 and k.t - r[#r - 3] <= QUAD_KILL then push(quad, me, k.t) end
        -- A big day.
        local day = me .. date("%Y-%m-%d", k.t)
        perDay[day] = (perDay[day] or 0) + 1
        if perDay[day] == 10 then push(day10, me, k.t) end
        if perDay[day] == 20 then push(day20, me, k.t) end
        local wday = tonumber(date("%w", k.t))
        if wday == 0 or wday == 6 then push(weekend, me, k.t) end
        -- Who and where.
        if k.kind == "kill_bg" then push(bg, me, k.t) end
        if tonumber(k.level) and tonumber(k.level) < 0 then push(skull, me, k.t) end
        local g = k.vg or ns.EnemyGuild(k.victim)
        if g then
          if ns.IsRival(g) then push(rivalKills, me, k.t) end
          guildSeen[me] = guildSeen[me] or {}
          if not guildSeen[me][g] then guildSeen[me][g] = true; push(guilds, me, k.t) end
        end
        -- Two killing blows within 10 seconds.
        if lastKill[me] and k.t - lastKill[me] <= DOUBLE_KILL then push(double, me, k.t) end
        lastKill[me] = k.t
        -- Between midnight and 5 in the morning (your clock).
        local hour = tonumber(date("%H", k.t))
        if hour < 5 then push(night, me, k.t) end
        if hour >= 5 and hour < 8 then push(morning, me, k.t) end
        -- A new zone.
        zoneSeen[me] = zoneSeen[me] or {}
        local zone = k.zone or ""
        if zone ~= "" and not zoneSeen[me][zone] then
          zoneSeen[me][zone] = true
          push(zones, me, k.t)
        end
        -- The same enemy, a 5th time.
        victimCount[me] = victimCount[me] or {}
        victimCount[me][enemy] = (victimCount[me][enemy] or 0) + 1
        if victimCount[me][enemy] == 1 then push(victims, me, k.t) end
        if victimCount[me][enemy] == GRUDGE_KILLS then push(grudge, me, k.t) end
        if victimCount[me][enemy] == 10 then push(grudge10, me, k.t) end
      end
      for _, a in ipairs(ns.Assists(k)) do push(assists, ns.Key(a), k.t) end
    end
  end
  for _, t in ipairs({ kills, assists, revenge, bounty, nemesis, double, night, zones, grudge, triple, quad, morning,
    weekend, day10, day20, victims, skull, bg, rivalKills, guilds, grudge10, vendetta, avenged,
    pvpDeaths, falls, drowns, fatigue, hunted }) do sortAll(t) end

  -- Champions: the leader of each finished month that had kills.
  local champion = {}
  local oldest = math.huge
  for _, k in ipairs(ns.db.killLog or {}) do oldest = math.min(oldest, k.t) end
  for offset = -1, -24, -1 do
    local fromT, toT = ns.MonthRange(offset)
    if toT <= oldest then break end
    local top = ns.KillStats(ns.QueryKills("all", fromT, toT), 2)
    if top[1] and top[1].count > 0 and not (top[2] and top[2].count == top[1].count) then
      push(champion, ns.Key(top[1].name), toT)
    end
  end
  sortAll(champion)
  return { kills = kills, assists = assists, revenge = revenge, bounty = bounty, nemesis = nemesis,
    double = double, night = night, zones = zones, grudge = grudge, champion = champion,
    triple = triple, quad = quad, morning = morning, weekend = weekend, day10 = day10, day20 = day20,
    victims = victims, skull = skull, bg = bg, rivalKills = rivalKills, guilds = guilds, grudge10 = grudge10,
    vendetta = vendetta, avenged = avenged, pvpDeaths = pvpDeaths, falls = falls, drowns = drowns,
    fatigue = fatigue, hunted = hunted }
end

local function buildIndex()
  local stamp = historyVersion .. "/" .. ns.LedgerStamp("KD", "WR") .. "/" .. (ns.EnemyGuildsVersion and ns.EnemyGuildsVersion() or 0)
  if not pvpIndex or pvpStamp ~= stamp then pvpIndex, pvpStamp = buildPvP(), stamp end
  local p = pvpIndex

  -- Loot.
  local loot, bigBuy, wonItem, rolls = {}, {}, {}, {}
  local bigBuy200, bigBuy500, council, lootNight, spent1000 = {}, {}, {}, {}, {}
  local lootDay, spent = {}, {}
  local history = ns.LootHistory()
  for i = #history, 1, -1 do -- oldest first
    local l = history[i]
    local k = ns.Key(l.winner)
    if l.council then push(council, k, l.t) end
    if not l.roll and l.amount >= 200 then push(bigBuy200, k, l.t) end
    if not l.roll and l.amount >= 500 then push(bigBuy500, k, l.t) end
    local day = k .. date("%Y-%m-%d", l.t)
    lootDay[day] = (lootDay[day] or 0) + 1
    if lootDay[day] == 5 then push(lootNight, k, l.t) end
    local before = spent[k] or 0
    spent[k] = before + (l.amount or 0)
    if before < 1000 and spent[k] >= 1000 then push(spent1000, k, l.t) end
  end
  for _, l in ipairs(history) do
    local k = ns.Key(l.winner)
    push(loot, k, l.t)
    if l.roll then push(rolls, k, l.t) end
    if not l.roll and l.amount >= 100 then push(bigBuy, k, l.t) end
    local id = ns.ItemID(l.item)
    if id then
      wonItem[k] = wonItem[k] or {}
      wonItem[k][id] = math.min(wonItem[k][id] or math.huge, l.t)
    end
  end
  sortAll(loot); sortAll(bigBuy); sortAll(rolls)

  -- Raids: standby, raid nights started, sign-ups accepted.
  local standby, raidsLed, signups, signed = {}, {}, {}, {}
  for _, e in ipairs(ns.LedgerEntries("AT")) do
    if e.how == "standby" then
      for name in (e.names or ""):gmatch("[^,]+") do push(standby, ns.Key(name), e.t) end
    end
  end
  for _, s in ipairs(ns.LedgerEntries("RS")) do push(raidsLed, ns.Key(s.a), s.t) end
  for _, e in ipairs(ns.LedgerEntries("SU")) do
    local tag = ns.Key(e.a) .. "\0" .. (e.ref or "")
    if e.status == "accept" and not signed[tag] then
      signed[tag] = true
      push(signups, ns.Key(e.a), e.t)
    end
  end
  -- The guild: events, profiles, titles, recruits.
  local events, eventKinds, planned, kindSeen = {}, {}, {}, {}
  for _, e in ipairs(ns.AllGuildEvents and ns.AllGuildEvents() or {}) do
    if e.start <= time() then
      push(planned, ns.Key(e.a), e.start)
      for k in pairs(ns.EventAttended(e.id) or {}) do
        push(events, k, e.start)
        kindSeen[k] = kindSeen[k] or {}
        local kind = e.etype or "other"
        if not kindSeen[k][kind] then kindSeen[k][kind] = true; push(eventKinds, k, e.start) end
      end
    end
  end
  local profile, titled, recruits, recruited = {}, {}, {}, {}
  for _, e in ipairs(ns.LedgerEntries("PF")) do
    local k = ns.Key(e.a)
    if not profile[k] then profile[k] = { e.t } end
  end
  for _, e in ipairs(ns.LedgerEntries("TI")) do
    local k = ns.Key(e.a)
    if e.title ~= "" and not titled[k] then titled[k] = { e.t } end
  end
  for _, e in ipairs(ns.LedgerEntries("RC")) do
    local who = ns.Key(e.name or "")
    if e.status == "joined" and not recruited[who] then
      recruited[who] = true
      push(recruits, ns.Key(e.a), e.t)
    end
  end
  for _, t in ipairs({ standby, raidsLed, signups, events, eventKinds, planned, recruits, council, bigBuy200,
    bigBuy500, lootNight, spent1000 }) do sortAll(t) end

  index = { kills = p.kills, assists = p.assists, revenge = p.revenge, bounty = p.bounty, nemesis = p.nemesis,
    double = p.double, night = p.night, zones = p.zones, grudge = p.grudge,
    champion = p.champion, loot = loot, bigBuy = bigBuy, rolls = rolls, wonItem = wonItem,
    standby = standby, raidsLed = raidsLed, signups = signups, events = events, eventKinds = eventKinds,
    planned = planned, profile = profile, titled = titled, recruits = recruits, council = council,
    bigBuy200 = bigBuy200, bigBuy500 = bigBuy500, lootNight = lootNight, spent1000 = spent1000 }
  for stat, list in pairs(p) do if not index[stat] then index[stat] = list end end
  return index
end

-- Raid nights per month: "YYYY-MM" -> { total, last }, kept until the record changes.
local monthsCache, monthsVersion
local function raidMonths()
  if monthsCache and monthsVersion == ns.LedgerVersion() then return monthsCache end
  local months = {}
  for _, s in ipairs(ns.LedgerEntries("RS")) do
    local m = date("%Y-%m", s.t)
    months[m] = months[m] or { total = 0, last = 0 }
    months[m].total = months[m].total + 1
    months[m].last = math.max(months[m].last, s.t)
  end
  monthsCache, monthsVersion = months, ns.LedgerVersion()
  return months
end

-- One member's stat: a sorted list of times.
local function statTimes(name, stat)
  local ix = index or buildIndex()
  local k = ns.Key(name)
  if ix[stat] then return ix[stat][k] or {} end
  if stat == "raids" then return ns.RaidNightsAttended(name) end
  if stat == "bosses" then return ns.BossKillTimes(name) end
  if stat == "bossFirsts" then return ns.BossKillTimes(name, true) end
  if stat:find("^streak") then
    local t = ns.FirstStreakOf(name, tonumber(stat:match("%d+")))
    return t and { t } or {}
  end
  if stat == "wish" then
    local out = {}
    for _, w in ipairs(ns.Wishes and ns.Wishes(name) or {}) do
      local t = ix.wonItem[k] and ix.wonItem[k][w.id]
      if w.won and t then out[#out + 1] = t end
    end
    table.sort(out)
    return out
  end
  if stat == "perfect" then
    -- Months (finished ones) with at least PERFECT_MIN raid nights, all attended.
    local months = raidMonths()
    local here = {}
    for _, t in ipairs(ns.RaidNightsAttended(name)) do
      local m = date("%Y-%m", t)
      here[m] = (here[m] or 0) + 1
    end
    local current, out = date("%Y-%m"), {}
    for m, n in pairs(here) do
      local v = months[m]
      if v and m ~= current and v.total >= PERFECT_MIN and n >= v.total then out[#out + 1] = v.last end
    end
    table.sort(out)
    return out
  end
  if stat == "fullClear" then
    -- Every boss of a raid (where the count is known) within 7 days, with you there for each.
    local byRaid, out = {}, {}
    for _, kill in ipairs(ns.MemberBossKills and ns.MemberBossKills(name) or {}) do -- oldest first
      if ns.RAID_BOSSES[kill.raid] then
        byRaid[kill.raid] = byRaid[kill.raid] or {}
        table.insert(byRaid[kill.raid], kill)
      end
    end
    for raid, kills in pairs(byRaid) do
      -- A week-long window sliding over the kills, counting different bosses in it.
      local need, count, n, first = ns.RAID_BOSSES[raid], {}, 0, 1
      for j = 1, #kills do
        local b = kills[j].boss
        count[b] = (count[b] or 0) + 1
        if count[b] == 1 then n = n + 1 end
        while kills[j].t - kills[first].t > WEEK do
          local old = kills[first].boss
          count[old] = count[old] - 1
          if count[old] == 0 then n = n - 1 end
          first = first + 1
        end
        if n >= need then out[#out + 1] = kills[j].t break end
      end
    end
    table.sort(out)
    return out
  end
  if stat == "claims" then return ns.BountyClaimTimes and ns.BountyClaimTimes(name) or {} end
  if stat == "bigNight" or stat == "bigNight10" then
    -- Boss kills you were at on one day: 5 (or 10).
    local need, perDay, out = stat == "bigNight" and 5 or 10, {}, {}
    for _, t in ipairs(ns.BossKillTimes(name)) do
      local day = date("%Y-%m-%d", t)
      perDay[day] = (perDay[day] or 0) + 1
      if perDay[day] == need then out[#out + 1] = t end
    end
    return out
  end
  if stat == "dkp500" or stat == "dkp1000" then
    return ns.Balance(name) >= (stat == "dkp500" and 500 or 1000) and { 0 } or {}
  end
  if stat == "alt1" then return #ns.AltsOf(name) >= 1 and { 0 } or {} end
  if stat:find("^level%d") then
    local m = ns.Member(name)
    return (m and m.level >= tonumber(stat:match("%d+"))) and { 0 } or {}
  end
  if stat == "profs" or stat == "rank300" or stat == "recipes" then
    -- From the crafters directory: when each profession was shared.
    local c = ns.db.crafters and ns.db.crafters[k]
    local out = {}
    if c then
      local latest = 0
      for _, p in pairs(c.profs) do
        latest = math.max(latest, p.v or 0)
        if stat == "profs" then out[#out + 1] = p.v or 0 end
        if stat == "rank300" and (p.rank or 0) >= 300 then out[#out + 1] = p.v or 0 end
      end
      if stat == "recipes" then
        for _, p in pairs(c.profs) do for _ = 1, #p.ids do out[#out + 1] = latest end end
      end
      table.sort(out)
    end
    return out
  end
  if stat == "alts" then
    return #ns.AltsOf(name) >= 3 and { 0 } or {}
  end
  if stat == "maxLevel" then
    local m = ns.Member(name)
    if m and m.level >= MAX_LEVEL then return { 0 } end -- 0: earned, when unknown
    return {}
  end
  return {}
end

------------------------------------------------------------------------
-- Earned achievements
------------------------------------------------------------------------
local earnedCache = {} -- key -> { id -> { t = time or 0, progress = n } }
local cacheStamp      -- what the cache was worked out from

-- Changes to anything achievements come from: the guild record, the kill and
-- death logs, and members' levels. When it differs from the cache's, the
-- cache is out of date and is worked out again the next time it's read, so
-- the Achievements tab, titles and player cards are right straight away.
local function freshness()
  return ns.LedgerVersion() .. ":" .. historyVersion .. ":" .. (ns.RosterLevelsVersion and ns.RosterLevelsVersion() or 0)
    .. ":" .. (ns.CraftersVersion and ns.CraftersVersion() or 0)
end

ns.OnLoad(function() ns.db.achievements = ns.db.achievements or {} end)

-- Achievements members have recorded with the guild (AE entries): key -> { id -> when }.
-- They're kept by everyone's addon, so they come back after a reinstall, on a
-- new computer, or if the game ever fails to keep Warcrest's saved data.
local aeCache, aeStamp
local aeVouchedByMe = {} -- key .. "\0" .. id -> true: ones you've already vouched for
local function guildRecorded()
  local stamp = ns.LedgerStamp("AE", "AG", "AW", "AB")
  if aeCache and aeStamp == stamp then return aeCache end
  aeCache, aeStamp = {}, stamp
  for _, e in ipairs(ns.LedgerEntries("AE")) do
    local k = ns.Key(e.a)
    aeCache[k] = aeCache[k] or {}
    if BY_ID[e.ach] then aeCache[k][e.ach] = tonumber(e.when) or 0 end
  end
  -- Several of your own at once (AB): "id.when,id.when".
  for _, e in ipairs(ns.LedgerEntries("AB")) do
    local k = ns.Key(e.a)
    aeCache[k] = aeCache[k] or {}
    for id, when in tostring(e.list or ""):gmatch("([%w_]+)%.(%d+)") do
      if BY_ID[id] and not aeCache[k][id] then aeCache[k][id] = tonumber(when) or 0 end
    end
  end
  -- Put back from what guildmates' addons had seen the member earn: one
  -- officer is enough (AG); otherwise two different guildmates must agree (AW).
  local vouches = {} -- key -> id -> { count, when }
  local function put(k, id, when)
    aeCache[k] = aeCache[k] or {}
    if BY_ID[id] and not aeCache[k][id] then aeCache[k][id] = tonumber(when) or 0 end
  end
  for _, e in ipairs(ns.LedgerEntries("AG")) do
    for id, when in tostring(e.list or ""):gmatch("([%w_]+)%.(%d+)") do put(ns.Key(e.who), id, when) end
  end
  local seenBy = {} -- key .. id -> { author -> true }
  for _, e in ipairs(ns.LedgerEntries("AW")) do
    local k, by = ns.Key(e.who), ns.Key(e.a)
    if k ~= by then
      for id, when in tostring(e.list or ""):gmatch("([%w_]+)%.(%d+)") do
        local tag = k .. "\0" .. id
        seenBy[tag] = seenBy[tag] or {}
        if not seenBy[tag][by] then
          seenBy[tag][by] = true
          vouches[k] = vouches[k] or {}
          local v = vouches[k][id] or { 0, tonumber(when) or 0 }
          v[1], v[2] = v[1] + 1, math.min(v[2], tonumber(when) or v[2])
          vouches[k][id] = v
        end
      end
    end
  end
  for k, ids in pairs(vouches) do
    for id, v in pairs(ids) do if v[1] >= 2 then put(k, id, v[2]) end end
  end
  aeVouchedByMe = {}
  local me = ns.Key(UnitName("player"))
  for tag, by in pairs(seenBy) do if by[me] then aeVouchedByMe[tag] = true end end
  return aeCache
end

local function compute(name)
  local k = ns.Key(name)
  -- What's been earned before: kept on this computer, and recorded with the guild.
  local saved = {}
  for id, t in pairs(guildRecorded()[k] or {}) do saved[id] = t end
  for id, t in pairs(ns.db.achievements[k] or {}) do saved[id] = saved[id] or t end
  local out, count = {}, 0
  for _, a in ipairs(LIST) do
    if a.stat ~= "others" then
      local times = statTimes(name, a.stat)
      local got = times[a.goal]
      if got then
        out[a.id] = { t = got, progress = a.goal }
      elseif saved[a.id] then
        out[a.id] = { t = saved[a.id], progress = a.goal }
      else
        out[a.id] = { progress = #times }
      end
      if out[a.id].t then count = count + 1 end
    end
  end
  -- Decorated and Guild Hero: earned once enough of the others are.
  local times = {}
  for _, e in pairs(out) do if e.t then times[#times + 1] = e.t end end
  table.sort(times)
  for _, a in ipairs(LIST) do
    if a.stat == "others" then
      if count >= a.goal then
        out[a.id] = { t = saved[a.id] or times[a.goal], progress = a.goal }
      else
        out[a.id] = { progress = count }
      end
    end
  end
  -- Remember what's earned, so it stays even if history goes.
  for id, e in pairs(out) do
    if e.t then
      ns.db.achievements[k] = ns.db.achievements[k] or {}
      ns.db.achievements[k][id] = ns.db.achievements[k][id] or e.t
    end
  end
  earnedCache[k] = out
  return out
end

-- A member's achievements: id -> { t = when earned (0 if unknown) or nil, progress = n }.
function ns.MemberAchievements(name)
  local stamp = freshness()
  if stamp ~= cacheStamp then earnedCache, index, cacheStamp = {}, nil, stamp end
  return earnedCache[ns.Key(name)] or compute(name)
end

function ns.HasAchievement(name, id)
  local e = ns.MemberAchievements(name)[id]
  return e ~= nil and e.t ~= nil
end

function ns.AchievementCount(name)
  local n = 0
  for _, e in pairs(ns.MemberAchievements(name)) do if e.t then n = n + 1 end end
  return n
end

-- Recently earned across the guild: { { name, id, t }, ... }, newest first.
function ns.GuildAchievements()
  local out = {}
  for _, m in ipairs(ns.GetRoster()) do
    local short = Ambiguate(m.name, "short")
    for id, e in pairs(ns.MemberAchievements(short)) do
      -- (Ones with no known date, like Max Level, aren't news.)
      if e.t and e.t > 0 then out[#out + 1] = { name = short, id = id, t = e.t, classFile = m.classFile } end
    end
  end
  table.sort(out, function(a, b)
    if a.t ~= b.t then return a.t > b.t end
    if a.name ~= b.name then return a.name < b.name end
    return BY_ID[a.id].order < BY_ID[b.id].order
  end)
  return out
end

-- Members with the most achievements: { { name, count, classFile }, ... }.
function ns.AchievementLeaders(n)
  local out = {}
  for _, m in ipairs(ns.GetRoster()) do
    local short = Ambiguate(m.name, "short")
    local c = ns.AchievementCount(short)
    if c > 0 then out[#out + 1] = { name = short, count = c, classFile = m.classFile } end
  end
  table.sort(out, function(a, b)
    if a.count ~= b.count then return a.count > b.count end
    return a.name < b.name
  end)
  while n and #out > n do table.remove(out) end
  return out
end

------------------------------------------------------------------------
-- Titles
------------------------------------------------------------------------
-- Each member's latest title choice: key -> achievement id ("" for none).
-- Rebuilt only when a title changes; looked up for every chat line.
local chosen, chosenStamp
local function titleChoices()
  local stamp = ns.LedgerStamp("TI")
  if chosen and chosenStamp == stamp then return chosen end
  chosen, chosenStamp = {}, stamp
  for _, e in ipairs(ns.LedgerEntries("TI")) do chosen[ns.Key(e.a)] = e.title end -- oldest first: the latest wins
  return chosen
end

-- The title a member chose (the achievement's id), if they've earned it.
function ns.TitleOf(name)
  local id = titleChoices()[ns.Key(name)]
  local a = id and BY_ID[id]
  if a and a.title and ns.HasAchievement(name, id) then return a.title, id end
end

-- "Lyra the Avenger", or just "Lyra".
function ns.TitledName(name)
  local short = Ambiguate(name, "short")
  local title = ns.TitleOf(short)
  return title and (short .. " " .. title) or short
end

-- The titles you've earned: { { id, title }, ... }.
function ns.MyTitles()
  local me = UnitName("player")
  local out = {}
  for _, a in ipairs(LIST) do
    if a.title and ns.HasAchievement(me, a.id) then out[#out + 1] = { id = a.id, title = a.title } end
  end
  return out
end

-- Pick your title (an achievement id), or "" for none.
function ns.SetTitle(id)
  id = id or ""
  if id ~= "" and not (BY_ID[id] and BY_ID[id].title and ns.HasAchievement(UnitName("player"), id)) then
    ns.Say("You haven't earned that title yet.")
    return
  end
  local _, current = ns.TitleOf(UnitName("player"))
  if (current or "") == id then return end
  return ns.LedgerAdd("TI", { title = id })
end

------------------------------------------------------------------------
-- Keeping up to date, and announcing new achievements
------------------------------------------------------------------------
local pending = false
local ready = false -- the first look after login only notes what's already earned

local postLater -- (below)

local function wanted()
  local c, show = ns.cfg, ns.db.show
  return c and c.enabled and c.types.achievement and show.achievement
end

-- Working everyone's achievements out again takes a moment in a big guild, so
-- it's done a few dozen members at a time instead of all in one frame. It's
-- only for announcing what's new: what each member had earned the last time
-- it looked is kept, and anything earned since is announced.
local CHUNK = 40
local run = 0          -- which recheck is current (a newer one stops an older one)
local seenEarned = {}  -- key -> { id -> true }, as of the last look

-- Your own new achievements, posted in guild chat (if the guild and you want
-- that), a moment after they're earned so several earned at once share a line.
local toPost = {}
local function postNow()
  local list = toPost
  toPost = {}
  if #list == 0 or not IsInGuild() then return end
  local c, show = ns.cfg, ns.db.show
  if not (c and c.enabled and c.types.achievement_chat and show.achievement_chat) then return end
  ns.db.postedAch = ns.db.postedAch or {}
  local names, titles = {}, {}
  for _, a in ipairs(list) do
    if not ns.db.postedAch[a.id] then
      ns.db.postedAch[a.id] = true
      names[#names + 1] = ns.T(a.name)
      if a.title then titles[#titles + 1] = ns.T(a.title) end
    end
  end
  if #names == 0 then return end
  local me = UnitName("player")
  local what = #names == 1 and names[1]
    or ns.TF("%s and %s", table.concat(names, ", ", 1, #names - 1), names[#names])
  local text = ns.TF("[%s] %s earned %s!", ns.BRAND or "Warcrest", me, what)
  if #titles > 0 then text = text .. " " .. ns.TF("New title: %s %s.", me, titles[#titles]) end
  pcall(SendChatMessage, text, "GUILD")
end
postLater = function(a)
  toPost[#toPost + 1] = a
  if #toPost == 1 then C_Timer.After(2, postNow) end
end

local function recheck()
  pending = false
  run = run + 1
  local mine = run
  local roster = ns.GetRoster()
  local now = GetServerTime()
  local i = 0
  local function step()
    if mine ~= run then return end
    for _ = 1, CHUNK do
      i = i + 1
      local m = roster[i]
      if not m then break end
      local short = Ambiguate(m.name, "short")
      local k = ns.Key(short)
      local was = seenEarned[k]
      local is = ns.MemberAchievements(short)
      local now_ = {}
      for _, a in ipairs(LIST) do
        local e = is[a.id]
        if e.t then
          now_[a.id] = true
          if ready and was and not was[a.id] and e.t > 0 and now - e.t <= ANNOUNCE_WITHIN then
            if wanted() then
              local text = ns.TF("%s earned %s!", short, ns.T(a.name))
              if a.title then text = text .. " " .. ns.TF("New title: %s %s.", short, ns.T(a.title)) end
              ns.Notify(ns.COLOR .. text .. "|r", ns.COLOR .. text .. "|r", nil, nil, "achievement")
            end
            if ns.IsMe(short) then postLater(a) end
          end
        end
      end
      seenEarned[k] = now_
    end
    if roster[i + 1] then C_Timer.After(0.01, step) return end
    if #roster > 0 then ready = true end
    if ns.RecordMyAchievements then ns.RecordMyAchievements() end
    if ns.RestoreAchievementsLater then ns.RestoreAchievementsLater() end
    if ns.RefreshPanel then ns.RefreshPanel() end
    if ns.RefreshPlayerCard then ns.RefreshPlayerCard() end
  end
  step()
end

-- Record your achievements with the guild (a few at a time), so they're kept
-- by everyone's addon and not only in this computer's saved data.
local recording = false
local RECORD_MAX = 150 -- characters of "id.when" pairs per entry, to fit one message
function ns.RecordMyAchievements()
  if recording or not IsInGuild() then return end
  local me = UnitName("player")
  local have = guildRecorded()[ns.Key(me)] or {}
  -- Several to an entry, so earning a lot at once doesn't fill the record.
  local todo, parts, len = {}, {}, 0
  for _, a in ipairs(LIST) do
    local e = ns.MemberAchievements(me)[a.id]
    if e and e.t and not have[a.id] then
      local item = a.id .. "." .. math.floor(e.t)
      if len + #item + 1 > RECORD_MAX then
        todo[#todo + 1] = table.concat(parts, ",")
        parts, len = {}, 0
      end
      parts[#parts + 1] = item
      len = len + #item + 1
    end
  end
  if #parts > 0 then todo[#todo + 1] = table.concat(parts, ",") end
  if #todo == 0 then return end
  recording = true
  local i = 0
  local function nextOne()
    i = i + 1
    local list = todo[i]
    if not list then
      recording = false
      ns.RecordMyAchievements() -- anything earned while these were going out
      return
    end
    ns.LedgerAdd("AB", { list = list })
    C_Timer.After(1.5, nextOne)
  end
  nextOne()
end

-- Put back achievements guildmates have lost. Your addon remembers what every
-- guildmate has earned; anything it remembers that isn't in the guild's record
-- yet is added to it. From an officer that's enough; from anyone else, two
-- different guildmates have to agree before it counts (so nobody can hand out
-- achievements on their own). A few at a time, and everyone starts at a
-- different moment so it isn't all sent at once.
local restoring, restoreQueued = false, false
local LIST_MAX = 150    -- characters of "id.when" pairs per entry, to fit one message
local MEMBER_MAX = 12   -- entries a member sends per session (officers aren't limited)
local memberSent = 0
function ns.RestoreGuildAchievements()
  if restoring or not IsInGuild() then return end
  local officer = ns.IsAddonOfficer()
  if not officer and memberSent >= MEMBER_MAX then return end
  local me = ns.Key(UnitName("player"))
  guildRecorded()
  local todo = {}
  for k, mine in pairs(ns.db.achievements) do
    local member = ns.Member(k)
    if member and k ~= me then
      local have = guildRecorded()[k] or {}
      local parts, len = {}, 0
      for id, t in pairs(mine) do
        if BY_ID[id] and not have[id] and BY_ID[id].stat ~= "others"
            and (officer or not aeVouchedByMe[k .. "\0" .. id]) then
          local item = id .. "." .. math.floor(tonumber(t) or 0)
          if len + #item + 1 > LIST_MAX then
            todo[#todo + 1] = { k, table.concat(parts, ","), member.name }
            parts, len = {}, 0
          end
          parts[#parts + 1] = item
          len = len + #item + 1
        end
      end
      if #parts > 0 then todo[#todo + 1] = { k, table.concat(parts, ","), member.name } end
    end
  end
  if #todo == 0 then return end
  restoring = true
  local i = 0
  local function nextOne()
    i = i + 1
    local t = todo[i]
    if not t or (not officer and memberSent >= MEMBER_MAX) then restoring = false return end
    -- Someone else may have put these back in the meantime.
    local have = guildRecorded()[t[1]] or {}
    local missing = false
    for id in t[2]:gmatch("([%w_]+)%.") do
      if not have[id] and (officer or not aeVouchedByMe[t[1] .. "\0" .. id]) then missing = true break end
    end
    if missing then
      ns.LedgerAdd(officer and "AG" or "AW", { who = Ambiguate(t[3], "short"), list = t[2] })
      if not officer then memberSent = memberSent + 1 end
      C_Timer.After(2, nextOne)
    else
      nextOne()
    end
  end
  nextOne()
end

function ns.RestoreAchievementsLater()
  if restoreQueued or restoring then return end
  restoreQueued = true
  -- Officers go first; members follow later, by which time most is usually back.
  local wait = ns.IsAddonOfficer() and (30 + math.random(0, 90)) or (150 + math.random(0, 300))
  C_Timer.After(wait, function()
    restoreQueued = false
    ns.RestoreGuildAchievements()
  end)
end

local function changed()
  if pending then return end
  pending = true
  C_Timer.After(1, recheck)
end

local previousHook = ns.OnHistoryChanged
function ns.OnHistoryChanged()
  historyVersion = historyVersion + 1
  changed()
  if previousHook then previousHook() end
end
ns.OnLedgerChanged(changed)
ns.AchievementsChanged = changed -- (the crafters directory changed)
ns.OnLevelsChanged = changed -- someone levelled up (Max Level)
table.insert(ns.OnGuildReady, changed)
-- Until the roster has loaded once, keep looking (that first look is the baseline).
ns.OnEvent("GUILD_ROSTER_UPDATE", function() if not ready then changed() end end)

------------------------------------------------------------------------
-- /warcrest check: why an achievement has or hasn't counted
------------------------------------------------------------------------
function ns.AchievementCheck(name)
  name = Ambiguate(name or UnitName("player"), "short")
  local k = ns.Key(name)
  local function line(text) print("  " .. text) end
  ns.Say(("Achievement check for %s (version %s):"):format(name, ns.version or "?"))
  local blows, assists, hidden, greys = 0, 0, 0, {}
  local latest
  for _, kill in ipairs(ns.db.killLog or {}) do
    local mine = false
    for _, n in ipairs(kill.killers or {}) do if ns.Key(n) == k then mine = true end end
    if mine then
      latest = latest or kill
      if ns.KillHidden(kill) then
        hidden = hidden + 1
        if #greys < 3 then greys[#greys + 1] = kill end
      elseif ns.Key(ns.KillingBlow(kill)) == k then
        blows = blows + 1
      else
        assists = assists + 1
      end
    end
  end
  line(("Kills in your log with %s: %d killing blow%s, %d assist%s, %d not counted (no honor)."):format(name,
    blows, blows == 1 and "" or "s", assists, assists == 1 and "" or "s", hidden))
  for _, kill in ipairs(greys) do
    local m = ns.Member(name)
    line(("  Not counted: %s (level %s), %s; %s is level %s now; honor reported: %s."):format(kill.victim,
      tostring(kill.level or "?"), ns.Date("%b %d %H:%M", kill.t), name, tostring(m and m.level or "?"), tostring(kill.honor)))
  end
  if latest then
    line(("Latest kill: %s at %s, by %s."):format(latest.victim, ns.Date("%H:%M %b %d", latest.t),
      table.concat(latest.killers or {}, ", ")))
  end
  if ns.IsMe(name) then
    local r = ns.lastReport
    if r then
      line(("Your last kill this session: %s (level %s, you %s) at %s: %s."):format(r.victim, tostring(r.level or "?"),
        tostring(r.mine or "?"), date("%H:%M", r.at), r.honor and "honorable, sent to the guild" or "grey, not sent"))
    else
      line("No kill seen yet this session.")
    end
    local heard = ns.lastOwnKillHeard
    line(heard and ("The guild got your last kill report (%s) at %s."):format(heard.victim, date("%H:%M:%S", heard.at))
      or "No kill report of yours has come back from the guild this session.")
    line(("Messages waiting to send: %d."):format(ns.QueueSize and ns.QueueSize() or 0))
  end
  local c, show = ns.cfg, ns.db.show
  line(("Achievement alerts: guild %s, you %s. Posting in guild chat: guild %s, you %s."):format(
    (c.enabled and c.types.achievement) and "on" or "off", show.achievement and "on" or "off",
    (c.enabled and c.types.achievement_chat) and "on" or "off", show.achievement_chat and "on" or "off"))
  local e = ns.MemberAchievements(name).kill1
  line(e and e.t and ("First Blood: earned %s."):format(e.t > 0 and ns.Date("%b %d %H:%M", e.t) or "")
    or "First Blood: not yet.")
  line(("Achievements earned: %d of %d. Recorded with the guild: %d."):format(ns.AchievementCount(name), #LIST,
    (function() local n = 0 for _ in pairs(guildRecorded()[k] or {}) do n = n + 1 end return n end)()))
  if #ns.loadErrors > 0 then line(("|cffff6060%d error%s this session; the first: %s|r"):format(#ns.loadErrors,
    #ns.loadErrors == 1 and "" or "s", ns.loadErrors[1])) end
end

