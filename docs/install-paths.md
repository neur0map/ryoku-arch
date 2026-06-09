# Install paths: Ryoku OS vs Ryoku Shell

Ryoku ships through two distinct, intentionally separate paths. Pick the one
that matches what you want; they are not interchangeable.

## Ryoku OS (the ISO / full install)

The complete, opinionated Arch workstation. This is the product: a fresh
machine that boots into a coherent, pre-riced Ryoku desktop.

- Code: `install/`, `install.sh`, `boot.sh`.
- Installs and manages the **whole system**: the limine bootloader, a btrfs +
  snapper layout, the SDDM display manager, plymouth, and system-wide config
  (`/etc/pacman.conf`, sudoers, udev, services).
- Requires fresh, vanilla Arch (see `install/preflight/guard.sh`).
- Arch only. Not reversible: it *is* the operating system.

Use it on dedicated hardware or a VM you are setting up for Ryoku.

## Ryoku Shell (the experimental shell-only install)

Just the Ryoku desktop **shell** (the Quickshell shell, a Hyprland session,
the `ryoku-*` commands, and theming) layered onto a system you already run.

- Code: `shell-install/` (and only there).
- Installs into **user scope** plus the dependencies and GPU/firmware packages
  the shell needs, and adds one wayland session entry. By default it makes no
  boot, initramfs, or bootloader changes (driver boot config is opt-in via
  `--with-boot-config`), and it recommends a system snapshot before starting.
- Coexists with your current setup and is **reversible**: every change is
  backed up and recorded in a manifest, and `shell-install/uninstall` replays
  it in reverse.
- Marked **experimental**.
- Arch family today (`arch`, `cachyos`, `endeavouros`, `manjaro`, `garuda`,
  ...). New distros attach via an isolated adapter in `shell-install/distros/`
  and never affect the OS install. Nix, if added, is a separate declarative
  path.

Use it if you already have an Arch setup you like and want to try the Ryoku
shell without committing your machine to it.

See `shell-install/README.md` for usage and the per-field comparison table.

## Why the split matters

Keeping the shell layer in `shell-install/` with its own distro adapters means
adding support for another distro (CachyOS, and later others) is done to the
**shell only**. The OS install flow, which is Arch-specific by design, is left
untouched. One repo, two paths, a clear boundary.
