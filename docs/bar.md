# Frame bars

This document describes **Sumi**, Ryoku's built-in painted-frame bar: one
frame-bar system of four independent rails that share the monitor's frame
scene. When Sumi is the active style,
`ryoku/shell/quickshell/shell/modules/bar/Bar.qml` creates a `FrameRail` for each
edge and reads the normalized `frameBars` object from `~/.config/ryoku/shell.json`.

Sumi is no longer the shipped default. The default is **qsbar**, a separate
full-color top bar that loads from a self-contained folder under
`shell/modules/bar/barstyles/`. `Frame.qml` draws Sumi's rails only while
`barStyle` resolves to no folder scene (the id `"sumi"` or an empty value), and
any other id mounts that folder style's `Scene.qml` instead. For style
selection and qsbar, see `docs/barstyles.md`.

A rail is a thin interactive strip, not a second panel process. The monitor
overlay owns its input region and the corresponding exclusive-zone reserve, so
tiled windows clear exactly the enabled edge rails.

## Default profile

The shipped profile enables a compact top rail and a continuous left rail:

- **Top**: centred clock.
- **Left**: quick settings and workspaces at the top, dock in the centre, tray,
  network, and clock at the bottom.
- **Bottom and right**: configured but initially disabled.

Every edge has its own `enabled`, `size`, `reveal`, and three axis-appropriate
zones. Horizontal rails use `start`, `center`, and `end`; vertical rails use
`top`, `center`, and `bottom`. A zone holds its group against its own end of
the rail: a start zone hugs the leading edge, a centre zone sits on the rail's
midpoint, an end zone hugs the trailing edge. The runtime accepts only
catalogued widgets that fit the target axis.

## Bar Studio

Open **Bar Studio** with **Super+Period**. The shortcut records the Bar Studio
section before opening the guarded Ryoku Settings process.

Bar Studio stages a complete immutable `frameBars` object through the normal Hub
draft and Save flow, and its edits apply to the running desktop as you make them.
Pick an edge to work on that rail. It edits only what changes the running frame:

- the frame chrome the shell draws around the desktop: the draw toggle, the
  opacity, the band thickness, and the corner radius;
- each rail's own switches: on or off, and thickness;
- the widgets in each rail's three zones: add a catalogued widget that fits the
  rail's axis and is not already on it, remove one, or reorder within a zone.

The frame's material and colour come from the shell's look (`Theme` and the
palette), not a user knob; picking a different bar style is a separate choice,
covered in `docs/barstyles.md`.

Every change is live on the desktop at once. Save keeps it and rebaselines;
Revert, or closing the window with unsaved edits, walks the desktop back to the
saved state through the same channel. Bar Studio never writes configuration
files directly.

The bounded menus and the `stash` frame surface keep whatever
values are persisted: every Bar Studio edit clones the whole `frameBars` object,
so a subtree it does not touch is never dropped. They are configured through
their defaults and the catalogue, not edited on this page.

## Menus and popout cards

A rail widget reports its own rectangle to the monitor-local
`FrameMenuManager`, which owns one open surface per anchor per monitor. It
combines the widget and body mask regions so input lands where it should, and it
closes on Escape, a click outside, focus loss, or fullscreen.

Most status widgets open a popout card. Click the network, Bluetooth, battery,
audio, system-monitor, recording, or music widget and a card grows out of the
rail from the point you clicked, then melts back the same way when it closes.
The cards are not read-outs, they are the controls: audio is a full mixer
(output, input, per-app volume, and the Bluetooth codec), Bluetooth pairs and
connects devices and shows their battery, battery carries the gauge, the power
profiles, and a detail panel, network runs Wi-Fi, and the rest follow suit. They
share one skin from a card kit (`shell/modules/bar/popouts/PopoutCard.qml` and its siblings),
so every card opens, reads, and dismisses the same way.

Super+Escape opens the only full-height control sidebar. Its fixed rail selects
independent modules catalogued in `MenuCatalog.js`; the default module list is
home, notifications, weather, and capture, while media is available as an optional
module. The home module retains the session actions and performance profiles.
Adding a module requires one catalog entry and one component under
`shell/modules/bar/framebars/menus/quicksettings/`, then its ID can be added to
`frameBars.menus.quick-settings.modules`.

`ryoku-shell menu <id>` opens a catalogued menu on the active monitor;
`MenuCatalog.js` holds the valid IDs, and anything else is rejected before it
reaches Quickshell. Asking for the menu that already owns an anchor closes it,
so a rail button and its command read as one toggle, and a different menu at
the same anchor replaces it safely. The keyring prompt and the voice toast are
daemon-owned, so they replace rather than toggle.

A card clears the rail it grows from and draws above the rails, so its body
never hides under rail chrome. Voice, keyring, and enabled plugin surfaces share
this same manager scene.

## Extending frame bars

1. Add a catalogued widget or surface with an explicit axis/anchor contract.
2. Add the matching finite IPC route if it needs a command entry point.
3. Keep menu body work gated by its `open` state and release it on close.
4. Preserve owner rectangles, mask regions, monitor locality, and identity-safe
   close behavior.
5. Add the behavior test and Bar Studio label before exposing the new ID.

Do not introduce a parallel renderer, unbounded component loader, or direct
configuration writer.
