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
- Keep the center notch as an empty placeholder (fixed width). Future content
  will fill it; for now it preserves the three-notch frame shape.
- Place workspace numbers in the right notch, adjacent to `rightSidebarButton`
  inside the dark notch area.
- Keep the combined right status button and weather on the right, alongside
  workspaces and the visible-on-demand timer and shell-update indicators.
- Preserve the top-left hot-corner left-sidebar behavior by leaving
  `modules/screenCorners/ScreenCorners.qml` out of scope.
- Preserve left-side brightness scroll, right-side volume scroll, and existing
  right-click behavior.
- Hide topbar renderers for time/date, resources/system monitor, media/player,
  quick actions, battery, and system tray.
- Reserve layout space for `TimerIndicator` and `ShellUpdateIndicator` in the
  right notch so they appear on demand (active timer, pending update) without
  pushing other elements around.

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
2. Center notch: centered on the screen, fixed-width empty placeholder
   reserved for future content.
3. Right notch: ends at the screen right edge and extends down around
   workspaces, weather, the timer/update indicators, and `rightSidebarButton`.

The gaps between notches remain visually open below a thin top strip. This
matches the reference image better than separate BarGroup surfaces because the
corners read as part of a top frame, not detached pills.

The right notch's right-to-left content order is `rightSidebarButton`,
`Workspaces`, `TimerIndicator`, `ShellUpdateIndicator`, fill spacer, and
`WeatherBar`, all anchored inside the dark notch interior. `SysTray` remains
hidden because its width grows with running tray clients and would fight
fixed-width notch sizing.

The middle flanking groups (`leftCenterGroup`, `rightCenterGroupContent`)
remain in layout with zero opacity so the rest of the bar measurement stays
stable. Their resource/media/clock/util/battery content is disabled while the
Ryoku hug frame is active. The `middleCenterGroup` keeps a fixed implicit
width while the hug frame is active so the empty center notch retains a
consistent shape independent of any (now-absent) workspace child.

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

The patch also moves the `Workspaces { id: workspacesWidget … }` instance out
of `middleCenterGroup` and re-inserts the same block inside
`rightSectionRowLayout` as the second child (declared immediately after
`rightSidebarButton`). Because the layout uses `Qt.RightToLeft`, the second
declared child renders one slot to the left of the first, which places
workspaces inside the dark notch interior right next to the status button.
The `Workspaces.qml` component itself is unchanged; only the instance
location moves.

To support the empty center notch, `middleCenterGroup.implicitWidth` is
replaced with a fixed `100` while the hug frame is active. With the existing
`ryokuCenterNotchWidth` clamp `Math.min(Math.max(middleCenterGroup.implicitWidth + ryokuNotchPadding * 2, 96), 220)`,
this resolves to roughly 140 px, which is wide enough to read as a real
notch but compact enough to leave room for future content without redrawing
the whole frame.

The right notch widens accordingly: `ryokuRightContentWidth` adds
`workspacesWidget.implicitWidth + rightSectionRowLayout.spacing`, and
`ryokuRightNotchWidth`'s upper cap increases from 360 to 480 so the wider
content fits.

Re-runs of the script must remain a no-op. The relocation step uses the same
`if (already-patched) { upgrade } else { apply }` shape as the existing
hug-frame patches: it detects whether the live tree already has Workspaces in
`rightSectionRowLayout`, and only moves the block on the first run. A new
migration in `migrations/` re-invokes the branding script so live systems
pick up the relocation on the next update.

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
- Sizes the left and right notches from their content; sizes the center
  notch from a fixed placeholder width while the hug frame is active.
- Patches source and runtime `BarContent.qml`.
- Does not patch `ScreenCorners.qml`.
- Keeps Hug mode enabled through `showBackground=true` and `cornerStyle=0`.
- Suppresses BarGroup pill backgrounds with `borderless=true`.
- Hides old borderless separators inside the frame gaps.
- Hides clock, util buttons, battery, and sys-tray modules without deleting
  their component files.
- Does NOT force-hide `TimerIndicator` and `ShellUpdateIndicator` while the
  hug frame is active (they remain space-reserving and on-demand visible).
- Places the `Workspaces` instance inside `rightSectionRowLayout` and not
  inside `middleCenterGroup`.
- Replaces `middleCenterGroup.implicitWidth` so it does not reference
  `workspacesWidget` while the hug frame is active.
- Includes `workspacesWidget.implicitWidth` in `ryokuRightContentWidth`.

Manual verification should restart the shell and inspect the screenshot:
left, right, and center notches must touch the top frame correctly; the
right notch must contain the workspace strip adjacent to the status button;
an active timer or pending shell update must surface its indicator inside
the right notch without overlapping workspaces or weather; the gaps must be
open below the top strip; and the top-left hot corner plus left/right
scroll controls must still work.
