# Top Right Control Center

**Status:** Ready for user review
**Date:** 2026-04-30
**Scope:** Redesign the `SUPER+ALT+SPACE` top-right Quickshell popup into a native Ryoku control center that replaces the old `ryoku-menu` navigation without duplicating existing shell surfaces.

## Goal

The top-right pill should open a polished Ryoku-native control center, not a tiny shortcut grid and not the old tofi menu. It should keep the current topbar eye candy: notch-attached geometry, dark translucent surfaces, compact motion, active state accents, and dense but readable controls.

The control center should replace the old user-facing `ryoku-menu` navigation. Legacy menu commands may stay as compatibility/fallback paths, but the primary `SUPER+ALT+SPACE` experience and the related old submenu bindings should route to native QML pages inside the top-right popup.

## Current State

`SUPER+ALT+SPACE` and related bindings currently call `ryoku-ipc shell toggle settings-menu`, which opens `SettingsMenuPopup.qml`.

The active settings popup contains only:

- Audio
- Wi-Fi
- Bluetooth
- Activity
- Dotfiles

The old menu code still exists in `bin/ryoku-menu` and in the installed share copy. Its old top-level sections are:

- Apps
- Learn
- Trigger
- Style
- Setup
- Install
- Remove
- Update
- About
- System

Several old submenus are still reachable through direct bindings, such as `ryoku-menu toggle`, `ryoku-menu hardware`, `ryoku-menu share`, and `ryoku-menu-keybindings`. The old bare main menu is no longer the `SUPER+ALT+SPACE` user experience.

## Existing Ownership

The redesign must avoid duplicating active surfaces that already have a clear owner.

### Toolbox

The center-pill toolbox owns capture and utility actions:

- Screenshot
- Screen Recorder
- Color Picker
- OCR
- QR Code
- Google Lens
- Mirror
- Caffeine
- Open Screenshots
- Open Recordings

The top-right control center must not add these actions.

### Dashboard

The dashboard owns personal, media, and telemetry content:

- Volume wave control
- Brightness wave control
- Profile
- Calendar
- Clock
- Player
- Telemetry rail
- Power Saver
- Advanced activity / btop

The top-right control center must not add volume or brightness sliders. Power Saver stays in the telemetry rail for this pass. Activity/btop should not be duplicated on the control center home.

### App Launcher

The dedicated app launcher owns the old Apps entry:

- `SUPER+SPACE` opens `AppLauncherPopup.qml`
- `toggleLauncher()` is already exposed through Quickshell IPC

The top-right control center must not add an Apps page or a launcher tile. The old menu's Apps path is considered mapped to the active app launcher.

### System Menu

The left system menu owns session and power actions:

- Screensaver
- Update
- Snapshot
- Lock
- Suspend
- Hibernate
- Log Out
- Restart
- Shutdown

The top-right control center must not duplicate lock, suspend, hibernate, logout, restart, or shutdown.

The system menu's `Update` action remains the quick one-shot update entry point. Detailed update and maintenance workflows belong under `Manage -> Maintain` in the control center, so the two surfaces do not expose the same action at the same depth.

### Dormant Vendored Popups

`AudioPopup`, `NetworkPopup`, and `QuickControl` exist but are dormant in `PopupLayer.qml`. This project should not depend on reviving those dormant popups unless that becomes a separately approved follow-up.

`QuickSettings.qml` has useful existing logic for Wi-Fi, Bluetooth, Airplane Mode, Hotspot, Night Light, Focus Mode, Do Not Disturb, and Filter. The implementation may reuse or extract this logic, but should not blindly copy brightness, Caffeine, or Screen Capture into the top-right control center because those are owned elsewhere.

## User Experience

`SUPER+ALT+SPACE` opens a larger top-right control center attached to the right topbar pill.

The popup should feel like a shell control surface, not a generic card dashboard:

- compact section rhythm
- accent rails and active-state indicators
- small, readable labels
- stable tile dimensions
- restrained hover and press states
- smooth open, close, and page transitions
- no decorative blobs, oversized marketing hero areas, or generic AI-style card clutter

Escape closes the popup. Clicking outside closes it. A page back control returns from a section page to the home view.

Related old submenu bindings should open the matching native destination instead of launching `ryoku-menu`:

- `SUPER+CTRL+O` opens the control center home view for quick toggles.
- `SUPER+CTRL+H` opens `Setup -> Hardware`.
- `SUPER+CTRL+S` opens the Share page.

`SUPER+SPACE` continues to open the app launcher. `SUPER+ESCAPE` continues to open the left system menu.

## Home View

The home view has two areas.

### Quick Controls

Include these controls because they are not better owned by the active dashboard, toolbox, telemetry rail, or system menu:

- Wi-Fi
- Bluetooth
- Airplane Mode
- Hotspot
- Night Light
- Focus Mode
- Do Not Disturb
- Filter

These controls should show active state and useful compact status where available, such as Wi-Fi SSID, connected Bluetooth device, hotspot status, or selected filter.

### Native Sections

Show these navigation sections:

- Learn
- Share
- Style
- Setup
- Manage
- About

`Manage` groups the old Install, Remove, and maintenance/update areas so the first screen stays clean.

Do not show a top-level System section in this popup. System actions stay in the left system menu.

Do not show the old Trigger section as a single page. Split it into better native destinations:

- old Toggle actions map to quick controls on the home view where they are in scope
- old Share actions map to the Share page
- old Hardware actions map to the Setup page

Do not show the old Apps section. Apps are already handled by the native launcher on `SUPER+SPACE`.

## Native Pages

Each section opens as a native QML page inside the same popup. The implementation should not open `ryoku-menu <section>` for section navigation.

Leaf actions may still call existing command-line helpers, tofi pickers, or terminal launchers where the actual workflow is command-backed.

### Learn Page

Include:

- Keybindings
- Omarchy Manual (upstream)
- Hyprland
- Arch
- Helix
- Bash

Leaf actions:

- Keybindings runs `ryoku-menu-keybindings`.
- Web documentation actions run `ryoku-launch-webapp` with the existing URLs from `ryoku-menu`.

### Share Page

Include:

- Clipboard
- File
- Folder

Leaf actions:

- Clipboard runs `ryoku-cmd-share clipboard`.
- File launches the existing file-share flow through `ryoku-cmd-share file`.
- Folder launches the existing folder-share flow through `ryoku-cmd-share folder`.

### Style Page

Include:

- Theme
- Font
- Background
- Hyprland look and feel
- Screensaver text
- About text

Leaf actions should reuse existing workflows:

- Theme opens the native appearance popup in theme mode.
- Font opens the native appearance popup in font mode.
- Background opens the native appearance popup in wallpaper mode.
- Hyprland look and feel opens `~/.config/hypr/looknfeel.conf`.
- Screensaver text opens `$RYOKU_CONFIG_PATH/branding/screensaver.txt`.
- About text opens `$RYOKU_CONFIG_PATH/branding/about.txt`.

### Setup Page

Include:

- Audio
- Wi-Fi
- Bluetooth
- Power Profile
- System Sleep
- Monitors
- Keybindings when `~/.config/hypr/bindings.conf` exists
- Input when `~/.config/hypr/input.conf` exists
- DNS
- Security
- Config
- Hardware

The Audio, Wi-Fi, and Bluetooth entries here are detailed setup launchers. They should call the existing external control helpers and should not duplicate the home quick toggle state tiles.

`System Sleep` is a setup workflow for sleep-related configuration. It is not an immediate suspend or hibernate command.

Security opens a child page with:

- Fingerprint
- Fido2

Config opens a child page with:

- Dotfiles Hub
- Defaults
- Hyprland
- Hypridle
- Hyprlock
- Hyprsunset
- Swayosd
- Launcher
- Waybar
- XCompose

Hardware opens a child page with:

- Laptop Display
- Hybrid GPU when `ryoku-hw-hybrid-gpu` succeeds
- Touchpad when `ryoku-hw-touchpad` succeeds

### Manage Page

Use a segmented control or compact tabs for:

- Install
- Remove
- Maintain

Install includes:

- Package
- AUR
- Web App
- TUI
- Service
- Style
- Development
- Editor
- Terminal
- AI
- Windows
- Gaming

Remove includes:

- Package
- Web App
- TUI
- Development
- Preinstalls
- Dictation
- Theme
- Windows
- Fingerprint
- Fido2

Maintain includes the old Update options:

- Ryoku
- Channel
- Config
- Extra Themes
- Process
- Hardware
- Firmware
- Password
- Timezone
- Time
- Rollback to Omarchy only when `$HOME/.local/state/ryoku/migration-state.txt` exists

Nested Manage pages should preserve the existing old menu options from `ryoku-menu` while presenting them in native QML.

### About Page

Include:

- Launch About
- Open about text

`Launch About` runs `ryoku-launch-about`.

`Open about text` opens `$RYOKU_CONFIG_PATH/branding/about.txt`.

## Command Model

Use native QML state for page navigation and quick control toggles.

Use existing helpers for leaf actions. The control center should close after launching external, modal, terminal, or editor workflows unless the action is an inline quick toggle.

Examples:

- `ryoku-launch-audio`
- `ryoku-launch-wifi`
- `ryoku-launch-bluetooth`
- `ryoku-launch-editor`
- `ryoku-launch-webapp`
- `ryoku-launch-floating-terminal-with-presentation`
- `ryoku-pkg-*` workflows through existing wrappers
- `ryoku-install-*`, `ryoku-remove-*`, `ryoku-update-*`, `ryoku-refresh-*`

The implementation should avoid shell-string construction in QML where a structured command array is enough.

## Architecture

The likely implementation target is `SettingsMenuPopup.qml`, expanded from a small shortcut popup into a multi-page control center.

Implementation may either:

- keep the full control center in `SettingsMenuPopup.qml` if the file remains manageable, or
- split reusable pieces into local QML components beside the popup, such as `ControlCenterTile.qml`, `ControlCenterPage.qml`, or `ControlCenterSection.qml`.

Split components if they reduce real complexity. Do not create abstractions just to make the file look architectural.

The popup should continue to:

- attach to the top-right topbar notch
- expose `settingsMenuVisible`
- use `Popups.settingsMenuOpen`
- support a requested page/subpage so bindings and IPC can open direct native destinations
- close through `Popups.closeAll()`
- stay mapped through close animation
- avoid interfering with `PopupDismiss`

The geometry should grow from the current compact popup into a larger but still topbar-attached control surface. It should remain smaller than the dashboard and should not become a fullscreen app.

## Live And Dev Copies

During implementation, changes must land in the dev repo first. After verification, the changed QML and any helper files must also be applied to:

- `/home/omi/.local/share/ryoku`
- `/home/omi/.config/quickshell/ryoku`

Quickshell must be restarted after the live config is updated.

## Tests And Verification

Add or update static regression coverage so the intended ownership boundaries stay clear:

- `SUPER+ALT+SPACE` still toggles `settings-menu`.
- `SUPER+CTRL+O`, `SUPER+CTRL+H`, and `SUPER+CTRL+S` no longer call `ryoku-menu toggle`, `ryoku-menu hardware`, or `ryoku-menu share`.
- `ryoku-ipc` exposes direct control-center page commands for home quick controls, Share, and Setup/Hardware.
- `SUPER+SPACE` still opens the app launcher and the control center does not expose an Apps page.
- `SettingsMenuPopup` exposes quick controls for Wi-Fi, Bluetooth, Airplane Mode, Hotspot, Night Light, Focus Mode, Do Not Disturb, and Filter.
- `SettingsMenuPopup` exposes native sections Learn, Share, Style, Setup, Manage, and About.
- `SettingsMenuPopup` preserves Dotfiles access through Setup/Config.
- `SettingsMenuPopup` does not expose toolbox-owned actions such as Screenshot, OCR, QR, Google Lens, Mirror, Caffeine, Open Screenshots, or Open Recordings.
- `SettingsMenuPopup` does not expose dashboard-owned volume or brightness sliders.
- `SettingsMenuPopup` does not expose system-owned lock, suspend, hibernate, logout, restart, or shutdown controls.
- Leaf actions call the existing Ryoku helpers, not legacy Omarchy command names.
- Live and installed-share copies match the verified dev QML after deployment.

Manual verification:

1. Press `SUPER+ALT+SPACE`.
2. Confirm the control center opens from the top-right pill.
3. Toggle each quick control that is safe to exercise on the current machine.
4. Open each native section and return with Back.
5. Launch at least one Learn web action and one editor/terminal leaf action.
6. Confirm dashboard, toolbox, telemetry rail, and system menu still own their existing features.

## Out Of Scope

This pass does not move Power Saver out of the telemetry rail.

This pass does not move volume or brightness out of the dashboard.

This pass does not move Caffeine or capture tools out of the toolbox.

This pass does not move lock, suspend, hibernate, logout, restart, or shutdown out of the system menu.

This pass does not move the app launcher out of `SUPER+SPACE`.

This pass does not revive dormant `AudioPopup`, `NetworkPopup`, or `QuickControl`.

This pass does not remove `bin/ryoku-menu`; it remains a compatibility and fallback surface until a later cleanup.
