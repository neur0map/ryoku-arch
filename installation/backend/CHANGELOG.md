# Changelog: installation/backend/

## Unreleased

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

### Fixed
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
