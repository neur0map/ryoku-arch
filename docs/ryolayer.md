# RyoLayer

RyoLayer is the Ryoku tool overlay: a transparent board summoned over the
desktop with `Super + G`. It is a workbench for instrument widgets, tools you
drag out, resize, and pin over your windows, sitting on a compositor-blurred
desktop whose blur you tune on a live slider. It ships two instruments, a music
controller (transport plus a real 10-band equalizer) and a microphone
controller (gain, mute, device, level, normalize), and the catalog is a data
list, so more are a file and one entry away.

It lives in `ryoku/shell/quickshell/ryolayer/`, a Quickshell component
supervised by the `ryoku-shell` daemon (a peer of `launcher`/`ryoshot`), kept
warm so it opens instantly and toggles with `ryoku-shell ryolayer`.

## Anatomy

- `shell.qml` the layer-shell overlay window (namespace `ryolayer`), resident
  and hidden at rest, shown on the focused monitor. Toggled over the daemon
  socket by an `IpcHandler`. It also owns the backdrop blur and the pinned
  windows (below).
- `Board.qml` the board body: the scrim that dismisses on a click-out, the
  `RyoSlot` for every widget placed on this screen, and the dock. The board
  fades in over the frozen desktop, 300ms in, 180ms accelerating out; the grain
  rides the fade.
- `RyoSlot.qml` one widget's plate: the paper body, the eyebrow (kanji + tracked
  title), the hover controls, the drag, and the bottom-right resize bracket. It
  loads the widget's body QML into a `Loader` and exposes itself as `slot`; the
  body only ever reads `slot`.
- `Dock.qml` the board's control strip: the catalog as chips and the blur
  slider.
- `Singletons/` the layer's state and registry: `Config` (`ryolayer.json`),
  `Catalog` (the widget vocabulary), `Eq` (`eq.json`), `Sound` (the PipeWire
  input field), `Players`, and `Motion`.

## The grammar

The dock names every tool the layer knows. Each is a chip: click to place it on
this screen, click again to remove it; a placed chip inverts to bone. A placed
widget is a plate you handle directly, the desktop-widgets precedent, manipulate
the thing where it lives:

- **Drag** anywhere on the plate to move it; on release it snaps to a `Tokens.s2`
  grid and the position persists.
- **Resize** from the bottom-right bracket, clamped to the widget's catalog
  min/max envelope.
- **Pin** (`●`) promotes the widget to a `WlrLayer.Top` window that outlives the
  board, so it stays on your desktop after `Super + G` closes. A pinned widget
  gains a **clickthrough** toggle (`◉`): masked to nothing at a quieter 0.8
  opacity, an ambient readout the pointer passes through.
- **Remove** (`✕`) takes it off the screen.

Geometry is stored as a normalized center plus a pixel size, per screen, so a
resolution change or a monitor swap keeps the layout. A pinned window maps under
the identical board slot fading in over it, so a plate never blinks on toggle.

## The blur

Hyprland's blur size is one global knob, so while the board is open RyoLayer
drives it to the layer's own `bgBlur` and restores the prior value on close.
This carries the launcher's proven force/restore: writes serialize through a
single `hyprctl eval` writer so states reach the compositor in order, and the
baseline is read from a drained compositor before it is overwritten, so a blur
that was off globally is put back off. The dock's slider (`0..64`) retunes the
forced strength live and persists once the drag settles. At `bgBlur = 0` the
window takes the `ryolayer-noblur` namespace and the compositor's blur rule
never matches.

## The widgets

Each widget is a folder under `widgets/<name>/`; its body QML fills the plate.
The two shipped instruments are backed by real system services, not mocks.

- **music** (`widgets/music/`) is a full media controller on
  `Quickshell.Services.Mpris`: previous / play-pause / next (each guarded by the
  player's `can*`), a seek rail when the track allows it, album art with a 音
  fallback, and player chips to switch when more than one player is live
  (deduped through `playerctld`). Its **EqPanel** is a real equalizer: an enable
  switch, the `flat`/`bass`/`vocal`/`bright` presets, and ten faders (31 Hz..16
  kHz, ±12 dB) over a live 20-band cava ghost. The panel drives `Eq`, which
  owns `eq.json`; `ryoku-eq` realizes it as a PipeWire `module-filter-chain`
  sink named **Ryoku Equalizer** and reads the file, applying at login (from
  Hyprland autostart, after `ryoku-mic`). Live band drags stream to the running
  chain through `ryoku-eq set`, throttled to one process every 50ms; the file
  write lands once on release.
- **mic** (`widgets/mic/`) controls capture through
  `Quickshell.Services.Pipewire`: a mute plate, a gain fader with a percent
  readout, device rows when more than one input exists, a **RECORDING NOW**
  section (the PipeWire stream nodes actually capturing the source, with the
  shell's own level-meter cava excluded by node identity), and one-tap unity
  normalize via `ryoku-mic apply`. A `LevelMeter`
  runs a cava VU on the default source, gated on visibility and unmuted so the
  analyser only runs when it is seen.

Both helpers add zero extra packages: the equalizer is a PipeWire filter-chain
and the mic normalize is a `wpctl` wrapper, and the availability matrix carries
`[equalizer]=pipewire` (`tests/shell-tool-availability.sh`).

## Persistence

- `~/.config/ryoku/ryolayer.json`: `{ bgBlur, widgets[{ id, screen, cx, cy, w,
  h, pinned, clickthrough }] }`. The center (`cx`/`cy`) is normalized to the
  screen; `w`/`h` are pixels.
- `~/.config/ryoku/eq.json`: `{ enabled, preset, gains[10] }`, written only by
  the `Eq` singleton and read by `ryoku-eq`.

Both are watched and atomic, the same contract as `launcher.json`, seeded on a
genuine first run and never clobbered, so they are additive with no reconciler.

## Theming

The plates are the printed-instrument plate language, tokens from `Ryoku.Ui`
(`Tokens`, `Grain`) and the layer's own `Motion`: paper bodies, the bone
inversion for a live state, tracked mono eyebrows, and the frost that sweeps
with the fade. Components read tokens, never hardcoded values.

## Future

The layer is designed for growth it does not yet ship.

- **Voice changer (mic effects).** The same mechanism as the equalizer, but
  source-side: a filter-chain with `capture.props` on the real mic and a
  virtual source out, the shape PipeWire itself ships as
  `source-rnnoise.conf`. Pitch and formant need a LADSPA/LV2 plugin package,
  which breaks the zero-dependency constraint, so it is deferred: when wanted it
  becomes `ryoku-voicefx` beside `ryoku-eq`, a `[voice-fx]` availability row,
  and a panel in the mic widget. Nothing in v1 blocks it.
- **Third-party widgets.** `Catalog.qml` is a data list and `RyoSlot` loads by
  URL, so a future `ryolayer` plugin host can map `docs/plugins.md` manifests
  into catalog entries. The plugins doc already reserves new hosts.
- **A Hub page.** The blur default and per-widget toggles could join Ryoku
  Settings later; v1 keeps configuration on the layer itself.
- **Rice capture.** `ryolayer.json` can join `rice.go`'s look-bundle keys once
  layouts prove stable.
