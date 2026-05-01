# Noctalia Settings Ryoku Integration Design

## Context

Ryoku currently binds `Super+Alt+Space` and `ryoku-ipc shell toggle settings-menu`
to the Brain Shell `SettingsMenuPopup.qml`. That menu is useful as a compact
topbar-attached quickmenu, but it is not the desired long-term settings
experience.

The target is Noctalia's centered settings panel from
`https://github.com/noctalia-dev/noctalia-shell`, using its visual and layout
code as the source of truth. The upstream source inspected for this design is
commit `9f8dd48c8df5ab1f7f87ddf9842627e1e5682186`.

The new work should preserve Noctalia's frontend instead of redesigning it:
centered settings window, left sidebar, search, tab ordering, content pane,
Noctalia widgets, indicators, scroll behavior, and the same disabled-control
language. Ryoku-specific work belongs behind that frontend as backend adapters,
command routing, feature availability, settings persistence, and IPC rollout.

## Goals

- Make `Super+Alt+Space` open a centered Noctalia-style settings panel.
- Preserve Noctalia's settings visual/layout QML as closely as practical.
- Keep every Noctalia sidebar tab visible.
- Disable and grey out features that Ryoku cannot safely back yet, instead of
  removing them.
- Port simple and practical system settings in the first implementation,
  especially Wi-Fi and Bluetooth.
- Replace old TUI-first Wi-Fi/Bluetooth flows with in-panel graphical settings.
- Keep the existing Brain Shell settings menu in the tree as a fallback until
  removal is explicitly approved.
- Preserve Ryoku command naming, IPC routes, theme paths, wallpaper paths, and
  user configuration ownership.
- Add Noctalia attribution and document the upstream commit and local changes.

## Non-Goals

- Do not redesign the settings UI/UX.
- Do not remove Noctalia tabs because their backend is not ready.
- Do not delete the existing Brain Shell `SettingsMenuPopup.qml` in this pass.
- Do not make Noctalia own Ryoku's full shell, bar, dock, widgets, telemetry, or
  update system.
- Do not write to Noctalia-owned user paths such as `~/.config/noctalia` unless
  the path is explicitly redirected into a Ryoku-owned namespace.
- Do not replace Ryoku public commands with Noctalia command names.

## Architecture

Vendor Noctalia's settings frontend under:

`config/quickshell/ryoku/vendor/noctalia-shell/upstream/`

This tree should carry Noctalia code and assets needed for the settings panel,
including:

- `Modules/Panels/Settings/`
- `Widgets/`
- `Commons/`
- `Assets/settings-default.json`
- `Assets/settings-search-index.json`
- `Assets/settings-widgets-default.json`
- `Assets/Translations/`
- required icons, helper JavaScript, and settings-supporting services

Ryoku-specific integration should live under:

`config/quickshell/ryoku/vendor/noctalia-shell/ryoku/`

That adapter layer owns:

- Ryoku settings persistence and defaults.
- Ryoku command bridge helpers.
- Feature availability and disabled-control state.
- Import wrappers needed to run the settings panel in Ryoku's Quickshell
  process.
- Service adapters for system-backed features.

Runtime QML should not import the upstream tree directly if Noctalia's
`qs.*` imports would resolve to the Ryoku shell root. The implementation should
create adapted runtime copies under:

`config/quickshell/ryoku/Noctalia/`

Those runtime copies should mechanically rewrite Noctalia imports from `qs.*`
to `qs.Noctalia.*`, redirect asset paths to the vendored Noctalia assets, and
replace backend service imports with Ryoku adapters. The byte-for-byte upstream
tree remains under `vendor/noctalia-shell/upstream/` for attribution and drift
review. Runtime copies may differ only for imports, paths, backend wiring,
feature availability guards, and documented disabled-state handling.

The Ryoku shell should instantiate only the settings window and the settings
services it needs. It must not run Noctalia's full `ShellRoot` bootstrap,
desktop widgets, bar, dock, telemetry, updater, plugin loader, or setup wizard.
Services copied for type compatibility should stay inert unless the settings
panel explicitly needs them.

The old Brain Shell menu remains at:

`config/quickshell/ryoku/vendor/brain-shell/src/popups/SettingsMenuPopup.qml`

It should stay functional as a fallback route while the new settings panel is
validated.

The default user-facing route changes in `config/quickshell/ryoku/shell.qml`.
The existing `toggleSettingsMenu()` IPC handler should open the new centered
Noctalia-style panel. A new fallback route should open the existing Brain Shell
settings menu.

## Panel Behavior

The centered panel should use Noctalia's `SettingsPanelWindow.qml` behavior as
the visual target:

- Floating centered window.
- Transparent outer window and rounded settings surface.
- Approximate Noctalia dimensions: `840 * Style.uiScaleRatio` by
  `910 * Style.uiScaleRatio`.
- The panel must not render offscreen on smaller laptop displays. Keep
  Noctalia's proportions and internal scrolling, but cap the window to the
  active screen's available geometry with margins.
- Left sidebar with Noctalia tab model, icons, search, collapsed behavior, and
  selection styling.
- Right content pane with Noctalia header, close button, scroll area, subtabs,
  and search-result highlighting.
- Noctalia widgets for toggles, combo boxes, sliders, buttons, tab bars, labels,
  indicators, boxes, and scroll views.

Ryoku should not restyle these controls. Any visual changes must be limited to
what is required to load in Ryoku, to respect Ryoku-owned colors where the
Noctalia frontend expects live color data, or to represent disabled features
through Noctalia's existing disabled-state language.

## Backend Mapping

The first implementation should wire practical system-backed pages, not ship a
hollow visual shell.

### Connections

Wi-Fi and Bluetooth are supported in v1.

The Wi-Fi page should use Noctalia's `WifiSubTab.qml` and service model, adapted
to Ryoku. It should support:

- Wi-Fi radio on/off.
- Scan and refresh.
- Connected, saved, and available network lists.
- Password entry.
- Hidden network entry.
- Connect to saved and new networks.
- Disconnect.
- Forget saved networks.
- Signal and connection detail display.

The adapter may use Noctalia's existing approach based on Quickshell Networking
and command-backed providers, but it must not require NetworkManager as the only
Wi-Fi backend. Ryoku's base package/config footprint includes `iwd` and
`impala`, and does not currently list NetworkManager as a required package. The
first implementation should therefore use a provider adapter:

- Prefer an `iwd`/`iwctl` provider when `iwd` is the active Ryoku network stack.
- Use a NetworkManager/`nmcli` provider when NetworkManager is present.
- Use Quickshell Networking only when it works with the active provider.
- Disable only the unavailable provider-specific actions, not the whole Wi-Fi
  tab, unless no supported backend is available.

The Noctalia Wi-Fi UI remains the target. Only service internals and command
routing should change.

The Bluetooth page should use Noctalia's `BluetoothSubTab.qml` and service
model, adapted to Ryoku. It should support:

- Adapter power on/off.
- Scanning.
- Discoverability.
- Connected, paired, and available device lists.
- Pair.
- Connect.
- Disconnect.
- Remove/unpair.
- Auto-connect and hide-unnamed settings where practical.

The adapter may use Noctalia's existing approach based on Quickshell Bluetooth
and `bluetoothctl`, adjusted for Ryoku. Ryoku already uses `bluetoothctl` in
current quick settings, so this is a first-pass supported backend.

Existing TUI launchers such as `ryoku-launch-wifi` and
`ryoku-launch-bluetooth` become fallback/debug actions, not the primary
settings UX. Existing direct keybindings for those launchers should be rerouted
to the new settings panel's Wi-Fi and Bluetooth subtabs where practical, with
separate fallback commands retained for manual debugging.

Wi-Fi password and enterprise credential handling should avoid exposing secrets
through logs or process lists. Prefer provider APIs, temporary stdin, or
backend-supported secret prompts over building shell command strings that place
passwords directly in `ps` output. Static tests should reject obvious password
string interpolation into command arrays or shell snippets.

### Color Scheme And Wallpaper

Keep Noctalia's Color Scheme and Wallpaper tabs visible and preserve their
layout. Supported actions should route through Ryoku's theme and wallpaper
pipeline:

- `ryoku-theme-list`
- `ryoku-theme-current`
- `ryoku-theme-set`
- `ryoku-theme-bg-set`
- `ryoku-wallpaper-list`
- `ryoku-wallpaper-cache`
- `ryoku-wallpaper-apply`
- `ryoku-ipc theme ...`
- `ryoku-ipc wallpaper ...`

Ryoku's existing theme structure remains the source of truth:

- `themes/*/colors.toml`
- `themes/*/backgrounds/`
- `default/themed/*.tpl`
- `~/.config/ryoku/current/theme/`

Noctalia controls that imply Noctalia-owned template paths, Matugen behavior,
or unsupported dynamic color generation should be disabled until a Ryoku-safe
backend exists. They should remain visible.

### Display, Audio, Session, And Power

Display and night-light basics should be backed where Ryoku already has
commands or config:

- Hyprland display/config paths where applicable.
- Hyprsunset or existing Ryoku night-light toggles.
- Existing Ryoku refresh/restart commands where settings change config files.

Audio should use Noctalia's settings layout where practical and back controls
with available PipeWire/WirePlumber or existing Ryoku audio commands. If detailed
device control is not safe in the first pass, those controls remain visible and
disabled.

Session, power, and lock actions should route through Ryoku's existing commands
and system actions.

### General And User Interface

Noctalia's General and User Interface pages should write to Ryoku-owned settings
storage. Settings that affect only Noctalia's full shell behavior should remain
visible but disabled when they do not apply to Ryoku.

Ryoku-specific settings storage should not be `~/.config/noctalia`. Use these
Ryoku-owned paths:

- settings file: `${RYOKU_CONFIG_PATH:-$HOME/.config/ryoku}/quickshell/settings.json`
- cache directory: `${RYOKU_STATE_PATH:-$HOME/.local/state/ryoku}/quickshell/noctalia-settings/`

The settings adapter should create these directories on startup, mirroring
Noctalia's delayed load behavior but changing only the target paths.

### Disabled But Visible

These areas are expected to be visible but mostly disabled unless a specific
Ryoku backend is added during implementation:

- Dock.
- Desktop widgets.
- Plugins.
- Noctalia telemetry.
- Noctalia update/supporter/GitHub services.
- Noctalia-only bar behavior that conflicts with Ryoku's current topbar.
- Any control that would write to Noctalia-owned paths or start Noctalia-owned
  services.

Disabled controls should use Noctalia's standard disabled appearance: reduced
opacity, disabled inputs, and concise availability/status text when helpful.

## IPC And Rollout

The new centered panel becomes the default settings target:

- `Super+Alt+Space`
- `Super+Ctrl+Alt+Space`
- `ryoku-ipc shell toggle settings-menu`
- `ryoku-ipc shell command settings-menu`

The old Brain Shell settings menu remains reachable through a fallback route:

- `ryoku-ipc shell toggle legacy-settings-menu`
- `ryoku-ipc shell command legacy-settings-menu`

Settings routes should be expanded and aliased to the closest Noctalia tabs:

- `ryoku-ipc shell settings-menu home` -> General tab.
- `ryoku-ipc shell settings-menu connections` -> Connections tab.
- `ryoku-ipc shell settings-menu wifi` -> Connections tab, Wi-Fi subtab.
- `ryoku-ipc shell settings-menu bluetooth` -> Connections tab, Bluetooth subtab.
- `ryoku-ipc shell settings-menu color-scheme` -> Color Scheme tab.
- `ryoku-ipc shell settings-menu wallpaper` -> Wallpaper tab.
- `ryoku-ipc shell settings-menu display` -> Display tab.
- `ryoku-ipc shell settings-menu audio` -> Audio tab.
- `ryoku-ipc shell settings-menu power` -> Session Menu tab.
- `ryoku-ipc shell settings-menu hardware` -> legacy hardware route in v1,
  until a Noctalia-styled Ryoku hardware page exists.

Existing routes such as `home`, `share`, and `hardware` should remain accepted
where current tests or bindings expect them. They should route into the new
settings panel or a deliberate fallback instead of silently going somewhere
unrelated. The `share` route should continue opening the legacy share page in
v1, because Noctalia does not provide an equivalent settings page. The
`hardware` route should continue opening the legacy hardware page in v1 for the
same reason.

Existing direct bindings should be updated as follows:

- `Super+Ctrl+W` should open the new settings panel at Connections -> Wi-Fi.
- `Super+Ctrl+B` should open the new settings panel at Connections -> Bluetooth.
- Separate fallback/debug commands should remain available for
  `ryoku-launch-wifi` and `ryoku-launch-bluetooth`.

If the Noctalia settings runtime fails to instantiate, `toggleSettingsMenu()`
should fail visibly in logs and leave the fallback IPC route usable. A temporary
automatic fallback to the legacy settings menu is acceptable during rollout, but
it must not hide repeated runtime-load failures from tests or logs.

The new centered panel should not participate in topbar-attached popup layer
behavior. It is a centered settings window, not a topbar menu. The old fallback
menu can keep its current topbar-attached popup behavior.

## Feature Availability

Add a Ryoku feature availability layer that every adapted settings tab can query.
It should answer whether a setting is:

- supported and writable;
- supported but read-only;
- unavailable because a command or service is missing;
- unavailable because it belongs to unsupported Noctalia shell behavior.

The availability layer should prevent unsafe writes. A disabled Noctalia control
must not call its original backend action.

The first pass should mark Wi-Fi and Bluetooth as supported when their required
tools/services are available. It should not grey out those pages just because
Ryoku previously used TUI launchers.

Search should keep disabled settings discoverable. Selecting a disabled search
result should navigate to the owning tab/control and show its unavailable state;
it should not silently omit the entry unless the upstream control is truly
irrelevant to Ryoku and has no visible disabled row.

## Dependencies

Before implementation, audit Ryoku's package lists and service setup against the
settings backends:

- `install/ryoku-base.packages`
- `install/ryoku-aur.packages`
- `install/ryoku-other.packages`
- `install/config/hardware/network.sh`
- `install/config/hardware/bluetooth.sh`

Wi-Fi support must account for Ryoku's existing `iwd`/`impala` setup. Do not add
a NetworkManager dependency just to match Noctalia unless the implementation
plan explicitly justifies migrating the network stack and includes migration,
service conflict, and rollback handling.

Bluetooth support should verify that BlueZ and `bluetoothctl` are installed and
that `bluetooth.service` is enabled by Ryoku's install path. If a package is
missing from the lists, the implementation plan should add it explicitly or mark
the affected controls unavailable.

## Error Handling

- Missing `nmcli` disables only the NetworkManager provider. It must not disable
  Wi-Fi controls when the `iwd`/`iwctl` provider is available.
- Missing `iwctl` or inactive `iwd` disables only the iwd provider. It must not
  disable Wi-Fi controls when NetworkManager is available.
- The Wi-Fi tab becomes unavailable only when no supported provider and no
  compatible Quickshell Networking backend are available, or when no supported
  Wi-Fi hardware is detected.
- Failed Wi-Fi scan/connect/disconnect/forget actions keep the panel open and
  surface an error/status through the Noctalia UI.
- Missing Bluetooth adapter disables Bluetooth controls and keeps the tab
  visible.
- Missing `bluetoothctl` or Quickshell Bluetooth support disables pairing and
  device actions while preserving the tab.
- Failed Bluetooth pair/connect/disconnect/remove actions keep the panel open
  and surface an error/status.
- Theme and wallpaper failures must not update current state optimistically.
- Disabled Noctalia-only controls must not silently write to Noctalia paths.
- The old fallback settings menu must remain usable while the new panel is being
  validated.

## Testing

Add or update static regression tests for:

- Noctalia vendor files exist.
- Noctalia vendor metadata records upstream repo, commit
  `9f8dd48c8df5ab1f7f87ddf9842627e1e5682186`, license, and local adaptation
  notes.
- The settings panel uses Noctalia's centered `SettingsPanelWindow` and
  `SettingsContent` structure.
- All Noctalia sidebar tabs remain present.
- Unsupported tabs and controls are disabled or guarded, not removed.
- Wi-Fi and Bluetooth tabs are supported in v1 and contain scan/connect/pair
  controls.
- `Super+Alt+Space` and `ryoku-ipc shell toggle settings-menu` route to the new
  centered panel.
- The legacy settings menu remains reachable through fallback IPC.
- New settings-menu routes and legacy route aliases are documented and accepted.
- Noctalia-only services such as telemetry/update/supporter/plugin services do
  not run unless explicitly supported.
- Noctalia path writes are redirected to Ryoku-owned paths or blocked.
- Runtime Noctalia imports use the isolated `qs.Noctalia.*` namespace and do
  not require copying Noctalia directories into the Ryoku root namespace.
- The full Noctalia `ShellRoot` bootstrap is not imported or instantiated by
  Ryoku.
- `Super+Ctrl+W` and `Super+Ctrl+B` route to the new graphical Wi-Fi and
  Bluetooth settings subtabs, with TUI fallback commands still present.

Add backend-oriented tests where practical for:

- Wi-Fi provider selection for `iwd`/`iwctl` and NetworkManager/`nmcli`.
- Wi-Fi scan command construction for each supported command provider.
- Wi-Fi connect, disconnect, and forget command construction for each supported
  command provider.
- Wi-Fi password handling does not place secrets in command strings or logs.
- Bluetooth power, scan, pair, connect, disconnect, and remove command
  construction.
- Dependency and service detection for `iwd`, NetworkManager, BlueZ, and
  `bluetoothctl`.
- Feature availability decisions for missing commands/services.
- Theme and wallpaper command routing through Ryoku commands.
- Disabled feature actions being blocked.

Manual verification:

- Restart Quickshell.
- Open `Super+Alt+Space`.
- Confirm the panel appears centered and matches Noctalia's settings layout.
- Confirm the panel stays usable on the smallest supported laptop display and
  scrolls internally rather than clipping offscreen.
- Use the search field and navigate search results.
- Search for a disabled setting and confirm it remains discoverable but
  unavailable.
- Toggle Wi-Fi and connect/disconnect from the panel.
- Forget a saved Wi-Fi network from the panel.
- Pair, connect, disconnect, and remove a Bluetooth device from the panel.
- Exercise color scheme, wallpaper, display/night-light, audio, session, and
  power basics where backed.
- Confirm unsupported features remain visible but disabled.
- Open the legacy settings menu with fallback IPC.

## Documentation And Attribution

Implementation must add or update:

- `config/quickshell/ryoku/vendor/noctalia-shell/UPSTREAM.md`
- vendored Noctalia `LICENSE`
- `README.md` credits
- `CREDITS.md`
- `NOTICE` if new notices are required

The upstream attribution should include:

- repository: `https://github.com/noctalia-dev/noctalia-shell`
- license: MIT
- copyright: `Copyright (c) 2025 noctalia-dev`
- pinned commit: `9f8dd48c8df5ab1f7f87ddf9842627e1e5682186`

Any direct edits to copied upstream files should be documented in
`UPSTREAM.md`. Prefer Ryoku wrappers and adapters over broad edits inside the
upstream vendor tree.

## Open Risks

- Noctalia imports many services beyond the settings panel. The implementation
  may need compatibility stubs to keep the visual panel intact without running
  unrelated Noctalia shell features.
- Quickshell module names may conflict if copied Noctalia code expects the root
  `qs` import namespace. Wrappers may be needed to keep imports stable.
- Full Wi-Fi and Bluetooth behavior depends on local `iwd` or NetworkManager,
  BlueZ, Quickshell Networking, and Quickshell Bluetooth behavior.
- Noctalia's settings schema is broad. Ryoku should avoid adopting settings that
  do not map cleanly to Ryoku behavior.
- Static tests can verify routing and source structure, but visual fidelity will
  still require manual verification against the Noctalia layout.
