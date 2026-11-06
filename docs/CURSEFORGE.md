# CurseForge release material

Texts and assets used on the CurseForge project page. Keep them in sync with `README.md`
and the `## Notes` line in `ForeverJourney.toc`.

## Project

| Setting | Value |
| --- | --- |
| Project name | Forever Journey - Adventure Journal |
| Project slug | `forever-journey-adventure-journal` |
| In-game title and folder | Forever Journey, `ForeverJourney` (unchanged) |
| Project ID | 1786557 (also `## X-Curse-Project-ID` in the TOC) |
| License | MIT (`LICENSE`, shipped inside the zip) |
| Third-party distribution | Allowed |

The plain name "Forever Journey" was already taken on CurseForge, so the project name carries
a subtitle. The addon itself keeps its name.

Source: <https://github.com/jebstern/Forever-Journey> (public, CurseForge clones it).
CurseForge setting: "package any new tagged commits", so ordinary pushes never become files.

## Automatic packaging

CurseForge builds and uploads the zip itself whenever a tag is pushed to GitHub, following
<https://support.curseforge.com/support/solutions/articles/9000197281-automatic-packaging>.

What the repository provides:

* `.pkgmeta` names the zip folder `ForeverJourney` (it must match the TOC file name), uses
  `CHANGELOG.md` as the file changelog and leaves out `AGENTS.md`, `DESCRIPTION.md`,
  `README.md`, `assets/` and `docs/`. Dot files are left out automatically.
* `ForeverJourney.toc` has `## Version: @project-version@`, which the packager replaces with
  the tag name. `Core/Init.lua` strips a leading `v` and shows `dev` when running from source.
* The game version comes from `## Interface: 16001`, the same way other Forever addons on
  CurseForge do it. Verified with v0.1.0: CurseForge labelled the file game version 1.60.1.

One-time setup (done by hand, needs the CurseForge account):

1. Create an API token at <https://www.curseforge.com/account/api-tokens>, named for example
   "Webhooks".
2. Copy the Project ID from "About This Project" on the project's overview page.
3. On GitHub open the repository Settings, then Webhooks, then "Add webhook". Payload URL:
   `https://www.curseforge.com/api/projects/<projectID>/package?token=<token>`.
   Leave every other setting at its default. Treat this URL as a secret.
4. The Project ID is in the TOC as `## X-Curse-Project-ID`, so addon managers can match an
   installed copy to the CurseForge project.

## Releasing a version

1. Add a section for the new version at the top of `CHANGELOG.md` and commit it.
2. Tag the commit and push the tag:

   ```sh
   git tag v0.1.0
   git push origin main v0.1.0
   ```

3. The tag name decides the release type. A tag containing `alpha` (`v0.2.0-alpha`) becomes an
   alpha file, one containing `beta` a beta file, anything else a release.
4. Check the new file on CurseForge: folder `ForeverJourney`, game version WoW Forever, version
   shown in the window footer. GitHub lists CurseForge's answer to each push under the
   webhook's "Recent Deliveries" if nothing shows up.

## Logo

Generated, original artwork (no game or trademarked assets): a dashed trail across a dark
journal background, gold milestones along the way and a compass star where the trail ends.
Colours are the addon's own (`UI/Theme.lua`).

| File | Use |
| --- | --- |
| `assets/logo.png` | 1024 x 1024, mark only. Upload this one as the project logo. |
| `assets/logo-400.png` | 400 x 400 copy of the same mark. |
| `assets/logo-wordmark.png` | 1024 x 1024 with the "Forever Journey" wordmark, for screenshots or the description header. |
| `assets/logo-wordmark-400.png` | 400 x 400 copy of the wordmark version. |
| `assets/logo-64.png` | Thumbnail check, not for upload. |

The `assets/` folder is not part of the addon. `.pkgmeta` keeps it out of the release zip.

## Description

The full project description lives in `DESCRIPTION.md` at the repository root. Paste it into
the CurseForge description editor as Markdown. English only for now; other languages, if any,
go below the English text.

## Summary

One line, English, shown as the project preview:

> A personal adventure journal for WoW: Forever that records where your character has been, what you have accomplished and what you could do next.

Alternative, feature-led:

> Your character's own story for WoW: Forever: zones, levels, quests, deaths and dungeons on a timeline, with charts, badges and ideas for what to do next.
