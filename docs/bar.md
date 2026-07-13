# The bar

The bar is the shell's resting face: a strip of modules riding one frame edge,
drawn in the frame's own blob scene and painted on top of the popouts, so it
stays visible and clickable while a popout is open. It lives in
`quickshell/pill/Bar.qml` (the `pill/` directory name is historical; there is no
pill). See `docs/frame.md` for the blob field it rides and the popouts it opens.

## Placement and skins

Ryoku Settings drives the bar through `Config`:

- `barEnabled` on/off; `barPosition` is **top** or **bottom** (left/right were
  dropped, so anything but `bottom` reads as top).
- `barStyle` the skin. `noctalia` and `caelestia` are carried from the credited
  reference shells; `aegis`, `stele`, `triptych`, `delos`, and `nacre` are Ryoku's own:
  - **`noctalia`** fully rounded capsule modules in a row; dot workspaces whose
    active dot widens into an accent lozenge with its number; the stacked clock.
  - **`caelestia`** the numbered workspace cell strip inside one container pill
    with a sliding indicator; Material Symbols Rounded iconography.
  - **`nacre`** grows the frame lobes like triptych, so the bar dips between three
    dark module islands with the same organic concave transition, but holds a
    persistent hairline top edge so the dips survive with the frame ring off and a
    popout melts cleanly, and it squares the display corners. The seal, a compact now-playing thumb, and the
    title left; the clock, small hollow-ring workspaces, and a live CPU/RAM/temp
    readout centred; status and tray right. The stats open a resources popout, and
    the workspace rings light the active one in the accent.
- `barHeight` and `fontScale` size it. Everything scales off `s =
  monitor.height / 1080 x fontScale` (clamped 0.7-1.6). The band the frame swells
  by is `barBand = barHeight x s`; modules size against `moduleSpan =
  round(barBand x 0.76)`.
- `barShowMedia` / `barShowStatus` toggle the now-playing and status modules.

The bar's edge gets `frameBorder + barBand` on the frame's `BlobInvertedRect`, so
the border swells into a band the bar rides; the other three edges stay a
hairline.

## The modules

A left group and a right group flank the centred clock:

- **力 seal** the brand mark and launcher trigger; a bare glyph (a `BarModule`
  with `filled: false`), not a control capsule.
- **workspaces** (`BarWorkspaces`) the skin's workspace strip.
- **focused title** the active window's title.
- **clock** (`BarClock`, centred) the time; clicking opens the calendar popout.
- **now-playing** (`BarMedia`) the track's art + title; clicking toggles play, the
  wheel nudges volume, and hovering opens the transport popout (`MediaPopout`).
- **status** (`BarStatus`) the volume / network / bluetooth / battery glyphs;
  each opens its own popout.
- **tray** (`BarTray`) the system tray.
- **power** a session glyph; clicking opens the power popout.
- **system stats** (`BarStats`, nacre only) a CPU / RAM / temperature readout off
  the `SysStats` singleton (native `/proc` + `/sys` polling); clicking opens the
  resources popout (`ResourcesPopout`) with usage sparklines and the top
  processes by CPU.

## BarModule: the shared capsule

Every control module is a `BarModule` (`BarModule.qml`): a fully rounded pill
(`Theme.tileBg`) carrying the caelestia StateLayer feel: an 8% overlay lifts on
hover and a soft ripple blooms from the press point. Content centres; the pill
hugs it plus `padX` / `padY`. Set `filled: false` for a bare mark (the 力 seal),
`interactive: false` for a display-only module (workspaces, status, tray). It
emits `tapped()` and `wheeled(steps)` and exposes `hovered`.

## Opening a popout from a module

A module never owns a popout; it asks the shell to open one, and the shell grows
the blob at the module (see `docs/frame.md`). Two signals on `Bar`, both handed
the module's along-axis centre in window coordinates so the popout emerges from
it:

- **`popoutRequested(name, center)`** a click. The clock module's `onTapped`
  emits `popoutRequested("calendar", ...centre...)` and `shell.qml` pins that
  popout at the centre; `BarStatus` forwards its glyph clicks the same way through
  its own `requestPopout` signal.
- **`hoverPopoutRequested(name, center, hovered)`** a hover. The now-playing
  module emits it from `onHoveredChanged`; `shell.qml`'s `setHoverPopout` drives
  the popout's `triggerHovered`, and a short grace lets the pointer cross the bar
  edge to the panel body, whose own hover latch then holds it open. This is the
  model for any hover popout.

## Adding a module

1. Add it to the right group in `Bar.qml`: the left `Row`, the centred clock
   slot, or the right `Row`. Wrap a control in a `BarModule { s: bar.s; height:
   bar.moduleSpan; ... }` and size everything off `bar.s` and `bar.moduleSpan` so
   it tracks the band.
2. If it opens a popout, emit `popoutRequested` (click) or `hoverPopoutRequested`
   (hover) with the module's centre, then add the matching `Popout` and its input
   mask region in `shell.qml` per `docs/frame.md`.
3. If the two skins must differ, branch on `Config.barStyle` the way the existing
   modules do, and keep each skin faithful to its reference.
