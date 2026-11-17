# Publishing The Imperium

This repository ([fantasyglassui/Imperium-Guild-Tools](https://github.com/fantasyglassui/Imperium-Guild-Tools)) holds the addon. When you push a version tag, GitHub builds the zip automatically, attaches it to a GitHub release, and can also upload it to CurseForge.

The addon's files sit at the top level of the repository, with `TheImperium.toc` at the root. `.pkgmeta` packages them into a `TheImperium` folder, and `.github/workflows/release.yml` runs the packager.

## 1. Release a version

1. Update `## Version:` in `TheImperium.toc`, add an entry to `CHANGELOG.md`, and add the notes to `UI/Updates.lua` so players see them in the in-game Updates panel.
2. Merge it to `main`, then create a tag for the version. Either:
   - on GitHub: **Releases > Draft a new release > Choose a tag**, type `v2.10.0`, pick "Create new tag on publish", and press **Publish release**; or
   - from a terminal: `git tag v2.10.0` then `git push origin v2.10.0`.
3. Within a few minutes the "Package and release" workflow attaches `TheImperium-v2.10.0.zip` to the release, and uploads it to CurseForge.

## 2. CurseForge uploads

`TheImperium.toc` carries the project ID (`## X-Curse-Project-ID: 1803056`), so the packager knows where to upload. It needs one thing from you, once:

1. Create an API token at [CurseForge: API tokens](https://authors.curseforge.com/account/api-tokens).
2. In this repository, go to **Settings > Secrets and variables > Actions > New repository secret**, name it `CF_API_KEY`, and paste the token.

Until the secret exists, tags still make the GitHub release; they just skip CurseForge.

Check that CurseForge lists WoW Forever as the game version of each upload. The packager picks it from the `## Interface:` number, and if CurseForge doesn't recognize 16001 you may need to set it by hand on the file's page.

## 3. Tests and the code checker

Every pull request, and every push to `main`, runs the "Tests" workflow:

- **luacheck** reads all the Lua files for mistakes such as typos in variable names, accidental globals, and unused code. Its settings, including the list of WoW functions the addon uses, are in `.luacheckrc`. If you start using a new WoW function, add it to `read_globals` there.
- **The tests** in `tests/` run the addon outside the game. `tests/wow.lua` stands in for the WoW API, and `tests/harness.py` runs several simulated guildmates, each with their own copy of the addon, passing addon messages between them on a simulated clock. The tests cover kill sharing and removal, Top Head Hunters months, the Wanted list, the send queue, raid nights, invites, DKP, auctions, alts and seasons, and that every tab of the panel builds without errors.

A red X on a pull request means one of them failed; open **Details** to see which. To run them yourself (Python 3 and Lua's luacheck needed):

```
pip install lupa pytest
pytest tests
luacheck .
```

To test a new feature, copy the pattern of an existing test: make a `Guild`, call the addon's functions on one member, `guild.run(seconds)`, and check what the others see.

## Editing the wiki

The wiki's pages live in the `wiki/` folder. When changes to them reach `main`, the "Publish wiki" workflow copies them to the repository's Wiki tab. Edit the pages here rather than on the Wiki tab, since the next run overwrites edits made there. To publish by hand, open **Actions > Publish wiki > Run workflow**.

## What's in the release zip

The packager leaves out `DISTRIBUTION.md`, `.gitignore`, `.luacheckrc`, and the `wiki`, `tests` and `.github` folders, so players only get the addon itself.
