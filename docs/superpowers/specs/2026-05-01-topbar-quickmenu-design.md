# Topbar Quickmenu Design

## Context

`Super+Alt+Space` currently routes to the Quickshell `SettingsMenuPopup`.
That popup works functionally, but the home view is too large and too text
heavy for quick actions. Wi-Fi, Bluetooth, Airplane Mode, and related states
are rendered as large labeled tiles even though they are mostly one-click
toggles. The result feels like a standalone drawer instead of an extension of
the topbar.

The topbar already has a better local pattern:

- `TopBar.qml` promotes the bar layer while attached surfaces are visible.
- `SystemMenuPopup.qml` uses a compact top-attached `PopupShape`.
- `PopupShape.qml` can visually melt a popup into the top edge.
- Topbar modules use dense, restrained controls rather than large cards.

The quickmenu should use those patterns while keeping the useful settings hub
routes that already exist.

## Goals

- Make `Super+Alt+Space` open a compact quickmenu that feels attached to the
  right side of the topbar.
- Put quick toggles first, with Wi-Fi, Bluetooth, Airplane Mode, Hotspot,
  Night Light, Focus Mode, Do Not Disturb, and Filter represented primarily by
  icon buttons.
- Make the default home view materially smaller than the current 456x520
  control-center drawer.
- Keep deeper menus available from the same surface, but restyle them to match
  the same compact topbar-extension language.
- Move status text out of every quick toggle and into a compact status line
  where it helps, for example Wi-Fi SSID, connected Bluetooth device, hotspot
  error, external focus mode, or active filter.
- Preserve current command and popup contracts, including
  `ryoku-ipc shell toggle settings-menu`, route-specific settings-menu IPC, and
  the existing keybindings.
- Keep the visual language cutesy and Caelestia-shell-like: soft, lively,
  rounded, icon-forward, and compact, while still fitting Ryoku's current
  topbar colors and geometry.

## Non-Goals

- Do not remove the settings hub routes.
- Do not turn `Super+Alt+Space` into a separate launcher or old Omarchy picker.
- Do not add a new popup framework.
- Do not redesign unrelated dashboard, wallpaper, dotfiles, or system menu
  surfaces.
- Do not replace existing shell commands for Wi-Fi, Bluetooth, hotspot,
  filters, or focus mode.

## UX

### Home View

The home view should be the quick action surface, not a settings directory.

Top to bottom:

1. A compact header integrated with the right topbar notch.
2. A single-row icon toggle rail with eight stable buttons:
   - Wi-Fi
   - Bluetooth
   - Airplane Mode
   - Hotspot
   - Night Light
   - Focus Mode
   - Do Not Disturb
   - Filter
3. A single status strip that summarizes the hovered, focused, recently
   toggled, or most relevant state.
4. Compact section entries for Learn, Share, Style, Setup, Manage, and About.

Toggle buttons should be square or near-square icon controls. They can expose
active, hover, pressed, busy, unavailable, and warning states through fill,
stroke, accent, opacity, or a small marker. They should not use full labels in
the normal layout. The status strip is the required text fallback: when a
toggle is hovered or focused, it shows that toggle's label and state. Tooltips
are not part of the first implementation unless the existing imports already
support them with no extra framework churn.

The status strip should avoid noisy repetition. It should show concise state
such as `Wi-Fi: NetworkName`, `Bluetooth: DeviceName`, `Hotspot: No ethernet`,
`Focus: External`, `Filter: blue-light`, or `All quick controls idle`.

Status priority should be deterministic:

1. Hovered or keyboard-focused quick toggle.
2. Most recently clicked quick toggle for a short period.
3. Warning or externally-owned state, such as hotspot failure or external
   focus mode.
4. Active filter, connected Wi-Fi, or connected Bluetooth.
5. Quiet default text.

Airplane Mode is a special case. When it is active, the status strip should
make that obvious and Wi-Fi/Bluetooth toggle state should not imply normal
connectivity.

### Deeper Menus

The existing route structure remains:

- Learn
- Share
- Style
- Setup
- Manage
- About
- Existing setup/manage subpages

Those pages should stop reading as large card grids. They should use compact
topbar-style rows or slim two-column chips with small icons, quiet text, and
restrained accent rails. The shape should remain playful but dense: rounded
6-8px controls, small icon cells, subtle active fills, and no oversized
decorative cards.

Long pages must scroll inside the popup instead of forcing the whole popup to
grow. This is important for Manage and setup subpages with many actions. The
outer topbar-attached shape stays stable; only the route content scrolls.

The Manage page may keep tab-like controls for Install, Remove, and Maintain,
but the tabs should use the same compact segmented control language as the
topbar rather than large card buttons.

### Attachment And Motion

The popup remains anchored to the top-right edge and uses `PopupShape` with
`attachedEdge: "top"`. The background should match the topbar more closely:

- Same `Theme.background` base color as the topbar. The main card should not
  use the current translucent drawer treatment as its default background.
- Subtle active stroke only where it helps the surface read as connected.
- No detached translucent drawer effect.
- Opening height should start at `Theme.notchHeight` and expand downward.

The menu should stay substantially smaller than the current full-size home
view. Route pages can be taller when needed, but the default quickmenu should
open as a compact topbar extension.

Target dimensions:

- Body width: 344px, plus the existing top flare width on both sides.
- Home body height: 276px below the topbar notch.
- Detail body height: 440px below the topbar notch, capped downward by the
  screen height and `Theme.popupMaxHeight` on smaller screens.
- Button rail: eight 34px icon buttons with tight spacing.
- Detail rows/chips: 38px high by default.

The implementation should replace the single fixed 520px body height with a
page-aware target height. The home view should not pay for the tallest Manage
subpage; long route pages should use a `Flickable`.

## Architecture

The main implementation target is:

`config/quickshell/ryoku/vendor/brain-shell/src/popups/SettingsMenuPopup.qml`

The existing state and process logic should remain in this file initially. The
visual delegate layer should be reorganized around smaller reusable local
components:

- `QuickToggleButton` for icon-first toggles.
- `StatusStrip` or an equivalent inline item for compact state text.
- `MenuEntryRow` or a slim tile delegate for section and action routes.
- A compact segmented control for Manage tabs.

If the local components make the file too difficult to work in, they can move
to `src/components/` in a follow-up. For this pass, keeping the change scoped
to `SettingsMenuPopup.qml` is preferred.

Icon data should be explicit. The current model uses semantic icon names such
as `wifi`, `bluetooth`, and `filter`; the implementation should add either a
small glyph role to the models or local mapping functions such as
`quickIconGlyph(icon)` and `actionIconGlyph(icon)`. Missing mappings should
fall back to a neutral dot or short initial, not blank space.

No new shell IPC is required. The existing functions stay as the behavior
surface:

- `quickActive(action)`
- `runQuickAction(action)`
- `pollQuickControls()`
- `wifiStatusText()`
- `bluetoothStatusText()`
- existing route and action functions

## Data Flow

The quick toggle data continues to come from `quickControlsModel`. Keep the
stable labels and actions so tests and accessibility text remain meaningful.
Use local glyph/status mapping functions by default; add compact model roles
only if that makes the QML simpler without duplicating state.

The popup should track lightweight presentation state in QML:

- hovered or focused quick action
- last clicked quick action
- reset timer for the last-clicked status text

That state is visual only. It must not replace the existing process-backed
state for Wi-Fi, Bluetooth, hotspot, airplane mode, night light, focus mode,
DND, or filters.

Opening the settings menu continues to:

1. Apply `Popups.settingsMenuRequestedPage` and
   `Popups.settingsMenuRequestedSubpage`.
2. Set `windowVisible`.
3. Poll quick controls.
4. Poll rollback availability.

Clicking a quick toggle continues to call `runQuickAction(action)`. Page and
subpage actions continue through `runAction(action)`.

## Error Handling

- Existing command failures should not wedge the popup open or leave busy state
  stuck.
- Hotspot failures continue to surface as short status text such as `Failed` or
  `No ethernet`.
- Externally-owned states, such as externally-owned hotspot or focus mode, stay
  visible in the compact status strip.
- Icon-only controls must never become ambiguous in failure states. If a toggle
  is busy, blocked, externally-owned, or failed, the status strip must expose
  that state.
- Missing optional commands should fail quietly in the same way current actions
  do, unless the current implementation already exposes a status label.

## Testing

Update `tests/quickshell-topbar-settings-menus.sh` to reflect the new design:

- Assert `SettingsMenuPopup` keeps topbar attachment through
  `attachedEdge: "top"` and right anchoring.
- Assert the default home view is compact, with new menu dimensions.
- Assert quick controls still define all eight labels and actions.
- Assert quick toggles bind `active` state and call `runQuickAction(action)`.
- Assert quick toggles use icon-first compact delegates rather than the old
  62px labeled tile grid.
- Assert the main popup background uses `Theme.background` directly rather than
  the old translucent drawer background.
- Assert the status strip exists and is driven by quick-control status helpers.
- Assert detail pages use a `Flickable` clipped scrolling region.
- Assert section/action pages use compact route delegates and do not rely on
  oversized card-grid dimensions.
- Preserve existing checks for route functions, command routing, state polling,
  and keybindings.

Manual verification:

- Restart Quickshell.
- Open `Super+Alt+Space`.
- Confirm the surface visually grows from the right topbar notch.
- Toggle Wi-Fi, Bluetooth, Airplane Mode, DND, Night Light, Focus Mode, Hotspot,
  and Filter where hardware/tools are available.
- Open Learn, Share, Style, Setup, Manage, and About.
- Confirm deeper menus keep the same compact, cutesy, topbar-extension style.
- Confirm Escape and outside click dismiss the popup.

## Open Risks

- `SettingsMenuPopup.qml` is already large. Keeping all behavior and visual
  delegates in one file may remain cumbersome, but extracting components during
  the same pass would increase scope.
- Quickshell tooltip support may not be worth introducing for this pass. If it
  is awkward, the status strip can carry the accessible text instead.
- Some quick states depend on hardware or services that may not be present on
  every system, so static tests should verify wiring while manual testing
  verifies available runtime paths.
