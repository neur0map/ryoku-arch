# Topbar Hug-Frame Design

## Context

Ryoku applies iNiR Quickshell branding and runtime patches from this
repository. The topbar should match the provided reference image: a continuous
top-attached frame with three downward notches and transparent gaps between
them. The previous floating-pill island approach is rejected because it
overrides the existing hug-corner language instead of extending it.

The target geometry is the same family as Brain_Shell's
`src/shapes/SeamlessBarShape.qml`: one Canvas-drawn top frame, with the left
notch attached to the top-left edge, the center notch attached to the top edge,
and the right notch attached to the top-right edge.

## Goals

- Add a Ryoku-specific topbar hug-frame style without deleting the existing bar
  style system.
- Keep iNiR's Hug corner mode and fake screen corner decorators.
- Draw a single seamless Canvas frame with three top-attached notches.
- Keep transparent open space below the thin top strip between notches.
- Keep logo plus active window title/status on the left.
- Keep workspace numbers centered.
- Keep the combined right status button and weather on the right.
- Preserve the top-left hot-corner left-sidebar behavior by leaving
  `modules/screenCorners/ScreenCorners.qml` out of scope.
- Preserve left-side brightness scroll, right-side volume scroll, and existing
  right-click behavior.
- Hide topbar renderers for time/date, resources/system monitor, media/player,
  quick actions, battery, tray, timer, and shell update indicators.

## Non-Goals

- Do not redesign the right sidebar or remove sidebar-owned controls.
- Do not delete media, timer, update, notification, audio, or system monitor
  components from the shell.
- Do not convert the bar to floating pill cards.
- Do not patch `ScreenCorners.qml`.
- Do not change keybindings, IPC, or compositor behavior.

## Layout

The visible frame is one Canvas path, not three independent rounded
rectangles. It has:

1. Left notch: starts at screen x=0 and extends down from the top edge around
   the logo/sidebar button and active-window/taskbar content.
2. Center notch: centered on the screen and sized around workspaces.
3. Right notch: ends at the screen right edge and extends down around weather
   plus `rightSidebarButton`.

The gaps between notches remain visually open below a thin top strip. This
matches the reference image better than separate BarGroup surfaces because the
corners read as part of a top frame, not detached pills.

The middle flanking groups remain in layout with zero opacity so workspace
centering stays stable. Their resource/media/clock/util/battery content is
disabled while the Ryoku hug frame is active.

## Architecture

The repo-owned implementation lives in:

- `default/ryoku-shell/config-overrides.json`
- `install/config/ryoku-shell-branding.sh`
- `tests/ryoku-shell-branding.sh`

The config overlay enables the additional Ryoku style:

- `bar.ryokuTopbarHugFrame = true`
- `bar.cornerStyle = 0`
- `bar.showBackground = true`
- `bar.borderless = true`

`showBackground` stays true so `Bar.qml` keeps rendering the Hug decorators.
`BarContent.qml` hides only its full-width `barBackground` while the Ryoku
frame is active. This preserves the outer corner-hug behavior without filling
the whole topbar.

The branding script applies an idempotent QML patch to both:

- `$SHELL_PATH/modules/bar/BarContent.qml`
- `$RUNTIME_SHELL_PATH/modules/bar/BarContent.qml`

The patch marker is:

- `readonly property bool ryokuTopbarHugFrame: (Config.options?.bar?.ryokuTopbarHugFrame ?? false)`

The script also upgrades the rejected legacy marker,
`root.ryokuThreeIslandFrame`, so live systems already patched with the pill
implementation can be corrected in-place.

## Data Flow

No new services are introduced. Existing data sources remain unchanged:

- Active window text comes from `ActiveWindow`.
- Workspace state comes from `Workspaces`.
- Wi-Fi, Bluetooth, notifications, mic mute, and volume mute remain inside
  `rightSidebarButton`.
- Weather remains the existing `WeatherBar` loader.
- Brightness and volume scroll actions continue through `performScrollAction()`.

## Testing

Static coverage in `tests/ryoku-shell-branding.sh` asserts that the overlay:

- Defines `apply_topbar_hug_frame_to_file()`.
- Adds the `ryokuTopbarHugFrame` marker.
- Draws one `Canvas` frame using rounded `ctx.arcTo()` transitions.
- Sizes the left, center, and right notches from their content.
- Patches source and runtime `BarContent.qml`.
- Does not patch `ScreenCorners.qml`.
- Keeps Hug mode enabled through `showBackground=true` and `cornerStyle=0`.
- Suppresses BarGroup pill backgrounds with `borderless=true`.
- Hides old borderless separators inside the frame gaps.
- Hides removed topbar modules without deleting their component files.

Manual verification should restart the shell and inspect the screenshot: left
and right notches must touch the screen corners, the center notch must attach
to the top edge, the gaps must be open below the top strip, and the top-left
hot corner plus left/right scroll controls must still work.
