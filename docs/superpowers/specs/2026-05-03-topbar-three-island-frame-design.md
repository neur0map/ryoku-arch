# Topbar Three-Island Frame Design

## Context

Ryoku currently runs the iNiR Quickshell bar through the runtime tree at
`~/.config/quickshell/inir`, with Ryoku applying branding and runtime patches
from this repository. The existing bar has useful edge interactions, but the
visible topbar is too busy for the desired frame style.

The target look is a topbar with rounded islands and open transparent space
between them, similar to a device frame. The current rounded bar treatment
should remain, but time/date, system monitor, media/player, quick action
buttons, battery, tray, timer, and update clutter should no longer render in
the topbar. Those features already live in the right sidebar or another shell
surface, so the topbar can become calmer without deleting functionality.

## Goals

- Render the topbar as three compact rounded islands with transparent gaps.
- Keep the current rounded-corner frame language.
- Keep hot-corner sidebar behavior.
- Keep left-side brightness scroll behavior.
- Keep right-side volume scroll behavior.
- Keep logo plus active window title/status on the left.
- Keep workspace numbers centered.
- Keep the right sidebar status button and weather on the right. The status
  button contains the Wi-Fi, Bluetooth, notification, mic, and volume-mute
  indicators.
- Remove topbar renderers for time/date, resources/system monitor,
  media/player, quick action buttons, battery, tray, timer, and shell update
  indicators.
- Preserve the right sidebar as the full control surface for controls removed
  from the topbar.

## Non-Goals

- Do not delete sidebar widgets, quick toggles, audio controls, notification
  controls, media controls, or system monitor functionality.
- Do not redesign the right sidebar.
- Do not change keybindings or IPC.
- Do not remove the left/right bar scroll hit areas.
- Do not alter unrelated hardware, installer, or migration changes.

## Layout

The topbar should be divided into three visible islands:

1. Left island: logo/sidebar button plus active window title/status text. If
   the user enables `bar.modules.taskbar`, the taskbar can still render in this
   left island instead of the active-window text. This keeps the current
   left-side behavior and remains the place where the user sees what window or
   view is active.
2. Center island: workspace numbers only. This island stays centered so
   workspace identity remains easy to scan.
3. Right island: `rightSidebarButton` plus weather. `rightSidebarButton` is
   the existing combined status button that contains Wi-Fi, Bluetooth,
   notifications, mic mute, volume mute, keyboard layout, and the sidebar
   toggle. Weather remains a separate `WeatherBar` loader next to it.

The space between islands should be transparent. The bar should no longer read
as one continuous filled strip, but each island should still use the existing
rounded Ryoku/iNiR styling rather than introducing a separate visual system.

Mechanically, transparent gaps come from:

- Setting `bar.showBackground` to `false`, which hides the single continuous
  `barBackground` rectangle in `BarContent.qml` and disables the matching
  full-bar shadow/decorator path.
- Setting `bar.borderless` to `false`, which lets existing `BarGroup.qml`
  backgrounds render as rounded island surfaces.
- Keeping the middle flanking groups at `centerSideModuleWidth` so workspaces
  remain centered, but making those spacer groups visually transparent. They
  should continue occupying layout width while not drawing empty islands.

The right-center mouse area can remain as an invisible spacer and redundant
right-sidebar toggle. It preserves centering and current click behavior without
adding visible clutter.

The hot-corner behavior is not part of `BarContent.qml`. It lives in
`modules/screenCorners/ScreenCorners.qml` as `sidebar.cornerOpen`, and top-left
currently toggles the left sidebar. This design preserves it by not patching
`ScreenCorners.qml`.

Left and right bar-side context behavior should stay intact: right-clicking the
bar side areas still opens the bar context menu, and right-clicking the
right-center area can continue toggling the control panel.

## Architecture

The implementation should patch the shell runtime through Ryoku's existing
branding overlay rather than editing unrelated installed files by hand only.
The main repo-owned target is:

- `install/config/ryoku-shell-branding.sh`

That overlay can apply a small, idempotent QML patch to:

- `$SHELL_PATH/modules/bar/BarContent.qml`
- `$RUNTIME_SHELL_PATH/modules/bar/BarContent.qml`

The patch should keep the existing bar mouse areas, context menu behavior, and
scroll actions intact. It should only adjust visible module composition and
background grouping.

Use an explicit idempotency marker in the patched QML:

- `readonly property bool ryokuThreeIslandFrame: true`

The branding script should grep for that marker before applying the topbar
frame patch. As with the existing branding patches, failure to find the exact
upstream block should skip cleanly.

The Ryoku config override should also set conservative defaults so fresh
installs prefer the clean topbar:

- Set `bar.showBackground` to `false`.
- Set `bar.borderless` to `false`.
- Disable battery, media, resources, util buttons, tray, timer, update, and
  clock visibility where those are config-controlled.
- Keep active window, left sidebar button, workspaces, right sidebar button,
  taskbar opt-in support, status indicators inside `rightSidebarButton`, and
  weather.

If a module is not currently config-controlled, the QML patch should hide it in
the topbar without removing the component file.

The implementation should patch both:

- `$SHELL_PATH/modules/bar/BarContent.qml`
- `$RUNTIME_SHELL_PATH/modules/bar/BarContent.qml`

The test updates belong in the existing `tests/ryoku-shell-branding.sh` file.

## Data Flow

All live data sources stay the same:

- Active window state continues to come from the existing active-window module.
- Workspace state continues to come from the existing workspace module.
- Wi-Fi and Bluetooth state continue to come from the existing
  `rightSidebarButton` indicator model/services.
- Weather continues to use the existing weather bar module.
- Brightness and volume scroll actions continue to use the existing
  `performScrollAction()` paths.

No new state model is needed.

## Coverage And Tradeoffs

Timer controls are still available in the right sidebar timer widget, including
the existing `TimerIndicator.openTimerPanel()` path that targets the sidebar
timer tab. Hiding the topbar timer indicator only removes the ambient topbar
badge.

Shell updates are not in the right sidebar, but they already have
`ShellUpdateOverlay.qml` and settings-page controls backed by the
`ShellUpdates` service. Hiding `ShellUpdateIndicator` removes the topbar badge;
it must not disable the `iiShellUpdate` panel, the update overlay, or the
settings controls.

Notifications remain represented inside `rightSidebarButton` and in the right
sidebar notification surfaces. The notification popup system itself is not in
scope.

## Error Handling

The patching function must be idempotent. If the expected upstream QML shape is
not found, it should skip cleanly rather than corrupting the file. Existing
branding-overlay behavior should continue to log and apply other patches.

## Testing

Static test coverage should assert that the Ryoku overlay:

- Contains the three-island topbar patch function.
- Uses `readonly property bool ryokuThreeIslandFrame: true` as the idempotency
  marker.
- Patches both source and runtime `BarContent.qml` paths.
- Sets `bar.showBackground` to `false` and `bar.borderless` to `false` in the
  Ryoku config overlay.
- Keeps left and right scroll actions in place.
- Disables or hides topbar clock, resources, media, util buttons, battery,
  tray, timer, and update indicators.
- Keeps active window or taskbar opt-in, workspaces, right sidebar indicators,
  and weather.
- Leaves `modules/screenCorners/ScreenCorners.qml` out of the topbar frame
  patch.

Manual verification should restart the live shell and inspect the topbar:

- Rounded left, center, and right islands are visible.
- Transparent spaces appear between islands.
- Hovering or pressing the configured top-left hot corner still toggles the
  left sidebar according to `sidebar.cornerOpen`.
- Scrolling left changes brightness.
- Scrolling right changes volume.
- Left text, workspace numbers, Wi-Fi, Bluetooth, and weather remain visible.
