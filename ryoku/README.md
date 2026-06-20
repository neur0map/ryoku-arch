# ryoku/

The desktop: what you see and use after logging in. `system/` builds the machine;
this tree makes it Ryoku. It deploys one way, into the user's home (`~/.config`,
`~/.local/...`) and a few system paths, and is the source of truth for the live
desktop. See `docs/structure.md` for the repo-wide map.

## What's here

- `hyprland/` The Hyprland config, authored in **Lua** (Hyprland 0.55+ loads
  `hyprland.lua` natively). `hyprland.lua` is the entry point and `require`s each
  module. `keyboard.lua`, `gpu.lua`, `monitors.lua` are hardware-managed seeds;
  `modules/` is one concern per file (env, input, displays, decoration,
  animations, binds, ryoshot, window rules, fullscreen, autostart); `scripts/`
  holds the leaf shell helpers the UI calls (the `ryoku-cmd-*` screen tools plus
  the stash and sysinfo helpers). `hypridle.conf` is the idle daemon's native
  config. The whole directory deploys to `~/.config/hypr/`.
- `shell/` The Ryoku shell subsystem: `quickshell/` (the QML UI: the morphing
  `pill` island and its `popouts`, the `sidebar`, and `ryoshot`), `plugin/`
  (`Ryoku.Blobs`, the C++/QML SDF metaball module the frame renders with; ships
  prebuilt), `wallust/` (palette from the wallpaper), `kde/` (`kdeglobals`),
  `systemd/` (the user session target), and `ipc/` (`ryoku-shell`, the Go
  control-plane daemon that supervises the UI and owns wallpaper, clipboard, and
  lock). `deploy.sh` and `dev-*.sh` are the live dev-loop tools.
- `hub/` Ryoku Hub, the control-center GUI (`Super + ,`): `backend/` (`ryoku-hub`,
  the Go data plane that reads the keybind legend from the live Hyprland config and
  persists hub state as TOML) and `quickshell/` (the Qt6/QML app).
- `lockscreen/` The login and lock screen: `qylock/` (the lock theme and its
  quickshell lockscreen, vendored), `install-qylock`, and `sddm/` (the greeter
  setup).
- `apps/` One directory per application, holding that app's native config only:
  kitty, fish, fastfetch (plus the `ryoku-fastfetch` launcher), nvim (LazyVim),
  yazi, starship, nautilus, npm (`npmrc`), pip (`pip.conf`). `mimeapps.list` sets
  the default apps.
- `assets/` `brand/` the 力 logo and icons, and `wallpapers/` the shipped wallpaper
  set (installs to `~/Pictures/Wallpapers`).

## Fonts, cursors, and helper scripts

Fonts (JetBrains Mono Nerd, Noto, Inter) ship as packages in `system/packages`.
The cursor theme (Bibata) is an AUR package, selected by the Hyprland environment.
The Go binaries (`ryoku-shell`, `ryoku-hub`) and the `Ryoku.Blobs` plugin ship
prebuilt: the ISO build compiles them, because the target has no build toolchain.
System helper scripts live next to what they serve under `system/hardware/` and
deploy to `/usr/local/bin`.
