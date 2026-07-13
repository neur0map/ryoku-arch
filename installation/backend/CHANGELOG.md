# Changelog: installation/backend/

## Unreleased

### Added
- Automated install tests (`installation/tests/`, run by the Install test
  workflow): `container-install.sh` builds the packages, installs `ryoku-desktop`,
  and asserts the materialized config is complete on Arch and CachyOS bases;
  `install-vm.py` boots the ISO and runs the real installer unattended in QEMU,
  then verifies the installed tree. A new `RYOKU_SKIP_AUR` skips the optional AUR
  set for an unattended or CI install.
- The install tests build the packages locally and serve them to the guest, so a
  packaged install is validated end to end without the public repo (CI cannot
  reach it: Cloudflare blocks datacenter IPs). `RYOKU_REPO_SERVER` /
  `RYOKU_REPO_SIGLEVEL` override the `[ryoku]` source (tests only).
- `RYOKU_GPU_MODE` is now consumed end to end. The TUI collects it on hybrid
  (iGPU + dGPU) machines but nothing acted on it; `lib/drivers.sh` now runs
  `ryoku-gpu mode` after the driver install (mapping `offload`->hybrid,
  `sync`->performance, `vfio`->passthrough) as the user against their
  `~/.config/hypr/gpu.lua`, via `runuser` like `deploy.sh`. Best-effort (a
  failure only skips the pin), dry-run narrated, skipped when `ryoku-gpu` is not
  installed. gpu.lua (not user.lua) because first-login `ryoku-gpu persist` only
  rewrites it when a discrete pin is "beneficial" (desktop/eGPU), so the pick
  survives on the hybrid laptop this targets, and gpu.lua is the file the Hub,
  `ryoku doctor`, and `ryoku materialize` all manage.

### Fixed
- `lib/chroot.sh`: the locale uncomment cannot silently generate nothing. The
  sed now escapes the dots (so `en_US.UTF-8` matches only its own line), and a
  locale that `locale.gen` does not list (a manual `RYOKU_LOCALE`, a slimmed
  file) is appended before `locale-gen` runs, gated on the target actually
  having its source definition (locale-gen is `set -e`, so appending a bogus
  name would abort the install after the wipe; that input class only logs a
  warning). Before, the pattern matched nothing, nothing was generated, and
  every tool on the target warned "cannot set locale" from first boot.
- `lib/drivers.sh`: a failed vendor driver script no longer claims "the iGPU
  still drives the display", which is false on dGPU-only machines; the message
  now points at `ryoku doctor` after first boot.
- `lib/deploy.sh`: the keyboard seed's sed uses `|` delimiters so a layout or
  variant string can never collide with the pattern delimiter.
- A package that downloads corrupt under load no longer permanently fails the
  install. pacstrap's one retry reused the target cache, so a corrupt cached
  package (bad PGP signature -- which non-interactive pacstrap cannot answer the
  delete prompt for) failed the retry identically; the retry now clears the target
  package cache first, so it re-fetches the package clean.
- The chosen keyboard layout reaches the graphical stack, not just the console.
  `lib/chroot.sh` writes `/etc/X11/xorg.conf.d/00-keyboard.conf` (X11 / Xwayland /
  the SDDM greeter) beside `vconsole.conf`, and `lib/deploy.sh` seeds the layout
  into the target's user-owned `hypr/keyboard.lua` before `materialize` lays it,
  so the desktop keyboard matches the install choice. The TUI passes the derived
  `RYOKU_XKB_LAYOUT` / `RYOKU_XKB_VARIANT`.
- The pacman keyring is built and verified BEFORE the disk is touched, not at
  pacstrap after the wipe. `ryoku-install` runs `ryoku_ensure_keyring` in the
  preflight phase now, and the helper dies with clear guidance if the keyring is
  still empty after init+populate, instead of a cryptic "invalid or corrupted
  package (PGP signature)" abort on an already-wiped disk.
- GPU driver install is time-bounded and non-fatal: each per-vendor driver script
  runs under `timeout 900` in the chroot, and a hang or build failure logs a
  warning and continues (the iGPU still drives the display) instead of stalling
  or aborting the whole install after the base system is in place.
- The AUR build's passwordless-sudo drop-in is removed from the target via a
  `RETURN` trap, so an early return from `ryoku_aur` can never leave the installed
  system shipping NOPASSWD sudo.
- `alongside` waits (bounded) for the by-partlabel nodes of the two freshly
  created partitions before mapping them, so a slow or busy bus (USB, Ventoy) can
  no longer spuriously abort a valid dual-boot layout; the mapping still fails
  loudly if they never appear.
- Dual-boot installs no longer fail mid-pacstrap or clobber Windows' boot. The
  `alongside` strategy reused the Windows/OEM ESP and mounted it at `/mnt/boot`,
  but that ESP is where pacstrap writes the kernel, mkinitcpio writes the
  initramfs images, and the Limine hook writes UKIs; a 100-260 MiB OEM ESP runs
  out of space (ENOSPC, "installation along windows fail"), and writing our
  `EFI/BOOT/BOOTX64.EFI` fallback there overwrites Windows' own. `lib/disk.sh`
  `alongside` now creates a DEDICATED Ryoku ESP (FAT32, GPT type EF00, partlabel
  `ryokuboot`, label BOOT) plus the Btrfs root (partlabel `ryoku`) in the largest
  free region and never touches the Windows ESP -- multiple ESPs per disk are
  valid UEFI, the NVRAM entry points at ours, and Windows keeps its own ESP +
  fallback. `lib/filesystem.sh` formats the new ESP exactly like whole-disk.
  Verified end to end against a loop-backed GPT disk with a fake Windows layout.
- `alongside` is idempotent across a retry: before measuring free space it
  reclaims any UNMOUNTED leftover partitions labeled exactly `ryoku`/`ryokuboot`
  from a previous failed run (in one atomic `sgdisk -d`, so removing one can't
  race the kernel's view of a sibling), so re-runs no longer stack partitions or
  falsely report "not enough free space". The minimum free region rose to
  `20 + swap + ESP` GiB (root floor 15 -> 20: measured base+dev+desktop closure
  plus AUR/snapshot headroom), and both new partitions keep every existing safety
  guard (pre-partition snapshot, parent-disk check, wipefs only the new ones).
- Free-space detection no longer truncates. `ryoku_largest_free_mib` parsed
  parted's MiB output through an awk `%d` cast that dropped the fraction; it now
  parses `parted unit B` in whole bytes, floors to MiB, and subtracts a 1 MiB
  alignment margin.
- A TUI retry after a failed install no longer wedges on a busy disk. The failure
  EXIT trap deliberately leaves `/mnt` mounted (for inspection), so the re-run
  began with `/mnt` and the installer's swapfile still held, and reclaim skipped
  the still-mounted leftovers. `ryoku_partition` now runs
  `ryoku_release_previous_attempt` first (swapoff `/mnt/swap/swapfile`, then
  `umount -R /mnt`). `ryoku_release_disk` also enumerates mountpoints from
  `/proc/mounts` instead of lsblk MOUNTPOINT (which prints only one per device,
  leaving a btrfs root's other subvol mounts pinning the disk) and swaps off any
  swapFILE backed by a disk mountpoint via `/proc/swaps`.
- Reclaim of leftover `ryoku`/`ryokuboot` partitions is now GATED behind
  `RYOKU_RECLAIM_LEFTOVERS=1` (the TUI's typed-ERASE ack). Without it, `alongside`
  finding such partitions dies listing them and the two ways forward instead of
  deleting what might be a healthy completed Ryoku install.
- `RYOKU_ENCRYPT=1` without `RYOKU_LUKS_PASSPHRASE` now fails in `ryoku-install`'s
  required-answers block, before any disk work, rather than after wipe + partition
  + luksFormat at `cryptsetup open` (`luks.sh` keeps the check as defense in depth).
- A `blkid` that returns nothing can no longer produce a silent unbootable
  `root=UUID=` or an unusable crypttab. `dev_uuid` fails non-zero on empty output,
  and every consumer (`ryoku_cmdline` root/LUKS UUID, `chroot.sh` crypttab) dies
  with a clear message instead of the errexit-swallowing command substitution.
- Whole-disk ESP sizing is exact: `RYOKU_ESP_GIB=1` now makes a true 1 GiB ESP
  (MiB math, `1MiB..1025MiB`), not the ~2 GiB the old `1 + RYOKU_ESP_GIB` GiB end
  produced.
- The >= 64 MiB ESP capacity check moved from the bootloader step to the end of
  `ryoku_mount` (right after the ESP mounts), so a too-small hand-built/reused ESP
  is caught before pacstrap/mkinitcpio fill `/boot`, not cryptically deep in the
  install after `/boot` is already half-written.
- `rtkit` is in `system/packages/base.packages`, so enabling `rtkit-daemon.service`
  succeeds even on an offline / `RYOKU_ONLINE=0` install (it otherwise arrived only
  with the `ryoku-desktop` umbrella, and the enable died when the desktop set was
  skipped).
- Preflight gates the real-hardware footguns before the disk is touched: it dies
  when firmware Secure Boot is on (Limine is unsigned) with "disable Secure Boot"
  guidance unless `RYOKU_ALLOW_SECUREBOOT=1`, rejects a `RYOKU_DISK` that is a
  partition rather than a whole disk (lsblk TYPE), logs the disk's logical sector
  size (`blockdev --getss`), and rounds the too-small-disk message to the nearest
  GiB.
- `lib/pacstrap.sh`: the keyring wait no longer races pacman-init. The `is-active`
  poll became a blocking `systemctl start pacman-init.service` (a oneshot's start
  returns only once it has finished), keeping the empty-keyring populate fallback.
  Broadcom wifi machines get `broadcom-wl` added to the pacstrap set when a
  `14e4:` PCI device is present (the in-kernel driver often can't associate).
- `lib/network.sh`: a dead-CMOS clock no longer breaks the install silently. When
  a mirror probe fails, `ryoku_ensure_mirrors` reads the server's clock over an
  unverified `curl -kI` and, if the system clock is off by more than a day, sets
  it from the `Date` header and re-probes once (best-effort, never aborts on its
  own), so TLS and pacman signatures stop failing on a wildly-wrong clock.
- `lib/deploy.sh`: the desktop set is now just `ryoku-keyring ryoku-desktop` --
  the `ryoku-desktop` umbrella version-pins and pulls every monorepo component, so
  an old ISO survives package renames/additions. The `pacman -S` retries once on a
  network flake, and a mismatch between the ISO's baked payload version
  (`$RYOKU_REPO/.payload`) and `pacman -Si ryoku-desktop` logs a visible warning
  (never fatal; a missing stamp is ignored).
- `lib/luks.sh`: `luksFormat` pins `--pbkdf argon2id` so a cryptsetup built with a
  different default can't silently weaken the key-derivation function.
- `lib/chroot.sh`: the hardcoded fallback `HOOKS=` line (used only when the repo
  mkinitcpio drop-in is absent) gained `resume` after `encrypt`, matching the repo
  file so hibernation resume works even on the fallback path.
- `ryoku-install`: a failed install now leaves a debuggable machine. An EXIT trap
  (acting only on a non-zero status, so a clean finish is untouched and
  `@@RYOKU_DONE` still prints only on success) names the stage that failed,
  restores the snap-pac hooks masked for the chroot, flushes to disk, LEAVES
  `/mnt` mounted, and points at `/var/log/ryoku-install.log` + `journalctl -b`.
- Hybrid NVIDIA laptops no longer produce a broken, unbootable install. The
  configure stage wrote `MODULES=(nvidia ...)` into mkinitcpio before the driver
  existed, so a driver that failed to build left the initramfs erroring with
  `module not found: nvidia` and shipped an incomplete image. `lib/chroot.sh` no
  longer writes that drop-in -- `system/hardware/drivers/nvidia.sh` writes it,
  and only when the module actually landed, so a driver that cannot build
  degrades to the integrated GPU instead of failing the whole install.
  `lib/pacstrap.sh` selects both `amd` and `intel` microcode for the
  `amd-nvidia` profile (it covers either CPU), and the install masks snap-pac's
  pacman hooks in the chroot -- they aborted with "fatal library error, lookup
  self" on every driver transaction with snapper unconfigured -- restoring them
  before it finishes.
- A dying connection fails the install before the disk is touched, not deep
  inside pacstrap. DNS was already verified, but a link can resolve names and
  still not move bytes (captive portal, half-up Wi-Fi); the first casualty is
  then a partial database sync, and pacman reports "target not found: go"
  (the first dev package) on an already-wiped disk, with stray curl failures
  around it. Preflight now probes the Arch geo mirror and repo.ryoku.dev over
  HTTP and stops with plain guidance while the disk is still intact, and
  pacstrap retries once on failure (the second run reuses the target's
  package cache) before failing with a message that names the network.
- Bluetooth actually works on installed systems: the bootloader step's service
  enable now includes `bluetooth.service` next to sddm and NetworkManager. The
  package set gained `bluez`/`bluez-utils` (system/packages), but nothing ever
  enabled the daemon, which is why the desktop's Bluetooth UI shipped dead on
  every install: no org.bluez on the bus, a silently no-op adapter toggle.
- Snapshots (and every generated kernel entry) now actually appear in the boot
  menu. The bootloader step wrote the branded config to
  `/boot/limine/limine.conf`, a location Limine scans BEFORE
  `/boot/limine.conf`, the only file `limine-entry-tool` (the stack behind
  `limine-mkinitcpio-hook` and `limine-snapper-sync`) manages, so the
  generated UKI tree and the snapper Snapshots submenu were shadowed forever
  and the firmware kept showing the frozen install-time menu. The config now
  lands at `/boot/limine.conf`, shadowing candidates are removed, and a new
  post-AUR `ryoku_bootloader_finalize` retires the flat placeholder entry and
  repoints `default_entry` at the newest UKI once the hook owns the menu.
  Existing installs are healed by the new `ryoku doctor` "limine boot menu
  layout" reconciler. Covered by `tests/limine-bootloader.sh`.
- The Limine binary the firmware boots is no longer frozen at install time.
  The EFI install used a hand-rolled path (`EFI/limine/limine.efi`) that no
  pacman hook ever refreshes; it now uses `EFI/limine/limine_x64.efi` + the
  `EFI/BOOT` fallback, exactly what `limine-install` refreshes on every
  `limine` package upgrade (and its NVRAM dedup adopts our entry instead of
  registering a second one), so the booted menu stops drifting stale against
  the installed package (old rendering, missing upstream fixes).
- The installer no longer wipes the disk before it can fetch packages.
  `pacstrap` resolves mirror hostnames, but a live box can have a default route
  (so the TUI reports "online") and still no working resolver, so the install
  partitioned the disk and then died at "Could not resolve host". A new
  `ryoku_ensure_dns` runs in preflight, before any disk write: it verifies name
  resolution, drops in public resolvers (1.1.1.1, 9.9.9.9, 8.8.8.8) when the live
  resolver is empty, and on a genuinely offline box aborts with the disk
  untouched instead of stranding a wiped disk at pacstrap. Covered by
  `tests/install-dns.sh`.
- `RYOKU_REPO` now defaults to `/usr/share/ryoku`, where `build.sh` bakes the
  repo payload, instead of the stale `/run/ryoku`. A backend launched without the
  installer session's export (a manual run, or the serial console's plain shell)
  read `/run/ryoku`, which does not exist, and died at "missing package list"
  only after the disk was already wiped. Preflight now also checks the payload
  (`system/packages/base.packages`) up front, so a missing or mispointed payload
  aborts before the wipe with the disk intact.
- `lib/mirrors.sh` ranks the package mirrors before pacstrap so a user far from
  the shipped mirrors no longer stalls the install. The static list leads with a
  CDN mirror, but a user that CDN routes badly still hit "failed retrieving
  file ... Operation too slow. Less than 1 bytes/sec", aborting pacstrap at
  "failed to install packages to new root". The new `ryoku_rank_mirrors` step
  ranks mirrors in the user's own country (resolved by IP geolocation, the same
  way chroot.sh resolves the timezone) by measured download rate, falls back to
  the fastest recent mirrors worldwide, then appends the shipped mirrors, so the
  result is never worse than what shipped. Best-effort: it keeps the shipped list
  on an offline box, a missing reflector, a failed geolocation, or a reflector
  that returns nothing. Covered by
  `tests/install-mirrors.sh`.
- `lib/luks.sh` + `lib/disk.sh` make the install idempotent across a retry. A
  `/dev/mapper/root` left open by an earlier failed run (or a retry in the same
  live session) made `cryptsetup open ... root` abort with "Device root already
  exists", stranding the install at the encryption step even on a fresh ISO. A
  new `ryoku_free_mapper` frees the name however it is held (unmount, `swapoff -a`
  for a swapfile that pins the mapper, then close), called before the wipe and
  again before the LUKS open, so neither step trips on a stale mapper. Covered by
  `tests/install-disk-teardown.sh`.
- The install now fails closed on disk destruction. `ryoku-install` and
  `lib/disk.sh` reject an empty or unknown `RYOKU_DISK_STRATEGY` instead of
  defaulting to `whole` (the old default silently wiped the disk when the TUI
  dropped the pick, deleting a user's Windows). `ryoku_partition_whole` refuses to
  zap a disk that already holds partitions unless `RYOKU_WIPE_CONFIRMED=1` is set;
  a truly blank disk still installs without it.
- `lib/disk.sh` `alongside` now proves it never touches an existing partition: it
  snapshots the pre-existing partition set, requires the new root's number to be
  strictly higher than every existing one, and asserts the created root is new and
  is neither the disk nor the reused ESP (parent matching the target disk) before
  any `wipefs`.
- `lib/luks.sh` hard-asserts the root partition is set and is neither the whole
  disk nor the ESP before `luksFormat`, so encryption can never reformat an
  existing OS partition or the shared ESP.
- `lib/deploy.sh`: chown the user's home before the qylock step (it ran after),
  so qylock's user-context writes no longer fail on root-seeded directories like
  `~/.local/share` (`cp: cannot create directory ...: Permission denied`, which
  aborted the install). Surfaced by a full qemu install test.

### Added
- `lib/disk.sh`: the `alongside` disk strategy for dual-booting. It keeps every
  existing partition and, in the largest contiguous free region, creates a
  dedicated Ryoku ESP + Btrfs root (needs GPT and >= `20 + swap + ESP` GiB free).
  The existing/Windows ESP is never reused or mounted. `whole` still wipes and
  lays a fresh GPT. Replaces the earlier abort that only accepted `whole`.
- `lib/bootloader.sh`: under `alongside`, add a Limine `efi_chainload` entry for
  an existing Windows install on the reused ESP, and register the bootloader
  with the ESP's real partition number (not a hardcoded 1).
- `lib/filesystem.sh`: `alongside` formats its own dedicated ESP (FAT32, label
  BOOT) exactly like `whole`; the existing/Windows ESP is left untouched.
- `lib/common.sh`: `part_num` helper, the inverse of `part_dev`, returns a
  partition device's trailing number.
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
  Required`, `Server = https://repo.ryoku.dev/stable/$arch`) to the target, copies the
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
