# Changelog

## [Unreleased]

### Changed

- **Default app launcher is now Vicinae**: `Super+Space` / `Super+R` open
  [Vicinae](https://github.com/vicinaehq/vicinae) instead of the in-frame
  ryoku-shell launcher. The server autostarts from the Hyprland session, the
  launcher theme follows the active wallpaper palette via matugen, and existing
  installs converge through a migration. The `Super+/`-style shell overview is
  unchanged.
- **Config honors hand edits, never clobbers them**: the typed `Ryoku.Config`
  layer round-trips keys it does not model, so editing
  `~/.config/ryoku/shell.json` by hand no longer loses those keys on the next
  Settings save. `config-overrides.json` is now fill-if-missing on update instead
  of a force-merge, so an update never reverts a dock, panel, or hotspot value the
  user set; changing a default for existing users goes through a `[global]`
  migration.
- **Leaner, human-authored comments**: removed thousands of redundant restatement
  and narration comments across the shell, keeping license headers, pragmas, real
  rationale, TODOs, and the "configurable in Settings" pointers.
- **Wallhaven is now a plugin**: the wallpaper popout moved out of the shell into the
  `ryoku-extras` catalogue (`plugins/wallhaven/`); the shell no longer hardcodes it and
  loads it through the new generic frame-plugin host. The old `shell/modules/wallhaven/`,
  `shell/services/Wallhaven.qml` and `bin/ryoku-wallhaven-search` are gone.

### Added

- **Settings → Launcher toggle**: a switch (on by default) to choose between
  Vicinae and the built-in Ryoku launcher. Turning it off stops the Vicinae
  server and points `Super+Space` back at the quickshell launcher; the keybind
  dispatches through `ryoku-launch-app` so the choice applies without editing
  the Hyprland config.
- **Vicinae packages**: `vicinae-bin` (default install, baked into the offline
  ISO mirror) plus its `qtkeychain-qt6`, `layer-shell-qt`, and `minizip`
  runtime dependencies.
- **Shell rule: user files are the source of truth**: `AGENTS.md` and
  `docs/ryoku-config-architecture.md` now require Settings to act as a control
  surface that preserves hand-edited config and never overwrites a value the user
  set; the rice and overrides only seed defaults.
- **Shell plugins with frame popouts**: the plugin system is activated and wired into the
  running scene (`PluginService.pluginContainer`). A new `framePanel` entry point lets any
  plugin register a frame-edge popout; a generic host in `shell/modules/drawers/`
  (`FramePlugins`/`FramePanelWrapper`) owns the hover, slide, input region, focus and blob
  deform, so a plugin only ships a service and a panel and names a corner. Authoring guide:
  `plugins/AUTHORING.md` in ryoku-extras.
- **Author- and user-controlled frame plugins**: a plugin's manifest `frame` block sets its
  hover-zone size (`activationWidth`/`activationHeight`) and a shortcut `key`. Shortcuts open
  through a leader menu: `Super+X` shows an in-shell HUD of installed plugins and their keys;
  pressing a key toggles that popout (no per-plugin Hyprland binds, so it works under
  HyprMod's Lua config too). Users rebind or clear a plugin's key in **Settings → Plugins →
  Edit**, and their choice wins over the author default.
- **Settings → Plugins** is reachable again (Installed / Available / Sources), and a new
  **Settings → Extras** tab replaces the unused Hooks tab. One Refresh git-pulls the
  `ryoku-extras` catalogue (new `RyokuExtras` service) for both plugins and bundles, the
  way lock-screen themes work.
- **The Ricer bundle + smart installer**: `ryoku-extras-install` installs a bundle or a
  single item, de-duping packages into one `ryoku-pkg-add` call and auto-skipping anything
  already present; curl-style installs use small `installers/*.sh` scripts. The first
  bundle, **The Ricer**, adds aether, cbonsai, cmatrix, pipes.sh and tty-clock plus the
  Wallhaven plugin.

### Fixed

- **Frame-plugin popouts open reliably on hover**: the drawer host now builds a
  plugin's `framePanel` when the plugin registers (off-screen) instead of on first
  hover. Lazy loading made the corner feel broken: the popout appeared slowly and,
  until its content existed the panel reported zero size, so the hover zone collapsed
  and moving toward the content closed it again; its content also now fades in over the
  back half of the slide so the blurred blob surface lands before the UI. The Wallhaven plugin also dropped a
  duplicate height animation that squashed its header while opening, hoisted its
  per-tile context menu into one shared instance (ending a storm of null-`modelData`
  warnings from menus living inside the recycling grid), and now dismisses that menu
  together with the popout so it can no longer be left orphaned on screen.
- **One updater, reachable from the GUI**: Settings to About "Update now" is now a thin
  launcher for `ryoku-update`: the same updater the CLI runs. It no longer pre-fetches
  and refuses with "No updates are available" when only the Ryoku git tree is current,
  and the button no longer hides itself on the git delta, so the GUI can run a full
  system/AUR update (not just Ryoku) and the terminal reports "already up to date" when
  there is nothing to do. Removed the now-dead duplicate fetch/realign helpers that had
  diverged from the updater.
- **Audio no longer ships dimmed ("100% volume but barely audible")**: Ryoku no
  longer forces WirePlumber software mixing on every machine. That override
  decoupled the volume slider from the codec's hardware "Master", so any device
  whose hardware Master shipped attenuated played ~20dB down on laptop
  speakers, headphones, and external/USB outputs alike. WirePlumber now manages
  the hardware mixer natively (the slider drives the hardware level), and the
  per-login self-heal only unmutes output switches instead of pinning them to
  100% (which fought WirePlumber and overrode the chosen volume). The universal
  WirePlumber 40% default-sink-volume override stays; existing installs recover
  through a `[global]` migration.
- **Multi-monitor workspace switching targets the right display**: clicking or
  scrolling the workspace dots on a bar on a second or third monitor now switches
  that monitor's own workspace instead of the focused one. The bar already showed
  per-monitor state but dispatched a plain `workspace N` (or relative `workspace
  r+1`), which Hyprland applies to the focused monitor, so interacting with an
  extended display switched the primary instead. Bar workspace actions now route
  through a monitor-targeted dispatch that focuses the bar's monitor first,
  atomically: one `hyprctl --batch` under Hyprland Lua config mode, ordered IPC
  dispatches under legacy Hyprland.

## [0.1.0-alpha-4] - 2026-05-18

This alpha is the first big Ryoku shell refresh from the live-first shell sync.
The point is not just to import upstream code; the update path now has to carry
additions, edits, removals, and repo metadata cleanly so existing users do not
keep stale shell files or miss new ones.

### Added

- **Native live wallpapers**: animated GIF/WebP via `awww` and video (mp4/mkv/mov/webm) via `mpvpaper`, picked via `Super+W`; Settings → Wallpaper → General exposes enable, mute, transition, and pause-on-fullscreen controls; game mode pauses live wallpapers automatically.
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
- **Doctor reports**: `ryoku-doctor` now writes an anonymized report under
  `/tmp` with failing checks, automatic fixes, update context, and sanitized
  log excerpts that users can share when asking for help.
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
- **Doctor entry point**: user-facing diagnostics now point to `ryoku-doctor`
  only; older shell/setup diagnostic paths are compatibility/internal routes.

### Fixed

- **Release-branch updates**: `ryoku-update-git` now switches an installed
  checkout back to the release branch before fast-forwarding. A live mirror that
  was left on an old shell-sync branch no longer blocks `main` updates.
- **Updater inhibitors on stricter systems**: `ryoku-update` no longer requests
  sleep, shutdown, or lid/key inhibitors that can trigger polkit prompts or
  access-denied failures before the update starts. It keeps the user-session
  idle inhibitor only.
- **Caffeine lock handoff**: the caffeine helper no longer leaks its `flock`
  descriptor into the background inhibitor. Repeated starts now return quickly,
  and the update runner no longer hangs when it enables caffeine for the update.
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
