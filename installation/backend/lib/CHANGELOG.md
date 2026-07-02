# Changelog: installation/backend/lib/

## Unreleased

### Added
- Step helpers split by concern: `common`, `preflight`, `disk`, `luks`,
  `filesystem`, `pacstrap`, `chroot`, `deploy`, `bootloader`.
- `snapshots`: a snapper `root` config, snap-pac registration, the snapper cleanup
  timer, and `limine-snapper-sync`, wired after the AUR step (dry-run safe, gated
  on the `@snapshots` subvolume).
- `common`: `append_file`, a dry-run-safe stdin-to-file appender.

### Changed
- `deploy`: install the desktop from the signed `[ryoku]` pacman repo plus
  `ryoku materialize`, replacing the per-file binary/dotfile/QML/udev copies (now
  package-owned). Brand assets, wallpapers, `~/.npmrc`, the neovim default-editor
  registration, and the qylock + SDDM theme are still seeded here.
- `bootloader`: `limine.conf` now lands at `/boot/limine.conf` (the ESP root),
  the one location `limine-entry-tool` manages, instead of
  `/boot/limine/limine.conf`, which Limine scans FIRST on the same partition
  and which therefore shadowed every generated entry: the UKI tree and the
  snapper snapshots never appeared in the boot menu. All shadowing config
  candidates are removed (mirrors `limine-install`'s conflict list).
- `bootloader`: the EFI binary now lands on `EFI/limine/limine_x64.efi` (plus
  the `EFI/BOOT` fallback), the exact path the tool's pacman hook refreshes on
  every `limine` upgrade, so the firmware never keeps booting an install-time
  binary that ages out of sync with the package (stale menu rendering). The
  NVRAM entry points there too, so `limine-install`'s dedup adopts it instead
  of registering a second one.
- `bootloader`: `default_entry` now matches the menu shape: `1` for the flat
  placeholder menu (offline installs), `2` once `limine-mkinitcpio-hook` owns
  the file (entry 1 becomes the `/+Ryoku` directory, which Limine refuses to
  autoboot; 2 is the newest UKI inside it).
- `bootloader`: new `ryoku_bootloader_finalize` (runs after the AUR step)
  retires the flat placeholder entry and repoints the default once the hook's
  UKI tree exists, then re-syncs the Windows chainload entry.

### Fixed
- `deploy`: install the `ryoku-mic` microphone normalizer onto the target. The
  Hyprland autostart runs it on login, but the bin step skipped it, so a fresh
  install lacked the mic-gain capping the live desktop applies.
- `filesystem`: the swapfile now lives in its own `@swap` subvolume instead of a
  `/swap` directory inside `@`. btrfs cannot snapshot a subvolume that holds an
  active swapfile, so the old layout made every snapper snapshot fail (`Creating
  snapshot failed`, then snap-pac's `Invalid snapshot '--type'`) on a default
  install with swap. `@swap` is created and mounted only when `RYOKU_SWAP_GIB > 0`.
