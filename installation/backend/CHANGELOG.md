# Changelog: installation/backend/

## Unreleased

### Fixed
- `lib/deploy.sh`: chown the user's home before the qylock step (it ran after),
  so qylock's user-context writes no longer fail on root-seeded directories like
  `~/.local/share` (`cp: cannot create directory ...: Permission denied`, which
  aborted the install). Surfaced by a full qemu install test.

### Added
- `ryoku-install` entrypoint: reads the `RYOKU_*` contract, runs the install end
  to end, and prints the `@@RYOKU_STEP` / `@@RYOKU_DONE` progress sentinels.
- `lib/` step helpers: `common`, `preflight`, `disk`, `luks`, `filesystem`,
  `pacstrap`, `chroot`, `deploy`, `drivers`, `bootloader`.
- `lib/deploy.sh`: deploys the desktop payload during the `configure` stage
  (GPU/monitor helper scripts, the GPU udev rule, brand assets, the user
  dotfiles, and the qylock bundle + SDDM clockwork theme), dry-run safe and
  tolerant of a partial repo.
- `lib/drivers.sh`: runs the per-vendor GPU driver scripts in the target during
  the `configure` stage, so each machine gets the generation-correct driver.
- `RYOKU_DRYRUN=1` mode: prints every destructive command (and file write)
  instead of running it, with secrets redacted, so the flow can be exercised
  without a disk.
- README documenting the contract, the progress protocol, and the dry-run mode.
- `lib/network.sh`: in the `configure` stage, pin the target's NetworkManager
  wifi backend to iwd and copy the live session's saved `.nmconnection` profiles
  into the target (`root:root`, 0600), so wifi keeps working after first boot.
- `lib/deploy.sh` now ships the full Ryoku shell as the desktop: the shell's
  Hyprland config (superseding the plain set), the quickshell UI, wallust, the
  qt/kde theme, the user session target, the prebuilt `ryoku-shell` daemon, the
  Neovim (LazyVim) and yazi configs, and Neovim as the default text editor.
- `lib/aur.sh`: after the bootloader step, bootstrap the `yay` AUR helper (AUR
  clone, GitHub release binary as a fallback) and build the `aur.packages` set
  as the user with a temporary passwordless-sudo grant. Online-gated and
  best-effort: an offline install or a failed build logs a warning and the
  install still completes.
- `lib/deploy.sh`: read the desktop payload from the consolidated tree, the shell
  from `ryoku/shell/*` and the Hyprland config from `ryoku/hyprland`.
- `lib/pacstrap.sh`: also install `system/packages/dev.packages`, so every machine
  ships the Go, Node/npm, Rust, Python, and mise toolchains.
- `lib/deploy.sh`: ship `~/.npmrc` and `~/.config/pip/pip.conf`, so `npm i -g` and
  `pip install --user` work without root out of the box.
- `lib/deploy.sh`: installs `ryoku-hw-laptop` and `ryoku-idle` into the target so
  laptop idle policy is available on first login.
- `lib/deploy.sh`: installs `ryoku` and `ryoku-leds`, letting the live mirror pull
  and reload repo changes while wallpaper changes apply wallust colors to
  OpenRGB-compatible lighting devices.
- `lib/deploy.sh`: seed `~/Pictures/Wallpapers` from the shipped
  `ryoku/assets/wallpapers`, so a fresh install has a wallpaper set and the first
  login lands on a random one.
- `lib/snapshots.sh`: after the AUR step, configure Btrfs snapshots: write a
  snapper `root` config (keep ~10 numbered snapshots, timeline off), register it
  in `/etc/conf.d/snapper` for snap-pac and the systemd timers, enable
  `snapper-cleanup.timer`, and enable `limine-snapper-sync.service` (best-effort,
  AUR-provided) so snapshots appear as Limine boot entries. Gated on the
  `@snapshots` subvolume and dry-run safe.
- `lib/common.sh`: `append_file`, a dry-run-safe helper that appends stdin to a
  file (used to add the `[ryoku]` stanza to the target `pacman.conf`).

### Changed
- `lib/deploy.sh`: install the Ryoku desktop from the signed `[ryoku]` pacman repo
  instead of copying files. The configure stage adds `[ryoku]` (`SigLevel =
  Required`, `Server = https://repo.ryoku.dev/$arch`) to the target, copies the
  live mirrorlist in, trusts the release key (`pacman-key --populate ryoku`),
  `pacman -S`es the desktop set (`ryoku-keyring ryoku-shell ryoku-hub ryoku-blobs
  ryoku ryoku-desktop`), and runs `ryoku materialize` as the user to lay
  `~/.config` from `/usr/share/ryoku/config`. The per-file binary, dotfile, QML
  plugin, and udev copies are gone (now package-owned); only the unpackaged
  user-data (brand assets, wallpapers, `~/.npmrc`), the neovim default-editor
  registration, and the qylock + SDDM theme are still seeded here. Online-gated
  and best-effort: an offline or partial install leaves `[ryoku]` configured and
  recovers on the first `ryoku update`.

### Fixed
- `lib/chroot.sh` and the TUI: fix timezone detection. The timezone screen runs
  before the network step, so a Wi-Fi install geolocated with no connection and
  silently fell back to UTC. The TUI no longer resolves the zone itself; the
  backend resolves it from two geolocation providers during the configure stage
  (network up), validates it against the zoneinfo database (UTC fallback with a
  warning), and enables systemd-timesyncd so the installed clock self-corrects.
- `lib/chroot.sh`: set the root password to the chosen install password instead
  of locking the root account, so `su` works alongside `sudo`. A locked root
  made `su` reject the user's password even though `sudo` worked.
- `lib/pacstrap.sh`: ensure the live pacman keyring is ready before pacstrap. It
  waits for `pacman-init.service` to settle, then populates the keyring if it is
  still empty, so the install no longer races the boot service and fails with
  "public keyring not found / failed to install packages to new root".
- `lib/deploy.sh`: own the user home before installing qylock, so its per-user
  files (the lockscreen under `~/.local/share`) are writable.
- `lib/deploy.sh`: deploy the Hyprland config as `*.lua` (it moved to Lua).
- `lib/bootloader.sh`: set EFI BootNext to the installed system so the first
  reboot boots it even if the USB installer is still plugged in.
- `ryoku-install`: sync and unmount the target before printing `@@RYOKU_DONE`, so
  the bootloader and config writes are flushed to disk. Without this an abrupt
  power-off after a non-reboot finish could leave a 0-byte `limine.efi` and an
  unbootable disk.
- `lib/disk.sh`: settle udev and wipe filesystem signatures on the freshly created
  partitions, so an old LUKS2 header left at the same offset by a previous install
  can no longer make the root mount fail with "unknown filesystem type
  crypto_LUKS".
