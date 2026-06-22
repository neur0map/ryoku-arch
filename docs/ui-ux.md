# UI and UX

The desktop's look and motion, and how to build or reproduce it. The UI is
Quickshell (QML) in `ryoku/shell/quickshell/`, driven by the `ryoku-shell` daemon.

## Design language

- **Dark, wallpaper-driven palette.** Colors come from `wallust`, regenerated
  from the current wallpaper. UI elements read their colors from that palette; do
  not hardcode a color that should follow the theme.
- **Brand constants.** The 力 mark and the brand orange (`#F25623`) are fixed and
  do not theme. Use them only for genuine brand accents (the logo, a key
  highlight), never for body text or large surfaces.
- **Type and cursor.** JetBrains Mono Nerd for mono, Noto for the rest; Bibata
  cursor. Keep to these.
- **Restraint.** Flat surfaces, generous spacing, few accents. A surface earns
  its place; if it does not, remove it.

## The surfaces

The frame is the chrome the others sit in; `pill`, `sidebar`, and `ryoshot` are
each their own directory under `quickshell/`, each component its own `.qml`:

- `frame` the rounded screen border and the popouts that melt into it; the
  desktop's signature surface and the chrome the others sit in. See
  `docs/frame.md`.
- `pill` the morphing top bar and its popouts (the centerpiece; it grows and
  reshapes between states). This is the reference for the project's motion. Its
  island has three styles set in Ryoku Settings (the classic fused island, a
  floating pill, or none, each optionally revealed on hover); the frame is the
  same in all.
- `sidebar` the slide-in panel.
- `ryoshot` screenshot capture and annotation.

## Motion

Motion is smooth, short, and purposeful. It exists to explain a state change, not
to decorate.

- Animate with QML primitives: `Behavior on <property>`, `NumberAnimation`,
  `PropertyAnimation`, and an explicit `easing.type`. Drive transitions from
  state, not from imperative timers, wherever possible.
- Keep durations and easing **consistent** across surfaces. Match what the `pill`
  already uses rather than inventing a new curve; consistency is the aesthetic.
- Respect inhibition and performance: no animation should fight the compositor or
  spin when idle.

## Building or replicating an animation

1. Read the closest existing component first; the `pill` shows the project's
   easing, durations, and structure. Reuse them.
2. Break the target motion into property transitions (size, position, opacity,
   radius) and the easing between them. Reproduce each with a `Behavior` or a
   named animation.
3. Prototype live: run the shell from the checkout with `ryoku/shell/dev-run.sh`
   (it launches via `qs -p` with hot-reload), so QML edits show as you save. Tune
   timing against the running surface.
4. Keep it in its own component file. Wire any state it needs through
   `ryoku-shell`, not ad hoc logic in the view.

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
