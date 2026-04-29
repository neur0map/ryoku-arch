# Quickshell Dashboard, Launcher, and Wallpaper Work Log

Date: 2026-04-29

## Scope

- Repaired dashboard telemetry and clock layout after live dashboard edits broke the center/topbar presentation.
- Added display refresh reporting and safe power-saver refresh switching with blackout transition.
- Replaced the dashboard clock card with a clock-only card.
- Added a Quickshell app launcher on `SUPER SPACE`, with compact topbar-extension geometry and launch-row animation.
- Added a Quickshell wallpaper switcher on `SUPER CTRL SPACE`, replacing the old background menu shortcut and keeping Brain Shell's bottom-opening pattern.

## Verification Commands

- `bash tests/dashboard-clock-card.sh`
- `bash tests/dashboard-telemetry-layout.sh`
- `bash tests/quickshell-app-launcher.sh`
- `bash tests/quickshell-wallpaper-switcher.sh`
- `tests/dashboard-top-controls.sh`
- `tests/power-profile-display-safety.sh`
- `qs -c ryoku ipc call popups toggleLauncher`
- `qs -c ryoku ipc call popups toggleWallpaper`
- `qs -c ryoku ipc call popups closeAll`
- `hyprctl reload`

## Live Backups Created

- `/home/omi/.config/quickshell/ryoku.bak.1777501608`
- `/home/omi/.config/quickshell/ryoku.bak.1777502186`
- `/home/omi/.config/quickshell/ryoku.bak.1777503034`
- `/home/omi/.config/quickshell/ryoku.bak.1777503413`
- `/home/omi/.config/quickshell/ryoku.bak.1777503756`
- `/home/omi/.config/quickshell/ryoku.bak.1777504530`

## Notes

- Unrelated dirty files in packaging, tofi wrappers, ISO docs, and monitor config were left unstaged.
- The Brain Shell wallpaper switcher applies wallpapers through `ryoku-theme-bg-set`, so Ryoku's current background symlink and `swaybg` flow stay authoritative.
