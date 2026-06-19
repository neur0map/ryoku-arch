# Repository structure

Three pillars, one job each. Everything else is documentation or tooling.

- `ryoku/` the desktop that a user runs.
- `system/` the machine the desktop runs on.
- `installation/` how that machine is built.

The golden rule: **every path has one purpose and appears once.** If you need
something that already exists, reference it; do not copy it.

## `ryoku/` the desktop

Deploys into the user's home (`~/.config`, `~/.local/...`) one way. Source of
truth for the live desktop.

- `apps/` one directory per application, holding that app's native config only:
  `kitty/`, `fish/`, `fastfetch/` (plus the `ryoku-fastfetch` launcher), `nvim/`
  (LazyVim), `yazi/`, `starship/`, `nautilus/`, `npm/` (`npmrc`), `pip/`
  (`pip.conf`). `mimeapps.list` sets default apps.
- `hyprland/` the Hyprland config, authored in **Lua**. `hyprland.lua` is the
  entry point and `require`s each module. `keyboard.lua`, `gpu.lua`,
  `monitors.lua` are hardware-managed seeds. `modules/` is one concern per file
  (`env`, `input`, `decoration`, `animations`, `binds`, `ryoshot`,
  `window_rules`, `autostart`). `scripts/` holds the few leaf shell helpers the
  UI calls directly. `hypridle.conf` is the idle daemon's native config. The whole
  directory deploys to `~/.config/hypr/`.
- `lockscreen/` `qylock/` (the lock theme and its quickshell lockscreen),
  `install-qylock`, and `sddm/` (the greeter setup).
- `shell/` the desktop shell subsystem: `quickshell/` (the QML UI: `pill` (the
  morphing top island, which also draws the screen frame and hosts the edge
  popouts under `pill/popouts/`), `sidebar`, `topbar`, `launcher`, `ryoshot`),
  `plugin/` (`Ryoku.Blobs`, the C++/QML SDF metaball module the frame renders
  with; `build.sh` builds it, and it ships prebuilt), `wallust/` (palette from
  the wallpaper), `kde/` (`kdeglobals`),
  `systemd/` (the user session target), `ipc/` (`ryoku-shell`, the Go
  control-plane daemon). `deploy.sh` and `dev-*.sh` are the live dev-loop tools.
- `assets/` `brand/` the 力 logo and icons, and `wallpapers/` the shipped
  wallpaper set (installs to `~/Pictures/Wallpapers`).

## `system/` the machine

System-level definition installed into the target.

- `boot/` the boot chain: `limine/`, `mkinitcpio/`, `plymouth/`.
- `hardware/` hardware policy and helper scripts (installed to
  `/usr/local/bin`): `gpu/` (`ryoku-gpu`, `ryoku-gpu-detect`, udev rule),
  `display/` (`ryoku-monitor`), `drivers/` (per-vendor `nvidia`/`intel`/`amd`/
  `vulkan` install scripts), `power/` (`ryoku-hw-laptop`, the shared laptop
  detector; `ryoku-idle`, the laptop-gated `hypridle` launcher).
- `packages/` the package sets: `base.packages` (every machine, pacstrapped),
  `hardware.packages` (per-profile microcode and GPU drivers), `dev.packages`
  (language toolchains, pacstrapped), `aur.packages` (built post-install).

## `installation/` the build

- `tui/` the Go terminal installer. Collects choices, writes the `RYOKU_*`
  contract, and drives the backend.
- `backend/` `ryoku-install` (the orchestrator) and `lib/` (one file per step:
  `preflight`, `disk`, `luks`, `filesystem`, `pacstrap`, `chroot`, `deploy`,
  `drivers`, `bootloader`, `network`, `aur`). It reads `system/packages/` and
  deploys the `ryoku/` payload.
- `iso/` the archiso profile. `build.sh` bakes the repo payload into the image,
  prebuilds the Go binaries, and runs `mkarchiso`. `profiledef.sh`,
  `packages.x86_64` (live-only set), and `airootfs/` complete the live image.

## The deploy model

- `installation/backend/lib/deploy.sh` copies the `ryoku/` payload into the
  target home and a few system paths.
- `installation/iso/build.sh` bakes every git-tracked file at
  `/usr/share/ryoku`, prebuilds the Go binaries (the TUI and `ryoku-shell`), and
  prebuilds the `Ryoku.Blobs` QML plugin into the payload, because the target has
  no build toolchain.
- It only ever flows **repo to system**. A change starts in the repo and is
  deployed; nothing is harvested back from a live machine.

## Shared, not duplicated

When two subsystems need the same thing, it lives once and both reference it:
`ryoku-hw-laptop` is the single laptop/desktop detector used by both GPU policy
and the idle policy. Reuse the helper; never re-implement its logic.
