# Changelog

## [0.1.0-alpha-4] - 2026-05-18

This alpha is the first big Ryoku shell refresh from the live-first iNiR v2.25
sync. The point is not just to import upstream code; the update path now has to
carry additions, edits, removals, and repo metadata cleanly so existing users do
not keep stale shell files or miss new ones.

### Added

- **Desktop widgets**: a real widget manager, example widget support, and new
  battery, system monitor, visualizer, media, weather, and clock widget pieces.
- **Music profile**: an opt-in RMPC + MPD profile with helper commands,
  package manifests, daemon toggle support, and theme integration.
- **Cava and visualizer theming**: Cava target manifests, color extraction, and
  shell controls so visualizer surfaces follow the active theme.
- **AI provider settings**: OpenAI Responses API and Anthropic strategy wiring
  in the shell services and settings.
- **Setup recipes**: a recipe framework under `shell/scripts/setup/`, starting
  with Spotify, so optional app setup can become repeatable instead of manual.
- **More focused regression tests**: coverage for widgets, clipboard display
  navigation, notification timeouts, recorder behavior, setup recipes, package
  integrations, and upstream/Ryoku naming boundaries.

### Changed

- **Version**: bumped Ryoku to `0.1.0-alpha-4` and moved the About page version
  display onto the same local version source the updater uses.
- **Settings layout**: music player options now live under Applications, and
  duplicate compositor/music controls were collapsed back into their existing
  surfaces.
- **Theming pipeline**: Steam moved to the Millennium material theme target,
  Cava and RMPC gained target manifests, and theming modules now gate more work
  through manifests so disabled targets stay quiet.
- **Media surfaces**: shared media artwork is used more consistently across bar,
  sidebars, OSD, lock, overview, and player presets.
- **Recorder UI**: the recording widget and filename handling were cleaned up
  for the new upstream behavior while keeping Ryoku naming.
- **Translations**: refreshed shell translations from the upstream sync while
  keeping tests around mirror-only update environments.

### Fixed

- **Release-branch updates**: `ryoku-update-git` now switches an installed
  checkout back to the release branch before fast-forwarding. A live mirror that
  was left on `sync/inir-v2.25-live-first` no longer blocks `main` updates.
- **Stale runtime files**: shell runtime sync now uses delete-aware rsync and
  manifest cleanup so removed upstream files disappear from the user machine
  instead of lingering beside the new payload.
- **Detached payload metadata**: installs that run from a vendored shell payload
  still stamp `version.json` from the real Ryoku repo, including version,
  commit, install mode, update strategy, and repo path.
- **Local-mod detection**: update checks compare runtime files against the repo
  working tree, local HEAD, and fetched remote content before warning about
  user modifications.
- **Duplicate package/settings surfaces**: the RMPC/MPD integration no longer
  creates duplicate compositor cards or duplicate install controls.
- **Stale dock entries and compact sidebar spacing**: upstream fixes were kept,
  but adjusted around Ryoku launcher behavior and local layout expectations.

### Update Safety

- The installed repo may add, edit, and remove files during update. Removed
  shell files are intentionally deleted from the runtime copy when the manifest
  says they no longer belong there.
- The updater keeps user-local modifications visible instead of silently
  overwriting them, but it no longer treats stale generated runtime files as
  user edits when they match repo content.
- The main-branch updater fix is already on `main` before this upstream branch
  merges, so users can receive the release-branch correction before the larger
  shell payload lands.

### Notes For Testers

- This is still an alpha. Expect visible shell churn, especially around desktop
  widgets, recorder controls, music profile setup, and theme target generation.
- If an update looks stuck, run `ryoku-doctor`. The update metadata now carries
  enough repo and runtime state to make those diagnostics useful.
