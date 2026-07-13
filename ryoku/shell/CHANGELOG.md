# Changelog: ryoku/shell/

## Unreleased

### Added
- **The desktop mark and name are now user-overridable across the shell.** Every
  力 seal in the chrome (the bar, launcher, overview, the pill deck and popouts,
  desktop widgets and the calendar, the wallpaper switcher, ryoshot's watermark,
  and the welcome tour) renders through a shared `BrandMark` that reads a new
  `~/.config/ryoku/brand.json`: a short text/glyph mark (default 力), or a custom
  SVG/PNG logo (tinted to the accent via `ColorOverlay`, or shown as-is), plus the
  desktop name ("Ryoku" by default) in the welcome copy. Ryoku's own apps (the
  Hub, ryo* apps) keep their brand and ignore it. Edit it in Ryoku Settings,
  Shell, Global (`BrandMark.qml` per app, each `Singletons/Config.qml` and
  `Theme.qml`, and the rewired seals across
  pill/launcher/overview/widgets/wallpaper/welcome/ryoshot).
- **The recorder island is now the single entry point for capture.** The 力
  deck's Record button no longer drops a mode menu; it opens the floating
  island in a pre-record chooser. The capture toggles (screen or region,
  desktop audio, microphone) moved into that chooser, next to three actions.
  **Quick** and **Studio** both capture with gpu-screen-recorder (clean on
  Wayland, no screen-cast portal double-prompt); **Edit** opens **ryomotion**
  (the OpenScreen-based editor, its own package) to import a clip. Quick morphs
  the island into the live control bar and saves a plain recording; Studio also
  samples the cursor, writes ryomotion's `<clip>.cursor.json` sidecar, and opens
  the clip in the editor on stop, so its automatic cursor-follow zoom still works
  (`RecordHud.qml`, `DeckRecord.qml`, `Singletons/Recorder.qml`,
  `ryoku-cmd-screenrecord`, `ryoku-cmd-studiorecord`, `shell.qml`).
- **Region recording shows a live boundary and works for Studio too.** Picking a
  region now dims everything outside it while you record -- a click-through
  overlay (`RegionOverlay.qml`) that stays up for the whole capture, so you can
  keep moving windows around the box while only the region records. Both Quick
  and Studio honour it (Studio used to always catch the full screen), and Studio
  re-bases its cursor sidecar to the region so auto-zoom maps inside it. The box
  the picker drew lives on `Recorder.regionGeom`, shared by the overlay and the
  recorder, and gsr crops to exactly that box (`RegionOverlay.qml`,
  `Singletons/Recorder.qml`, `RecordHud.qml`, `shell.qml`, `ryoku-cmd-studiorecord`).
- **`ryoku-shell system` toggles the right (System) sidebar**, so it can be
  bound like the left `toolkit`/`sidebarLeft`. `Super+Alt+D` uses it; the daemon
  maps the verb to the pill's existing `sidebarRight` handler (`ipc/daemon.go`).
- **The desktop visualiser gains four new looks: a stiff line, LED segments, a
  radial ring and a morphing circle, plus peak caps and a frame budget you
  control.** Beside bars, dots and the filled wave the spectrum now draws as a
  **line** (a stiff angular readout with its own glow that snaps where the wave
  flows), **segments** (a lit LED stack per band), a **radial** ring of bars
  around a pulsing centre, and a **circle** (a closed blob whose radius breathes
  with the music). New per-look controls: render **fps** (30 by default, up to
  60, with cava sampled at the same rate so nothing is computed twice),
  **smoothing** and **sensitivity**, falling **peak caps**, and the **segments**
  count, all live from `visualizer.json` (`Visualizer.qml`,
  `Singletons/Config.qml`, `Singletons/Spectrum.qml`, `shell.qml`).
- **An adaptive governor keeps the visualiser cheap under load.** When the render
  timer slips behind for a sustained stretch (a busy machine or a heavy pick),
  the engine steps down in tiers: it lowers the frame rate, drops the bloom
  buffer and reflection, sheds the peak cache, and folds segments back to bars,
  then climbs back when headroom returns. It throttles the cost, never the
  spectrum, so the desktop keeps drawing (`Visualizer.qml`).
- **Ryoshot gains a Beautify editor (the 力 button), sharing-first.** After a
  capture, the toolbar's 力 button opens a full editor with a frosted, textured
  chrome (the launcher's grainy look): a live canvas beside a grouped panel that
  uses the right control for each job. Background is a thumbnail grid of gradient
  presets plus Solid / custom Gradient (two colours + angle) / Image / None
  (transparent); Frame has padding, roundness and a coloured border; Shadow has
  strength, blur, distance and a direction dial; plus Adjust (brightness /
  contrast / saturation) and a Ratio row with social formats (X, Instagram,
  Story, LinkedIn, YouTube, Pinterest) and an optional 力 + `user@RyokuArch`
  watermark. Copy or Save
  through the same path as a plain shot, so it matches the desktop and needs no
  new dependency (`Beautify.qml`, `Slider.qml`, `Dial.qml`, `Toolbar.qml`,
  `shell.qml`).
- **Beautify presets with a savable default.** A PRESETS row offers one-tap
  looks (Ember, Ocean, Sunset, Mono, Paper, Bare). *★ Set as default* writes the
  current look to `~/.config/ryoku/ryoshot-beautify.json`, so every later capture
  opens already styled without re-tuning; with a default set, the annotate toolbar's
  Copy and Save bake it in and export directly, no editor needed. *Reset* strips to a
  plain image, and the shadow casts the way the dial points (`Beautify.qml`, `shell.qml`).
- **Ryoshot annotation gains a magnifier, counters, pixelate redaction and a
  hand-drawn style.** The toolbar adds a **magnifier** loupe (drag a circle that
  zooms the shot beneath it, ringed), a numbered **counter** stamp (click to drop
  1, 2, 3… badges that scale with the pen width), a **pixelate** region for
  redaction (a mosaic over the frozen shot, beside the existing blur), and a
  **sketch** toggle that renders rectangles, ellipses, lines and arrows with a
  smooth hand-drawn stroke (`Toolbar.qml`, `Icon.qml`, `AnnLayer.qml`,
  `Overlay.qml`, `shell.qml`).
- **Beautify HD ×2 export (opt-in AI upscale).** A SHARE toggle runs the export
  through the GPU (`waifu2x`, no denoise so text stays crisp) to double the
  resolution before Copy/Save. Off by default and saved with your default, so it
  can bake in automatically; it skips already-large shots and falls back to the
  plain grab when the tool is absent (`Beautify.qml`).

### Fixed
- **Setting a wallpaper with no wallpaper daemon installed says so instead of
  hanging and going silent.** With neither `awww` nor `swww` on the box (an
  AUR build that never landed), every image apply ground through ~15s of
  retrying a daemon that does not exist and then returned as if it had worked.
  The daemon start now fails fast when the binary is absent and the apply
  returns a real error naming the fix (`install awww`, or `ryoku doctor` heals
  it), which the shell surfaces like any other wallpaper failure
  (`ipc/wallpaper.go`).
- **The sidebars now close as fast as they open.** A keybind or click dismiss
  sat through the 300ms hover-intent grace before it began melting, so `Super+D`
  (and the right sidebar) snapped open but felt laggy to shut. The grace now
  applies only to a hover-leave -- its real job, debouncing a graze across the
  blob rim -- while a deliberate unpin melts at once, even under the pointer
  (`quickshell/pill/popouts/Popout.qml`).
- **Live (video) wallpapers stop freezing and play smooth and native.** Three
  bugs made a live wallpaper set, then freeze on the first frame, then stutter
  when it did move. (1) The daemon paused mpvpaper whenever the active workspace
  held any window (`pauseWhenCovered` plus the `desktopVisible` "a window covers
  it" heuristic borrowed from the widget layer), so on a single-monitor desktop
  opening one window froze the wallpaper even though it shows through gaps and
  around windows. A live wallpaper is meant to move, so it plays continuously
  now: the covered-pause path (`livePauseReconcile`, the `pause-sync` mode, the
  hyprwatch hook, and the ryowalls "Pause when covered" toggle) is gone. (2)
  Playback ran with `video-sync=display-resample`, which needs the panel refresh
  to pace frames, but mpvpaper's libmpv render path never reports one, so the
  resampler ran blind and juddered; it paces to the clip's own rate now. (3) 4K
  clips dropped frames downscaling with the default scalers, so `profile=fast`
  uses cheap scalers (invisible on a background) while hwdec keeps decode on the
  GPU, so playback stays native and smooth (`ipc/wallpaper.go`,
  `ipc/hyprwatch.go`, ryowalls `SettingsPanel.qml`, `Singletons/Wallhaven.qml`).
- **Styles with a fixed baseline no longer freeze on screen when the music
  stops.** With the idle wave off, the circle and the radial centre ring kept a
  constant radius that never shrank to nothing, so the render ticker halted and
  left a static ring behind (bars, which collapse, cleared fine). The whole
  field now fades out with the "playing" signal, its floor meeting the ticker's
  stop threshold, so every style vanishes on silence (`Visualizer.qml`).
- **The visualiser's analyser no longer runs faster than it draws.** cava was
  pinned at 60fps while the render capped near 30, sampling twice for every frame
  shown; it now follows the configured frame rate (default 30), roughly halving
  its steady-state cost (`Singletons/Spectrum.qml`).
- **The left screen edge is clickable again (no dead strip while browsing).** The
  left sidebar's drag-to-stash trigger masked a band the full hover-corner width
  (`sidebarCornerSize`, ~54px scaled) down the entire left edge, but windows only
  inset `gaps_out` (18px), so roughly 36px of every window's left edge silently
  swallowed clicks for its whole height (a browser's back button, scrollbar, and
  first tab sit under it). The band is now a thin sliver kept inside the frame gap:
  it still opens the stash when a file is flung at the left edge, but never covers
  window content (`pill/shell.qml`).
- **`ryoku deploy` preserves every user file now, matching a packaged update.**
  The dev deploy rebuilt `~/.config/hypr` from the repo and carried across only
  seven named files, so any other user-owned file (an extra `.lua`, a custom
  `modules/*.lua`) was silently dropped, while a packaged `ryoku materialize`
  keeps every file the release does not ship. `deploy.sh` now mirrors it: it
  carries across anything the freshly-staged repo tree does not contain
  (`user.lua`, `monitors_user.lua`, `settings.lua`, `theme.lua`, and anything
  else the user added) and keeps the live copy of the per-machine seeds
  (`monitors.lua`, `gpu.lua`, `keyboard.lua`) over the shipped default, so a dev
  box and an installed box preserve the same set.

### Changed
- **The desktop calendar grew up: edit, time ranges, and navigation that comes
  home.** Clicking an event now reopens it in the add field for editing (Enter
  replaces it, Esc cancels), a leading `9:30-10:30` range is parsed into start
  and end times and shown on the row (the pill's calendar displays it too), and
  every face navigates: month and heat page by month, week by week, agenda by
  seven-day page, each with an accent TODAY chip that appears once you leave
  today and snaps the view (and selection) back. The viewed month derives from
  today plus an offset, so the old one-way navigation that froze the widget in a
  past month is gone and the view self-heals at rollover. Week pre-selects today
  and no longer deselects on a re-click; empty days say "Nothing on this day"
  over the add field; the delete tick arms on the first tap and removes on a
  second within two seconds, on a 24px hit area (chevrons grew to 26px). Under
  the hood: heat cells count events without sorting, the today marks derive from
  a once-a-day key instead of the 1s tick, the calendar slot releases its
  keyboard grab on teardown, and the right-click menu gained an Accent row.

### Removed
- **RyoTunes / YouTube Music is gone from the launcher.** The `@` YouTube Music
  search provider, the mpv radio engine (`Singletons/Radio.qml`), saved playlists
  (`Singletons/Playlists.qml` + the `SavedPlaylists` strip), the pasted
  YouTube-link "play" row, and the MPRIS "YT Radio" seed verb are all removed. The
  now-playing card and the other-sources strip stay, now driven by a slim
  `Players` singleton (the proxy-drop/dedupe helper extracted from the old
  engine), so controlling Spotify, a browser tab or any MPRIS player still works.
  Drops the `mpv-mpris` package, which existed only to expose the YT Music stream.

### Added
- **A first-run welcome walkthrough greets new users once.** On the first login,
  a floating `welcome` surface (`quickshell/welcome`, run as `qs -c welcome`) opens
  over fal.ai-generated Greek-noir threshold art: a five-step guided tour that
  introduces the essential keybinds, names each desktop surface and how to summon
  it, and offers a few genuinely-wired quick settings: shuffle the wallpaper via
  `ryoku-shell`; set the bar position, the bar skin, and the shell-frame corner,
  merged into `shell.json` with a key-preserving write so the running shell retunes
  with no reload; and the window-corner rounding, round-tripped through the Hub's
  own `ryoku-hub hypr` appearance path. The Hyprland
  autostart launches it once, guarded by an flock and a
  `~/.local/state/ryoku/welcome-seen` flag written after the window closes, so the
  tour shows exactly once; a `float-ryoku-welcome` window rule floats and centres
  it. The backdrop is generated at dev time and committed
  (`welcome/art/welcome-bg.png`), so the running target keeps no generation
  dependency.
- **Live wallpapers take motion settings and play smoother.** When it launches
  mpvpaper, the wallpaper daemon reads a max-fps cap and a fill/fit choice from
  `ryowalls.json`, and a new `wallpaper live-reload` mode relaunches the current
  clip with fresh options when ryowalls changes them (no state write, no
  retheme). mpvpaper now also runs with `video-sync=display-resample`, so frames
  are paced to the panel refresh instead of juddering; a sub-60 fps target caps
  decode and paint for battery while 60 (the default) plays the clip at its own
  native rate (`ipc/wallpaper.go`).
- Active quick-toggle icons stay legible on a light wallpaper accent: the icon on
  a lit tile flips to dark ink on the accent fill instead of washing out in
  warm-white.
- **Weather takes a set location and unit.** Beyond auto-locating by IP, the
  shell reads a `weatherLocation` (a city name, geocoded via Open-Meteo; blank
  keeps the IP auto-locate) and a `weatherUnit` ("auto" follows the locale, else
  celsius / fahrenheit), both set from Ryoku Settings' Global tab. A unit change
  re-fetches, so the reading, not just the degree symbol, is right.
- **Two corner-hover sidebars, replacing the control deck.** Full-height panels
  that melt out of the left and right frame edges and fuse into the top and bottom
  frame, so a whole side swells open with no gap. Push the cursor into a top corner to open (a
  short intent, a grace on leave), or toggle via IPC. **Left is Features** (the
  Stash file board, room for more); **right is System**, the control centre folded
  in from the old deck: 力 clock and weather, the session and quick toggles, the
  screen-capture tools and a clipboard button, a volume fader, and a tab rail over
  the notification digest, the month calendar, now-playing, the weather forecast,
  and screen recording. Ryoku Settings' Shell section gains a **Sidebar** tab
  (enable each side, pick and order each side's panes, open-on-hover vs click,
  width, corner-hotspot size). Built on a new `Popout` `fullSpan` mode; the old
  `DeckSurface` / `DeckPopout` control deck is gone.
- **Drag a file to the left edge to stash it.** The left (Features) sidebar now
  springs open when a file is dragged onto the left frame edge or corner -- a
  masked `DropArea` band `sidebarCornerSize` deep, since a HoverHandler can't
  fire while a drag holds the pointer -- so its Stash board is right there to
  drop onto (the board copies the file in and the sidebar tucks away when the
  drag ends; a drop on the edge itself stashes too).
- **A global `roundness` knob and a Global settings tab.** One shell-wide inner
  corner radius (Ryoku Settings' new **Global** tab, alongside the frame melt,
  surface, shadow, and typography controls moved there) rounds every tile, card,
  row and chip so the shell shares one shape with the rounded frame. 0 restores
  the old brutalist sharp corners.
- **A single floating-island bar, `delos`.** `barStyle` takes `delos`: the whole
  bar becomes one draggable island in the frame's blob field, the recorder
  island generalised. Grab its 6-dot grip and it pulls off the edge (the rest
  of the island stays interactive, so the modules keep their taps and wheels);
  near another edge it and a frame bump reach for each other and merge like two
  drops; let go and it drifts to the nearest edge; on a side edge it turns
  vertical (its modules restacking into a narrow strip); tap the grip to
  tuck it to a nub a hover pops back. It carries the modules you pick
  (`islandModules`: workspaces, clock, date, now-playing, and optionally the
  window title, status glyphs, tray), opens the frame-aware popouts from its
  docked edge, and remembers where it sits across a restart. The window reserve
  follows it live: dock it to any edge and tiles tuck against it there, hide it
  and the reserve shrinks to the nub. Power is not a module here; Super+Esc
  opens it as a vertical strip in the top-right corner.
- **Two Ryoku-native bar skins beside the two carried ones.** `barStyle` takes
  `aegis` and `stele` alongside `noctalia` and `caelestia`. Aegis drops the
  module pills for flat modules on the band, a mono editorial clock led by an
  accent tick, an accent underline beneath the active workspace and the
  interactive modules, and tabular mono status: the instrument-panel read.
  Stele engraves every module as a sharp bracket-cornered cell, frames the
  active workspace in accent, and splits the clock with a hairline divider.
  Both ride the same swollen frame edge and grow the same bar-edge popouts as
  the reference skins.
- **A third native skin, triptych.** `barStyle` also takes `triptych`, in the
  Brain_Shell mould: the top edge stays a hairline and the frame grows three
  lobes fused under the module clusters (left: seal, workspaces, title; centre:
  clock, plus now-playing while it sounds; right: status, tray, power), so the
  bar dips between the three instead of swelling into one straight band. The
  lobes are `BlobRect`s in the frame's own field. A popout on triptych is
  frame-aware: its own section swells to a full band to host it while the other
  clusters keep their dips, and on close it narrows back toward the module it
  grew from and melts into that lobe, so the dips return around it rather than a
  wide band deflating in place and snapping shut. The other skins keep their
  straight band.

### Changed
- **The workspace overview and wallpaper switcher open instantly.** Both were
  cold-spawned as a fresh `qs -c` process on every keypress, so Super+Tab paid a
  whole Quickshell start (Qt, Wayland, scene graph, first frame) and the overview
  then polled Hyprland every 140 ms for its still-empty window model before it
  could draw. They now run resident under the shell daemon and toggle over IPC,
  the way the launcher and pill already do: Super+Tab and Super+C flip a hidden
  surface visible against warm compositor models instead of launching a process.
  The overview's live `ScreencopyView` captures are gated on open, and both use
  the render-on-demand loop, so a hidden resident instance draws nothing and
  costs about its memory. The daemon also staggers the persistent components'
  startup so a handful of them no longer cold-start in the same login frame.
- **The orphaned standalone Alt-Tab switcher config is gone.** `quickshell/switcher`
  was a `qs -c switcher` overlay no keybind launched; the workspace overview
  covers window switching, so the dead surface was removed.
- **Bar-island content eases in and out instead of snapping.** The now-playing
  module grows along the band and fades when it appears and shrinks back when it
  leaves (music starting or stopping), instead of popping into place, and the
  island, and its triptych lobe, resizes with it. The focused-window title
  cross-fades old to new on a focus change and eases its width to the new
  length. Both ride the shared motion curves; `BarReveal` and `BarTitle` carry
  it, so every skin gets it.

### Fixed
- **`pip.conf`, the default-app map, and the nvim editor handler now reach every
  install.** `pip.conf` was shipped by no package, installer, or deploy path, so
  `pip install --user` hit the PEP 668 wall everywhere; `mimeapps.list` and the
  nvim `.desktop` were seeded once at install and never updated after. The
  package now ships all three, so `ryoku update` materializes them with the rest
  of the config, and `ryoku/shell/deploy.sh` lays them on a dev box too.
- **Tray menus open under their icon.** A right-click on a system-tray icon
  anchored the menu at the icon's local x inside the tray row, not its position
  in the window, so the menu appeared at the bar's left edge instead of under
  the icon. It maps to the icon's window position now, on every bar skin.
- **A runtime frame-border change repaints.** `BlobInvertedRect`'s border
  setters marked the blob group dirty but never scheduled the item's own
  repaint, so a border-thickness change at runtime, switching bar skins or
  moving the bar between edges, left the old band on screen until the next
  geometry change happened to nudge it. The setters now schedule the repaint.
- **The stele clock divider is visible again.** Its hairline used `Theme.line`,
  a token the bar theme does not define, so it resolved to transparent; it now
  uses `Theme.hair` like the other bar hairlines.
- **A popout close is one monotonic melt again.** The visible dip-then-pop
  was the border sink: the melt buries the body rect fully inside the frame
  band, which is exactly the state that makes the inverted border's inner
  wall recede to pocket a rect, so every close dug a body-wide notch past the
  flush line and released it in one frame at the zero-size drop-out. Blob
  shapes now carry a `sinks` flag and the popout body opts out, so it slides
  in flush while a docked recorder island still gets its pocket. Three
  supporting causes went with it: content teardown at half melt shrank
  `openW`/`openH` through the overshooting spatial Behavior mid-retract (the
  size is now latched at close start, the way `heldAlong` latches the
  centre; Caelestia freezes its launcher height on close with the same
  trick); the input-mask regions re-read the animated body rect and
  recommitted the wayland input region every melt tick (they now bind the
  resting open geometry and drop to zero when the close starts, so a
  dismissed body stops eating clicks; hover bands keep tracking live content
  size so a never-opened popout stays hoverable).
- **The blob deform spring survives hitchy frames and coordinate jumps.** The
  integrator now runs in 8 ms substeps, stable at any configured stiffness
  through a 100 ms frame (at stiffness 800 and up one such frame used to flip
  it divergent, which is what the giant-blob guard was catching), and a
  centre jump past 8000 px/s is treated as a coordinate change rather than
  motion, so a terminal melt collapse or a group rejoin cannot yank a squash
  into the whole field and ring for half a second.
- **Popouts now melt fully flush instead of stalling and snapping shut.** The
  blob body kept its full neck buried in the frame band until the very last
  frame of a close, and the smooth-min fillet held the fused edge a couple of
  pixels proud of the band; when the shape hit zero size it was deleted in one
  frame, ledge, wings and outline all vanishing at once. The body now retracts
  its inner face one smoothing-depth into the border as the close progresses,
  so the silhouette is already flush when the shape drops out. The mirrored
  pop-in on the first open frame is gone too.
- **A closing popout no longer teleports along the bar.** Opening popout B
  while A was up wrote the new icon centre while A was still pinned, so A
  jumped under B's icon (or to bar centre on a keybind) and melted there. The
  toggle now unpins the old popout before moving the anchor, so it melts where
  it opened.
- **Click-opened popouts close the moment you ask.** The body-hover latch that
  keeps the media hover panel alive while the pointer crosses onto it also
  applied to pinned popouts, so a close button, Escape or a keybind re-toggle
  appeared dead until the pointer left the panel. The latch is now scoped to
  hover-driven popouts.
- **Dragging the recording island no longer snaps it home mid-drag.** The
  overlay's input region only covered the island's current rectangle, and the
  island clamps at the frame lips, so a drag toward an edge let the pointer
  slide off the rect: the compositor dropped the grab and the return-to-frame
  spring yanked the island back while the button was still held. The mask now
  widens to the whole surface for the duration of the drag.
- **Wallpaper matching keeps the shell readable on loud wallpapers.** A
  saturated red wallpaper made wallust emit a bright crimson background, and
  the shell painted the frame, bar, popouts, launcher and widgets with it raw:
  red icons on red surface at 1.2:1. The Wallust singletons now tone-map the
  background into the shell's dark band (hue kept, value and saturation
  clamped) and walk accents toward white until they clear 3:1 against the
  surface. Dark palettes pass through byte-identical, so nothing changes on a
  well-behaved wallpaper. The media popout's time labels also move from the
  decorative `faint` token to `dim` so position and duration stay legible.
- **A home-deployed Ryoku.Blobs plugin can no longer shadow the packaged one.**
  The daemon prepended `~/.local/lib/qt6/qml` to the QML import path
  unconditionally, so one old deploy or recovery run pinned the compiled blob
  plugin at that vintage forever, ignoring every later `ryoku-blobs` update.
  Now only a home-deployed daemon (a dev checkout or recovery) prefers the
  home modules; a packaged `/usr/bin/ryoku-shell` loads the packaged plugin.
- **The blob deform spring can never draw diverged geometry.** If the
  integration state ever goes non-finite or lands a whole unit off identity
  (the target stretch caps at 1.35), the plugin snaps that shape to rest
  instead of rendering the garbage on every following frame.

### Changed
- **Voice dictation now runs on Voxtype, not Handy.** Super+` drives Voxtype
  (from `voxtype-bin`) with `voxtype record start`/`stop` on the tap, and its
  engine and model are chosen in Ryoku Settings' Dictation page. The pill's mic
  wave is unchanged; only the transcription engine behind it moved.

### Fixed
- **Live wallpapers no longer hijack the media controls.** mpvpaper is an mpv
  instance, and with `mpv-mpris` installed it registered the wallpaper clip as an
  MPRIS player: the launcher's NowPlaying listed the silent wallpaper as video,
  pausing your music handed the now-playing slot to it, and the MPRIS play/pause
  crosstalk froze the clip when music resumed. The wallpaper mpv now launches with
  `no-config load-scripts=no`, so the plugin never attaches.
- **Live wallpapers set without mpvpaper now, instead of erroring.** Setting a
  video called `mpvpaper` unguarded, so on a box without that optional AUR daemon
  ryowalls reported "Could not set wallpaper" even though the clip downloaded. The
  shell now falls back to a still frame of the clip (one ffmpeg grab shown through
  the image daemon) when mpvpaper is absent, so the pick applies and themes: with
  mpvpaper the wallpaper moves, without it it is the frame. mpvpaper stays a true
  optional enhancement.
- **Wallpapers set again on machines that predate the `swww` -> `awww` rename.**
  The shell drove the wallpaper daemon by the hard-coded name `awww`; upstream
  renamed `swww` to `awww`, and a `ryoku update` never pulls the AUR rename, so a
  box still carrying `swww` silently no-op'd every wallpaper set (static images,
  and with the daemon absent the palette retheme too). The shell now resolves
  whichever of `awww`/`swww` is actually installed (awww preferred, identical
  CLI), so ryowalls and Super+W work on either.
- **The voice dictation wave tracks the mic instead of stalling.** The mic
  spectrum used cava's PipeWire input, the same backend that quits within
  seconds here, so the wave came up late and dropped out mid-sentence while the
  mic itself was fine. It now reads the mic through cava's Pulse backend and
  execs cava so the analyser is reaped cleanly, matching the desktop visualiser.
- **Super+` voice dictation opens centred, and Handy stops flickering.** The
  keybind's socket fast path set the popout without clearing the previous
  icon's centre, so the mic wave grew from wherever the last popout had opened;
  it now recentres like every other keybind popout. The tap also toggled Handy
  via `handy --toggle-transcription`, which launches a second instance to relay
  the flag; on Wayland, where Handy cannot claim a global shortcut of its own,
  that popped the app in and out, so the shell now signals the running instance
  with SIGUSR2.
- **The desktop and launcher spectrum visualisers work again.** cava's PipeWire
  input backend quits within seconds on current PipeWire, so the bars blanked
  and restarted until the surface showed nothing at all. Both visualisers now
  read the sink monitor through cava's Pulse backend (pipewire-pulse), which is
  stable here, and exec cava from the launch shell so the surface's exit reaps
  the analyser instead of leaking a client every time it unloads.

### Added
- **A recording control that lives in the frame's blob field.** While a screen
  recording runs, a small island melts out of the nearest frame edge: a 6-dot
  drag handle, the elapsed time beside a pulsing dot, pause/stop, and mic +
  desktop-audio mutes. Grab it anywhere on the body to pull it off into a
  floating island; as it nears any edge the frame and the island reach for each
  other and merge (both surfaces bulge, like two drops). Let go anywhere, even
  at a corner, and it settles back onto the nearest edge. On a side edge it
  turns vertical while you hold it. A hide button tucks it to a nub with a
  record dot still pulsing on it, so you can see it is hidden, not gone;
  hovering that edge pops it back out. It melts into the frame when recording
  ends, leaving no mark.
- **The app launcher reads its look from a config the Hub edits.** A new
  `~/.config/ryoku/launcher.json` (watched live) sets the palette's corner
  roundness, the home card's weather units (Auto follows the locale, or force
  C/F), the backdrop image with its strength and focal spot, and whether the
  greeting and weather glance show. Changing the unit refetches, so the reading
  is always in the unit on screen, never a value wearing the other's symbol.
- **The now-playing module opens a transport on hover.** Hovering the bar's
  media module grows a compact popout from the frame edge at the module: an
  elapsed / total line you can drag to seek, over a prev / play-pause / next
  cluster. It melts open through the shared blob field like every other popout
  and stays open while the pointer is on the module or the panel.
- **The bar shows only the workspaces you're using.** The strip lists the
  workspaces that own a window plus the active one, so empty numbers vanish
  and it stays as short as your session; occupancy comes straight from hyprctl
  so it's right the moment the shell starts. A toggle in Ryoku Settings' Shell
  section brings back the classic 1..5 run with empties dimmed.

### Changed
- **Notification toasts grow from the bell.** A toast now melts out of the bar
  edge at the notifications bell like the inbox does, and dismisses on its own
  timer, instead of appearing in a separate top-right window. Clicking it still
  opens the full inbox.
- **A popout in a corner fuses into the wall.** A popout clamped against a
  screen edge (the power menu, a toast) now reaches that wall and melts into the
  frame border through the shared blob field, squaring off the corner, instead
  of floating a bar's-width inset off it and leaving a gap.
- **Ryoku Settings' Shell section matches the bar-and-popouts shell.** The
  Island tab is gone with the island; the live knobs it still drove (the
  volume/brightness OSD and notification toasts) moved to a Notifications
  group under Frame, the bar position is top or bottom, and the now-playing
  cover no longer crowds its title.
- **The wallpaper picker is a full-screen switcher now.** Super+C opens a
  Super+Tab-style overlay instead of the pill filmstrip: images and live video
  wallpapers ride two endless belts, the top drifting right and the bottom
  drifting left, sorted into colour groups. The belts idle-drift on their own,
  settle to a stop while the pointer is over them, and a scroll (or the arrows)
  pushes them faster before they ease back; a
  swatch strip filters by colour and an All/Images/Live row by kind. Tiles are
  cut-cornered with a colour chip, a LIVE tag on video and a dot on the
  wallpaper already set; hover or the centre pick lights one, a click or Enter
  sets it, Esc closes. Live tiles preview muted on the pick. The pill's
  wallpaper surface and the old thumbnail script are gone; the switcher keeps
  its own thumbnail and dominant-colour index under `~/.cache/ryoku-wp-thumbs`.
- **The floating pill and centre island are gone.** Everything the pill used to
  host now opens as a bar-edge popout that grows from the frame at its trigger
  with the bar painted on top (caelestia's model), so a panel never hides the
  bar and the bar stays clickable while one is open. `Super+V` clipboard,
  `Super+D` control deck, `Super+Tab` workspaces, the wifi/bluetooth link
  surface, the keyring prompt, voice dictation and the notification inbox all
  moved off the pill; keyboard panels hold the keyboard while open and release
  it on close. The volume/brightness OSD became a small edge window that floats
  above the bar.
  Left/right bar positions and the sysinfo panel were dropped. `Pill.qml`, the
  island blob fields and the island-reserve machinery are deleted.
- **The bar skins are the references now, not our riff on them.** After fair
  pushback that the plate slabs looked bad on round shells, the two bar
  styles are carried one-to-one from the credited shells: `noctalia` (fully
  rounded capsule modules on the band, dot workspaces whose active pill
  widens into an accent lozenge with its number, the stacked clock that
  folds to one line on thin bands) and `caelestia` (the numbered workspace
  cell strip inside one container pill with the sliding indicator and its
  stretchy leading/trailing edges, the calendar-glyph clock, the column
  layout on side bars). Iconography moved to Material Symbols Rounded
  (`ttf-material-symbols-variable`, now in the base set) with the caelestia
  hover/press feel on every module: an 8% overlay and a soft ripple from the
  press point, and the Material 3 expressive curve family drives the module,
  island and reveal motion. Content centres across the full band, so modules
  no longer crowded the bar's bottom edge.
- The battery readout works on AC again everywhere (the bar and the battery
  popout): UPower's synthetic display device drops off some
  versions once the cell sits full, so the Battery singleton now reads the
  physical battery. Wifi signal in the bar's status cluster reads the active
  connection's strength instead of an in-use marker nmcli omits without a
  rescan.

### Added
- Four wallpaper switch transitions ported from **caelestia shell v2**'s
  Material 3 Expressive motion (the animation curves in its
  `plugin/src/Caelestia/Config/tokens.hpp`) join the Super+W rotation.
  `celeste_veil` reproduces caelestia's own wallpaper crossfade (the
  `expressiveSlowEffects` curve) exactly; `comet_streak` (emphasized-decelerate
  wipe), `aurora_ripple` (expressive-fast wave) and `starfall_bloom` (standard
  iris from the top) carry its other signature curves onto our geometric
  sweeps. All ride the shared transition speed. caelestia's springy spatial
  curves overshoot and its emphasized curve is a two-segment spline, so they
  fall outside awww's single monotonic bezier and are left out.
- Status-cluster click popouts, matching the reference catalog. Clicking a
  status icon on the bar reveals its own compact control panel growing from the
  bar edge at that icon (and melting back into it), on a top or bottom bar
  alike. A volume icon opens the mixer (moved off the now-playing module); the
  wifi icon a network panel (enable toggle, rescan, signal-sorted list, inline
  password connect); a bluetooth icon a device panel (adapter toggle, scan,
  pair/connect); the battery icon a readout (charge, state, time, draw,
  capacity, health); and the clock opens the month calendar. The network and
  bluetooth panels reuse the Link surface's own wifi/bluetooth engines, so
  connect and pair behave identically.
- **The bar moves and wears two skins.** `barPosition` places the band on the
  top or bottom frame edge. The chosen edge swells and claims its own strip.
  `barStyle` picks the skin: `plates` keeps the sharp washi slabs, `capsule`
  renders every module as a fully rounded tonal pill (the caelestia idiom) for
  shells riced round, and the workspace block, media art and hover fills all
  follow the choice. With a bar present the resting clock island is gone -- the
  bar carries the clock, workspaces, media and status, and summoned panels grow
  from the bar edge instead of a floating centre pill.
- **The top bar is a real bar now, and the default face.** The band used to be
  naked text floating on the frame's thickened edge; it is now composed of
  module plates: sharp slabs with a faint warm fill and a hairline edge that
  lift on hover, so every module reads as touchable (`pill/BarPlate.qml`).
  What the plates carry:
  - the 力 seal opens the launcher;
  - a workspace strip (`pill/BarWorkspaces.qml`) with mono numerals and an
    accent block that slides behind the active one, leading edge fast and
    trailing edge slow, so a switch stretches across and contracts (the
    caelestia trail); occupied numerals read brighter, click jumps, wheel
    walks neighbours, and cells past five only appear once used;
  - the clock plate (the anchor the calendar drops from) with the vermilion
    colon and a tracked mono date;
  - now-playing (`pill/BarMedia.qml`): art thumb, ping-pong title, play
    wedge; click toggles, wheel nudges the sink volume, and the live
    wallpaper's mpv is filtered out so scenery never poses as music;
  - a status cluster (`pill/BarStatus.qml`): wifi arcs or an ethernet tick
    (fed by the new gentle `Network` singleton, nmcli without rescans),
    battery cell + percentage, the inbox bell with an ember dot while
    something waits, and the DND mark; each glyph routes to its surface
    (link, battery, inbox);
  - the tray on a quiet plate with per-icon hover lift, and the power glyph.
  A wheel over bare band nudges the volume, narrated by the OSD. New shells
  start with the bar on (`barEnabled` default true).

### Fixed
- `ipc/wallpaper.go`: setting a live (video) wallpaper could silently do
  nothing. Every `wallpaper set` was gated behind `ensureWallDaemon()` (the
  awww image daemon), yet a video plays through mpvpaper and never needs awww;
  awww is not autostarted either, so a session that boots on a live wallpaper
  never starts it. If awww then failed to come up, the set returned success
  with nothing painted (ryowalls reported "Wallpaper set" while the wallpaper
  stayed put). The daemon now chooses the backend by file type: a video goes
  straight to mpvpaper with no awww dependency, only image sets ensure awww,
  and a failed mpvpaper launch surfaces as a real error instead of a no-op.
- Blob motion matches the reference shell now. The blobs already render
  identically, but five things made the melt feel less smooth: the deform
  spring used explicit Euler (the energy-injecting form our own ported comment
  warns against) -> switched to the semi-implicit closed form so it settles
  instead of wobbling on frame hitches; the render loop was basic (on-demand,
  GUI-thread) -> threaded (vsync-locked) so the per-frame spring gets regular
  deltas; popouts opened on a no-overshoot curve -> the spatial spring (500ms);
  deformScale was ~40x too large so any motion slammed the stretch cap -> cut
  to the reference's subtle value; and popout content was rigid over a
  deforming blob -> it now transforms by the blob's deform matrix and fades on
  the effects curve, so content and blob move as one body.
- Bar mode no longer swallows notifications and the volume OSD. The island
  logic only summoned the drop panel for open surfaces, so a toast or a
  volume change rendered nothing while the bar was on; both now melt out of
  the band like any summoned surface, and the input mask follows the panel
  so toast actions stay clickable.
- The resting island shows a small ember tick while notifications wait (and
  DND is off), so a quiet desktop still answers "did anything ping me".
- Mixer and power popouts fuse with a side bar as one body. On a left or
  right bar they now grow from the bar's inner edge (power right at its
  button, the mixer from the bare-band centre) and melt back into the band
  on close. Before, they grew from a fixed frame inset that landed inside
  the swelled band, so opening lumped the popout and band into one stuck
  slab, and the power menu even opened on the edge opposite its button.
- Hovering the clock (or anything) on a side bar no longer opens the power
  menu. The power popout carried a tall invisible hover band that, sitting
  by the power button at the bottom, overlapped the clock and status
  modules above it. The side-bar power menu is now click-only (open it by
  tapping the power button, like the reference), with no edge band behind
  its neighbours; the island/top-bar power keeps its edge hover.
- Side-bar popouts open from their own module, not an invisible edge band, so
  hovering one module can never open another's popout (the reference's
  per-module ownership). The now-playing module owns the mixer (hover opens it
  there; a tap still plays/pauses, the wheel still nudges volume); the power
  button owns the power menu (click). This removes the last stray edge band
  from a side bar; top/bottom/island popouts keep their thin-lip band.

### Security
- `ipc`: the `ryoku-shell` control socket is now created owner-only (0700). It
  drives session-scoped actions (surface toggles, wallpaper, dictation), and
  `net.Listen` left it at the ambient umask (0755 at the usual 022), so the
  socket node was world-traversable; when `XDG_RUNTIME_DIR` was unset it fell
  back to `/tmp`, where another local user could reach it. Forcing the umask
  around `Listen` makes it 0700 atomically, with no world-visible window.

### Added
- Ryoku now ships the reference desktop feel as the default look. Shell
  (`quickshell/*/Singletons/Config.qml` + the hub's reset baseline): a thinner,
  softer frame (radius 9, border 59, smoothing 8, shadow 0.63/12), a **floating**
  island that reveals on hover, and JetBrains Mono Nerd Font at 1.3x. Windows
  (`hyprland/modules/decoration.lua` + `hub` `defaultOverrides`): near-square
  rounding 2, gaps 12/18, border 2, blur 4/1, opacity 1/0.94. Seeded on first
  run, so fresh installs get it; existing configs are untouched, and Reset to
  defaults adopts it. Hardware and private bits (monitors, cursor, widgets,
  wallpapers, input) stay at the shipped baseline.
- `plugin/` (`Ryoku.Blobs`) and `quickshell/pill`: the frame, pill and popouts
  gain a 1-2px outline along their shared silhouette, in the wallust hue Hyprland
  uses for window borders (raw `color4`, exposed as `Wallust.border`). `BlobGroup`
  gained `borderColor`/`borderWidth`; the SDF shader paints a band just inside the
  rim, so the melted shapes read as one lined body, not per-shape strokes.
- `quickshell/launcher` **Bluetooth bubbles**: connected devices float as their
  own compact square-cornered cards under the palette window, one per device,
  the Android quick-pair tile in Ryoku grammar -- name up top, a big
  Material-style class pictogram on the left (BlueZ classifies the device as
  audio-headset, input-mouse, phone, ...; the glyphs come from the Material
  Design Icons set already embedded in the shipped Nerd Font), and the battery
  reading large in the corner when the device reports one ("connected" when it
  doesn't). Live off Quickshell.Bluetooth: cards appear on connect, drop on
  disconnect, battery updates in place. Nothing connected renders nothing at
  all. The launcher socket's `state` dump gains `btConnected`
  (`BtConnections.qml`, instantiated in `shell.qml` under the Launcher card).
- `ipc`: a new `ryoku-shell stash-send <file>` command opens the control deck's
  LocalSend picker on that file (a new pill `stashSend` IpcHandler that shows the
  stash and calls `openSendPicker`), so the Nautilus stash menu can hand a file to
  the deck's send flow instead of reinventing device discovery. The path is the
  raw remainder of the command line and goes through the qs client, so a path with
  spaces survives intact; `stashSendPath` is unit-tested. `deploy.sh` also drops
  the `ryoku-stash-menu.py` Nautilus extension into the user extensions dir for the
  dev loop.
- `quickshell/launcher` RyoTunes gains **shuffle** and **gapless prefetch**. A
  shuffle toggle in the now-playing transport (lit when on) reorders the queue via
  mpv's own `playlist-shuffle`/`playlist-unshuffle` (history and prev/next stay
  intact); the engine re-syncs its queue from mpv's new order by videoId so the
  card's cover/title stay correct. mpv now runs with `--prefetch-playlist=yes`, so
  it opens the next queue entry only as the current one nears its end (initial
  connect + `yt-dlp` resolve, not an early full download) - the next track starts
  gaplessly without stealing bandwidth mid-song, safe on slow connections.
- `quickshell/launcher` RyoTunes plays **pasted YouTube / YouTube Music links**,
  including playlists and mixes. Pasting a link (with or without the `@` prefix)
  offers a one-tap "Play": a bare track link seeds its radio, a playlist or mix
  link (`?list=...`) queues the whole playlist through the same InnerTube `/next`
  path. Played playlists are **cached** (`Singletons/Playlists.qml`, an LRU under
  the cache dir) and shown as a **力 SAVED PLAYLISTS** chip row under the
  now-playing stack (`SavedPlaylists.qml`), so the full playlist replays instantly
  with one tap and no network round-trip. Link parsing and the playlist-aware
  radio body are in `providers/media/ytmusic/ytmusic.js` (node-tested); the
  provider surfaces unprefixed links via a `urlFallback` gate
  (`lib/dispatch.js` `looksYtUrl`). Documented in `docs/ryotunes.md`.
- `quickshell/launcher` **RyoTunes**, YouTube Music as the built-in free-music
  source. The `@` provider now searches YouTube Music's keyless InnerTube API
  (`curl`) instead of `yt-dlp`, returning proper songs with clean title/artist/
  album and **square album art inline** (shown in the row and on the now-playing
  card, no second cover lookup), markedly faster than the old search; a prefix
  cache makes refining a query feel instant, and `yt-dlp` flat search stays as a
  fallback when InnerTube is unreachable. Playing a track no longer stops at its
  end: a new engine (`Singletons/Radio.qml`) streams it with a persistent `mpv`
  driven over its JSON IPC socket (Quickshell native `Socket`, no `socat`) and
  auto-extends an **endless YouTube Music radio** (the `/next` continuation),
  which `mpv-mpris` exposes so the card's Next/Prev, the media keys, an up-next
  peek, and **scrub-to-seek** (drag the wavy bar) drive the queue. Playing a track **takes over**: other players (a
  browser tab, Spotify) pause so audio never stacks, and the now-playing card
  **extends into a slim strip per other player** (`MediaSources.qml`) so both
  sources stay visible and one tap switches between them. The card is sticky
  (pausing it never makes it jump to another source) and shows a **buffering**
  state with a frozen seekbar so a slow load never ticks in silence. The MPRIS
  now-playing row gains a **YT Radio** verb that seeds an endless station from
  whatever is already playing; our stream yields to other audio by fading out and
  pausing (not a hard kill). Search + radio parsing live in one node-tested file
  (`providers/media/ytmusic/ytmusic.js`, so QML resolves the shared helpers with
  no `require`); the iTunes cover fallback (`albumart.js`) strips video noise
  (`(Official Video)`, `[HD]`, `feat.`) for a better match. Documented in
  `docs/ryotunes.md`. No new packages.
- `quickshell/launcher` removed the built-in Spotify catalog provider (`s:`) and
  its `ryoku-shell spotify` Web API backend (never released). Spotify stays a
  fully detected MPRIS player: the now-playing card controls it and the YT Radio
  verb can seed free music from it.
- `quickshell/launcher` a standalone command palette (`Super + Space`), a full
  rebuild of the old pill app-list, dropped from the pill so it has room for a
  Raycast/Alfred-class feature set. A daemon-supervised, kept-warm Quickshell
  component (`ryoku-shell launcher`) with provider folders under `providers/`:
  apps, calculator (qalc), system actions (`/`), clipboard (`;`), windows, web
  (`?` + bangs), files (fd), snippets + quicklinks, packages (GPK), MPRIS
  now-playing, YouTube Music (`@`), and a rofi-script/dmenu protocol provider for
  third-party scripts. Two-tier UX (root search + `Ctrl+K` action panel), an
  all-apps grid (`Ctrl+A`), and a now-playing detail with the wavy seekbar.
  Ranking and protocol logic are `lib/*.js` with `node` tests. Documented in
  `docs/launcher.md`. Blur via the `launcher` layer rule in
  `hyprland/modules/decoration.lua`; the `launcher` verb moves from the pill to
  the standalone component in `ipc/daemon.go`. Adds `ryoku-cmd-songrec`.
- `quickshell/launcher` web provider: a `?` query now shows an inline DuckDuckGo
  instant answer above the search row (heading, wrapped abstract, source), so
  `?what is nmap` answers in place instead of only offering a Google search. The
  answer is fetched keyless and async (`providers/web/ddg.js`, node-tested;
  rendered by `AnswerPanel.qml`); a `!bang` skips the fetch and goes straight to
  the chosen site, and the search row stays as the always-present fallback.
- `quickshell/launcher` now-playing: when the media player exposes no cover art
  (an mpv or yt-dlp stream, some browsers), the card fetches one from the keyless
  iTunes Search API by artist and title, once per track
  (`providers/media/albumart.js`, node-tested), so the music-note placeholder is
  a last resort rather than the norm.
- `quickshell/launcher` now-playing: a live cava spectrum wave now sweeps behind
  the card, the same filled smoothed curve the desktop visualiser draws, tinted
  vermilion and eased per frame so it flows with the music. A launcher-local
  `Singletons/Spectrum.qml` reads the PipeWire monitor, gated in `shell.qml` to
  run only while the launcher is open and a player is actually playing (never on
  a hidden or silent palette); the path geometry is `lib/spectrum.js`, node-tested.
- `deploy.sh` installs the Ryoku VM launcher icon (the brand mark) into the user
  icon theme, so the **Ryoku VM** app entry shows the logo instead of a blank tile.
- `quickshell/pill` Control Deck: a **Game Mode** control in the deck, a session
  tile that flips `Flags.gameMode` (the one-click
  competitive toggle). The shell bridges the flag to `ryoku-cmd-game-mode` the way
  Keep-Awake bridges the caffeine helper, and pulls Do-Not-Disturb on while it is
  active (`Flags` saves and restores the prior DND so it never clobbers a user who
  keeps DND on independently). Covered by
  `tests/game-mode.sh`.
- A desktop plugin's right-click menu renders the plugin's own settings inline from
  its `metadata.settings` schema - choice chips, a toggle, a slider, and an image
  thumbnail strip scanned from `~/Pictures` - so a widget (e.g. the photo frame) is
  restyled and its picture changed in place, no Settings trip. Mouse-only (the
  wallpaper layer has no keyboard, so text fields stay hub-side); changes persist
  through `ryoku-plugins-place settings`.
- `quickshell/plugins/ryoku-plugins-place` gains `seed`, `settings`, and `forget`
  verbs: `seed` injects a plugin's manifest preset block (default host + default
  settings) into `plugins.json`, filling only what is missing so user edits
  survive; `settings <json>` merges an edit; `forget` drops the entry. Enabling a
  plugin now also seeds, so its settings exist in the right place the moment it
  goes live.
- `quickshell/pill` stash install: drop a file, get a launcher entry. Beyond
  AppImages and self-contained tarballs, the installer now handles native and
  portable package formats so they open afterwards:
  - Arch packages (`.pkg.tar.zst`, or any tar carrying a `.PKGINFO`) install with
    `pacman -U` through pkexec (the polkit agent prompts); the package's own
    desktop entry is read natively. Previously these were misread as plain
    tarballs and extracted into `~/.local`, producing a broken entry (the binary
    lives under `/opt`), which is why a Warp terminal install never opened.
  - Flatpak bundles (`.flatpak`) install into the user installation with
    `flatpak install --user` (the flathub remote is ensured first so the runtime
    resolves), and flatpak exports the desktop entry. Adds `flatpak` to the base set.
  - `.deb` and `.rpm` payloads are extracted with bsdtar and run through the same
    app-discovery as tarballs (best-effort; an app that hardcodes system paths is
    better served by its native package or flatpak).
  `Stash.qml` `hasInstallable` offers exactly these; self-extracting `.bin`/`.run`
  stay out (running an arbitrary installer blind is unsafe). Covered by
  `tests/stash-install.sh`.
- `quickshell/pill` stash install now clears the source from the stash after a
  successful install, so an installed app is not left duplicated as a leftover
  drop (it already lives in the app store, or a system/flatpak install). It only
  removes on success, never on failure, and `RYOKU_STASH_KEEP=1` opts out.
  Covered by `tests/stash-install.sh`.
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
  cursor), the bottom-right bracket resizes it (scrubbing the scale, with a live
  readout), and right-click opens a menu in the carbon-dossier idiom (a 力
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
- `quickshell/launcher`: the rest card's clock/date strip is reworked from a flat
  slab into a solar-arc scene. The clock and greeting read over a filled wave
  horizon that traces the real day: the stretch behind the marker glows the phase
  colour (how far through this phase we are), the stretch ahead stays faint (what
  is left of it), and a sun by day or a carved crescent moon by night rides the
  ridge at its true position. Day runs from the IP-located sunrise to sunset, night
  wraps midnight to the next sunrise, both fetched through the same Open-Meteo call
  as the weather (`daily=sunrise,sunset`, parsed by `sunFrac`); until that resolves
  the marker falls back to a plain clock. It is the same fill-is-elapsed grammar as
  the NowPlaying seekbar below it, so the resting card and the playing card read as
  one family. The sky colours are fixed (golden day, cool night) and deliberately
  independent of the wallust accent, so the sun stays a sun on any wallpaper. The
  old 力 seal is dropped, a recessed `cardBot` surface with a top sheen replaces the
  lighter floating fill, the colon breathes in the phase colour like the other clock
  faces, and the wave drifts only while the palette is shown so an idle launcher
  costs nothing.
- `ipc/`: the daemon is the single owner of `wallust`. A palette-only `wallpaper
  repaint` re-derives colours with no image transition, and the hub calls it
  instead of running wallust itself. Shell chrome (pill, island, widgets,
  plugins, switcher) reads the one colour master, `theme.json` `followWallpaper`,
  instead of `shell.json` `matchWallpaper`, so borders and chrome follow the
  wallpaper together.
- `quickshell/pill`: the `力 CONTROL DECK` is restructured into a tighter control
  centre (~40% smaller footprint) so it reads less like a generic settings list.
  The right column's six stacked sections collapse to three whitespace-grouped
  zones: **Tools** (the capture-launcher strip, now spread edge-to-edge), a new
  **Controls** zone, and **Record**. Controls unifies what were three separate
  sections: Keep-Awake and Game-Mode become two wide session stat-tiles (glyph,
  label, live value; the whole tile taps to toggle and tints when on) over the
  wifi/bluetooth/mic/DND/night quick-toggle row. Record folds the recordings list
  in under one eyebrow with the count. Section eyebrows drop from eight to four,
  the interior hairline rules give way to spacing, the decorative Tools WaveMeter
  is gone, the masthead is slimmer, and the surface narrows from 660 to 590
  scale-units. This also removes the void where Stash stretched to match the
  taller right column. No functionality is dropped.
- `quickshell/pill`: the mixer popout is reworked from a row of vertical faders
  into an audio control center, while keeping the frame-edge melt and the
  `ryoku-shell mixer` pin. OUTPUT and INPUT each show the active device with an
  inline selector that detects and switches the PipeWire default sink/source
  (`preferredDefaultAudioSink`/`Source`), a horizontal ink fader with a live peak
  meter, and mute. A Bluetooth output adds a chip with battery (native BlueZ
  device), codec, and an A2DP/Headset profile toggle, read from the bluez card via
  `pactl`. An APPS section gives each playback stream its own volume, mute, and
  meter with app icon and name. DISPLAY keeps per-monitor brightness (ddcutil) and
  vibrance (nvibrant), restyled to match. The popout melts to fit and grows as the
  picker expands. New `Singletons/Audio.qml` owns the graph; new `HFader`,
  `MixerDeviceRow`, `MixerAppRow`, and `MixerDisplay` components; `VFader` retired.
- `quickshell/widgets`: a desktop widget's right-click image picker gains a
  **Browse** tile that opens the system file chooser (portal), and its thumbnail
  scan recurses one level into `~/Pictures` (so Wallpapers / Screenshots appear),
  not just the top level.
- `quickshell/widgets`: a desktop-widget tile now honours its plugin's manifest
  default card style (`defaults.desktopWidget.bg`) when the placement pins none,
  so a plugin like photo-frame can opt out of the host card (`bg: "none"`) and
  draw its own frame.
- `quickshell/pill`: Stash, Tools, and Utilities are unified into one wide
  `力 CONTROL DECK` surface instead of three separate pill popouts, opened by
  `Super+D` (the old `Super+Z` and `Super+U` binds are removed). Single view, no
  sub-tabs: a 力 masthead over two hairline-split columns (Stash left; Tools,
  Controls and Record right), corner registration ticks, mono micro-labels and tabular
  figures in the hub Profile dossier idiom. Stash drops onto a filling tray with
  the Profile's square spec grid; its action bar is evenly spaced; the Send,
  Receive, Download and Task sub-screens are dismissed by a single Back control
  in the stash header beside the file count. New `DeckSurface`, `DeckStash`,
  `DeckTools`, `DeckControls`, `DeckRecord`, `DeckSegmented`, `MicroLabel`, `SpecRow`,
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
- `quickshell/pill`: the island's rest state (idle, collapsed) drops the 力 stamp
  for a cleaner read. A tabular `HH:MM` clock with a vermilion colon leads a
  stacked mono weekday/date, above the workspace wave; the Ame bead's rest anchor
  moves from the stamp to the clock.
- `quickshell/pill`: the now-playing card is reworked into the carbon-dossier
  idiom. A 力 MEDIA eyebrow leads the title and artist, the source/time line is
  mono uppercase, the play seal is flat vermilion (no gloss), and corner
  registration ticks frame it. The album art and the Ryoku wave seek line stay.
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
- `ipc/wallpaper.go`: a live wallpaper could vanish a while after being set and
  revert to the previous one. `stopLive` fired an async `pkill` and relaunched at
  once, and `mpvpaper -f` forks, so a just-launched instance was invisible to the
  next kill: instances leaked, and a leftover one still playing an earlier
  wallpaper reclaimed the background layer. `stopLive` now waits for every
  mpvpaper to actually exit (escalating to SIGKILL), and a launch waits until the
  new instance is really up (its ipc socket appears) before returning, so exactly
  one ever plays and a stale one cannot win. Setting an image over a video clears
  the video reliably now, too.
- `ipc/wallpaper.go`: the "pause live wallpaper when covered" toggle only paused
  for a fullscreen window, so a wallpaper hidden behind ordinary tiled windows
  kept playing at full tilt. It now pauses whenever the desktop is covered on
  every monitor, reusing the same `desktopVisible` coverage test the widget layer
  parks itself on, and reconciles on the window and workspace events that change
  coverage (`affectsCoverage`, shared with the widget gate) rather than only on
  fullscreen toggles.
- `quickshell/launcher` RyoTunes: a batch of fixes so the built-in music finally
  feels native and fast, all in the engine (`Singletons/Radio.qml`) and its `@`
  provider (`providers/media/ytmusic/YtMusic.qml`).
  - **Playback no longer stops a few seconds in.** The "graceful yield" paused our
    own stream whenever *any* other MPRIS player was playing, so a background
    browser tab silenced the music ~4s after it started. The yield is now
    audio-focus: it fires only when another player *transitions* into playing while
    ours is (a deliberate hand-off), never for audio already playing when the engine
    came up (a primed baseline). A player we take over on an explicit play stays a
    baseline, so it never bounces the music straight back.
  - **Play is near-instant, not a ~2s stall.** mpv resolved each track with yt-dlp
    (~1.9s) before the first sound. The provider now pre-resolves the top hit's
    direct audio URL in the background (`prewarm`) as results land, and `play()`
    hands mpv that URL, so the resolve overlaps read time (first sound ~0.16s warm
    vs ~2.1s cold). The videoId rides a `#ryt=` URL fragment (never sent to the
    server) so shuffle and reload-adoption still recover it from the opaque stream
    URL. Raw InnerTube `/player` is not a faster path: YouTube gates playback behind
    PoToken/attestation, which yt-dlp maintains.
  - **Adopted and radio covers are square, not a cropped 16:9 thumbnail.** A
    reloaded stream was adopted as skeletons carrying only a 16:9 `ytimg` frame, and
    radio `/next` dedup'd away the square version of an already-queued track. The
    extend handler now upgrades a skeleton in place with the square cover and clean
    title, and adoption enriches from the current track so the cover lifts within ~1s.
- `quickshell/pill` link: the Bluetooth row and drill-in no longer present a
  dead toggle when bluetoothd is gone. The toggle hides without an adapter, the
  device list line becomes "Service off -- tap to start" (`pkexec systemctl
  enable --now bluetooth.service`, with a transient failure line), the row
  subtext says "Service off" instead of the stray German "Aus", and enabling
  from an rfkill-blocked state unblocks first (`rfkill unblock bluetooth`,
  seat-writable via systemd uaccess), powering the adapter when the unblock
  lands (`setAdapterEnabled` in `LinkBt.qml`, reused by the Link row toggle).
- Wallpaper colours no longer inherit a previous image's tune. `ipc/wallpaper.go`
  `tuneArgs` applies the ryowalls palette tune only when it is keyed to the
  current wallpaper (an `image` match), so a Super+W cycle or a different image
  falls back to default extraction. A green wallpaper is no longer themed with a
  stale complementary (magenta) palette left from an earlier tuning session.
- `quickshell/launcher`: three launcher features shipped wired to tools that no
  package set installed, so they silently did nothing on a real machine.
  `system/packages/base.packages` now ships them and `tests/shell-tool-availability.sh`
  gates all three so the gap cannot reopen.
  - Calculator: `libqalculate` was never packaged, so `ryoku-cmd-calc` fell back
    to a Python evaluator that only did `+ - * / // % **`. `2^10`, `sqrt(16)`,
    `sin(0)`, `15% of 200`, `pi`, `4+3x43`, and units/currency returned nothing.
    Ships `libqalculate` (qalc is the primary path, now gated on its exit code so
    input it cannot parse falls through instead of printing a garbage unit
    string) and hardens the AST-safe fallback to also handle `^` as power,
    `X%`/`X% of Y`/`A +/- B%` percentages, the constants `pi`/`e`/`tau`, and an
    allowlist of `math` functions, so the calculator works even without qalc. The
    script also normalizes hand-typed multiply and divide (`x`/`X` between
    operands, `×`, `÷`, ` of `) so `4+3x43` reads as `4+3*43`. `lib/dispatch.js
    looksNumeric` now routes an unprefixed `sqrt(16)`, `(1+2)*3`, `.5`, or `-3` to
    the calculator (it stays false for app names like `route66`).
    `providers/calc/Calc.qml` no longer starves its own debounce when another
    provider re-runs the results binding. Covered by `tests/calc-eval.sh` (which
    stubs qalc to force the fallback path) and expanded `dispatch.test.mjs` cases.
  - Music: `mpv-mpris` was never packaged, so the YouTube Music mpv stream never
    appeared as an MPRIS player and neither the now-playing card nor the transport
    verbs could see or control it. Ships `mpv-mpris` (autoloaded from
    `/etc/mpv/scripts`). `providers/media/mpris/Mpris.qml matches()` no longer
    leaks the now-playing row into unrelated searches (a substring test against the
    joined keyword list matched any query containing a common letter). `YtMusic.qml`
    stops racing the previous mpv when starting a new stream, and `NowPlaying.qml`
    gains working prev/play-pause/next transport controls. Ships `songrec` for the
    Recognize Music action. `docs/launcher.md` drops the stale socat claim.
  - Rest card: the clock and weather glance rendered weather as text with no icon
    and an unbalanced right column. `RestDashboard.qml` is redesigned with a vector
    weather glyph (new `WeatherGlyph.qml`, sharing the pill's glyph paths), the
    temperature, condition and city, and today hi/lo, balanced against the clock,
    with a clean date-only fallback while weather is still fetching.
- `quickshell/launcher` now-playing: the YouTube Music stream now yields when
  another player starts. `YtMusic.qml` watches MPRIS while its mpv is streaming
  and stops the moment a different player (identity not `mpv`, so Spotify, a
  browser tab, any app) begins playing, so two streams never overlap and the
  card follows whatever is actually playing. The watcher runs only during
  playback, so it costs nothing at rest.
- `quickshell/launcher` now-playing: the cava wave backdrop no longer flickers
  or leaves the analyser running when nothing plays. Its visibility follows the
  fade rather than the per-frame path (an empty path just draws nothing), each
  band keeps a small floor so the curve does not collapse between beats, and the
  seekbar now advances: MPRIS never pushes `position`, so `NowPlaying.qml` polls
  it every 500ms while playing, with elapsed and total time labels flanking the
  transport and the fill gliding between polls.
- `quickshell/launcher` Audio Visualizer action: fired the plain `visualizer`
  verb, which only flips the desktop visualiser's enabled flag while it sits on
  the bottom layer behind every window, so a maximised window hid any change. It
  now fires `visualizer-overlay`, which raises the visualiser over the windows
  (and enables it), so the action actually shows it.
- `quickshell/ryoshot`: the screenshot key (`Super + S`) silently stopped working
  after a **Save** from the toolbar. Save grabbed the shot to the auto-path, then
  ran `kdialog` to pick a destination - but `kdialog` is a KDE tool that Ryoku
  (Hyprland) does not ship, so the `Process` failed to *start*, and a process that
  never starts never fires `onExited`. `dialogMode` stayed `true` forever; the
  per-monitor overlays are `visible: !dialogMode`, so the surface went invisible
  while the instance stayed alive holding `/tmp/ryoshot.lock`. The keybind's
  `flock -n` then turned every later `Super + S` into a silent no-op. The save
  picker now runs through `sh -c "zenity ... || kdialog ..."` (zenity is already a
  dep; kdialog kept as fallback), matching `ryovm`'s `ImportDialog`. Because the
  `sh` wrapper always starts, `onExited` always fires, so a missing or cancelled
  picker drops `dialogMode` and returns to the editor instead of wedging.
- `quickshell/pill`: an app launched from the pill launcher (notably
  Discord/Electron and Vivaldi/Chromium) sometimes came up un-typeable until you
  moved it to another monitor or reopened it. The pill is a full-screen
  `WlrLayer.Overlay` that is always mapped, and its idle keyboard focus was
  `OnDemand`, so when a typing surface closed `Exclusive` -> `OnDemand` the pill
  held the keyboard instead of releasing it to the new window. It now uses
  `keyboardFocus: None` whenever no typing surface is open (the voice surface
  included), `Exclusive` only while a search field is up. Same fix as the
  desktop-widgets layer below.
- `deploy.sh` now carries `keyboard.lua` across a redeploy (added to the preserve
  list beside `user.lua`, `settings.lua`, and the generated drop-ins), matching
  `ryoku materialize`'s seed handling. A `ryoku deploy` was overwriting a
  hand-edited keyboard layout back to the `us` default, the same regression
  `materialize` had.
- `quickshell/plugins`: a desktop plugin's `plugins.json` could be blanked to an
  empty file when two writers landed at once (a drag committing while Settings
  toggled), because every write shared one `$f.tmp`. Each write now uses a unique
  temp and an atomic rename, and both `ryoku-plugins-place` and `discover.sh`
  treat a missing, empty, or corrupt file as `{}` and self-heal it - so one bad
  write no longer blanks the installed list and breaks the plugin store.
- `hyprland/scripts/stash-install.sh`: a `.deb`/`.rpm` whose desktop `Exec` is an
  absolute path (every native package ships one, e.g. `/opt/Termius/termius-app`)
  now resolves onto the extracted tree at that exact path. It used to rewrite the
  `Exec` by searching the whole payload for the basename and taking the first hit,
  which matched an unrelated same-named file when one sorted first: Termius ships
  an `etc/cron.daily/termius-app` cron script, so the launcher ran the cron job and
  the app never opened. Covered by `tests/stash-install.sh`.
- `shell/deploy.sh`: the Hyprland config swap is now near-atomic, so a reload can
  never catch `hyprland.lua` missing. It built `~/.config/hypr` with `rm -rf` then
  `cp -a`, leaving a long window with no `hyprland.lua`; a manual reload or a fresh
  login in that window (both bypass the autoreload pause) tripped emergency mode
  and a stale "cannot open hyprland.lua". It now stages the config in a sibling
  dir, carries the preserved user files and generated drop-ins across, then renames
  staging into place; it also touches the entry, since `cp -a` carried the repo's
  older mtimes and an mtime-watching autoreload could otherwise miss the swap.
- `quickshell/widgets`: opening an app on an empty workspace now focuses it. The
  desktop-widgets layer (full-screen `WlrLayer.Bottom`) requested
  `keyboardFocus: OnDemand`, so on a workspace with no window above it that layer
  held the keyboard and a freshly launched window (terminal keybind or app
  launcher) stayed unfocused until you moved the mouse or hit a focus bind. It now
  uses `keyboardFocus: None`; pointer input (widget drag, right-click desktop
  menu) is unaffected, since layer-shell gates clicks by the input region, not
  keyboard interactivity.
- `quickshell/pill` LocalSend receive: incoming transfers now require consent.
  The receiver auto-accepted any device's `prepare-upload` and dropped the bytes
  straight into the stash. It now holds each offer at `prepare-upload`, shows
  "‹device› wants to send ‹N› file(s)" with Accept/Decline in the receive sheet,
  and issues an upload token only once you Accept (Decline or 60s of silence
  returns 403, so declined bytes never cross the wire). The shell answers over
  the receiver's stdin; the Python program now loads from fd 3 to leave stdin
  free for that channel. Covered by `tests/localsend-receive.sh`.
- `quickshell/pill` stash install: the control deck now steps aside for the sudo
  prompt. Installing a pacman package shells out to `pkexec`, whose polkit window
  (`hyprpolkitagent`) landed behind the deck's overlay layer and could not take
  the password (the deck holds an exclusive keyboard grab), forcing a close-deck,
  type-password, reopen dance. `stash-install.sh` emits an `@AUTH` marker before
  the privileged step, the stash reads it live and the pill dismisses the deck so
  the prompt takes focus, and a window rule floats and centres the
  `hyprpolkitagent` prompt. Covered by `tests/stash-install.sh`.
- `quickshell/visualizer` no longer pins a CPU core and overheats the machine on a
  high-refresh panel. It ran a `FrameAnimation` once per vsync (re-rendering 96
  bands plus the bloom at 165Hz though cava only feeds 60fps), and the `wave` style
  rasterised a full-width filled curve on a software `Canvas` on the main thread.
  Now a Timer caps updates to ~60fps while sound plays and ~30fps for the idle wave
  (and stops entirely when silent), the wave renders as a GPU `Shape` instead of a
  `Canvas`, and the bloom skips its pass when the spectrum is flat. Wave-style CPU
  fell from ~85% of a core to ~10% and the package temperature from ~95°C to ~67°C
  on a 165Hz panel.
- `deploy.sh` no longer trips a live Hyprland session into emergency mode when run
  from outside the session (ssh, an agent, or the curl recovery, which also calls
  it). The config swap pauses Hyprland autoreload first, but that pause was gated
  on hyprctl being reachable, which it is not when `HYPRLAND_INSTANCE_SIGNATURE` is
  absent from the environment, so the brief `rm`+`cp` window where `hyprland.lua`
  is missing got caught by autoreload. deploy now recovers the running instance
  signature from the runtime dir, so the pause happens whenever a session is up.
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
- `quickshell/pill`: the workspace wave under the clock no longer leaks memory. It
  animated a software `Canvas` at 30fps forever, even while the pill was auto-hidden
  (the pill hides by opacity, not visibility, so the wave stayed "visible" and kept
  ticking), accruing the same idle-`Canvas` leak already fixed in `WaveMeter` and the
  visualiser (~1.2 MB/min here, GBs over a day's uptime). The wave is now a static
  Canvas: it repaints only on a workspace/focus/size change and only while the pill
  is shown. The focus crest still glides on switch, it just no longer shimmers at rest.
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
