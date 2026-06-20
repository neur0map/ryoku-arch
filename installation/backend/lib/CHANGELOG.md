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

### Fixed
- `deploy`: install the `ryoku-mic` microphone normalizer onto the target. The
  Hyprland autostart runs it on login, but the bin step skipped it, so a fresh
  install lacked the mic-gain capping the live desktop applies.
- `filesystem`: the swapfile now lives in its own `@swap` subvolume instead of a
  `/swap` directory inside `@`. btrfs cannot snapshot a subvolume that holds an
  active swapfile, so the old layout made every snapper snapshot fail (`Creating
  snapshot failed`, then snap-pac's `Invalid snapshot '--type'`) on a default
  install with swap. `@swap` is created and mounted only when `RYOKU_SWAP_GIB > 0`.
