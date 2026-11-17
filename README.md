# The Imperium

[![Tests](https://github.com/fantasyglassui/Imperium-Guild-Tools/actions/workflows/tests.yml/badge.svg)](https://github.com/fantasyglassui/Imperium-Guild-Tools/actions/workflows/tests.yml)

The official addon of The Imperium for World of Warcraft: Forever.

## Features

- **Raid sign-ups.** Officers schedule raids; members sign up by role and get a reminder before the raid.
- **DKP.** Earned on time and every hour of a raid, or awarded by officers. Spent by bidding on loot in live auctions.
- **Death alerts.** When a guild member dies, everyone in the guild running the addon gets an alert in chat and in the middle of the screen, with a sound. Two kinds of death are covered: world PvP, and falling, drowning or fatigue. Deaths to monsters, and deaths in battlegrounds and arenas, are not announced.
- **PvP kill alerts.** When a guild member kills an enemy player, the guild hears about it. Guildmates who take down the same player together share one alert.
- **Choose what you see.** Turn each alert type on or off for yourself.
- **Deaths on the map.** Recent guild deaths (24 hours by default, adjustable from 1 hour to 7 days) are marked on the world map with an X (a skull for PvP), including inside OpenMap. Click a mark to set a TomTom waypoint.
- **Kill log and Top Head Hunters.** Every PvP kill by guild members, with killing blows and assists, and a monthly board of the guild's top PvP killers.
- **Wanted list.** Enemy players who keep killing guild members. When a guildmate sees one, the whole guild is alerted and the sighting goes on the map.
- **Celebrations.** The guild cheers when a member reaches every 10th level and max level, or every level if you prefer.
- **Shared history.** Logs and leaderboards are shared between guildmates, so you catch up on what happened while you were offline.
- **Quiet mode.** Alerts wait until you're out of a dungeon or raid, and optionally out of combat.
- **Version check.** The addon tells you when a newer version is out, and officers can see who is out of date.
- **Guild tools for officers.** A searchable roster where officers can edit notes, promote, demote, remove and invite members, and update the Message of the Day.
- **Guild-wide settings.** Officers can turn death alerts on or off, or choose which death types are announced, for the entire guild at once.
- **Officer Log.** A record of promotions, demotions, removals, joins, leaves, note edits, Message of the Day changes and settings changes.

## A fresh start at release

Version 2.1.0 is the release version. The first time you load it, any test data from before launch (kills, PvP deaths, Wanted sightings, raids, sign-ups, DKP and the Officer log) is cleared automatically, and nothing from before launch can come back from players still on older versions. Your personal settings are kept.

## Installation

1. Download the latest `TheImperium-x.y.z.zip`.
2. Extract it into your WoW Forever `Interface/AddOns` folder, so you end up with `Interface/AddOns/TheImperium/TheImperium.toc`.
3. Restart the game, or type `/reload` if you're already logged in.
4. Make sure **The Imperium** is enabled in the AddOns list on the character select screen.

When updating, delete the old `TheImperium` folder first so no old files are left behind.

## Opening the addon

- Click the guild emblem on the edge of your minimap. Left-click opens guild tools, right-click opens Settings, and Shift-click opens Kills. Drag it to move it.
- Type `/imperium` (or `/imp`).
- Click **The Imperium** in the addons menu by the minimap.
- Press Esc, open **Options > AddOns > The Imperium**, and click **Open Guild Tools**.

## Commands

| Command | What it does |
| --- | --- |
| `/imperium` | Open or close the guild tools window |
| `/imperium raids` | Open raid sign-ups |
| `/imperium dkp` | Open DKP |
| `/imperium auction [item] [min bid]` | Auction an item to your raid (officers; Shift-click the item into the command) |
| `/imperium kills` | Open the kill log |
| `/imperium wanted` | Open the wanted list |
| `/imperium quiet` | Turn holding alerts during combat on or off |
| `/imperium sync` | Fetch the last two days of guild history from guildmates |
| `/imperium test` | Show a test alert (a different death type each time) |
| `/imperium sound` | Turn alert sounds on or off for you |
| `/imperium warn` | Turn the center-screen alert on or off for you |
| `/imperium minimap` | Show or hide the minimap button |
| `/imperium debug` | Show error details in chat, for troubleshooting |
| `/imperium updates` | Show what changed in recent versions |
| `/imperium addon` | See who has the addon installed |
| `/imperium versions` | Ask guildmates which version they have |
| `/imperium version` | Show your installed version |

## How deaths are detected

WoW Forever doesn't let addons read the combat log, so the addon can't see exactly what killed you. Instead, each member's addon works out their own death from the situation and reports it:

- **Falling, drowning or fatigue:** you died just after falling, or when your breath or fatigue bar ran out.
- **World PvP:** you died PvP-flagged in the open world with an enemy player nearby.
- **Monsters:** if a monster was attacking you, the death isn't announced. Deaths inside dungeons and raids are only announced for falling, drowning or fatigue.

During a fight, the addon keeps track of which enemy is attacking you, and that's who gets named as the killer. It works best with enemy nameplates turned on, since the addon can only see enemies that are on your nameplates, targeted or focused. Some names can't be read during boss fights.

PvP deaths are marked with a skull.

## Deaths on the map

When a guild member dies, their addon sends where it happened along with the alert. The mark is placed on Blizzard's world map, so it also shows in map addons built on it, such as OpenMap. The game hides your position inside dungeons and raids, so falls there have no map mark. Marks only appear for deaths recorded while you were online, and only from members on version 1.6.0 or later.

## Raids and sign-ups

When it's time, officers click **Invite sign-ups** to invite everyone online who accepted or is tentative; a party is turned into a raid automatically. Members who signed up but aren't there when the raid starts get a reminder.

Officers click **New raid** on the Raids tab, then fill in the raid's name, day, start time (24-hour, in your own time; everyone sees it in theirs) and optional notes. Members pick a raid on the left, choose their role, and click Accept, Tentative or Decline. Anyone who accepted or is tentative gets a reminder 15 minutes before the start. **Show current raid group** lists everyone in your raid with their sign-up and DKP.

## DKP

**Earning.** On raid night, an officer in the raid clicks **Start raid** on the Raids tab, with the on-time and hourly amounts (10 and 10 by default). Every guild member in the raid who is online gets the on-time DKP straight away, then the hourly DKP every hour until the officer clicks **End raid**. The hourly awards come from the officer who started the raid, so they should stay in the raid. Officers can also give or take DKP by hand on the DKP tab: tick members (or click **Select current raid**), enter an amount and reason, and click Add DKP or Remove DKP.

**Spending.** An officer Shift-clicks an item into the item box on the DKP tab, sets the minimum bid and time, and clicks **Start auction**. Everyone in the raid with the addon gets a bid window. Each bid must beat the highest bid and can't be more than your DKP; a bid in the last 5 seconds adds 5 more seconds. When time runs out, the highest bidder wins and their DKP is deducted automatically.

**Standby.** During a raid night, officers open **Show current raid group** on the Raids tab and add members to standby. They get the same on-time and hourly DKP as the raid and count as attending.

**Attendance and no-shows.** The DKP tab shows each member's attendance over the last 30 days. Anyone who accepted a raid but didn't come (and wasn't on standby) is marked as a no-show on that raid and in their attendance details.

**Decay.** Officers can take a percentage off everyone's DKP with **Decay now**, or tick **Every week** to have it done automatically after each Tuesday reset. This stops DKP piling up and keeps newer members competitive. Each week can only be decayed once.

**Hidden bids.** Officers can switch auctions to hidden bids. Nobody sees anyone else's bid; the highest bid wins but only pays one more than the second-highest bid. People can bid what an item is really worth to them without being outbid by a point or overpaying.

**Boss DKP.** When starting a raid, officers can set DKP per boss kill. It's awarded automatically to everyone in the raid (and on standby) each time a boss dies, once per boss per night.

**Free rolls.** If an auction ends with no bids, the raid gets 20 seconds to roll for the item, and the highest roll wins it for free. Only each raid member's first roll counts.

**Class check.** The bid window warns you before you bid on armor or weapons your class can't use, and asks you to confirm.

**Alts.** Open **Alts** on the DKP tab. On your alt, type your main's name and click **Ask to link**, then log in on your main and click **Confirm**. Linking needs both characters, so nobody can claim someone else's character. Alts share their main's DKP and attendance. Officers can also link or unlink alts directly.

**Corrections.** Switch the DKP tab to **All changes** to see every DKP change. Officers can right-click one to undo it. Right-clicking an item in **Loot history** lets officers refund it or give it to someone else. Undone changes stay visible, marked as undone, so the history is always complete.

**Starting balances.** Officers can click **Import balances** and paste lines like "Alice, 120" to set everyone's DKP at once. This is handy when moving from another DKP addon or a spreadsheet.

**Seasons.** Every DKP change is kept, so after many months there's a lot of history to add up. Officers can click **New season** on the DKP tab: everyone keeps their current DKP, but DKP changes and loot history from before the season, and raids and attendance older than 30 days, are archived for good. Export first if you want a copy. A good rhythm is a new season each raid tier or every few months.

**Loot history.** On the DKP tab, switch from Standings to **Loot history** to see every item won in an auction: who won it, for how much, and on which raid night. Hover an item for its tooltip, or search by item or winner.

**Backups.** Officers can click **Export DKP** to get a plain-text copy of standings, loot and every DKP change, ready to paste into a text file or spreadsheet.

**Keeping it fair.** Every raid, sign-up and DKP change is kept in a shared record that's never edited, only added to. Only officers can create raids or change DKP. An officer's change is only accepted straight from that officer or passed along by another officer, so nobody can add fake DKP. Members catch up on changes they missed whenever an officer is online.

## Shared history

Each person's addon records events while they're online. When you log in, your addon asks the guild for anything from the last two days that you missed, and one online guildmate sends it to you privately, a few entries a second. Events you already have are skipped, and shared history never sets off alerts. History is only accepted from guild members.

## The Wanted list

An enemy player becomes wanted after killing guild members in world PvP a set number of times in the last 30 days (3 by default; change it on the Wanted tab). When a guildmate's addon sees a wanted player on their target, focus, mouseover or nameplates, the guild gets an alert and the spot is marked on the map with a purple diamond for 30 minutes. The same player is reported at most once every 10 minutes. Right-click someone on the Wanted tab to hide them from your own list.

When a guild member kills a wanted player, the bounty is claimed: the kill alert says so, and they drop off the list. Only guild deaths after that kill count toward them, so they come back if they keep ganking. Untick "Remove from the list when a guild member kills them" at the bottom of the Wanted tab to keep them listed instead.

## Clearing logs

Only the Guild Master can clear the Kills and Officer logs. A clear removes everything in that log up to that moment for the whole guild, and old entries can't come back through shared history. Guildmates who were offline get the clear the next time they catch up with an officer online.

## Quiet mode

In Settings, "Hold alerts in dungeons and raids" is on by default and "Hold alerts during combat" is off. Held alerts are listed together in chat once you're out.

## How PvP kills are detected

The addon can't see killing blows, so a kill counts for you only if you actually attacked that enemy player in the last 10 seconds before they died: you cast a harmful spell while they were your target, you were auto-attacking or shooting them, or your pet was attacking them. Being in a party that gets honor for the kill, targeting the enemy, or being attacked by them isn't enough.

**Killing blows and assists.** Each guild member who took part reports how long before the death they last hit the victim. Whoever hit last gets the killing blow; everyone else gets an assist. It's a best guess, since the exact blow can't be seen, but it's close. Top Head Hunters ranks by killing blows, with assists shown next to them.

**Honor kills only.** Kills the game gives no honor for (victims at a grey level, far below yours) don't count, so farming low-level players doesn't climb the leaderboard. This is on for the guild by default; officers can turn it off in Settings, and members can turn it on just for themselves.

**Removing bad kills.** Officers can right-click a kill on the Kills tab to remove it for the whole guild. It stays removed for everyone, including guildmates who were offline at the time.

Healers who only healed don't get credit, since healing isn't an attack.

## Good to know

- Raid deaths and battleground kills are turned off by default for each person, since they can send a lot of alerts. Turn them on in **Alert Settings** if you want them.
- The officer log records what happens while you're online. Each person has their own copy.
- The guild tools window closes when you enter combat and reopens when combat ends. The game doesn't allow its guild action buttons to be used in combat.
- The Officer Log tab only appears for officers. The text of edited notes is never shared, only that a note was changed.

## For officers

- Buttons in the Roster tab only work for actions your guild rank already allows. The game server checks every action, so the addon can't give anyone extra powers.
- Alert settings can be changed by the Guild Master and the rank directly below by default. The Guild Master can change which ranks are allowed in the Alert Settings tab.
- Settings reach everyone who is online when you save. Members who log in later get the current settings from any online officer.
- The **Addon** tab shows who has the addon and who needs to update. Click **Check now** to ask everyone online.

## More help

The [wiki](https://github.com/fantasyglassui/Imperium-Guild-Tools/wiki) has step-by-step guides for members and officers. Found a bug or have an idea? [Open an issue](https://github.com/fantasyglassui/Imperium-Guild-Tools/issues/new/choose).

## Contributing

Pull requests are checked automatically by luacheck and a test suite that runs the addon outside the game. See [DISTRIBUTION.md](DISTRIBUTION.md#3-tests-and-the-code-checker) for how to run them yourself and how releases work.

## License

The Imperium is released under the [MIT License](LICENSE).
