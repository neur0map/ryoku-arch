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
  reference shells; `aegis`, `stele`, `triptych`, `delos` and `nacre` are Ryoku's own; `inir` / `aurora` / `angel` are flat frame-off skins ported from snowarch's iNiR; `washi` is the floating warping pill ported from Gakuseei's Ricelin (which Ryoku forked from); and `atoll` is the floating multi-island bar ported from ilyamiro's nixos-configuration:
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
  - **`inir`** / **`aurora`** / **`angel`** flat frame-off bars ported from
    iNiR, now carrying iNiR's per-*module* character recoloured to bone-and-ink:
    a flush, full-width strip at the screen edge (seal, workspaces, the special
    cue, stats and now-playing left; the clock centred; status, weather, toggles
    hairline cell separators; `aurora` is a clean, modern niri-style bar: one flat
    translucent tone the wallpaper shows faintly through, with a crisp hairline top
    and flat borderless modules -- no layered glass sheen (the bar shares the
    frame's Wayland layer and cannot blur its live backdrop, so it stays clean
    rather than faking frost);
    `angel` is a brutalist panel whose modules are raised keys wearing a hard
    accent offset shadow (the iNiR "escalonado" -- no blur, deepening on hover)
    over a heavy base border and a bright inset top edge. Meant for the frame
    off, and the Bar paints their surface itself instead of riding the band.
  - **`washi`** a floating pill at top-centre that warps in place into full
    surfaces (media, calendar, clipboard, mixer, network + bluetooth, power,
    resources, notifications, workspaces, and a wallpaper strip on Ryoku's own
    switcher), the surface growing out of the body on the liquid morph curve as
    its content cross-fades in, the Ame flame docking to each. At rest it shows a
    glyph, the clock and a breathing flame bead; hover expands it to workspaces,
    the date and quick-surface icons. Keybinds, the hover icons and the `pill`
    IPC all open surfaces. `washiVariant` picks the look: `ryoku` (the 力 mark,
    Space Grotesk, paper-ink) or `ricelin` (faithful: the 時 kanji and JetBrains
    Mono). Re-homed on Ryoku's own surfaces, Ame flame and tokens.
  - **`atoll`** ilyamiro's floating multi-island bar, ported frame-off: a row of
    dark rounded islands riding the wallpaper (search + settings; numbered
    workspace pills with a sliding bone chip behind the active one; a now-playing
    media island; the clock, date and weather centred; bright status chips that
    invert to bone plates when on, and the tray, right) that cascade up on startup
    and lift on hover. Its popouts are ilyamiro's own, re-homed on Ryoku's
    surfaces and tokens: the radial network/bluetooth orbit, the month grid with
    an hourly weather sun-arc, the 10-band EQ music player, the liquid-fill system
    cards, the battery ring with session controls, and the volume orb. Frame-off,
    so the islands float and the frame edge does not swell.
- `barHeight` and `fontScale` size it. Everything scales off `s =
  monitor.height / 1080 x fontScale` (clamped 0.7-1.6). The band the frame swells
  by is `barBand = barHeight x s`; modules size against `moduleSpan =
  round(barBand x 0.76)`.
- `barShowMedia` / `barShowStatus` / `barShowWeather` / `barShowSpecialWs` toggle
  the now-playing, status, weather and special-workspace modules; `barToggles` is
  the ordered set of quick-toggles the bar carries (empty = none). All live in
  Ryoku Settings -> Shell -> Bar -> Content, so a user adds or removes what the
  bar shows without editing files.

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
  wheel nudges volume, and hovering opens the transport popout (`MediaPopout`). The
  title width is capped per skin (`maxW`) so a long track name elides instead of
  crossing the clock or a neighbouring cluster.
- **status** (`BarStatus`) the volume / network / bluetooth / battery glyphs;
  each opens its own popout.
- **tray** (`BarTray`) the system tray.
- **power** a session glyph; clicking opens the power popout.
- **system stats** (`BarStats`, on the band faces, nacre and the flat iNiR skins) a CPU / RAM / temperature readout off
  the `SysStats` singleton (native `/proc` + `/sys` polling); clicking opens the
  resources popout (`ResourcesPopout`) with usage sparklines and the top
  processes by CPU.
- **weather** (`BarWeather`) the condition symbol + temperature off the `Weather`
  singleton (Open-Meteo); clicking opens `WeatherPopout` (current reading, an
  hourly strip and the daily forecast). Hidden until a reading lands.
- **quick toggles** (`BarToggles` -> `BarToggle`) placeable wifi / bluetooth /
  mic / do-not-disturb / caffeine / night-light switches, each accent-lit while
  on. State + actions live in the shared `Toggles` singleton, which also backs the
  System deck's control tiles, so there is one copy of the logic, not two.
- **special-workspace cue** (`BarSpecialWs`) an accent `layers` pill naming the
  active Hyprland scratchpad while one is up (tracks the `activespecial` event and
  seeds from hyprctl), collapsed to nothing otherwise; clicking toggles it away.

## The contextual island (delos)

`barStyle: delos` collapses the whole bar into one floating island in the frame's
blob field (`DelosIsland.qml`): docked to an edge, drag it off and it melts back
to the nearest one, tap the grip to tuck it to a nub. Beyond the modules it
carries (`islandModules`), it is a **contextual dynamic island** in the ActivSpot
mould: its face follows the live context -- now-playing (art + title + transport),
a screen-recording tally (pulsing dot + timer), or a Discord voice call (glyph +
timer) -- and springs to fit, falling back to the clock/modules when nothing is
live. When more than one context is active the non-primary ones ride beside it as
**minibubbles** (satellite blobs that meld into the same field), and a slow timer
rotates which context holds the island's face. Recoloured throughout to Delos's
fixed red sun.

## Reorderable zones (band skins)

On the straight-band skins (noctalia, caelestia, aegis, stele) the left, centre
and right clusters are reorderable: `barLayoutLeft` / `barLayoutCentre` /
`barLayoutRight` are ordered lists of module ids (`seal`, `workspaces`,
`special`, `title`, `clock`, `media`, `stats`, `weather`, `toggles`, `status`,
`tray`, `power`), edited from Ryoku Settings -> Shell -> Bar -> Layout. A zone
left empty keeps the classic arrangement, so the default bar is untouched; set
any zone and `BarModularFace` renders that skin's module treatment from the data
(a module can move between clusters, reorder, or drop). The bespoke skins
(triptych, nacre, the flat iNiR set, delos) keep their designed layouts.

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
