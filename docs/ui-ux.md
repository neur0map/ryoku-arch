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

Every surface reads its look from a `Singletons/Theme.qml` singleton that mirrors
the website's `app/assets/css/tokens.css`. Add a token or read one; never write a
hex, a font name, or a radius literal in a component.

- `ryoku/hub/quickshell/Singletons/Theme.qml` is the fullest reference (it names
  the site token each value maps to).
- `ryoku/shell/quickshell/{pill,launcher,widgets,plugins,plugins/kit}/Singletons/Theme.qml`
  and `switcher/shell.qml` are the shell twins. They carry the wallust-matched
  accent with the vermillion fallback; `widgets` keeps the accent fixed because a
  desktop widget sits on the wallpaper and must read on any backdrop.

The core palette (the fixed fallback; wallust overrides only the accent):

|Token|Value|Use|
|---|---|---|
|`brand` / `sun`|`#e2342a`|the one vermillion accent; `sun` is the fixed red-sun motif|
|`sunDeep` / `emberDeep`|`#b81f19`|pressed / hover|
|`gold`|`#d9a441`|kintsugi seams, warnings, sparingly|
|`bright` / `cream` / `subtle` / `dim`|`#f3ede1` / `#e6dccb` / `#c7bfae` / `#8f8770`|warm-white text ramp|
|`bgTop` / `bgBot`|`#16110b` / `#0f0c07`|near-black canvas / recessed panels|
|`line` / `lineStrong`|warm-white at `0.14` / `0.40` alpha|hairline dividers / card borders|
|`shadow`|`#000000`|hard brutalist offset (never the ink colour)|

## Type

Self-hosted, no CDN. Four families, one role each:

|Role|Family|Token|
|---|---|---|
|Editorial headlines|**Fraunces**|`Theme.display`|
|UI and body|**Space Grotesk**|`Theme.font` (a user's configured UI font overrides it)|
|Labels, numerals, code|**JetBrains Mono Nerd Font**|`Theme.mono`|
|Kanji marks (力)|**Noto Sans CJK JP**|`Theme.fontJp`|

Mono labels are uppercase with wide tracking (letter spacing roughly `1.5` to
`3`); that spacing is the technical, poster feel. Keep it.

## Geometry: brutalist

- **Sharp corners inside surfaces.** `Theme.radius` is `0`. Cards, rows, inputs,
  chips, and menus are square. Only true circles stay round: status dots, toggle
  knobs, badges, the VRAM ring. The outer Hyprland window rounding is the user's
  own knob (the frame); inside our surfaces we are sharp.
- **Hairline borders.** `1px` (`Theme.border`), warm-white at low alpha.
- **Hard offset shadows.** A solid `Theme.shadow` rectangle offset by
  `Theme.shadowStep` (6px, or `shadowStepLg` 8px for larger cards), no blur,
  `antialiasing: false`. Depth comes from the offset, not a glow.

## The idioms: shared primitives

The website's chrome idioms exist as small QML components. Reuse them; do not
re-roll a bespoke header or divider in each surface.

|Idiom|Website (`base.css`)|QML component|
|---|---|---|
|Eyebrow: a vermillion tick, the 力 seal, then a mono uppercase label|`.eyebrow`|`hub/quickshell/Eyebrow.qml`, `shell/quickshell/pill/Eyebrow.qml`|
|Red-sun disc: a soft radial vermillion glow behind a subject|`.sun-disc`|`hub/quickshell/SunDisc.qml`|
|Registration mark: a printing crosshair as poster chrome|`.regmark`|`hub/quickshell/RegMark.qml`|
|Brutalist panel: sharp face, hairline border, hard offset shadow|the card pattern|`hub/quickshell/BrutalPanel.qml`|

## The surfaces

Each surface is its own directory under `quickshell/`, each component its own
`.qml`. The frame is the chrome the others sit in.

- **frame** the rounded screen border and the popouts that melt into it; the
  desktop's signature surface. See `docs/frame.md`.
- **pill** the morphing top bar and its popouts (the centerpiece; it grows and
  reshapes between states). This is the reference for the project's motion. Its
  island has three styles set in Ryoku Settings (the classic fused island, a
  floating pill, or none, each optionally revealed on hover); the frame is the
  same in all.
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
- **the keyring island** the GNOME keyring password prompt, grown from the pill
  centre rather than gcr's centred dialog. The `ryoku-shell` daemon acts as the
  keyring system prompter and drives it; `KeyringSurface.qml` renders it.
- **desktop widgets** the clock and weather that sit on the wallpaper, a
  click-through `WlrLayer.Bottom` surface configured in Ryoku Settings' Desktop
  Widgets section. Faces and weather skies live under `quickshell/widgets`.
- **Ryoku Settings (the Hub)** the settings app (`ryoku/hub/quickshell/`, run as
  `qs -c hub`). Its `PageHeader`, `NavRail`, and the primitives above set the
  pattern every page follows.

## Motion

Motion is smooth, short, and purposeful. It exists to explain a state change, not
to decorate.

- Animate with QML primitives: `Behavior on <property>`, `NumberAnimation`,
  `PropertyAnimation`, and an explicit `easing.type`. Drive transitions from
  state, not from imperative timers, wherever possible.
- Keep durations and easing **consistent** across surfaces. The tokens are
  `Theme.quick` (120ms), `Theme.medium` (240ms), `Theme.slow` (360ms), eased
  with `Easing.OutExpo` (the QML twin of the site's `cubic-bezier(0.22,1,0.36,1)`).
  Match what the `pill` already uses rather than inventing a new curve;
  consistency is the aesthetic.
- Respect inhibition and performance: no animation should fight the compositor or
  repaint when idle. A hidden or resting surface costs nothing.

## Building or replicating an animation

1. Read the closest existing component first; the `pill` shows the project's
   easing, durations, and structure. Reuse them.
2. Break the target motion into property transitions (size, position, opacity)
   and the easing between them. Reproduce each with a `Behavior` or a named
   animation.
3. Prototype live: run the shell from the checkout with `ryoku/shell/dev-run.sh`
   (it launches via `qs -p` with hot-reload), so QML edits show as you save. Tune
   timing against the running surface.
4. Keep it in its own component file. Wire any state it needs through
   `ryoku-shell`, not ad hoc logic in the view.

## Art

Figurative art (the launcher clock background, the Hub profile card, the
fastfetch emblem) follows the website's pipeline: generated at dev time with
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
