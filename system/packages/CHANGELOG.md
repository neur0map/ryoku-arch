# Changelog: system/packages/

## Unreleased

### Added
- `base.packages`: the curated base set the installer pacstraps.
- `hardware.packages`: per-profile CPU microcode (`[amd]`, `[intel]`). GPU drivers
  come from `system/hardware/drivers/*.sh`, which the installer runs in the target.
- `aur.packages`: AUR add-ons (Limine hooks, Bibata cursors, AUR helper).
- `dev.packages`: the developer toolchains shipped with every machine (Go,
  Node/npm, Rust, Python/pip, mise).
- `base.packages`: the Ryoku shell runtime (`quickshell`, `awww`, `cliphist`,
  `hyprpicker`, `imagemagick`, `jq`) and the `yazi` file manager. `aur.packages`
  gains `wallust` (palette); `quickshell` moved from AUR to base (now official).
- `aur.packages`: add `gpk-bin` (GlazePKG), the RyokuArch package manager.

### Fixed
- `base.packages`: add the desktop session pieces a plain Hyprland needs to render
  and function: `xorg-xwayland`, `hyprpolkit-agent`, `qt6-wayland`, `qt6ct`,
  `xdg-desktop-portal-gtk`, and `adwaita-icon-theme`. Without them the installed
  desktop failed (no Xwayland binary, no polkit agent, unthemed Qt/GTK apps).
