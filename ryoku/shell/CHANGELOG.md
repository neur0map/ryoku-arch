# Changelog: ryoku/shell/

## Unreleased

### Added
- `quickshell/widgets`: desktop widgets on the wallpaper. A new `WlrLayer.Bottom`
  host (per monitor, below windows, namespace
  `ryoku-widgets`), supervised like the pill/visualiser via a `{"widgets", true}`
  entry in `ipc/daemon.go`, carries a clock and a weather widget. The clock ships
  five faces (digital, minimal, analog, flip-card, and a wallust ring clock) with
  12/24h and an optional seconds cluster, plus three toggleable date designs
  (inline, badge, stacked); its accent follows wallust, the brand, or stays mono.
  The weather widget ships three designs (card, minimal, strip) over a live
  animated sky (sun/moon-and-stars, drifting clouds, rain, snow, lightning storm,
  fog) chosen by the WMO condition, with a C/F unit toggle and a today/week scope.
  Every widget is fully customisable, design, size, background (none/card/glass)
  and radius, placement (nine snap zones or a free dragged position), and
  opacity. On the desktop the widgets are interactive: left-drag moves a widget
  (snapping to a grid that fades in, with a press bump and an open/closed-hand
  cursor), and right-click opens a menu in the carbon-dossier idiom (a 力
  masthead, corner registration ticks, hairline rules, mono spec rows with a
  vermilion hover tick). Right-clicking the bare desktop opens the desktop menu
  (show or hide each widget, settings, reload); right-clicking a widget opens its
  own (cycle the design, toggle date/motion/units, lock against accidental drags,
  snap to a zone, hide it), both ending in the global settings and reload-shell
  actions. The layer is interactive across the wallpaper so the right-click lands
  anywhere, but it sits below windows and a left click on bare wallpaper falls
  through to nothing. State lives in
  `~/.config/ryoku/widgets.json` (a watched `Config` singleton, defaults seeded on
  first run), so a save in Ryoku Settings, a drag, or a menu action retunes the
  running widgets with no reload. Weather comes from Open-Meteo (no key), reusing the pill's cached
  location at `~/.local/state/ryoku/weather-loc.json`; its WMO-to-animation mapping
  and parsing live in `weather/lib/weather.js`, unit-tested by
  `weather/lib/weather.test.mjs`. A `Wallust` singleton watches
  `~/.cache/wallust/colors.json` so tinted widgets retune to the wallpaper.
- `quickshell/pill` stash: a cobalt download window. The Download action now opens
  a paste-the-link panel modelled on cobalt (https://github.com/imputnet/cobalt):
  auto/audio/mute modes, a Paste button, and a processing queue that runs links in
  order with per-item progress. A Remux tab rebuilds a media file's container
  losslessly (no re-encode), and a drop zone takes files straight in. The engine is
  cobalt: `stash-cobalt.sh` POSTs to a cobalt API instance (set `COBALT_API_URL`,
  default `http://localhost:9000`; run one per cobalt's docs) and falls back to
  yt-dlp when none is reachable, so a fresh install still downloads. Remux is a
  local ffmpeg stream copy, the same on-device operation cobalt's own remux does.
  The cobalt credit stays visible in the window since the engine is theirs.
- `quickshell/pill` stash: LocalSend receive and send-a-note. The header's Receive
  switch runs a LocalSend v2 server (`localsend.sh receive`, a self-signed HTTPS
  endpoint that announces the machine on the LAN over multicast) which drops any
  pushed file straight into the stash and shows a live tally; the Text action
  sends a typed or pasted note (written to a temp file) to a picked device. The
  `Stash` singleton drives both: the receiver streams `READY`/`INCOMING`/`SAVED`
  lines parsed by a `SplitParser`, the rest reuses the existing send helpers.
- `quickshell/pill`: weather now comes from Open-Meteo (no API key) instead of the
  rate-limited wttr.in scrape, with the resolved location cached at
  `~/.local/state/ryoku/weather-loc.json` so a restart skips the lookup. The
  temperature unit follows the locale (Fahrenheit for US/LR/MM, Celsius
  elsewhere). The pill and calendar readout (`temp`, `condition`, `glyph`) is
  unchanged; `hourly`, `daily`, `humidity` and `city` are now exposed for a future
  hourly/5-day pane. The WMO-code mapping, unit logic and parsing live in
  `lib/weather.js`, unit-tested by `lib/weather.test.mjs` against a captured
  response.
- `quickshell/pill`: the Calendar surface gains local events. A new `Events`
  singleton persists a JSON array at `~/.local/state/ryoku/events.json` (its date
  logic lives in `lib/events.js`, unit-tested by `lib/events.test.mjs`: coverage,
  multi-day spans, time ordering, and the `HH:MM` entry parser). Days with events
  show a dot, clicking a day selects it, and a compact editor under the grid lists
  that day's events (delete on hover) with a single add field that reads an
  optional leading `HH:MM` start time. The surface grows downward only, so the
  pill geometry stays unchanged.
- `quickshell/pill/lib` + `tests/`: unit-test coverage for the launcher fuzzy
  ranker (`fuzzy.test.mjs`, 15 assertions over prefix, substring, and subsequence
  ranking, the usage tiebreak, and `noDisplay` exclusion), plus a
  `tests/shell-unit-tests.sh` runner and a `Shell unit tests` CI workflow that run
  every `ryoku/shell/**/*.test.mjs` (the ranker and the ryoshot
  coords/keymap/annotation libs) on each change. These pure-JS helpers have no
  Quickshell or display dependency, so unlike the advisory qmllint job this is a
  real gate.
- `ipc/ryoku-shell` + `quickshell/pill`: the GNOME keyring password prompt is now
  a pill island instead of gcr's centred GTK dialog. The daemon registers as the
  keyring system prompter (`org.gnome.keyring.SystemPrompter`, interface
  `org.gnome.keyring.internal.Prompter`) on the session bus and reimplements the
  `sx-aes-1` secret exchange (Diffie-Hellman over the 1536-bit IKE group,
  HKDF-SHA256, AES-128-CBC) so gnome-keyring is unaware of the swap. The typed
  secret returns to the daemon over the control socket on its own line, never as
  a process argument (which would leak through world-readable /proc cmdline). A
  new `KeyringSurface` grows the prompt out of the pill centre (the unlock ask,
  the choose-a-new-password ask with a confirm field, and plain confirms), takes
  exclusive keyboard focus, and treats Escape, the backdrop, and Cancel as a
  cancellation. `ipc/prompter.go` and `ipc/secretexchange.go` hold the daemon
  side; `quickshell/pill/Singletons/Keyring.qml` holds the live state. The daemon
  owns the name from startup, so gcr's own prompter stays as the fallback when the
  shell is not running.
- `quickshell/pill`: island appearance styles. The top island now has three
  looks, read from `shell.json` (`islandStyle`) and chosen in Ryoku Settings'
  Shell section: `island` (the classic pill melted into the top frame, the default
  and unchanged), `floating` (a detached pill that hangs just under the frame and
  floats over the content), and `none` (no resting island). An `islandAutohide`
  flag hides the island at rest and reveals it on a hover of the top centre, for
  the `island` and `floating` styles. In every style but the always-shown classic
  island, the reserved top strip collapses so tiled windows rise to the same gap
  as the other three frame edges. A hidden island stays out of the way: only an
  open surface (a keybind), a peek, or (auto-hidden) a top-centre hover summons it,
  so keybinds stay fully functional while a passing toast or OSD never pops it. The
  frame is identical across styles.
- `ipc/wallpaper`: a `refresh` mode (`ryoku-shell wallpaper refresh`) repaints the
  current wallpaper on every output with no transition, so a monitor connected
  mid-session shows the same image without re-animating the displays that already
  have it. The Hyprland hotplug handler calls it after autoscale.
- `quickshell/pill`: the shell's look is now config-driven and live-editable. A
  new `Config` singleton reads `~/.config/ryoku/shell.json` (watched, atomic
  writes, defaults seeded on first run), and the frame and island read every
  appearance value from it: the screen border's corner radius, thickness, surface
  colour, opacity, edge-melt smoothing, and contact shadow (strength and size),
  and the top island's width, height, rest/open corner radius, top gap, bud-melt
  smoothing, and opacity. The mixer/power popouts follow the frame's radius and
  smoothing. Ryoku Hub's Shell Settings edits this file, so a save retunes the
  running shell with no reload; the hand-tuned defaults preserve the shipped look.
- `quickshell/visualizer`: a desktop audio visualiser. A full-width cava spectrum
  rises from the bottom of the wallpaper on a click-through `WlrLayer.Bottom`
  surface, behind every window and per monitor, with vertical-beam bars, a soft
  bloom, and a fading reflection. It blooms while audio plays and settles to a
  calm breathing line when the system is silent. On by default and supervised like
  the pill; `ryoku-shell visualizer` (`Super+M`) toggles it, `ryoku-shell
  visualizer-overlay` (`Super+Shift+M`) raises it over the windows on demand, and
  cava only runs while it is on. Adds the `Spectrum` (64-band cava on the PipeWire playback
  monitor) and `Wallust` singletons under `quickshell/visualizer/Singletons`, and
  the `visualizer` route plus persistent component in `ipc/daemon.go`.
- `quickshell/visualizer`: the visualiser is now config-driven and live-editable. A
  new `Config` singleton reads `~/.config/ryoku/visualizer.json` (watched, atomic,
  defaults seeded), and the spectrum reads its look from it: on/off (also `Super+M`,
  which now persists), style (bars, a filled wave, or floating dots), position
  (bottom, top, or centre), bar/dot shape (rounded or flat), left-right mirroring,
  band count, bar height and width, bloom, reflection, and the idle breathing wave.
  Changing the band count restarts cava with the new bars. Ryoku Hub's Shell
  Settings has a Visualizer tab, with a live preview, that edits this file.
- `quickshell/visualizer`: every style now animates off one per-frame `FrameAnimation`
  ticker locked to the display refresh, easing each band toward its target (fast
  attack, slow decay) so motion is smooth at 60fps+ rather than stepping between
  cava frames. A smoothed `activity` signal (fast rise, ~1s release) crossfades
  between the live spectrum and the idle wave, so a quiet gap fades down and back
  up gracefully instead of snapping off. With the idle wave disabled the spectrum
  fades to nothing on silence (the minimum sliver and the wave canvas clear fully)
  rather than leaving a thin line.
- `wallust`: a new `shell` template writes the live palette to
  `~/.cache/wallust/colors.json` on every wallpaper change. The visualiser's
  `Wallust` singleton watches it, so the spectrum's colours retune to the
  wallpaper. This is the first QML surface to follow wallust at runtime; the Theme
  palette stays static.

### Changed
- `quickshell/pill`: Stash, Tools, and Utilities are unified into one wide
  `力 CONTROL DECK` surface instead of three separate pill popouts, opened by
  `Super+D` (the old `Super+Z` and `Super+U` binds are removed). Single view, no
  sub-tabs: a 力 masthead over two hairline-split columns (Stash left; Tools over
  Utilities right), corner registration ticks, mono micro-labels and tabular
  figures in the hub Profile dossier idiom. Stash drops onto a filling tray with
  the Profile's square spec grid; its action bar is evenly spaced; the Send,
  Receive, Download and Task sub-screens are dismissed by a single Back control
  in the stash header beside the file count. New `DeckSurface`, `DeckStash`,
  `DeckTools`, `DeckUtilities`, `DeckSegmented`, `MicroLabel`, `SpecRow`,
  `CornerTicks`; the standalone `StashSurface`, `ToolkitSurface`, and
  `UtilitiesSurface` are retired, and the old Caffeine tile drops out (Keep-Awake
  covers it).
- `quickshell/pill`: the battery surface shows real Health now, read from the
  physical battery device (the synthetic UPower display device reports no
  capacity), and Rate/Time read `0 W`/`Full` on AC instead of bare dashes. The
  soul bead no longer docks on the percentage digits.
- `quickshell/pill`: the island is reworked into the Ryoku carbon-dossier
  language (matching the hub Profile). A 力 foundry stamp leads, the clock is
  tabular over a mono date/weather line, corner registration ticks frame the
  readout, and hairline rules separate a running-app dock from the status cluster
  on flat carbon. Wi-Fi is dropped from the island (it lives in the hub
  Connections section now); battery and notifications stay. New `AppDock` and
  `BatteryGlyph` components. The battery surface is redesigned: a hero percentage,
  the Ryoku wave as the charge gauge, and a rate/time/capacity/health stat grid.
  The pill calendar's today cell is a warm brand marker (vermilion fill, ring,
  flame lap) instead of the cool frame.
- `quickshell/pill` stash: the action bar lights only what applies. It reads the
  live file types (`Stash.hasMedia` / `hasInstallable`), so Compress dims unless
  there is a video/image/audio file and Install dims unless there is an AppImage or
  tarball; a lone note no longer offers to compress or install it. The LocalSend
  send sheet gained a Scan again button (and a header rescan icon) so an empty
  device list can be refreshed without reopening it.
- `quickshell/pill` stash: the surface is rebuilt around a full-width file grid
  with a toolkit-style action bar (Send all, Text, Download, Compress, Install) in
  place of the cramped left rail, plus a header file count and Receive switch.
  Sends raise a focused sheet (LAN scan, pick a device, then a confirmation naming
  exactly what goes where), and every rail job now opens on a confirm step
  (download shows the clipboard link it found) before it runs; removing a file
  confirms inline on its tile rather than vanishing on a stray click. The look
  follows the Hub's flat tiles, hairline rules, and type tags in the pill palette,
  with a brand drop ring while a drag is over the surface. `StashRail.qml` is
  retired; `StashActions`, `StashSendSheet`, and `StashReceive` are new.
- `quickshell/pill` update island: surfaces the git update channel it was built
  for. Its count and target version read the commits the checkout is behind
  `origin/main` (from `ryoku status --json`) rather than pacman package counts.
- `ipc/wallpaper.go`: a wallpaper change keeps the palette of a fixed Ryoku
  Settings theme instead of re-deriving colours from the image (the theme lock at
  `~/.config/ryoku/theme.json`). Wallpaper-driven themes are unaffected.

### Fixed
- `quickshell/pill`: an auto-hidden island no longer collapses while the cursor
  travels onto its buds (the music/update island and the activity strip). The
  reveal expands the pill, and a bud's x tracks the pill width, so hovering a bud
  collapsed the pill (the music island actively suppresses the pill hover), which
  slid the bud out from under the cursor and hid the island before it could be
  used. A hovered bud (`satelliteHover`) now freezes the pill's expand state, so
  it neither collapses nor slides the bud away and the reveal stays put.
- `quickshell/pill` bar: the bar-mode surface now closes by fading its content
  out against the still-opaque panel, then fading the empty panel, so the busy
  desktop behind never shows through a half-faded surface as a doubled overlay.
  The open and resting looks stay the fused melt; only the bar close changed.
- `quickshell/pill`: hover works again across the whole island. The neck/reveal
  hover zone sitting in front of the pill (added so crossing the tray icons would
  not collapse the island) was a covering sibling holding a `HoverHandler`, which
  swallowed hover from every surface beneath it, so stash tiles, action buttons,
  device rows and the like never lit or revealed their hover actions. Island hover
  is now read by a `HoverHandler` on the pill itself (an ancestor of the surfaces,
  so it never blocks their own hover) OR'd with a neck-only zone that no longer
  overlaps the body.
- `deploy.sh` preserves the user's own and per-machine generated Hyprland files
  across a redeploy. The config swap still replaces the shipped base, but now
  restores `user.lua`, `monitors_user.lua`, `settings.lua`, `theme.lua`,
  `monitors.lua`, and `gpu.lua` from the backup afterwards, so a dev redeploy (or
  `ryoku update` on a checkout) never resets your settings, theme, display layout,
  or GPU pin, matching `ryoku materialize` on a packaged install.
- `quickshell/pill` update island: re-check `ryoku status` on a steady cadence
  (every 5 min) instead of only once at startup, so the island reliably surfaces
  updates that appear during a session and recovers if the first check came back
  empty.
- `deploy.sh` now also installs `ryoku-monitor` alongside the other hardware
  helpers, so the dev loop gets the current version (with the `list`/`apply`/
  profile commands the Displays settings need) instead of a stale package copy.
- `deploy.sh` now builds and installs the real Go `ryoku` CLI (`ryoku/cli`) as the
  `ryoku` command, replacing the old `ryoku/shell/ryoku` dev script (removed). The
  dev mirror now runs the production update CLI (`ryoku status`/`update`), so the
  Hub and island read real data; the dev redeploy is now `ryoku deploy` (the old
  `ryoku update` meant "deploy the mirror"; `ryoku update` is now the real pacman
  system update).
- `deploy.sh` clears any orphaned shell surfaces (`qs -c pill`/`sidebar`/
  `visualizer`) before it restarts the daemon. A crashed or quit daemon left them
  running holding their single-instance lock, so the freshly restarted pill could
  not start and the new daemon died with it, leaving a dead shell after a
  `ryoku update` or `ryoku deploy`. The restart now always comes up clean.

### Added
- `plugin/` (`Ryoku.Blobs`) and `quickshell/pill`: the frame border casts a soft
  contact shadow inward for depth. `BlobGroup` gained `shadowStrength`/`shadowSize`;
  the SDF shader draws a falloff just inside the border (0.5 / 26px), gated to the
  border so the pill and popouts, being the frame swelling open rather than panels
  on top, cast no shadow of their own.
- `quickshell/pill`: a workspace switcher overview grown from the pill centre
  (`Super + Tab`, `ryoku-shell workspaces`). A filmstrip of this monitor's
  workspaces, each a scaled mini-map that draws its windows where they actually
  sit as icon cards (off-workspace windows are unmapped in Hyprland and cannot be
  live thumbnails, so a faithful card layout stands in). Click a window to focus
  it, click a tile to switch workspaces, drag a window onto another tile to move
  it there, or drop it on the trailing `+` tile to send it to a fresh workspace;
  the active workspace and the current drop target carry the brand accent. Window
  icon resolution moved to a shared `Singletons/Apps`, so the minimized tray and
  the switcher resolve icons through one place instead of two copies.
- `quickshell/pill`: an update island on the top-right of the frame. When a newer
  build is available it shows a compact chip (a brand download glyph, the target
  version, and the count of pending commits) that opens the Hub's Updates section.
  While an update runs it mirrors the Hub's progress as a Ryoku wave, and on
  success becomes a Refresh shell button (`ryoku-shell reload`) so the update can
  be applied from here too. The run state is read from a small runtime file the
  Hub publishes; availability is still mock in `Singletons/Updates.qml`.
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
- `quickshell/pill`: the island stays open while hovering the tray/minimized-app
  icons. The hover zone that drives `pill.hovered` sat behind the pill, so the
  icons' own `hoverEnabled` MouseAreas swallowed the hover and the island
  collapsed the moment the pointer reached one; the zone now sits in front of the
  pill. It is handler-only (a passive `HoverHandler`), so it reports the hover
  without blocking the icons' clicks or their own hover highlight.
- `quickshell/pill`: surface content rides the blob morph instead of fading on its
  own. `PillSurface` faded content over a separate, shorter timeline than the
  pill's size morph, so on close the content ghosted out while the shape closed;
  its opacity now animates on the morph's exact duration and curve, growing and
  shrinking with the island.
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
