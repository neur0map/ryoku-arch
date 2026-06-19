# Changelog: system/packages/

## Unreleased

### Added
- `base.packages`: the curated base set the installer pacstraps.
- `hardware.packages`: per-profile CPU microcode (`[amd]`, `[intel]`). GPU drivers
  come from `system/hardware/drivers/*.sh`, which the installer runs in the target.
- `aur.packages`: AUR add-ons (Limine hooks, Bibata cursors, AUR helper).
- `dev.packages`: the developer toolchains shipped with every machine (Go,
  Node/npm, Rust, Python/pip/pipx, mise).
- `base.packages`: the Ryoku shell runtime (`quickshell`, `awww`, `cliphist`,
  `hyprpicker`, `imagemagick`, `jq`) and the `yazi` file manager. `aur.packages`
  gains `wallust` (palette); `quickshell` moved from AUR to base (now official).
- `aur.packages`: add `gpk-bin` (GlazePKG), the RyokuArch package manager.
- `base.packages`: add `hypridle` for laptop dim/lock/suspend timeouts and
  `upower` for the shell battery surface.
- `base.packages`: add `openrgb` for wallpaper-driven keyboard and lighting
  color control through `ryoku-leds`.
- `base.packages`: add `noto-fonts-cjk` and `inter-font` so Japanese Ryoku shell
  labels, the 力 brand mark, and the configured UI font render on fresh installs.
- `base.packages`: add `cava` for the pill's separated music visualizer island.
- `base.packages`: add `curl`, `python`, `libnotify`, and `xdg-utils` for the
  pill's file stash (LocalSend LAN discovery and send), weather (wttr.in), and
  opening stashed files with the default app.
- `base.packages`: add `ffmpeg` and `yt-dlp` for the stash's media compress and
  download actions, and `desktop-file-utils` so installing AppImages and tarballs
  refreshes the launcher's desktop database.
- `base.packages`: add `tesseract` and `tesseract-data-eng` for the pill's Super+D
  toolkit OCR (recognize text in a screen region to the clipboard).
- `base.packages`: add `zbar` for the Super+D toolkit QR scanner (decode a QR code
  in a screen region, copy it, and open URLs).
- `base.packages`: add `gpu-screen-recorder` and `wf-recorder` for the pill's
  Super+U utilities Screen Recorder (gpu-screen-recorder, with a wf-recorder
  fallback on multi-GPU machines).

### Fixed
- `base.packages`: add the desktop session pieces a plain Hyprland needs to render
  and function: `xorg-xwayland`, `hyprpolkit-agent`, `qt6-wayland`, `qt6ct`,
  `xdg-desktop-portal-gtk`, and `adwaita-icon-theme`. Without them the installed
  desktop failed (no Xwayland binary, no polkit agent, unthemed Qt/GTK apps).
