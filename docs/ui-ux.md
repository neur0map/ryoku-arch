# UI and UX

The desktop wears the same visual language as the Ryoku website: **Greek-noir**.
Classical beauty carrying warrior power, cracked and mended in gold, shot on
black. Greek marble fused with Japanese irezumi and gold kintsugi, every subject
anchored by a single red sun.

The canonical recipe (the idea, the exact palette, the art pipeline) lives with
the site: `ryoku-site/docs/design-system.md`. This doc is how that language is
applied in the QML desktop: the tokens, the type, the geometry, the shared
primitives, the surfaces, and the motion. The UI is Quickshell (QML) in
`ryoku/shell/quickshell/` (plus Ryoku Settings in `ryoku/hub/quickshell/`),
driven by the `ryoku-shell` daemon.

## Design language

A near-black canvas, warm-white type, one vermillion accent, gold used only as
kintsugi. Restraint is the point: flat surfaces, generous spacing, few accents. A
surface earns its place; if it does not, remove it.

- **Near-black canvas, warm-white type.** Backgrounds are the warm near-black of
  the website's `--paper` (`#100d08` and its neighbours `#16110b` / `#0f0c07`).
  Text is a warm-white ramp, never pure `#fff`: bright `#f3ede1`, cream `#e6dccb`,
  subtle `#c7bfae`, dim `#8f8770`.
- **One accent, and it follows the wallpaper.** This is the shell's single
  deviation from the fixed-vermillion website. When Ryoku Settings has *Match
  wallpaper* on, the accent is the `wallust` colour pulled from the current
  wallpaper; when off, it falls back to the brand vermillion `#e2342a`
  (deep `#b81f19`). Use the accent sparingly and deliberately: the active
  section, a focused field, numerals, the 力 mark. Never for body text or large
  fills.
- **The red sun stays fixed.** The red-sun disc motif and the day/night scene
  colours (the launcher's solar arc, the sun and moon) are always the fixed
  vermillion and their own scene palette, deliberately independent of the
  wallust accent, so a sun is always a sun on any wallpaper.
- **Gold is kintsugi only.** `#d9a441`, used rarely: a seam, a warning. Never a
  second accent hue.
- **Depth from hairlines and hard shadows, not gradients or blur.** Panels are a
  flat surface with a `1px` warm-white hairline border and, where they need to
  lift, a hard offset shadow: a solid black rectangle pushed down and right, no
  blur. The soft blurred shadow survives only where it is genuinely a drop
  shadow (a tray, a wallpaper tile).
- **力 is the brand mark.** The kanji seal is the one fixed brand constant. Use
  it as a mark (the masthead, an eyebrow lead), not as decoration.

## Tokens: never hardcode a colour

Every surface reads its look from `Ryoku.Ui`. One module, imported by the shell's
configs, the Hub and the apps. `import Ryoku.Ui.Singletons` and read `Tokens`;
never write a hex, a font name, a radius or a duration in a component.

    import Ryoku.Ui
    import Ryoku.Ui.Singletons

There used to be eleven `Singletons/Theme.qml` copies kept in step by hand. They
were not in step. They had drifted into three families with the same token names
carrying different values: `Theme.border` was a width in the Hub and a colour in
the pill, so a file moved between them broke silently, and `border2` exists
because the width token was evicted to make room. The `widgets` config ran two
Theme singletons at once. Do not add a twelfth. If a value is missing from
Tokens, add it to Tokens.

The module lives at `ryoku/ui/`. An installed system reads it from
`/usr/lib/qt6/qml/Ryoku/Ui`, which Qt resolves unaided. A deploy.sh checkout
puts it under `~/.local/lib/qt6/qml`, and only the daemon injects that path
(`ipc/daemon.go`), so `qs -c hub` from a keybind cannot see it without
`QML_IMPORT_PATH`. `hyprland/modules/env.lua` sets it for the session. If an
import fails in dev and works on an installed box, that is why.

### What follows the wallpaper, and what does not

The old text here claimed wallust overrides only the accent. It does not, and
never did. What the shell actually does, which is the better policy:

- **The accent follows the wallpaper.** `Wallust.accent` is `legible(vivid(color4),
  elevated, 3.0)`: the wallpaper's colour, walked toward white until it clears
  3:1 against the surface it sits on. Three of the nine Wallust copies skipped
  that clamp, which is why the Hub used to preview an accent the shell would
  never render.
- **The surfaces follow the wallpaper too, inside a clamp.** `shade()` tone-maps
  the wallpaper's background into a dark band: HSV value clamped to `[0.08,
  0.26]`, saturation capped at 0.55, hue kept. That is what stops a neon
  wallpaper producing an unreadable shell. The near-black canvas is derived, not
  fixed.
- **The 力 mark and the sun are never derived.** A sun is a sun on any wallpaper.
- **App content carries no accent at all.** The Hub, ryowalls and ryovm are paper
  and ink. Emphasis is inversion: a surface flips to bone and its ink flips to
  black. The frame carries the accent; the content does not compete with it.

So the rice wins inside an envelope the brand enforces. Write that down rather
than the reverse: the clamp is the design.

## Type

Self-hosted, no CDN. Four families, one role each:

|Role|Family|Token|
|---|---|---|
|Editorial headlines|**Fraunces**|`Tokens.display`|
|UI, body, labels, numerals|**Space Grotesk**|`Tokens.ui` (a user's configured UI font overrides it)|
|Tabular data only|**Space Mono**|`Tokens.mono`|
|Kanji marks (力)|**Noto Sans CJK JP**|`Tokens.jp`|

Mono labels are uppercase with wide tracking (`Tokens.trackLabel` 1.4,
`Tokens.trackMark` 2.2); that spacing is the technical, poster feel. Keep it.

Mono is not the UI face. It carries what is literally valid in a config file:
keys, ranges, defaults, paths, ids. Everything a human reads as language is
Space Grotesk, numerals included. Setting the whole UI in mono makes it read as
a terminal instead of a printed instrument, which is a different product.

## Geometry

- **A hair of rounding.** `Tokens.radius` is `2`. Cards, rows, inputs, chips and
  menus take it. Only true circles stay round: status dots, toggle knobs,
  badges, the VRAM ring. The outer Hyprland window rounding is the user's own
  knob; inside our surfaces we are near-square.
- **Hairline borders.** `1px` (`Tokens.border`) at `Tokens.line`. Depth is a
  hairline, not a glow.
- **No shadows in app surfaces.** The Hub and the apps are print: a flat
  instrument sheet does not cast. The brutalist offset shadow is retired; an
  overlay separates with `Tokens.paperLift` and a `lineStrong` border instead.
  The frame's own drop shadow over the wallpaper is a different thing and is
  outside this doc.

## The idioms: shared primitives

They live in `Ryoku.Ui`. Reuse them; do not re-roll a bespoke header, control or
divider in each surface. That is how eleven Themes happened.

|Idiom|Component|
|---|---|
|A setting: label, value, unit, struck default, description, control|`Cell`|
|A named group that packs its own cells|`Section` (spans come from `Spans`, never by hand)|
|The eight controls|`Sw` `Step` `Slid` `Seg` `Chips` `Multi` `PickBar`+`Picker` `Gallery`|
|Save / Revert / Reset, and the dirty state|`ActionBar`|
|The block a live preview sits in|`Preview`|
|The matte|`Grain`, one layer, topmost|

The old table here listed `Eyebrow`, `SunDisc`, `RegMark` and `BrutalPanel`. The
Hub used `RegMark` and `BrutalPanel` zero times: the brutalist card the tokens
described was built and never adopted, and the pages hand-rolled a hairline
`Rectangle` instead. A documented primitive nobody reaches for is not a design
system, it is a museum. If a new idiom is worth having, put it in `Ryoku.Ui` and
use it somewhere in the same change.

**Choosing a control is not a taste decision.** `Spans.controlFor(kind, options)`
picks it from the option count, because the counts are known: of the Hub's enums
79 have 1-4 options, 10 have 5-8, 23 have 10 or more, and `islandModules` is a
set rather than a choice. Two options is a `Seg`. Ten is a `Pick`. The ten bar
skins are a `Gallery`, because no label distinguishes "engraved bracket cells"
from "three islands with concave dips".

## A page is its surfaces

A settings page is not a list of settings. Across the Hub there are 479 settings
and 508 surfaces, and not one page has zero: the previews, the update console,
the monitor drag-arrange, keybind capture, the bezier editor, store cards, scan
lists, file pickers, the empty and loading states. WifiTab is one setting and
thirty-one surfaces.

So a schema is half a page. Port in this order:

1. List the page's surfaces before writing anything.
2. Build them first, as full-width blocks in the section grid. A preview or a
   console is not a setting and does not go in a `Cell`.
3. Let the rows flow around them.
4. Check all four: every surface present, every key present, the adapter still
   writing (`tests/ui/wire-probe.sh`), nothing below 4.6:1.

The `ActionBar` goes in first. A page that previews live and cannot save does
not look broken; it looks fine and then eats the edit on the way out.

## The surfaces

Each surface is its own directory under `quickshell/`, each component its own
`.qml`. The frame is the chrome the others sit in.

- **frame** the rounded screen border and the popouts that melt into it; the
  desktop's signature surface. See `docs/frame.md`.
- **pill** the shell surface directory (`quickshell/pill/`, the name is
  historical): the module **bar** riding one frame edge and every popout it
  opens. The bar is the resting face (the 力 seal, the sliding workspace strip,
  the focused title, the clock, now-playing, status glyphs, tray, and power),
  placeable top or bottom, in two skins carried one-to-one from
  the credited reference shells: Noctalia (capsule modules, dot workspaces, the
  stacked clock) and Caelestia (the numbered cell strip with the sliding
  indicator, Material Symbols iconography). See
  `docs/bar.md` for the bar and `docs/frame.md` for the popouts it grows.
- **launcher** the Super-triggered app launcher and command palette, with a
  zero-query rest card (the solar-arc clock and weather). See `docs/launcher.md`.
- **switcher** the full-screen Alt-Tab window switcher.
- **ryoshot** screenshot capture and annotation.
- **overview** the full-screen workspace expo (Super+Tab), launcher-style: the
  compositor blurs the desktop and a filmstrip shows the current desktop's
  workspaces as scaled mini-desktops with live window previews. Drag windows
  between workspaces or up onto the top desktop strip, cycle spaces
  (scroll/Tab) and desktops (Super+Alt+Tab). A "desktop" is a block of ten
  workspace ids, so each desktop keeps its own 01..10; the same grouping drives
  the desktop-relative Super+N binds (`scripts/ryoku-workspace`).
- **the keyring prompt** the GNOME keyring password prompt, grown from the bar
  edge as a popout rather than gcr's centred dialog. The `ryoku-shell` daemon acts as the
  keyring system prompter and drives it; `KeyringSurface.qml` renders it.
- **the sidebars** two full-height panels that melt out of the left and right
  frame edges on a top-corner hover, the frame's blob swelling open edge to edge.
  Left is Features (the Stash board, room for more); right is System (力 masthead,
  the control-centre toggles, capture tools plus a clipboard button, a volume
  fader, and a tab rail over notifications, calendar, now-playing, weather, and
  recording). See `docs/frame.md`.
- **desktop widgets** the clock and weather that sit on the wallpaper, a
  click-through `WlrLayer.Bottom` surface configured in Ryoku Settings' Desktop
  Widgets section. Faces and weather skies live under `quickshell/widgets`.
- **Ryoku Settings (the Hub)** the settings app (`ryoku/hub/quickshell/`, run as
  `qs -c hub`). Its `PageHeader`, `NavRail`, and the primitives above set the
  pattern every page follows.
- **welcome** the first-run guided tour, shown once on the first login: a floating
  window (`qs -c welcome`) over generated Greek-noir threshold art that walks a new
  user through the core keybinds, names each surface and how to summon it, and
  offers a few live quick settings (wallpaper, bar position and skin, frame and window roundness). The Hyprland
  autostart launches it once, gated on a `~/.local/state/ryoku/welcome-seen` flag;
  it lives in `quickshell/welcome`.

## Motion

Motion is smooth, short, and purposeful. It exists to explain a state change, not
to decorate.

- **The `Motion` singleton is the token set** (`pill/Singletons/Motion.qml`).
  Reach for its durations and curves rather than inventing values: `fast`
  (140ms) hover/press, `standard` (300ms) general, `morph` (420ms) shape changes
  and popout close, `emphasized` (400ms, `emphasizedCurve`) slides and indicator
  travel, `spatial` (500ms, `spatialCurve`, a spring with overshoot) popout open
  and travel, `effects` (200ms) plain fades. The curves are `cubic-bezier`
  control-point arrays fed to `easing.bezierCurve` with `easing.type:
  Easing.BezierSpline`; the caelestia Material-3-expressive family is carried
  over one-to-one so the bar and its popouts move like the reference.
- Drive transitions from **state** (`states` + `transitions`), not imperative
  timers, wherever possible; the popout reveal is the model.
- **The frame's give is physical, not scripted.** A `BlobRect`'s `stiffness` /
  `damping` / `deformScale` squash it as it moves and settle it at rest, the
  liquid feel when a popout grows. See `docs/frame.md`.
- Respect inhibition and performance: no animation should fight the compositor
  or repaint when idle. Gate live work (a `MultiEffect`, a poll, a scanner) on
  the surface being open or visible; a hidden or resting surface costs nothing,
  and idle blobs snap to rest.

## Building or replicating an animation

1. Read the closest existing component first; the bar and its popouts
   (`quickshell/pill/`) show the project's durations, curves, and structure.
   Reuse the `Motion` tokens.
2. Break the target motion into property transitions (size, position, opacity)
   and the easing between them, and reproduce each with a `Behavior` or a named
   animation on a `Motion` token. If the frame itself should give, let a
   `BlobRect` carry it rather than animating geometry by hand.
3. Prototype live: run the shell from the checkout with `ryoku/shell/dev-run.sh`
   (it launches via `qs -p` with hot-reload), so QML edits show as you save. Tune
   timing against the running surface.
4. Keep it in its own component file. Wire any state it needs through
   `ryoku-shell`, not ad hoc logic in the view.

## Art

Figurative art (the launcher clock background, the Hub profile card, the welcome
backdrop, the fastfetch emblem) follows the website's pipeline: generated at dev time with
`fal-ai/nano-banana-pro`, background flood-filled to the canvas colour so it
blends seamlessly, and committed as a static asset (the running target has no
generation dependency). The full recipe (prompt suffix, post-processing) is in
`ryoku-site/docs/design-system.md`. One desktop constraint: Quickshell's Qt build
has no webp plugin, so shell/Hub art ships as **PNG**, not webp.

## Research

When a control, protocol, or animation is unfamiliar, look it up against primary
sources and confirm on the running system:

- The Quickshell documentation and example configurations for QML widgets, the
  IPC surface, and layer-shell behavior.
- The Hyprland wiki for compositor behavior, dispatchers, and protocols
  (idle-inhibit, layer rules, window rules).
- The Qt/QML documentation for animation, layouts, and bindings.
- The Arch Wiki and each tool's own docs for system-level pieces.

Prefer official sources, cross-check a second one for anything load-bearing, and
verify the result live with the dev loop rather than assuming it renders.
