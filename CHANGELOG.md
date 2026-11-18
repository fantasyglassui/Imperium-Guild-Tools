# Changelog

## Unreleased
- Lists across the guild panel have a dark background with a thin gold edge, and every other row is shaded, so it's easier to follow a row across.
- Every list says something when it's empty or nothing matches your search, including ones that used to be blank: the roster, DKP standings and changes, raid sign-ups, your raid group and the Addon tab.
- The guild panel opens on the tab you used last.
- Tooltips on 30 buttons that didn't explain themselves, such as Promote, Start raid, Add DKP, Decay now, Import balances and the kill log filters. They show even when a button is greyed out, so you can see what it does.
- Behind the scenes: the addon's files are organized into folders by feature (Core, Guild, PvP, Raids, and the panel's tabs under UI/Tabs). Nothing changes in game. If you install by hand, delete the old TheImperium folder before unzipping the new one, so the old loose files don't stay behind (they're unused, but it keeps things tidy).

## 2.11.1
- Fixed: kills of grey-level players (far below the killer's level) were still logged and announced, for two reasons: when the game gave an honor message the kill counted whatever the victim's level, and officers could switch "Honor kills only" off. Now the victim's level decides (the honor message only counts when the level couldn't be seen), and grey kills are never reported, announced or logged.
- Guildmates' reports are checked against the killers' levels from the guild roster, so grey kills sent by older versions, live or through kill-log sync, are dropped too. Grey kills already in your log are cleared out shortly after you log in, so the Kills tab, Top Head Hunters and the weekly recap no longer count them.
- The "Honor kills only" option is gone from Settings: it's always on.

## 2.11.0
- New: raid makeup check. The Raids tab lists who has accepted by class (in class colors, with names colored too) and warns about gaps: too few tanks (2 wanted from 10 players, otherwise 1), too few healers (about one per five players), with tentative sign-ups for that role noted. Once 10 have accepted, it also names any class that has max-level members in the guild but nobody signed up. Hover the warning for the details. Raids with gaps get an orange "!" in the Upcoming raids list.
- New: an hour before a scheduled raid, officers get one chat line about any gaps in its makeup.
- New: weekly recap. After the Tuesday reset, everyone gets a short summary of the guild's last week in chat: enemy players killed and the top three head hunters, guild members killed by enemy players and who killed us most, raid nights and bosses killed, and loot handed out with the biggest buy. Anyone offline at the reset sees it at their next login. It's skipped for quiet weeks and for a fresh install. Turn it off, or show it again, in Settings (Weekly recap), or type /imperium recap (or /imperium recap now for this week so far).

## 2.10.0
- Top Head Hunters resets monthly. The Kills tab shows this month by default (the board's title names the month); switch to Last month, Last 7 days or All time to see earlier standings. Months follow the realm's clock, so everyone resets at the same moment.
- Reset-day announcement: on the 1st, everyone online hears last month's top three head hunters, with the champion in the middle of the screen. Anyone who wasn't on that day hears it at their first login that week. Last month's champion is also shown under the board.
- Fixed: for kills recorded without hit timings (from versions before 2.5.0), different guildmates could credit the killing blow to different people. The choice is now the same on every copy.
- The kill log keeps up to 2,000 kills (was 500), so last month is always available.

## 2.9.0
- New: DKP seasons. Officers click New season on the DKP tab. Everyone keeps their current DKP; DKP changes and loot history from before the season, and raids, sign-ups and attendance older than 30 days, are archived. Alt links, DKP rules and kill removals are kept. Guildmates who were offline archive their copy when they next catch up, and archived history can't come back.
- Faster: the DKP record is now indexed once per change instead of being re-scanned and re-sorted on every lookup, which speeds up balances, attendance and the Raids and DKP tabs.

## 2.8.0
- New: alts. Link an alt to your main from the DKP tab (Alts): ask from the alt, then confirm from the main. Alts share the main's DKP and attendance, and can bid with it. Officers can link or unlink any alt directly.
- New: boss DKP. A "Per boss" amount when starting a raid, awarded automatically to the raid (and standby) on each boss kill, once per boss per night.
- New: free rolls. When an auction ends with no bids, the raid gets 20 seconds to /roll for it, and the highest roll wins it for free. Only each raid member's first roll counts.
- New: class check. The bid window warns you, and asks to confirm, before you bid on armor or weapons your class can't use.
- New: corrections. Officers can undo any DKP change from the new "All changes" view, and right-click loot to refund it or give it to someone else. Undone changes stay visible, marked as undone.
- New: import starting balances. Officers paste "Name, DKP" lines to set everyone's balance at once, useful when moving from another DKP system.

## 2.7.0
- New: attendance. The DKP tab shows each member's attendance over the last 30 days (green 75%+, yellow 40%+, red below). Hover a name for the exact count and any no-shows.
- New: standby. During a raid night, officers can add members to standby on the Raids tab (Show current raid group). Standby members get the on-time and hourly DKP and count as attending.
- New: no-show tracking. Once a raid night is held for a scheduled raid, accepted sign-ups who never came are marked "No-show" on the Raids tab and count against their attendance.
- New: Invite sign-ups. One officer button invites every online member who accepted or is tentative, turning the party into a raid automatically. When the raid starts, members who signed up but aren't there get a reminder.
- New: DKP decay. Officers can take a percentage off everyone's DKP with "Decay now", or tick "Every week" to have it applied automatically after each Tuesday reset. A week can only be decayed once.
- New: hidden bids. With this on, nobody sees anyone else's bid; the highest bid wins and pays the second-highest bid + 1 (or the minimum if there's only one bid).

## 2.6.0
- New: Loot history on the DKP tab. Every item won in an auction, the winner, the DKP paid and the raid night, with the item's tooltip on hover. Searchable by item or winner.
- New: officers can export DKP as plain text (standings, loot and every DKP change) to keep a backup outside the game.
- Fixed: on busy nights, messages could be silently dropped by the game's sending limits, losing kills, bids or catch-up data. All messages now go through a queue that stays within the limits, with alerts and loot bids sent first and catch-up data on its own channel.

## 2.5.0
- Killing blows and assists. Each killer reports how long before the death they last hit the victim; whoever hit last gets the killing blow, the rest get assists. Top Head Hunters ranks by killing blows, with assists shown next to them. Alerts read "Alice killed Ganker (assist: Bob)".
- Honor kills only. Kills the game gives no honor for (grey, much lower level victims) no longer count in alerts, the Kills tab or Top Head Hunters. On by default for the guild; officers can turn it off in Settings, and members can turn it on just for themselves. The victim's level is recorded and shown in the tooltip.
- Officers can right-click a kill on the Kills tab to remove it for the whole guild. Removals are kept in the shared record, so they stay removed for everyone.

## 2.4.1
- Fixed: guildmates' Kills tabs and Top Head Hunters drifted apart, because catching up only covered the last two days and came from one guildmate. Kill logs now compare with each other every 15 minutes and at login, and swap any differences both ways, over the full history.
- Fixed: killing the same player twice within 2 minutes counted as one kill. Reports are now only combined within 30 seconds.

## 2.4.0
- New Addon tab: every guild member with whether they have The Imperium, which version, and when their addon was last seen. Filter by has it, doesn't have it, or out of date, and click Check now to ask everyone online.
- New command: `/imperium addon`.

## 2.3.0
- New: when a guild member kills a wanted player, the bounty is claimed and they drop off the Wanted list. Only guild deaths after that kill count toward them, so they return if they keep ganking.
- Kill alerts add "Wanted bounty claimed!" when the victim was wanted.
- A checkbox at the bottom of the Wanted tab turns this on or off (on by default).

## 2.2.0
- New: an Updates panel appears once after each update, showing what changed since the version you last used. Reopen it with `/imperium updates`.

## 2.1.1
- Fixed: deaths to damage over time were announced as falling to death. A death now only counts as a fall if you dropped for at least a second, died the moment you landed, and weren't in combat during the fall.

## 2.1.0 (release)
- Fresh start for release: the first time you load this version, all test data is cleared (kills, PvP deaths, Wanted sightings, raids, sign-ups, DKP and the Officer log). Your personal settings are kept.
- Anything recorded before the release is refused, so test data can't come back from players still on an older version.

## 2.0.0
- Removed duels: the Duels tab, duel alerts, the duel log and its leaderboard. Old duel data is cleared when you log in.
- The Guild Master's Clear log now covers the Kills and Officer logs.
- `/imperium debug` now shows error details in chat, for troubleshooting.

## 1.9.6
- Fixed: duels couldn't be decided when the game hides health during combat. The addon now waits for combat to end to read health, and when both duelists have the addon they share their health and the lower one lost.
- Debug mode watches more chat channels for the duel result line.

## 1.9.5
- `/imperium debug` is now listed in the command list.
- `/imperium version` also reports whether any part of the addon has run into a problem, and shows the first one.
- If one part of the addon runs into an error, the rest keeps working instead of stopping. With debug on, errors are shown in chat.

## 1.9.4
- Fixed: duels weren't announced or logged for some players. The game's duel result line is now matched more loosely, with built-in English wording as a backup, and if the line can't be read at all, the result is worked out from the game's duel events (who you dueled, whether someone left the duel area, and your health when it ended).
- New: `/imperium debug` shows what the addon sees during a duel, to help track down problems.

## 1.9.3
- Only the Guild Master sees the Clear log button on the Kills, Duels and Officers tabs.
- Clearing now clears that log for the whole guild, not just your own copy, and old entries can't come back through shared history. Guildmates who were offline get the clear when they next catch up.

## 1.9.2
- Fixed: party members who didn't fight were reported as killing enemy players. A kill now only counts if you attacked that player in the last 10 seconds: a harmful spell on them, auto-attacking or shooting them, or your pet attacking them. Shared party honor, targeting an enemy, or being attacked by one no longer counts.

## 1.9.1
- Removed the Deaths tab, including the death log and the most-deaths leaderboard.
- Shift-clicking the minimap button now opens the Kills tab.

## 1.9.0
- New Raids tab. Officers schedule raids (name, day, start time, notes). Members sign up as Tank, Healer or DPS with Accept, Tentative or Decline, and get a reminder 15 minutes before a raid they're going to. A second view shows your current raid group with each person's sign-up and DKP.
- New DKP tab. Everyone's DKP with each member's history on hover. Officers award or remove DKP for ticked members, with "Select current raid" to tick everyone in the raid.
- Attendance DKP: an officer clicks Start raid in the Raids tab. Every guild member in the raid gets the on-time bonus, then DKP every hour until the officer clicks End raid.
- Loot auctions: an officer Shift-clicks an item into the DKP tab and starts an auction. Raid members get a bid window with the item, the highest bid and a countdown. Bids must beat the highest bid and be within the bidder's DKP; a bid in the last 5 seconds adds time. The winner's DKP is deducted automatically.
- Raids and DKP are kept in a shared record that guildmates sync with each other. Only officers can create raids or change DKP, and nobody can slip in fake DKP.
- New commands: `/imperium raids`, `/imperium dkp`, `/imperium auction [item] [min bid]`.
- The guild tools window is wider to fit the new tabs.

## 1.8.2
- Removed all deaths to monsters: dungeons, raids and the open world. Only world PvP deaths and falling, drowning or fatigue are announced now, and old monster deaths are cleared from the death log.

## 1.8.1
- Kills tab: the board is now "Top Head Hunters", showing the top 18 with the top three in gold. The kills-to-deaths board was removed.
- Deaths to raid bosses and open-world bosses are no longer announced or logged. Other raid deaths, such as to trash, still are.

## 1.8.0
- New: shared history. When you log in, a guildmate who was online sends you the last two days of deaths, kills and duels you missed, so everyone's logs and leaderboards match. Type `/imperium sync` to fetch it again.
- New Kills tab: every PvP kill by guild members, with Top hunters and each member's kills next to their world PvP deaths.
- New Wanted tab: enemy players who kept killing guild members in world PvP over the last 30 days. When a guildmate sees one, the guild is alerted and the sighting is marked on the map with a purple diamond for 30 minutes.
- New: level-up celebrations. Every 10 levels and max level by default; every level up can be turned on.
- New: quiet mode. Alerts are held in dungeons and raids (on by default) and, if you choose, during combat, then listed in chat once you're out.
- The Settings tab now scrolls, and tabs have shorter names to fit: Roster, Deaths, Duels, Kills, Wanted, Settings, Officers.
- New commands: `/imperium kills`, `/imperium wanted`, `/imperium quiet`, `/imperium sync`.

## 1.7.0
- New minimap button with the guild emblem. Left-click opens guild tools, right-click opens Alert Settings, Shift-click opens the Death Log. Drag it to move it around the minimap.
- Hide or show it with `/imperium minimap` or on the Options page.

## 1.6.3
- New addon icon: the guild emblem (the trident in its golden sunburst), redrawn crisply without the shield border. Used in the AddOns list, the addons menu by the minimap, chat messages and the guild tools window.

## 1.6.2
- New slider in Alert Settings: choose how long a guild death stays marked on the world map, from 1 hour to 7 days (default 24 hours).

## 1.6.1
- Removed battleground and arena deaths. They are no longer announced, logged or shown on the leaderboard, and old ones are cleared from the death log.
- Battleground and arena kills are unchanged and can still be turned on in Alert Settings.

## 1.6.0
- New: guild deaths are marked on the world map with an X (a skull for PvP deaths) for 24 hours. Works on the normal world map and inside OpenMap. Hover a mark for details; click it to set a TomTom waypoint if you use TomTom.
- Click a death in the Death Log to open the world map where it happened.
- New Duel Log tab: recent duels with a leaderboard of most wins and most duels fought, filterable to duels between guildmates.
- New command: `/imperium duels`.
- Map marks can be turned off in Alert Settings.

## 1.5.2
- New addon icon and window portrait taken from the guild artwork: the IMPERIUM logo with the guild's heroes below it.

## 1.5.1
- The Imperium's own crest is now the addon icon: in the AddOns list, the addons menu by the minimap, the guild tools window and before every chat message.
- The full guild artwork is shown on the addon's page under Esc > Options > AddOns.

## 1.5.0
- New: duel alerts. When a guild member wins, loses or flees a duel, the guild gets an alert. A duel between two guildmates shows as one alert.
- Duel alerts can be turned on or off guild-wide by officers and for yourself.
- The Alert Settings tab is grouped into Deaths, PvP kills and Duels.
- Officers on 1.5.0 still send settings that members on 1.3.x and 1.4.x understand.

## 1.4.0
- New: PvP kill alerts. When a guild member kills an enemy player, the guild gets an alert with a red X marker. Guildmates who take down the same player together are shown in one alert.
- World PvP kills and battleground/arena kills can each be turned on or off, both guild-wide by officers and for yourself. Battleground kills start off for each person, since they can be very frequent.
- Officers on 1.4.0 still send settings that members on 1.3.x understand.

## 1.3.1
- PvP deaths now show a skull in chat, in the center-screen alert and in the death log.
- Fixed: Promote, Demote, Remove, Invite and Message of the Day were blocked by the game. They now use the game's own guild commands through secure buttons.
- Fixed: deaths to monsters didn't name the monster. The addon now keeps track of what is attacking you during a fight.
- World PvP detection is more accurate: a death is only counted as PvP when an enemy player was attacking you, if the addon saw who was.
- The guild tools window closes when you enter combat and reopens afterwards, because its secure buttons can't be used in combat.

## 1.3.0
- Death alerts now cover six death types: world PvP, battlegrounds and arenas, dungeons, raids, the open world, and falling, drowning or fatigue.
- Each member can choose which death types they see. Raid deaths are off by default.
- Officers can choose which death types are announced for the whole guild.
- New Death Log tab with recent deaths and a leaderboard of most deaths and top killers.
- Version check: you're told when a newer version is out, and the Roster tab shows who has the addon and who is out of date.
- New Officer Log tab recording promotions, demotions, removals, joins, leaves, note edits, Message of the Day changes and settings changes.
- Code reorganized into modules, with packaging set up for CurseForge and GitHub releases.
- Still shows PvP alerts sent by members on 1.2.0, but everyone should update.

## 1.2.0
- Renamed to **The Imperium**, the official guild addon.
- New guild tools window with Blizzard-style tabs and the guild crest.
- Added an entry under Esc > Options > AddOns and in the addons menu by the minimap.
- New commands: `/imperium` and `/imp`.

## 1.1.0
- Officer Roster tab: notes, promote, demote, remove, invite, Message of the Day.
- Guild-wide alert settings controlled by officers, synced to the whole guild.

## 1.0.0
- PvP death alerts for the guild.
