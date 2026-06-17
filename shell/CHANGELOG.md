# Changelog: shell/

## Unreleased

### Added
- The Ryoku desktop shell, imported and reorganized into this tree: the Quickshell
  UI (`pill` bar, `sidebar`, `topbar`, `launcher`, `ryoshot`), the Hyprland
  config in Lua, wallust palette generation, and the per-app configs.
- `ipc/`: `ryoku-shell`, a single Go program that is the shell's control plane.
  `ryoku-shell daemon` supervises the Quickshell components (restarting them if
  they exit), brings up the clipboard-history watchers and the wallpaper, and
  serves one Unix socket. `ryoku-shell <command>` is the client the Hyprland
  keybinds call. It resolves the active monitor itself and fans out to the
  Quickshell IPC, the wallpaper daemon and wallust, and qylock for the lock.
- `dev-run.sh`, `dev-stop.sh`, `dev-binds.sh`: run the shell from this checkout on
  a live Hyprland session via `RYOKU_SHELL_DIR` (`qs -p`), with quickshell
  hot-reload, so it can be developed without installing anything.
- `README.md`: documented the shell's runtime dependencies and how to run it live.
- `deploy.sh`: installs this tree into `~/.config` (one way; the repo is the
  source) and `ryoku-shell` onto `PATH`. Pauses Hyprland auto-reload across the
  `~/.config/hypr` swap so the missing-file window cannot trip emergency mode;
  `--no-reload` stages the files for the next login.

### Changed
- Replaced the per-component daemon and toggle shell scripts with the Go IPC: the
  `*-daemon.sh` watchdogs, `cliphist-watch.sh`, and the `launcher`/`sidebar`/
  `clipboard`/`link`/`lock`/`wallpaper`/`wallpaper-picker` scripts are gone. The
  keybinds (`binds.lua`), autostart (`autostart.lua`), and the QML that ran those
  scripts (the power menus, the wallpaper picker) now call `ryoku-shell`. Only the
  two leaf thumbnailers the UI invokes directly remain under `hypr/scripts/`.
- De-branded the import: no upstream name, attribution, or credits; `torii` ->
  `ryoku`, `rishot` -> `ryoshot`, and the matching file and directory renames.
  Removed the em-dashes from the QML display strings (the regex keeps splitting on
  one via an escape).
- Dropped the shell's own lock component; qylock (shipped by `ryoku/`) stays the
  lock, and `ryoku-shell lock` launches it.
- Standardized the terminal and file manager on `kitty` and `nautilus` (what
  `ryoku/` ships): `binds.lua`, the `window_rules.lua` float rule, the wallust
  template (a `kitty` palette now), and the README; removed the `ghostty` config.
- Replaced the import's machine-specific values with portable, hardware-managed
  ones: dropped the hardcoded dual-monitor layout, the German keyboard, and the
  `DP-1`/`HDMI-A-1` -> workspace mapping in the pill and topbar `Workspaces.qml`
  (a monitor-agnostic fixed range now). `hyprland.lua` requires the managed
  `gpu`/`keyboard`/`monitors` and runs `ryoku-gpu`/`ryoku-monitor` from autostart,
  as `ryoku/` does. Fixed the leftover `/home/erik/...` paths, and made `fish`
  match the base (greeting off, `~/.local/bin` on `PATH`).
- Reworked the keybinds: `SUPER+Q` closes, `W` cycles the wallpaper, `B` opens
  chromium, `A`/`SHIFT+A` float (compact) / tile (restore) the window, and `S`
  takes a ryoshot screenshot; dropped the SUPER-tap launcher and `SUPER+T` float.
  `SUPER+[1..0]` focus workspaces, `SUPER+SHIFT+[1..0]` move the window there.
  `SUPER+N` opens Neovim, `SUPER+ALT+E` opens yazi; `EDITOR`/`VISUAL` are nvim.
- `input.lua`: matched the upstream Ryoku input, `sensitivity` 0, no explicit
  `accel_profile` (libinput's adaptive default), `touchpad.natural_scroll` false,
  and hardware cursors. The shell's reversed scroll and a positive sensitivity
  were what felt non-native.
- `monitors.lua` seed uses `highrr`, so a panel comes up at its top refresh
  (165Hz here) instead of the EDID-preferred 60Hz.
- Kept `ryoku/`'s branded `ryoku-fastfetch` as the terminal readout: dropped the
  shell's wallust fastfetch template and `fastfetch/` dir, so wallust no longer
  overwrites `~/.config/fastfetch/config.jsonc`. wallust themes the kitty palette
  and Hyprland colors only.

### Fixed
- `ipc/wallpaper.go`: resolve a symlinked wallpaper directory (`EvalSymlinks`)
  before scanning, so `wallpaper next` and the picker work when
  `~/Ryoku/wallpapers` links to a collection elsewhere.
- `quickshell/ryoshot`: create `~/Pictures/Screenshots` on launch; it did not
  exist, so the screenshot grab failed and copy/save silently did nothing.
- `quickshell/ryoshot`: de-branded the selection label (dropped the leftover
  torii glyph; it now reads `ryoshot · WxH`).

### Not included
- The GRUB theme (the system boots with Limine) and the SDDM theme (a 38 MB
  third-party video, and the login screen is qylock). Bring either in later if
  wanted.
