# Ryoku Niri/iNiR Integration Design

## Confirmed Live Baseline

The live machine has passed the Niri/iNiR gate on May 2, 2026:

- `XDG_CURRENT_DESKTOP=niri`
- `DESKTOP_SESSION=niri`
- `niri.service` is active with `/usr/bin/niri --session`
- `inir.service` is active with `/usr/bin/qs -n -p ~/.config/quickshell/inir`
- `inir status` reports shell running, Niri detected, no pending migrations, and clean runtime payload
- `./setup doctor` in `~/.local/share/inir` reports `Passed 24`, `Failed 0`
- `inir overview toggle`, `inir clipboard toggle`, and `inir settings` respond in the live session
- Old live Hyprland/Ryoku UI configs and packages were removed after confirmation
- Ryoku screensaver assets were preserved:
  - `~/.config/ryoku/branding/screensaver.txt`
  - `~/.config/ryoku/branding/about.txt`
  - `~/.local/share/ryoku/default/alacritty/screensaver.toml`
  - `~/.local/share/ryoku/default/ghostty/screensaver`

This means source work can now start. The live system no longer depends on
Hyprland as a fallback.

## Decision

Ryoku should wrap and curate iNiR first, instead of porting Ryoku's old
Hyprland/Brain Shell implementation directly to Niri.

Reasoning:

- iNiR is already running cleanly on the live system.
- iNiR owns the Niri service wiring, Quickshell runtime, lock surface, shell IPC,
  wallpaper/color generation, and SDDM theme.
- Ryoku's current source tree still assumes Hyprland across package lists,
  refresh/restart helpers, keybinds, tests, and Brain Shell UI.
- Wrapping iNiR keeps the transition small and reversible at the command layer,
  while giving Ryoku a stable Niri backend.

Ryoku should keep its identity, boot branding, command names, install flow, and
screensaver assets. The compositor shell backend should become iNiR/Niri.

## Live Cleanup Already Applied

These live-system changes are part of the confirmed baseline and should be
captured in source:

- SDDM autologin:
  - `Session=niri.desktop`
  - `Relogin=true`
  - theme `ii-pixel`
- Installed required iNiR packages not present in the first pass:
  - `darkly-bin`
  - `qt5-graphicaleffects`
  - `awww`
  - `uv`
  - `ttf-material-symbols-variable`
- Removed old Hyprland-era packages:
  - `hyprland`
  - `hypridle`
  - `hyprlock`
  - `hyprsunset`
  - `hyprland-preview-share-picker`
  - `waybar`
  - `mako`
  - `swayosd`
  - `walker`
  - `elephant`
- Preserved because iNiR or Niri still need them:
  - `niri`
  - `quickshell`
  - `xwayland-satellite`
  - `swayidle`
  - `hyprpicker`
  - `xdg-desktop-portal-gnome`
  - `xdg-desktop-portal-gtk`
- Removed old live user configs:
  - `~/.config/hypr`
  - `~/.config/waybar`
  - `~/.config/mako`
  - `~/.config/swayosd`
  - `~/.config/uwsm`
  - `~/.config/quickshell/ryoku`
  - `~/.config/ryoku/current`
- Preserved `~/.config/ryoku/branding`.

## Package List Changes

Replace the default Hyprland shell stack in `install/ryoku-base.packages` with
the Niri/iNiR runtime stack.

Remove from the default install:

- `hyprland`
- `hypridle`
- `hyprlock`
- `hyprsunset`
- `hyprland-preview-share-picker`
- `waybar`
- `mako`
- `swayosd`
- `walker`
- `elephant`

Keep or add:

- `niri`
- `quickshell`
- `xwayland-satellite`
- `xdg-desktop-portal`
- `xdg-desktop-portal-gtk`
- `xdg-desktop-portal-gnome`
- `swayidle`
- `wl-clipboard`
- `cliphist`
- `grim`
- `slurp`
- `swappy`
- `hyprpicker`
- `ydotool`
- `awww`
- `uv`
- `darkly-bin`
- `qt5-graphicaleffects`
- `ttf-material-symbols-variable`

AUR packaging needs an explicit path for `darkly-bin` unless Ryoku vendors an
equivalent build recipe.

## Config Layout

Add Niri/iNiR source defaults:

- `config/niri/`
- `config/quickshell/inir/` or an installer-managed iNiR runtime sync
- `config/systemd/user/inir.service`
- `config/sddm/ii-pixel/`

Stop installing default live configs for:

- `config/hypr/`
- `config/waybar/`
- `config/mako/`
- `config/swayosd/`
- `config/quickshell/ryoku/`

Ryoku source may keep these temporarily for migration compatibility, but the
default install path should not refresh or restart them.

## Command Mapping

Ryoku commands should remain `ryoku-*`. Backend commands should delegate to
iNiR/Niri where possible.

Initial command mapping:

- `ryoku-ipc overview toggle` -> `inir overview toggle`
- `ryoku-ipc clipboard toggle` -> `inir clipboard toggle`
- `ryoku-ipc settings open|toggle` -> `inir settings`
- `ryoku-lock-screen` -> `inir lock activate`
- `ryoku-system-logout` -> `inir session toggle` or direct Niri/session action
- `ryoku-cmd-colorpicker` -> `inir colorpicker`
- `ryoku-cmd-screenshot`/region tools -> `inir region screenshot`
- `ryoku-cmd-ocr` -> `inir region ocr`
- `ryoku-restart-ui` -> restart `inir.service`, not Mako/SwayOSD/Waybar/Hypridle
- `ryoku-restart-shell` -> restart `inir.service`
- `ryoku-refresh-sddm` -> install the iNiR SDDM theme and ensure
  `qt5-graphicaleffects` is present

Hyprland-specific commands should become compatibility bridges that print a
clear Niri migration message, unless there is a direct Niri/iNiR equivalent.

Examples:

- `ryoku-refresh-hyprland`
- `ryoku-refresh-hyprlock`
- `ryoku-refresh-hypridle`
- `ryoku-refresh-hyprsunset`
- `ryoku-restart-hyprctl`
- `ryoku-hyprland-monitor-*`

## SDDM

Ryoku should default SDDM to Niri:

```ini
[Autologin]
User=<install-user>
Session=niri.desktop
Relogin=true
```

Theme config should use iNiR's `ii-pixel` theme:

```ini
[General]
DisplayServer=x11

[Theme]
Current=ii-pixel
```

The SDDM greeter on this system is Qt5-linked, so the iNiR SDDM theme requires:

- `qt5-graphicaleffects`
- `import QtGraphicalEffects 1.0` in the installed SDDM theme

Do not rewrite this import to `Qt5Compat.GraphicalEffects`; that is for Qt6
Quickshell runtime code, not Qt5 SDDM.

## Theming

iNiR should own terminal/app color generation.

The live Alacritty config now imports only:

```toml
[general]
import = ["~/.config/alacritty/colors.toml"]
```

Do not re-add `~/.config/ryoku/current/theme/alacritty.toml` after the Niri
transition. Preserve Ryoku screensaver terminal profiles separately.

## Tests

Update tests away from Hyprland assumptions:

- `tests/ryoku-restart-ui.sh`
  - assert `inir.service` restart behavior
  - stop asserting `hyprctl reload`, Mako, SwayOSD, Waybar, and Hypridle
- `tests/quickshell-topbar-settings-menus.sh`
  - replace Hyprland settings/menu assertions with iNiR/Niri actions
- `tests/quickshell-toolbox.sh`
  - replace Hyprland submap, Hyprland window-rule, and `hyprctl` assertions
- `tests/quickshell-wallpaper-switcher.sh`
  - point bindings and wallpaper behavior at Niri/iNiR
- `tests/quickshell-volume-feedback.sh`
  - assert iNiR OSD/audio IPC instead of SwayOSD

Add new tests:

- package list excludes removed Hyprland-era packages
- package list includes required Niri/iNiR packages
- `ryoku-ipc` maps overview/clipboard/settings to `inir`
- `ryoku-lock-screen` maps to `inir lock activate`
- SDDM config defaults to `niri.desktop`
- Ryoku screensaver assets remain installed

## Verification

Before merging the implementation:

```bash
git status --short
./setup doctor
inir status
inir overview toggle
inir clipboard toggle
inir settings
niri msg -j outputs
```

Repo tests should pass after the command and package-list migration. Live
verification should show `./setup doctor` with zero failures.

## Open Questions

- Whether to vendor iNiR into Ryoku source or keep installing it as a tracked
  external checkout under `~/.local/share/inir`.
- Whether `hyprpicker` should remain the color picker backend or be replaced
  with an iNiR/Niri-native alternative.
- Whether Ryoku's Brain Shell code should be archived, removed, or retained as
  a reference while iNiR becomes the shell backend.
