# Changelog: installation/

## Unreleased

A ground-up hardening of the installer for real hardware. Granular backend and
ISO detail live in `backend/CHANGELOG.md` and `iso/CHANGELOG.md`.

### Added
- The installer TUI (`tui/`, Go / Bubble Tea v2): `main.go` the UI, `system.go`
  the machine glue and the `RYOKU_*` handoff. Safety gates for legacy BIOS,
  Secure Boot, the live boot medium, the wipe acknowledgement, and online-only.
- `backend/` (`ryoku-install` + `lib/`): a readable top-to-bottom bash install
  driven entirely by `RYOKU_*`, with a full `RYOKU_DRYRUN` mode.
- `iso/`: an archiso profile that boots straight into the TUI (cage + foot).
  Reproducible builds (commit-pinned `SOURCE_DATE_EPOCH`, `-buildid=`-stripped Go
  binaries, `SHA256SUMS`, opt-in `RYOKU_ISO_REPRO` archive pinning), a payload
  provenance stamp, and safe-graphics (`nomodeset`) + copy-to-RAM (`copytoram`)
  boot fallbacks on both firmware paths.
- Install verification: `installation/tests/` (`container-install.sh`,
  `install-vm.py`, `iso-stage-check.sh`) plus the root `tests/install-*.sh`
  fixtures; `RYOKU_SKIP_AUR` for unattended and CI installs.
- Docs: `installation/README.md` (the map), `backend/lib/README.md` (the
  per-stage reference), `tui/README.md`, and `docs/installation-hardware.md` (the
  real-hardware playbook).
- The `Ryoku.Blobs` QML plugin and `ryoku-hub` ride the install path: prebuilt
  into the payload and installed onto the target with no build toolchain.

### Changed
- Dual-boot redesign. `alongside` no longer reuses the Windows/OEM ESP (too small
  for our kernel + initramfs + UKIs, and reuse clobbers Windows' loader): it
  creates a dedicated Ryoku ESP (partlabel `ryokuboot`, EF00) + root (partlabel
  `ryoku`) in the largest free region and never touches the Windows ESP. Minimum
  free space is `20 + swap + ESP` GiB; make room by shrinking Windows first.
- Preflight gates the footguns before the disk is touched: Secure Boot (Limine is
  unsigned; `RYOKU_ALLOW_SECUREBOOT=1` override), a whole-disk (not partition)
  target, and DNS + HTTP reach (installs are online-only).
- Hibernation and Intel VMD are carried into the target: `resume=`/`resume_offset=`
  plus the `resume` hook when a swapfile exists, and `MODULES+=(vmd)` when the
  live kernel needed VMD to see the NVMe.

### Fixed
- Disk strategy is fail-closed: a missing or empty selection never defaults to a
  wipe, and a whole-disk install onto a populated disk requires the typed `ERASE`
  acknowledgement (`RYOKU_WIPE_CONFIRMED=1`); a blank disk installs without it.
- `alongside` is idempotent across retries: it reclaims unmounted leftover
  `ryoku`/`ryokuboot` partitions from a prior failed run before measuring free
  space, and free-space measurement no longer truncates.
- A dead-CMOS clock is auto-corrected from the mirror's HTTP `Date` header so TLS
  and pacman signatures stop failing; the keyring wait no longer races pacstrap;
  Broadcom Wi-Fi machines get `broadcom-wl`.
- The Limine menu no longer loops on the adopted UKI-tree layout, and a failed
  install leaves `/mnt` mounted with a named stage for inspection.
- TUI: the swapfile is carved from root (raising swap shrinks usable root), and
  the done screen actually runs `systemctl reboot` / `poweroff` on Enter.
