# Publishing The Imperium

This repository ([fantasyglassui/Imperium-Guild-Tools](https://github.com/fantasyglassui/Imperium-Guild-Tools)) holds the addon. When you push a version tag, GitHub builds the zip automatically, attaches it to a GitHub release, and can also upload it to CurseForge.

The addon's files sit at the top level of the repository, with `TheImperium.toc` at the root. `.pkgmeta` packages them into a `TheImperium` folder, and `.github/workflows/release.yml` runs the packager.

## 1. Release a version

1. Update `## Version:` in `TheImperium.toc` and add an entry to `CHANGELOG.md`.
2. Commit, then create and push a matching tag:

   ```
   git tag v2.10.0
   git push origin v2.10.0
   ```

3. Within a few minutes the release, with `TheImperium-v2.10.0.zip`, appears on the repository's **Releases** page. Guildies can download it from there.

Also add the release's notes to `UI/Updates.lua`, so players see them in the in-game Updates panel.

## 2. Upload to CurseForge automatically

The addon is already on CurseForge. To have every tag upload there too:

1. Find the **Project ID** on the CurseForge project page (in the "About Project" box).
2. Add this line to `TheImperium.toc`, with your real ID:

   ```
   ## X-Curse-Project-ID: 123456
   ```

3. Create an API token in your CurseForge account settings.
4. In the GitHub repository, go to **Settings > Secrets and variables > Actions** and add a secret named `CF_API_KEY` containing the token.

From then on, every tag you push uploads to CurseForge as well.

Check that CurseForge lists WoW Forever as a game version for your upload. The packager picks the game version from the `## Interface:` number, and if CurseForge doesn't recognize 16001 yet you may need to set the game version by hand on the CurseForge file page.

## What's in the release zip

The packager leaves out `DISTRIBUTION.md`, `.gitignore` and the `.github` folder, so players only get the addon itself.
