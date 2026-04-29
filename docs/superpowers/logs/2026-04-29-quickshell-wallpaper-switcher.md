# Quickshell Wallpaper Switcher Log

Date: 2026-04-29

## Summary

- Added a compact Brain Shell-derived wallpaper switcher popup to Ryoku Quickshell.
- Replaced `SUPER CTRL SPACE` from the old `ryoku-menu background` to `qs -c ryoku ipc call popups toggleWallpaper`.
- Routed wallpaper apply through `ryoku-theme-bg-set` instead of Brain Shell's upstream `awww` and `matugen` pipeline.
- Listed wallpapers from the active Ryoku theme and the user's matching theme background folder.
- Kept the popup visually connected to the topbar, with outside-click close and exclusive keyboard focus for search.

## Verification

- `bash tests/quickshell-wallpaper-switcher.sh`
- `bash tests/quickshell-app-launcher.sh`
- `bash tests/dashboard-clock-card.sh`
- `bash tests/dashboard-telemetry-layout.sh`
- `tests/dashboard-top-controls.sh`
- `tests/power-profile-display-safety.sh`
- `qs -c ryoku ipc call popups toggleWallpaper`
- `qs -c ryoku ipc call popups closeAll`
- `hyprctl reload`

## Live Apply

- Refreshed Quickshell with `env RYOKU_PATH=/home/omi/prowl/ryoku-arch bin/ryoku-refresh-quickshell`.
- Restarted Quickshell with `bin/ryoku-restart-shell`.
- Copied the updated Hyprland utility bindings into `/home/omi/.local/share/ryoku/default/hypr/bindings/utilities.conf`.
- Live Quickshell backup: `/home/omi/.config/quickshell/ryoku.bak.1777504530`.
