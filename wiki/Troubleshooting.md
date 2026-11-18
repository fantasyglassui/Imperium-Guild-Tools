# Troubleshooting

Most problems come down to an old version. Check `/warcrest version` first, and update if you're behind.

| Problem | Try this |
| --- | --- |
| The addon doesn't open | Make sure **Warcrest** is ticked in the AddOns list on the character screen, then fully restart the game. |
| I didn't get a bid window | Make sure you're on the latest version and in the **raid** group, not just a party. |
| My DKP looks wrong | Hover your name on the DKP tab to see recent changes, or check **All changes**. Ask an officer to fix anything wrong. |
| Guildmates see different DKP or kills | It usually catches up within 15 minutes (DKP needs an officer online). `/warcrest sync` speeds it up. |
| A kill I made didn't count | You need to have attacked the enemy in the 10 seconds before they died, and grey (no-honor) kills don't count. Turn on enemy nameplates (V). |
| A boss kill didn't show on the Progress view | Type `/warcrest bosses`: it lists the last bosses that died and why each did or didn't count (it needs a raid instance, a raid group, and 5 or more guild members making up at least half the raid). Send a screenshot of it if it looks wrong. |
| Hourly DKP stopped | The officer who started the raid left or logged off. They should end the raid and another officer start it again. |
| Alerts went quiet in a dungeon | That's quiet mode. Held alerts are listed in chat when you leave. Change it in **Settings**. |
| Something's broken | Turn on `/warcrest debug`, install BugSack, and send the errors to an officer or open an issue on this repository. |

## Reporting a problem

Open an issue on the [GitHub repository](https://github.com/fantasyglassui/Imperium-Guild-Tools/issues) with your version (`/warcrest version`), what you did, what you expected, and any errors from BugSack or `/warcrest debug`.
