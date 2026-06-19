# Changelog: ryoku/shell/

## Unreleased

### Added
- `quickshell/pill`: a voice dictation surface, toggled with ``Super+` `` (tap to
  start, tap to stop). `ryoku-shell voice` flips Handy's transcription and
  grows a centre-island Ryoku wave driven by the live microphone (`VoiceBars`
  runs cava on the default input): flat while silent, swelling into highs and
  lows as you speak. The surface is non-focus-grabbing, so Handy types the
  transcription into the focused app rather than the pill. The pill's tray hides
  Passive StatusNotifier items (per spec), so Handy, run `--no-tray`, stays out of
  the island instead of churning the hover row and flickering it.
- `quickshell/pill`: a dedicated 力 INBOX surface for notifications, opened by the
  pill's bell icon. Notifications group per app with expandable stacks, critical
  entries flagged, an empty IDLE state, and clear-all. The bell used to open the
  LINK surface with the notification inbox buried under the connectivity rows.
- The Ryoku desktop shell, imported and reorganized into this tree: the Quickshell
  UI (`pill` bar, `sidebar`, `ryoshot`), the Hyprland
  config in Lua, wallust palette generation, and the per-app configs.
- `plugin/` and the pill-shell frame: the screen frame, brought from the legacy
  shell and reorganized. `plugin/` is `Ryoku.Blobs`, a C++/QML SDF metaball
  module: a rounded border (`BlobInvertedRect`) and bodies (`BlobRect`) that melt
  into one shared smooth-min field, with a velocity spring that squashes them as
  they move. The pill shell hosts the field per monitor: a click-through rounded
  border in Hyprland's outer gap (retracting to nothing on fullscreen), the pill
  itself as a top blob necked into the border (the island reads as the frame
  swelling open at top-centre), and edge popouts under `pill/popouts/` (the mixer
  left, power right) that grow out of the centre-left/right border on hover and
  melt back into it; the music and activity islands stay on a separate field. See
  docs/frame.md. `deploy.sh` builds the module (cmake + ninja + qt6-shadertools)
  onto `~/.local/lib/qt6/qml` when that toolchain is present (skipping cleanly
  otherwise), and `ryoku-shell` points the quickshell processes'
  `QML2_IMPORT_PATH` there. The module ships prebuilt, like the Go binaries.
- `ipc/`: `ryoku-shell`, a single Go program that is the shell's control plane.
  `ryoku-shell daemon` supervises the Quickshell components (restarting them if
  they exit), brings up the clipboard-history watchers and the wallpaper, and
  serves one Unix socket. `ryoku-shell <command>` is the client the Hyprland
  keybinds call. It resolves the active monitor itself and fans out to the
  Quickshell IPC, the wallpaper daemon and wallust, and qylock for the lock.
- `dev-run.sh`, `dev-stop.sh`, `dev-binds.sh`: run the shell from this checkout on
  a live Hyprland session via `RYOKU_SHELL_DIR` (`qs -p`), with quickshell
  hot-reload, so it can be developed without installing anything.
- `README.md`: documented the shell's runtime dependencies and how to run it live.
- `deploy.sh`: installs this tree into `~/.config` (one way; the repo is the
  source) and `ryoku-shell` onto `PATH`. Pauses Hyprland auto-reload across the
  `~/.config/hypr` swap so the missing-file window cannot trip emergency mode;
  `--no-reload` stages the files for the next login.
- Hyprland autostart now launches `ryoku-idle start`; that helper starts
  `hypridle` on laptops only.
- The Super+D screen toolkit gained a Caffeine tile: a coffee-glyph toggle that
  holds `Flags.keepAwake` (and thus the pill and sidebar `IdleInhibitor`) on until
  it is turned back off, so the screen never dims or locks. Unlike the launcher
  tiles it flips in place and stays lit warm while active.
- Keep-Awake now survives a shell reload/restart. The durable idle inhibitor runs
  as an external `systemd-inhibit --what=idle:sleep` process outside the shell's
  process tree (`hyprland/scripts/ryoku-cmd-caffeine`, launched via `systemd-run
  --user` with a `setsid` fallback), so respawning the pill no longer drops it and
  the screen can't sleep during the swap. The in-shell Wayland `IdleInhibitor`
  still provides immediate effect; the pill bridges any `Flags.keepAwake` change to
  the helper (`start`/`stop`) and reconciles on startup. The helper persists the
  request to `~/.local/state/ryoku/caffeine.enabled` and exposes
  `start/stop/restore/hold/release/toggle/status`.
- `quickshell/pill`: a Utilities surface grown from the pill centre (Super+U), the
  legacy bottom-right panel reworked as a centre island. Keep-Awake with a live
  elapsed counter (shared `Flags.keepAwakeSince`), a Screen Recorder card with a
  record-mode dropdown (display / region / +sound) and running controls
  (pause/stop, elapsed, REC pulse), quick toggles (wifi / bluetooth / mic / DND /
  night light via hyprsunset),
  and a recordings list (with file sizes) and play / open-folder / trash. Recording is driven by
  the `Recorder` singleton (`ryoku-cmd-screenrecord`: gpu-screen-recorder with a
  wf-recorder fallback).
- `ipc/wallpaper.go`: after wallust regenerates the palette, call `ryoku-leds`
  so OpenRGB-compatible keyboards and lighting devices follow wallpaper changes.
- `ryoku`: lightweight live-mirror CLI. `ryoku update` refuses dirty repo state,
  pulls with `--ff-only`, deploys the shell and Hyprland config, reloads Hyprland,
  and restarts `ryoku-shell`.
- `quickshell/pill`: ported ActivSpot's live-activity functions as Ryoku-native
  islands. A left strip of automatic status chips (screen recording, Discord
  voice call, WireGuard tunnel) folds open beside the pill while each state is
  live, and a separated album-art/CAVA music island sits to the right that
  expands its own transport controls on hover without resizing the main pill.
- `quickshell/pill`: the REC activity chip stops the recording on click. Its dot
  squares into a stop icon on hover, so the chip reads as a control rather than a
  readout, and the recording can be ended without opening the Utilities surface.
- `quickshell/pill`: three more native surfaces grown from the pill. A SYSTEM
  card (`SysInfoSurface` + `Singletons/SysInfo`) reads user@host, distro, kernel,
  CPU/GPU, memory and disk meters, uptime and packages; a file STASH
  (`StashSurface` + `Singletons/Stash` + `hyprland/scripts/localsend.sh`) is a
  drop-target grid over `~/Downloads/Stash` that sends any file to a LAN peer over
  LocalSend; and current weather (`Singletons/Weather`, from wttr.in) shows in the
  calendar surface and the hover clock. The card and stash open from new hover-row
  glyphs, and the stash also rides the activity strip as a live chip.
- `quickshell/pill`: the STASH gains an action rail down its left edge: send the
  whole stash over LocalSend, install dropped AppImages and tarballs into the app
  launcher (Super+Space), compress videos and images through ffmpeg, and pull
  media in from the clipboard with yt-dlp. Adds `StashRail`, `StashTaskOverlay`,
  the `send`/`install`/`compress`/`download` `GlyphIcon` glyphs, `Singletons/Stash`
  actions, and the `hyprland/scripts/stash-install.sh`, `stash-compress.sh`,
  `stash-download.sh` helpers (plus a `send-all` mode on `localsend.sh`) behind them.
- `quickshell/pill`: a TOOLKIT centre island (Super+D) of screen tools that grow
  from the pill and run self-contained `hypr/scripts` helpers: Google Lens (upload
  a region and open the search), a color picker (hyprpicker to the clipboard), OCR
  (tesseract on a region to the clipboard), a webcam Mirror (a flipped mpv
  picture-in-picture, floated and toggled), and a QR scanner (zbar on a region,
  copying the result and opening URLs).

### Changed
- `quickshell/pill`: the media player's seek line is the Ryoku wave now, a uniform
  sine ripple with a dim track and a bright played crest, matching the WaveMeter
  signature instead of the damped brush stroke it used to draw.
- `quickshell/pill`: the mixer is audio and display faders only. The DND and
  Keep-Awake chips moved out (they already live on the Utilities centre island),
  and each fader now shows its level at rest instead of only on hover.
- `quickshell/pill`: the LINK surface is connectivity only (Network, Bluetooth).
  Its notification inbox moved to the new INBOX surface: the bell icon opens that,
  the wifi icon opens LINK.
- `quickshell`: Keep-Awake shows one icon everywhere (the coffee glyph). The
  Utilities toggle and the sidebar quick toggle dropped their eye and clock glyphs
  to match the Toolkit Caffeine tile.
- `ryoku-cmd-screenrecord`: starting a recording no longer raises a "recording
  started" toast. The REC chip on the pill's activity strip is the live indicator,
  so the toast was redundant noise; the stop and failure notifications stay.
- `quickshell/pill`: the Stash tiles show a file-type glyph (archive, image, film,
  music, code, document) instead of a large extension label, and the empty state
  is a faint 力 watermark over a minimal prompt, for a less templated look.
- Relocated from the top-level `shell/` to `ryoku/shell/` as part of folding the
  whole desktop into one `ryoku/` tree. The Hyprland config moved to
  `ryoku/hyprland` (the single Hyprland config); the duplicate `fish` was dropped
  for the base `ryoku/apps/fish`.
- Replaced the per-component daemon and toggle shell scripts with the Go IPC: the
  `*-daemon.sh` watchdogs, `cliphist-watch.sh`, and the `launcher`/`sidebar`/
  `clipboard`/`link`/`lock`/`wallpaper`/`wallpaper-picker` scripts are gone. The
  keybinds (`binds.lua`), autostart (`autostart.lua`), and the QML that ran those
  scripts (the power menus, the wallpaper picker) now call `ryoku-shell`. Only the
  two leaf thumbnailers the UI invokes directly remain under `hypr/scripts/`.
- De-branded the import: no upstream name, attribution, or credits; `torii` ->
  `ryoku`, `rishot` -> `ryoshot`, and the matching file and directory renames.
  Removed the em-dashes from the QML display strings (the regex keeps splitting on
  one via an escape).
- Dropped the shell's own lock component; qylock (shipped by `ryoku/`) stays the
  lock, and `ryoku-shell lock` launches it.
- Standardized the terminal and file manager on `kitty` and `nautilus` (what
  `ryoku/` ships): `binds.lua`, the `window_rules.lua` float rule, the wallust
  template (a `kitty` palette now), and the README; removed the `ghostty` config.
- Replaced the import's machine-specific values with portable, hardware-managed
  ones: dropped the hardcoded dual-monitor layout, the German keyboard, and the
  `DP-1`/`HDMI-A-1` -> workspace mapping in the pill and topbar `Workspaces.qml`
  (a monitor-agnostic fixed range now). `hyprland.lua` requires the managed
  `gpu`/`keyboard`/`monitors` and runs `ryoku-gpu`/`ryoku-monitor` from autostart,
  as `ryoku/` does. Fixed the leftover `/home/erik/...` paths, and made `fish`
  match the base (greeting off, `~/.local/bin` on `PATH`).
- Reworked the keybinds: `SUPER+Q` closes, `W` cycles the wallpaper, `B` opens
  chromium, `A`/`SHIFT+A` float (compact) / tile (restore) the window, and `S`
  takes a ryoshot screenshot; dropped the SUPER-tap launcher and `SUPER+T` float.
  `SUPER+[1..0]` focus workspaces, `SUPER+SHIFT+[1..0]` move the window there.
  `SUPER+N` opens Neovim, `SUPER+ALT+E` opens yazi; `EDITOR`/`VISUAL` are nvim.
- `binds.lua`: Super+Z opens the file stash.
- `input.lua`: matched the upstream Ryoku input, `sensitivity` 0, no explicit
  `accel_profile` (libinput's adaptive default), `touchpad.natural_scroll` false,
  and hardware cursors. The shell's reversed scroll and a positive sensitivity
  were what felt non-native.
- `monitors.lua` seed uses `highrr`, so a panel comes up at its top refresh
  (165Hz here) instead of the EDID-preferred 60Hz.
- Kept `ryoku/`'s branded `ryoku-fastfetch` as the terminal readout: dropped the
  shell's wallust fastfetch template and `fastfetch/` dir, so wallust no longer
  overwrites `~/.config/fastfetch/config.jsonc`. wallust themes the kitty palette
  and Hyprland colors only.
- The shell reads wallpapers from `~/Pictures/Wallpapers` (the XDG Pictures home,
  was `~/Ryoku/wallpapers`); the random picker, the picker strip, and the
  thumbnailer accept `.webp` alongside `.jpg`/`.jpeg`/`.png`.
- Removed the orphaned `brave-theme/`: the shipped browser is chromium (`Super+B`)
  and the theme was deployed by neither the dev nor the install path.
- `ipc/wallpaper.go`: Super+W now cycles nine hand-tuned awww transitions
  (`fade`, `wipe`, `wave`, and the `grow`/`center`/`outer`/`any` circle reveals)
  picked at random and never repeated back-to-back, instead of the one fixed wave.
  All share one slow, smooth speed (a single `--transition-duration`/`--transition-fps`
  appended to every preset), so only the shape varies. Border colors follow the
  wallpaper via `hyprctl reload config-only` (Hyprland's new parser rejects runtime
  `keyword`, and `config-only` leaves the monitors untouched).
- `quickshell/pill`: the STASH signs itself with a `WaveMeter` house mark under
  the header that fills on open, dropping the Ame bead that used to dock in its
  centre; the surface is wider and taller so the rail and a two-row grid have room.

### Fixed
- `quickshell/pill`: the shell fully hides while a window is fullscreen. The
  frame, pill, music island, and edge popouts stayed drawn over fullscreen
  content; the whole shell layer now gates on the active workspace's fullscreen
  state (read from the typed `HyprlandWorkspace.hasFullscreen` rather than the
  workspace's last IPC object, which the monitor refresh could clobber).
- `quickshell/pill`: the music island's spectrum bars no longer animate without
  audio behind them. When cava sends no frames they settle to a flat resting line
  instead of a synthetic wave, so the bars read as real playback levels or rest
  flat, the way VoiceBars already treats the mic.
- `quickshell/pill`: the media player surface is reachable from the UI. Tapping
  the now-playing music island opens it; the tap was wired to the file stash, so
  the media surface had no entry point other than the IPC command.
- `quickshell/pill`: Keep-Awake now holds across a shell reload. The in-process
  Wayland `IdleInhibitor` dies with the pill on every respawn, so a durable
  `ryoku-cmd-caffeine` systemd-inhibit (launched outside the shell) bridges the
  swap; toggling any surface still just flips `Flags.keepAwake`.
- `quickshell/pill`: the Recorder detects gpu-screen-recorder by full command line.
  Linux truncates the process comm name to 15 chars, so `pgrep -x
  gpu-screen-recorder` never matched and a live recording read as stopped.
- `quickshell/pill`: the Recorder runs `ryoku-cmd-screenrecord` by its full path.
  `~/.config/hypr/scripts` is not on the shell's PATH, so the bare name never
  resolved and the Record button silently did nothing.
- `quickshell/pill`: the mixer and power edge popouts close on hover-leave. The
  close spring was underdamped enough to spring the body back open past flush,
  re-triggering the hover and sticking the popout (power especially) open; the
  close now eases out with no overshoot.
- `quickshell/pill`: the activity-strip chips (REC stop, stash) now receive hover
  and clicks. The strip rides left of the pill, outside the pill's input mask, so
  its region was never grabbed and clicks fell through to the window behind; the
  mask now covers the strip's bounds, like the music island and edge popouts.
- `ipc/wallpaper.go`: resolve a symlinked wallpaper directory (`EvalSymlinks`)
  before scanning, so `wallpaper next` and the picker work when
  `~/Pictures/Wallpapers` links to a collection elsewhere.
- `quickshell/ryoshot`: create `~/Pictures/Screenshots` on launch; it did not
  exist, so the screenshot grab failed and copy/save silently did nothing.
- `quickshell/ryoshot`: de-branded the selection label (dropped the leftover
  torii glyph; it now reads `ryoshot · WxH`).
- `quickshell/pill`: music track changes no longer open the main pill as a media
  OSD; main and music islands use their own rounded-shape hover masks, so workspace
  dots stay reachable and the separated music island owns its compact controls.
- `quickshell/pill`: the separated music island's close animation no longer pops.
  `scale` was derived from the animated `reveal` but carried its own `Behavior`
  (a ~220ms lag), and opacity was a constant, so the bubble vanished mid-shrink;
  it now fades with `reveal` and scales directly, retracting cleanly behind the pill.
- `ipc/wallpaper.go`: Super+W no longer lags. The retheme (wallust palette, the
  Hyprland reload, and the OpenRGB LED pass) ran synchronously under the wallpaper
  lock, so every press blocked on the multi-second `ryoku-leds`/OpenRGB device scan
  and presses serialized behind it. The keybind now only fires the transition and
  returns (~150ms); the palette+border reload and the slow LED pass run on
  coalescing background workers, so rapid presses stay smooth and the settled
  wallpaper still themes once.
- `quickshell/pill`: removed the island's on-hover wave animations. Both the
  per-icon hover underline (a crossfading trail of orange marks across the status
  row) and the island-open wake-wave streak read as a glitchy wave line on hover;
  both are gone (WakeWave.qml and its latch deleted), and the icons just brighten
  on hover. The hover content clips to the pill and fades in as the island opens,
  so it loads immediately instead of staying blank until the morph settles.

### Not included
- The GRUB theme (the system boots with Limine) and the SDDM theme (a 38 MB
  third-party video, and the login screen is qylock). Bring either in later if
  wanted.
