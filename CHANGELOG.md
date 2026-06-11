# Changelog

## [Unreleased]

### Added

- **Game mode is now a full performance bundle**: one click on the Quick Toggles
  gamepad button (or `ryoku-shell ipc gameMode toggle`) disables compositor
  visuals (animations, blur, shadows, gaps, rounding), enables fullscreen VRR,
  direct scanout and tearing, freezes shell animations, silences notifications,
  keeps the machine awake, pauses night light and live wallpapers, switches to
  the performance power profile, and, through a polkit-scoped root unit
  (`ryoku-gamemode-perf@`) shipped by a `[global]` migration, forces AMD GPU
  dpm levels high, CPU boost on, and locks NVIDIA clocks. Everything restores on
  the second click, with pre-toggle state remembered across shell restarts. Games
  launched via `gamemoderun` (gaming profile) auto-toggle it. Every piece is
  configurable in Settings → Game Mode.

- **Guided installer TUI**: `shell-install/install` opens a `gum` interface: a
  styled support verdict (every distro is told whether it is supported, with the
  reason and a clean exit if not), a recommended pre-install snapshot (detects
  and offers `snapper`/`timeshift`), the confirm, and a closing summary. `gum` is
  installed on the fly; without it everything falls back to plain output. Cards
  are gum-rendered, so the borders always close.
- **`shell.ryoku.dev/install.sh` bootstrap**: the standalone installer has a
  one-command public entry hosted on R2 (`curl -fsSL https://shell.ryoku.dev/install.sh | bash`).
  The `Publish shell installer` workflow uploads `shell-install/boot.sh` there as
  `install.sh`; the bootstrap pulls the live installer from the repo, so the link
  never needs updating.
- **`ryoku-hw-laptop`**: chassis/lid-based laptop-vs-desktop detection that
  returns an exit code for use in conditionals (`if ryoku-hw-laptop; then …`).
  Gates laptop-only power behaviour (lid suspend-then-hibernate). Honours
  `RYOKU_ASSUME_LAPTOP` / `RYOKU_CHASSIS_TYPE_FILE` overrides for VMs and tests.

### Changed

- **Repositioned as a modular Arch distro**: docs frame Ryoku as a lean base
  (8GB covers a browser and everyday use) that scales with plugins and extras,
  not a 16GB-minimum, premium-only workstation. Plugins are framed as native,
  open-source, and user-extensible; extras as the catalogue that installs apps
  and tools with the compatible drivers and dependencies they need.
- **One installer source of truth; the standalone installs everything Ryoku uses**:
  the standalone `shell-install/` no longer keeps its own package map or build
  logic. It reads the shared `install/ryoku-*.packages` (skipping `# @os-only`
  regions), builds `cava-ryoku`/libcava through the same
  `install/packaging/distro-arch.sh` the ISO install and `ryoku-update` use, and
  installs the GPU/firmware drivers from `install/config/hardware/*.sh`. Drivers
  default to packages-only (`RYOKU_BOOT_CONFIG=0`: no mkinitcpio/modprobe/bootloader
  writes, safe on any existing system); `shell-install/install --with-boot-config`
  opts into full ISO parity. The `--minimal` flag is removed (a full install is the point).
- **Standalone installs update like ISO installs**: `shell-install` deploys a git
  checkout of the channel branch to `~/.local/share/ryoku`, so `ryoku-update`
  (git-based) works and `distro/` ships for cava rebuilds. Previously the rsync
  deploy stripped `.git`, leaving standalone installs unable to update.
- **Dropped the generated `ryoku-shell` branch**: only `main` and `unstable-dev`
  remain. `shell-install/boot.sh` defaults `RYOKU_REF=main` (override with
  `unstable-dev`), and the `publish-ryoku-shell` workflow is removed.
  `docs/ryoku-shell-branch.md` now documents the product vs provisioning boundary.

### Fixed

- **Game mode toggle works again on the Lua Hyprland config**: the shell sent
  legacy `keyword` IPC requests, which Hyprland 0.55+ rejects in Lua mode
  ("keyword can't work with non-legacy parsers"), so the Quick Toggles gamepad
  button silently did nothing. `HyprExtras` now probes the parser once and speaks
  `eval hl.config(...)` in Lua mode (legacy `.conf` boxes keep the keyword path).
  The same fix revives the drawer transparency layerrules and the caps/num-lock
  toast binds, broken by the same root cause.
- **Hyprland option reads (`Hypr.options`) repaired for 0.55**: the plugin parsed
  `descriptions` by the pre-0.55 keys (`value`/`data.current`), so the live option
  map was permanently empty: game mode state detection and the area picker's
  border/rounding silently fell back to defaults. It now reads `name`/`current`
  (with the old keys as a fallback).

- **Standalone shell renders on a CachyOS Niri+Noctalia base**: that edition
  ships `noctalia-qs`, which `provides` and `conflicts` `quickshell` and owns
  `/usr/bin/qs`, so the manifest's `quickshell` silently failed to install and
  the shell ran on an incompatible fork that rejects its QML pragmas (a black
  screen). The Arch adapter now detects a conflicting `quickshell` provider and
  replaces it with the real package before installing the deps.
- **Standalone installs theme the SDDM greeter with qylock**: the deploy runs
  `ryoku-install-qylock` (SDDM-only, non-fatal), matching the OS install, so the
  login screen is the Ryoku greeter instead of the distro default.
- **The installer no longer reports success over a broken shell**: `rsi_verify`
  checks the real `quickshell` package and `hyprland.lua` (not the stale
  `hyprland.conf`), and the install exits with an "incomplete" notice instead of
  sending the user to reboot into a session that would come up blank.
- **System update force-refreshes the package db** (`pacman -Syyu`) so a stale
  local db cannot 404 on packages the mirror has already rebuilt.
- **Laptops no longer rot in s2idle on lid-close** (the overnight "dead keyboard
  on wake" hang): `ryoku-hibernation-setup` now wires the suspend-then-hibernate
  it always prepared the groundwork for. On laptops a `logind.conf.d` drop-in
  routes the lid + suspend key through `suspend-then-hibernate`, and a
  `sleep.conf.d` `HibernateDelaySec` (50min) bounds the s2idle window so the
  machine hibernates to disk instead of sitting in (and intermittently failing
  to wake from) modern standby. A `[global]` migration backfills installs that
  already have hibernation set up; desktops only get the (harmless) delay.
- **Idle fires again** (screensaver, screen-off/DPMS, lock, idle-suspend): three
  separate bugs silently pinned the screen on. (1) `inhibitWhenAudio` inhibited
  idle on a *stream existing*, not on audio actually playing: it counted MPRIS
  "Playing" sessions and even capture streams, so a browser/game tab reporting
  "Playing" with no sound, or the shell's own Cava visualiser/beat-tracker audio
  *capture* stream, blocked every idle action indefinitely. It now inhibits only
  on an actual playback stream (`media.class` `Stream/Output/Audio`), ignoring
  capture streams; genuine no-idle apps (fullscreen video) stay covered by the
  per-monitor Wayland idle-inhibit (`respectInhibitors`). (2) The two competing
  keep-awake toggles are unified onto one source of truth: `IdleInhibitorService`
  (bar/control-center) is now a thin adapter over the persisted `IdleInhibitor`
  (caffeine), and `IdleMonitors` gates on that single state, so turning
  keep-awake "off" can no longer leave a second, stuck inhibitor blocking idle.
  (3) The idle screensaver was killed the instant it appeared: opening its
  fullscreen window resets `ext_idle`, and the monitor's `returnAction`
  (`pkill org.ryoku.screensaver`) fired on that self-generated activity: a
  self-kill loop, so it never stayed visible. The screensaver now dismisses
  itself (`ryoku-cmd-screensaver` reads input and checks focus, like Omarchy)
  and is no longer killed by the idle monitor.
- **Idle-lock and lock-before-sleep render the lockscreen without hypridle**:
  `LockBridge` wires the shell's logind watcher (`Ryoku.Internal.LogindManager`)
  so `loginctl lock-session` (idle timeout, manual, or any client) and pre-sleep
  locking launch qylock directly, honouring `lockBeforeSleep`. hypridle is retired.
  It was left half-migrated (enabled but dead on plain `start-hyprland` sessions,
  and double-firing the shell's screensaver/lock timers where it did run); it is
  now masked, un-autostarted, and no longer the lock bridge.
- **`ryoku-toggle-idle` works again**: it toggled a retired `swayidle`; it now
  flips the unified keep-awake inhibitor through the shell IPC.

## [0.1.0-beta2] - 2026-06-08

### Changed

- **Hyprland now runs on its native Lua config**: the compositor config ships as
  `config/hypr/hyprland.lua` (+ `colors.lua`, `monitors.lua`, `keyboard.lua`,
  `gpu.lua`, `custom.lua`, `hyprland-gui.lua`), which Hyprland 0.55+ loads instead of
  `hyprland.conf`. `ryoku-monitor`, `ryoku-gpu`, `ryoku-cursor-set`/`-list`,
  `ryoku-keybinds`, the NVIDIA/keyboard install steps, and the verify-and-restore
  safety net all emit and read the Lua format (with a hyprlang fallback for
  not-yet-migrated boxes). Theme switches recolor the window borders via the new
  `ryoku-hypr-colors`. Existing installs convert their config in place through a
  `[global]` migration (the old `.conf` is kept as a fallback); the hypr* tools
  (hyprlock, hypridle) stay on hyprlang.
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
