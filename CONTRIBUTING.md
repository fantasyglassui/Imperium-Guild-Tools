# Working on Warcrest

This repository ([fantasyglassui/Imperium-Guild-Tools](https://github.com/fantasyglassui/Imperium-Guild-Tools)) holds the addon. When you publish a version tag, GitHub builds the zip automatically, attaches it to a GitHub release, and uploads it to CurseForge.

## Where things live

| Folder | What's in it |
| --- | --- |
| `Warcrest.toc` | The addon's info and the list of files, in the order the game loads them |
| `Compat/TheImperium/` | A tiny addon, packaged as its own `TheImperium` folder, that hands saved data from the old name over to Warcrest |
| `Core/` | The shared namespace, events and addon messages (`Core.lua`), the release reset, syncing logs between guildmates, clearing logs, and the shared ledger that raids and DKP are kept in |
| `Guild/` | Roster, permissions and guild-wide settings (`Guild.lua`), level-up celebrations, the officer log, the weekly recap |
| `PvP/` | Kill alerts and the kill log, deaths (used by the Wanted list), the Wanted list |
| `Raids/` | Raid sign-ups and raid nights (`Raids.lua`), DKP and loot auctions (`DKP.lua`) |
| `UI/` | The theme (`Theme.lua`: colors, fonts, icons), shared widgets, the guild panel, map pins, the minimap button, the loot auction window, the updates panel |
| `UI/Tabs/` | One file per tab of the guild panel |
| `Media/` | The icon and artwork, the Inter font (`Fonts/`) and the side menu icons (`Icons/`, white so they can be tinted) |
| `tests/` | Tests that run the addon outside the game (not shipped) |
| `wiki/` | The wiki's pages (not shipped) |
| `.github/` | The build, test and wiki workflows, and the issue forms (not shipped) |

Each file starts with a comment saying what it does. Logic lives in the feature folders and the screens that show it live in `UI/`, so for example the Kills tab is `UI/Tabs/KillLog.lua` and the kills themselves are `PvP/Kills.lua`.

Files share one table, `ns`, and the game runs them in the order `Warcrest.toc` lists them, so a file can only use what loaded before it. When adding a file, add it to the TOC in the right place; the tests load the TOC too, so a missing or misplaced file shows up there.

## 1. Release a version

1. Update `## Version:` in `Warcrest.toc`, add an entry to `CHANGELOG.md`, and add the notes to `UI/Updates.lua` so players see them in the in-game Updates panel.
2. Push it to `main`, then create a tag for the version. Either:
   - on GitHub: **Releases > Draft a new release > Choose a tag**, type `v2.11.0`, pick "Create new tag on publish", and press **Publish release**; or
   - from a terminal: `git tag v2.11.0` then `git push origin v2.11.0`.
3. Within a few minutes the "Package and release" workflow attaches `Warcrest-v3.0.0.zip` to the release, and uploads it to CurseForge.

## 2. CurseForge uploads

`Warcrest.toc` carries the project ID (`## X-Curse-Project-ID: 1803056`), so the packager knows where to upload. It needs one thing from you, once:

1. Create an API token at [CurseForge: API tokens](https://authors.curseforge.com/account/api-tokens).
2. In this repository, go to **Settings > Secrets and variables > Actions > New repository secret**, name it `CF_API_KEY`, and paste the token.

Until the secret exists, tags still make the GitHub release; they just skip CurseForge.

Check that CurseForge lists WoW Forever as the game version of each upload. The packager picks it from the `## Interface:` number, and if CurseForge doesn't recognize 16001 you may need to set it by hand on the file's page.

## 3. Tests and the code checker

Every pull request, and every push to `main`, runs the "Tests" workflow:

- **luacheck** reads all the Lua files for mistakes such as typos in variable names, accidental globals, and unused code. Its settings, including the list of WoW functions the addon uses, are in `.luacheckrc`. If you start using a new WoW function, add it to `read_globals` there.
- **The tests** in `tests/` run the addon outside the game. `tests/wow.lua` stands in for the WoW API, and `tests/harness.py` runs several simulated guildmates, each with their own copy of the addon, passing addon messages between them on a simulated clock. The tests cover kill sharing and removal, Top Head Hunters months, the Wanted list, the send queue, raid nights, invites, raid makeup, the weekly recap, DKP, auctions, alts and seasons, and that every tab of the panel builds without errors.

A red X on a pull request means one of them failed; open **Details** to see which. To run them yourself (Python 3 and Lua's luacheck needed):

```
pip install lupa pytest pillow
pytest tests
luacheck .
```

To see the interface without the game, run `python3 tests/render.py some-folder`: it draws every tab of the panel and a window or two as PNG pictures, from the layout the addon's own code sets up. It's an approximation (no game textures, scroll bars or tooltips), but close enough to spot something out of place. `tests/test_render.py` uses it to check nothing sticks out past the panel's edges.

## The look

`UI/Theme.lua` holds the colors and fonts. Build screens from the helpers in `UI/Widgets.lua` (`UI.Label`, `UI.Button`, `UI.EditBox`, `UI.Check`, `UI.List`, `UI.Window`...) rather than the game's templates, so everything matches. Labels can ask for the game's usual text styles (`GameFontNormalLarge` and so on) and get the matching Warcrest style. Give a screen's main action the gold style: `UI.Button(parent, "Start raid", 100, "primary")`.

To test a new feature, copy the pattern of an existing test: make a `Guild`, call the addon's functions on one member, `guild.run(seconds)`, and check what the others see.

## Editing the wiki

The wiki's pages live in the `wiki/` folder. When changes to them reach `main`, the "Publish wiki" workflow copies them to the repository's Wiki tab. Edit the pages here rather than on the Wiki tab, since the next run overwrites edits made there. To publish by hand, open **Actions > Publish wiki > Run workflow**.

## What's in the release zip

The packager leaves out `CONTRIBUTING.md`, `.gitignore`, `.luacheckrc`, and the `wiki`, `tests` and `.github` folders, so players only get the addon itself.
