# Ryoku Shell UI Patterns

Ryoku shell UI should use the shared component and token layer. A page may choose layout, copy, and control state, but shared color, sizing, spacing, typography, radius, and animation decisions should come from `import Ryoku.Config`.

## Current Workstation Paths

Use these paths when verifying shell behavior on this workstation:

```bash
DEV="$HOME/prowl/ryoku-arch"
INSTALL="$HOME/.local/share/ryoku"
SHELL_PATH="$HOME/.local/share/ryoku-shell"
RUNTIME="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/ryoku-shell"
```

Use the development tree for source edits. Use the installed tree only when the user explicitly asks for live mirror parity, and then patch only the scoped files that are part of the request.

## Runtime Verification

Check the active shell before assuming a source edit is visible:

```bash
env -u QS_CONFIG_NAME -u QS_CONFIG_PATH -u QS_MANIFEST qs list --all
systemctl --user status ryoku-shell.service --no-pager
```

For shell-only preview:

```bash
DEV="${RYOKU_DEV_PATH:-$HOME/prowl/ryoku-arch}"
RUNTIME="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/ryoku-shell"
RYOKU_DEV_PATH="$DEV" "$DEV/shell/setup" install -y -q --skip-deps --skip-setups --skip-sysupdate --skip-build
systemctl --user restart ryoku-shell.service
```

Run `ryoku-doctor shell` when shell startup, service state, runtime paths, or compositor integration are part of the change.

## Shared Components

Prefer existing components before creating new local controls:

- `shell/components/StyledRect.qml`
- `shell/components/StyledText.qml`
- `shell/components/MaterialIcon.qml`
- `shell/components/SectionContainer.qml`
- `shell/components/SectionHeader.qml`
- `shell/components/PropertyRow.qml`
- `shell/components/containers/StyledWindow.qml`
- `shell/components/containers/StyledFlickable.qml`
- `shell/components/containers/StyledListView.qml`
- `shell/components/controls/IconButton.qml`
- `shell/components/controls/IconTextButton.qml`
- `shell/components/controls/TextButton.qml`
- `shell/components/controls/ToggleButton.qml`
- `shell/components/controls/StyledSwitch.qml`
- `shell/components/controls/SwitchRow.qml`
- `shell/components/controls/StyledSlider.qml`
- `shell/components/controls/Menu.qml`
- `shell/components/controls/MenuItem.qml`
- `shell/components/controls/Tooltip.qml`

Use `IconButton` for icon-only commands, `IconTextButton` for labeled actions, `TextButton` for text-only actions, `StyledSwitch` or `SwitchRow` for binary settings, and `StyledSlider` for continuous values. Do not build local button or switch styling when a shared control already fits.

## Tokens

Import the config layer for shell-wide values:

```qml
import Ryoku.Config
```

Use token groups instead of literal one-off dimensions:

- `Tokens.padding.*`
- `Tokens.spacing.*`
- `Tokens.rounding.*`
- `Tokens.font.size.*`
- `Tokens.anim.*`
- `Tokens.colors.*`

When a global value needs to become user-configurable, add it to the typed config layer under `shell/plugin/src/Ryoku/Config/`, expose it through `GlobalConfig`, and make consumers read the shared value. Settings pages should call `GlobalConfig.saveConfig()` after mutating persistent settings.

## Layout

Keep operational surfaces dense and predictable:

- Use stable width, height, or `implicit*` sizing for repeated controls.
- Use shared spacing tokens between rows and sections.
- Keep cards for repeated items, menus, modals, and framed tools.
- Avoid nested cards.
- Keep text inside controls short enough to fit at narrow widths.
- Do not use viewport-scaled font sizes.

## Modules

Current shell surfaces live in these areas:

- `shell/modules/bar/`
- `shell/modules/bar/popouts/`
- `shell/modules/controlcenter/`
- `shell/modules/dashboard/`
- `shell/modules/launcher/`
- `shell/modules/sidebar/`
- `shell/modules/utilities/`

If a change affects a shared service or global behavior, trace the flow from config or IPC into every consumer instead of patching one visible page.

## Popout animations

Every popup that emerges from the screen frame (the bar's inner edge, a frame border, or a top-notch tab) must animate as the frame expanding: pin the frame-side edge, grow only the size, clip and reveal full-size content, and fuse to the frame with a `PanelBg` blob neck. Never slide a full panel in from off-screen, fade with `opacity`, or center-zoom the whole panel. Plugin and bar/frame additions follow the same contract through `FramePanelWrapper`. See `docs/popup-animations.md`.

## System Boundaries

QML should not own system mutations directly. For package, service, display, compositor, power, network, update, rollback, cursor, font, wallpaper, or hardware work, use a named `ryoku-*` command and call it through a narrow service or IPC boundary.

For compositor state, use `shell/services/Hypr.qml` or an existing Ryoku command. Do not add ad hoc `hyprctl` calls to UI components.

## Documentation Checks

Merge-ready documentation should describe the current Hyprland/Ryoku-shell workstation only. Historical planning notes that describe retired shell or compositor stacks should be removed or rewritten before merging.
