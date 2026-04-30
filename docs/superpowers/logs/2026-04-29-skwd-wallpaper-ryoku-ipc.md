# SKWD Wallpaper Selector And Ryoku IPC Log

Date: 2026-04-29

## Summary

- Added `ryoku-ipc` as the stable shell/wallpaper command facade.
- Replaced direct Quickshell wallpaper keybind calls with `ryoku-ipc shell toggle wallpaper`.
- Added local wallpaper cache, thumbnails, color grouping, Wallhaven search/download, and image/video apply helpers.
- Replaced the simple wallpaper strip with a fullscreen SKWD-style selector rendered inside Ryoku Quickshell.
- Added runtime packages for Wallhaven and video preview/apply: `curl`, `qt6-multimedia-ffmpeg`, and `mpvpaper`.
- Follow-up: fixed Wallhaven UI searches so API results are not hidden by local filename filtering, and the Web source chip can submit the typed query.

## Verification

- `bash tests/ryoku-ipc.sh` passed.
- `bash tests/ryoku-wallpaper-cache.sh` passed; the corrupt fixture thumbnail warning is expected.
- `bash tests/ryoku-wallhaven-search.sh` passed.
- `bash tests/quickshell-wallpaper-skwd.sh` passed.
- `bash tests/quickshell-wallpaper-switcher.sh` passed.
- `bash tests/quickshell-app-launcher.sh` passed.
- `bash tests/dashboard-top-controls.sh` passed.
- `git diff --check` passed.
- `env RYOKU_PATH=/home/omi/prowl/ryoku-arch bin/ryoku-refresh-quickshell` refreshed the live Quickshell config.
- `bin/ryoku-restart-shell` relaunched `quickshell -c ryoku`.
- `install -m 0644 default/hypr/bindings/utilities.conf /home/omi/.local/share/ryoku/default/hypr/bindings/utilities.conf` applied the live binding copy.
- `hyprctl reload` returned `ok`.
- `/home/omi/.local/share/ryoku/bin/ryoku-ipc shell toggle wallpaper` opened the selector after installing the new helpers to `~/.local/share/ryoku/bin`.
- `hyprctl layers -j` showed Quickshell layers on the active display, including a fullscreen overlay layer while the selector was open.
- `qs -c ryoku log --tail 180` showed no wallpaper selector QML load errors after the video-preview fix.
- `/home/omi/.local/share/ryoku/bin/ryoku-ipc wallpaper cache rebuild` returned `rebuilt`.
- `/home/omi/.local/share/ryoku/bin/ryoku-ipc wallpaper list --jsonl | head -5 | jq -c .` returned local wallpaper JSON rows with `source`, `type`, `path`, `thumb`, `name`, `hue`, and `mtime`.
- `/home/omi/.local/share/ryoku/bin/ryoku-ipc wallpaper wallhaven search --query "samurai city" --page 1 --json` returned Wallhaven JSON rows from the live deployed helper.

## Notes

- Live validation initially exposed a Quickshell load failure from `MediaPlayer.muted`; `a6403863` fixes video previews to mute through `AudioOutput`.
- Static wallpaper apply remains routed through `ryoku-theme-bg-set` behind `ryoku-ipc`.
- Video apply uses `mpvpaper`; `yay -Ss mpvpaper` confirmed `aur/mpvpaper 1.8-1`, and the package is now listed in `install/ryoku-aur.packages`.
- Wallhaven defaults to SFW search unless `WALLHAVEN_API_KEY` and settings explicitly allow other purity filters.
- Remaining Quickshell warnings during verification were pre-existing optional/system warnings: invalid module-path scanner warnings, missing `envycontrol`, and missing profile image `/home/omi/.curr_wall_static.jpg`.
