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
  fixtures; `RYOKU_SKIP_AUR` for unattended and CI installs. `install-vm.py`
  installs with a non-us keymap (`it`) and asserts it lands in `vconsole.conf`,
  the X11 `00-keyboard.conf`, and Hyprland `keyboard.lua`, guarding the
  keyboard-layout fix end-to-end.
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
- The packaged install smoke test (`installation/tests/container-install.sh`) now
  installs the Hyprland-plugin and wallust build deps (`rust`, `hyprland`,
  `hyprcursor`, `pango`, `cairo`, `pkgconf`) it always claimed to mirror from
  `publish-repo.yml`. Without them the newly packaged compositor-plugin PKGBUILDs
  failed in `prepare()` (`pkg-config` could not find `hyprland`), so the smoke
  test - and the publish gate that reuses it - could not build the `[ryoku]` set.
- The TUI catches a failed password hash at the password screen. `hashPassword`
  shells out to `openssl passwd -6`; on a failure it returned "" and the wizard
  marched on, handing the backend an empty `RYOKU_PASSWORD_HASH` that only died
  at preflight after the whole wizard was walked. Enter on the confirm field now
  re-prompts with a visible error instead (`tui/main.go`).
- The chosen keyboard layout now reaches every place a password is typed, so a
  non-us layout no longer locks you out after install. The graphical installer
  runs in a Wayland session (cage) whose layout is fixed at launch and `loadkeys`
  only affects the text console, so a password set on (say) an Italian keyboard
  was captured as us and then failed at the login prompt. The keyboard step now
  relaunches the session under the chosen layout (the password is captured in it),
  and the install writes that layout to the console (`vconsole.conf`), the
  X11/greeter (`/etc/X11/xorg.conf.d/00-keyboard.conf`), and Hyprland
  (`keyboard.lua`), so installer, SDDM greeter, desktop, and console all agree.
- The TUI's connectivity gate no longer false-negatives on ICMP-filtered
  networks. `netOnline` still treats a default route as online, but its fallback
  fetches an Arch mirror over HTTPS instead of pinging `8.8.8.8` (ICMP is dropped
  by many corporate/hotel/ISP firewalls even where mirrors are reachable), so the
  install is no longer blocked at Review on those networks.
- Partition labels with spaces or other special bytes render and match correctly:
  `lsblk -P` output is decoded through `unescapeLsblk` (the `\xNN` escapes), so a
  dual-boot "Windows Data" partition no longer shows as `Windows\x20Data` and the
  `ryoku`/`ryokuboot` reclaim match is not thrown off by embedded escapes.
- Live-medium exclusion now resolves a layered boot medium to its physical disk.
  `liveDisk` only walked a partition to its parent (`lsblk PKNAME`), so a Ventoy
  boot (the ISO is mapped through a device-mapper node, not a plain partition)
  left the USB unresolved and therefore visible in the disk picker: the installer
  could offer to erase the very stick it booted from. It now walks the inverse
  `lsblk -s` tree to the bottom disk (new `bottomDisk`, covered by
  `TestBottomDisk`); the direct-flash `PKNAME` path is unchanged.
- Disk strategy is fail-closed: a missing or empty selection never defaults to a
  wipe, and a whole-disk install onto a populated disk requires the typed `ERASE`
  acknowledgement (`RYOKU_WIPE_CONFIRMED=1`); a blank disk installs without it.
- `alongside` is idempotent across retries and no longer auto-deletes: partitions
  labeled exactly `ryoku`/`ryokuboot` (leftovers of a prior failed run) abort the
  install unless `RYOKU_RECLAIM_LEFTOVERS=1` (the TUI's typed `ERASE` ack) deletes
  only the unmounted ones before measuring free space; a mounted match is left
  alone, and free-space measurement no longer truncates.
- A dead-CMOS clock is auto-corrected from the mirror's HTTP `Date` header so TLS
  and pacman signatures stop failing; the keyring wait no longer races pacstrap;
  Broadcom Wi-Fi machines get `broadcom-wl`.
- The Limine menu no longer loops on the adopted UKI-tree layout, and a failed
  install leaves `/mnt` mounted with a named stage for inspection.
- TUI: the swapfile is carved from root (raising swap shrinks usable root), and
  the done screen actually runs `systemctl reboot` / `poweroff` on Enter.

### Hardened (adversarial re-audit)

A second, adversarial pass closed the findings a fresh review surfaced on the
pass-1 installer. Per-area detail is in `backend/CHANGELOG.md` and
`iso/CHANGELOG.md`.

- Reproducible builds now survive a non-root local build: `mkarchiso` runs under
  `sudo --preserve-env=SOURCE_DATE_EPOCH` so sudoers `env_reset` cannot strip the
  anchor, and `profiledef.sh` renders the ISO label and version with `date -u`,
  so one commit builds one name in any timezone.
- `build.sh` fails loudly if a `[core]`/`[extra]` mirror-sync window baked a
  `broadcom-wl` module against a kernel the image does not ship (it asserts one
  kernel module dir carrying `wl.ko`), which had silently killed live Wi-Fi on
  Broadcom laptops.
- The Windows dual-boot playbook gained recovery paths: booting Windows straight
  from the firmware menu when the Limine chainload boot-loops, the ESP fallback
  plus a one-line `efibootmgr` re-registration after a Windows feature update
  reshuffles NVRAM, the BitLocker recovery-key prompt that chainloading triggers,
  and the caveat that Microsoft does not support two ESPs on one disk.
- CI covers the previously unwired suites: the Limine menu and Windows-entry
  fixtures, the disk-teardown and DNS gates, and the installer TUI Go tests join
  the per-area workflow, and the ISO staging reproducibility check runs inside
  the ISO build (skipping cleanly when a runner lacks the Qt6 toolchain).
- Documentation was corrected against the tree: the honest `tests/install-*.sh`
  enumeration and the full airootfs entry list in `installation/README.md`, the
  installer test list in `docs/development.md`, and the twelve `release/packages`
  dirs plus the `ryoku-desktop` dependency set in `docs/structure.md`.
