# Changelog: system/boot/

## Unreleased

### Fixed
- `limine/default.conf`: document what `TARGET_OS_NAME` is for and why it is
  `Ryoku`. It must match the OS entry name limine-snapper-sync hangs the Snapshots
  submenu under (the `/+Ryoku` UKI tree, name "Ryoku"); `ryoku doctor` now
  re-aligns it if a box is stuck on the flat `/Ryoku Linux` fallback entry, where
  the mismatch failed snapper-cleanup and left no rollback snapshots in the menu.
- `limine/limine.conf` documents its real deploy target: `/boot/limine.conf`
  (the ESP root), the one config `limine-entry-tool` manages. The old comment
  described `/boot/limine/limine.conf`, a location Limine scans FIRST, so a
  config there shadows every generated entry (UKI tree, snapshots submenu).
- `limine/limine.conf`: `default_entry: 2`, matching the tool-managed menu
  (entry 1 is the `/+Ryoku` directory, which Limine refuses to autoboot; 2 is
  the newest UKI inside it). The installer rewrites it to 1 while the menu is
  still the flat placeholder. The placeholder path now names the UKI the hook
  actually builds (`ryoku_linux.efi`, from `CUSTOM_UKI_NAME="ryoku"` + the
  `linux` pkgbase), not the never-produced `ryoku.efi`.
- `limine/default.conf`: comment named the shadow path; now points at
  `/boot/limine.conf`.
- efibootmgr NVRAM registration is now best-effort. On firmware that exposes
  NVRAM as readonly or reports it full (HP / Insyde-class), `--create` /
  `--bootnext` used to abort the whole install under `set -e`. They now log a
  loud warning and continue: the UEFI removable-path fallback
  `EFI/BOOT/BOOTX64.EFI` on Ryoku's own ESP keeps the machine bootable. That
  fallback copy is always safe now that both partitioning strategies install
  onto Ryoku's own ESP (never the Windows ESP), so it can't clobber a foreign
  fallback loader.
- Intel VMD carry-over: when the live installer kernel needed the `vmd` module
  to see the NVMe (Intel RST "VMD" mode), the installer now writes
  `/etc/mkinitcpio.conf.d/ryoku-vmd.conf` with `MODULES+=(vmd)` before building
  the initramfs (both the limine-mkinitcpio UKI path and plain `mkinitcpio -P`),
  so the installed system can still find its own root disk at boot instead of
  dropping to an emergency shell.

### Added
- `mkinitcpio/ryoku.conf`: `resume` hook, right after `encrypt`, for
  hibernation. When a swapfile exists (`RYOKU_SWAP_GIB > 0`), the installer
  appends `resume=<dev> resume_offset=<n>` to the kernel command line (`<dev>`
  mirrors `root=`: `/dev/mapper/root` under LUKS, else the root fs `UUID=`;
  `<n>` from `btrfs inspect-internal map-swapfile -r`). Older btrfs-progs
  (< 5.16) without `map-swapfile` are skipped cleanly (no resume=, still boots).
  `resume` stays a separate word so the installer's `encrypt`-stripping sed is
  unaffected, and it is a no-op with no `resume=` cmdline, so it is safe on
  every install.
- ESP free-space guard: before writing the Limine binary the installer asserts
  `/mnt/boot` has >= 64 MiB free and dies with a clear message otherwise -- a
  last-line guard that should never fire with the dedicated >= 1 GiB ESP, but
  fails clearly instead of half-writing and erroring deep in efibootmgr.
- `limine/limine.conf`: Ryoku-branded Limine config (branding string, orange
  accent, Greek Noir palette, timeout, default UKI entry placeholder).
- `limine/default.conf`: UKI build settings (TARGET_OS_NAME, ESP_PATH,
  ENABLE_UKI, CUSTOM_UKI_NAME, snapshot entries, `quiet splash` cmdline).
- `plymouth/ryoku/`: vendored Ryoku Plymouth splash (manifest, script, assets).
- `mkinitcpio/ryoku.conf`: HOOKS drop-in with `plymouth` and `kms`; `encrypt`
  documented as LUKS-only.
