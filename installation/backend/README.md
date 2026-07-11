# installation/backend/

`ryoku-install` is the script that actually installs Ryoku. The TUI collects the
answers, exports them as `RYOKU_*` environment variables, and runs this backend.
There is no archinstall and no JSON config: just plain bash doing the steps in
order, so you can read the whole thing top to bottom and follow exactly what
happens to the disk.

## Running it

```
RYOKU_DISK=/dev/nvme0n1 RYOKU_DISK_STRATEGY=whole \
RYOKU_HOSTNAME=ryoku RYOKU_USERNAME=ryo \
RYOKU_PASSWORD_HASH="$(openssl passwd -6)" \
RYOKU_KEYMAP=us RYOKU_LOCALE=en_US.UTF-8 RYOKU_TIMEZONE=Europe/Madrid \
RYOKU_PROFILE=amd-nvidia \
./ryoku-install
```

It must run as root, on a UEFI machine with Secure Boot disabled, against a whole
disk of at least 32 GiB, with a working network connection (the install is
online-only). Set `RYOKU_ALLOW_SECUREBOOT=1` only if you have enrolled your own
keys -- Limine ships unsigned and will not boot under enforced Secure Boot.

## Dry run

Set `RYOKU_DRYRUN=1` and nothing is written. Every destructive or system command
is printed with a `DRYRUN:` prefix instead of being run, and file writes show the
content they would produce. Preflight reports its checks and returns rather than
probing real hardware, so the full flow can be exercised on any machine without a
target disk. Secrets (the LUKS passphrase, the password hash) are never printed,
even in dry-run.

```
RYOKU_DRYRUN=1 RYOKU_DISK=/dev/vda RYOKU_DISK_STRATEGY=whole RYOKU_HOSTNAME=ryoku RYOKU_USERNAME=ryo \
RYOKU_PASSWORD_HASH=x RYOKU_KEYMAP=us RYOKU_LOCALE=en_US.UTF-8 \
RYOKU_TIMEZONE=UTC RYOKU_PROFILE=vm RYOKU_REPO=/path/to/repo ./ryoku-install
```

## The RYOKU_* contract

Required:

| Variable              | Meaning                                                     |
|-----------------------|------------------------------------------------------------|
| `RYOKU_DISK`          | Target block device, e.g. `/dev/nvme0n1` or `/dev/sda`.    |
| `RYOKU_PASSWORD_HASH` | `openssl passwd -6` hash of the user password (no plaintext). |
| `RYOKU_DISK_STRATEGY` | `whole` (wipe the disk) or `alongside` (dual-boot; dedicated Ryoku ESP). No default: an empty value aborts rather than risk a silent wipe. |

With defaults:

| Variable                  | Default            | Meaning                                  |
|---------------------------|--------------------|------------------------------------------|
| `RYOKU_HOSTNAME`          | `ryoku`            | Hostname.                                |
| `RYOKU_USERNAME`          | `ryoku`            | Primary user (wheel, login shell fish).  |
| `RYOKU_KEYMAP`            | `us`               | Console keymap (`vconsole.conf`).        |
| `RYOKU_LOCALE`            | `en_US.UTF-8`      | Locale (`locale.gen` + `locale.conf`).   |
| `RYOKU_TIMEZONE`          | `UTC`              | `Region/City`, or `auto` (ipinfo.io).    |
| `RYOKU_PROFILE`           | `vm`               | `amd-nvidia` \| `amd` \| `intel` \| `vm`. |
| `RYOKU_ESP_GIB`           | `1`                | ESP size in GiB.                         |
| `RYOKU_SWAP_GIB`          | `0`                | Swapfile size in GiB (0 disables it).    |
| `RYOKU_SUBVOL_SNAPSHOTS`  | `1`                | Create `@snapshots` -> `/.snapshots`.    |
| `RYOKU_SUBVOL_HOME`       | `1`                | Create `@home` -> `/home`.               |
| `RYOKU_SUBVOL_BACKUPS`    | `0`                | Create `@backups` -> `/.backups`.        |
| `RYOKU_REPO`              | `/usr/share/ryoku` | Repo payload on the live system.         |
| `RYOKU_ONLINE`            | `1`                | Pacstrap from network mirrors.           |

Encryption (set together):

| Variable                | Meaning                                              |
|-------------------------|-----------------------------------------------------|
| `RYOKU_ENCRYPT`         | `1` to encrypt root with LUKS2.                     |
| `RYOKU_LUKS_PASSPHRASE` | The LUKS passphrase (required when encrypting).     |

Other (all optional, env-only):

| Variable                  | Meaning                                                              |
|---------------------------|----------------------------------------------------------------------|
| `RYOKU_GPU_MODE`          | Hybrid-GPU render mode, **consumed** after driver install: `offload` (iGPU-first default), `sync` (pin the dGPU as primary), `vfio` (pin the iGPU alone, freeing the dGPU for a VM). Applied with `ryoku-gpu mode` to the user's `~/.config/hypr/gpu.lua`. Empty leaves Hyprland's own selection. |
| `RYOKU_RECLAIM_LEFTOVERS` | `1` lets `alongside` DELETE *unmounted* partitions labeled exactly `ryoku`/`ryokuboot` (leftovers of a prior failed run). Without it, finding such partitions aborts the install (they may be a working Ryoku install). The TUI sets it after the typed `ERASE` ack. |
| `RYOKU_WIPE_CONFIRMED`    | `1` lets `whole` wipe a non-empty disk (the TUI's typed `ERASE` ack). |
| `RYOKU_REBOOT`            | Non-empty reboots after a successful install.                        |
| `RYOKU_SKIP_AUR`          | Skip the optional AUR set (unattended / CI install).                 |
| `RYOKU_ALLOW_SECUREBOOT`  | `1` to install despite firmware Secure Boot being on (Limine is unsigned). |
| `RYOKU_DRYRUN`            | Print destructive commands instead of running them (see Dry run).    |

## Disk strategies

`RYOKU_DISK_STRATEGY` picks how the target is laid out:

- `whole` wipes the disk and writes a fresh GPT: a `RYOKU_ESP_GIB` GiB ESP
  (FAT32, label `BOOT`) plus a Btrfs root taking the rest. A disk that already
  holds partitions needs `RYOKU_WIPE_CONFIRMED=1` (the TUI sets it after the
  typed `ERASE` ack); a blank disk installs without it.
- `alongside` keeps every existing partition (e.g. a Windows install) and never
  reuses or mounts the existing/Windows ESP. In the largest contiguous free
  region it creates a *dedicated* Ryoku ESP (`RYOKU_ESP_GIB` GiB, FAT32, GPT
  type EF00, partlabel `ryokuboot`, label `BOOT`) followed by the Btrfs root
  (partlabel `ryoku`). Multiple ESPs per disk are valid UEFI: the NVRAM entry
  points at ours, and Windows keeps its own ESP + fallback loader. Partitions
  labeled exactly `ryoku`/`ryokuboot` (leftovers of a prior failed run) abort
  the install unless `RYOKU_RECLAIM_LEFTOVERS=1` (the TUI's typed `ERASE` ack) is
  set, which deletes the *unmounted* ones so re-runs never stack partitions; a
  mounted one is always left alone.

  Minimum free region for `alongside` is `20 + RYOKU_SWAP_GIB + RYOKU_ESP_GIB`
  GiB -- a 20 GiB root floor covers the base + dev + desktop closure with headroom
  for AUR builds and snapshots. Make room first by shrinking Windows.

## Install is online-only

There is no offline package source: the base system, the desktop, and the dev
toolchains all download from the network mirrors and the signed `[ryoku]` repo.
The installer probes DNS and HTTP reach *before* the disk is touched and fails
early with plain guidance if it cannot reach them (a dead-CMOS clock that breaks
TLS is auto-corrected from the mirror's own clock). `RYOKU_ONLINE=0` exists only
for the backend's own tests, not for a real install.

## Progress protocol

The backend streams its log to stdout. To drive the staged rows in the TUI it
also prints sentinel lines:

```
@@RYOKU_STEP <id>
```

at the start of each stage, with `<id>` in order: `partition`, `filesystems`,
`mount`, `pacstrap`, `configure`, `bootloader`. On success it prints
`@@RYOKU_DONE` and exits 0. On any failure it exits non-zero without printing
`@@RYOKU_DONE`.

## Layout

`ryoku-install` is the entrypoint; it sets defaults, validates the required
variables, prints the sentinels, and calls the stage functions in order. The
stages live in `lib/`, split by concern (see `lib/README.md`). The `configure`
stage runs two: the chroot config (`chroot.sh`) then the desktop install
(`deploy.sh`: add the `[ryoku]` repo, `pacman -S` the Ryoku packages, then
`ryoku materialize`), both under the one `configure` sentinel. After the
bootloader and AUR steps, `ryoku_bootloader_finalize` promotes the Limine menu
to the tool-managed UKI tree (when `limine-mkinitcpio-hook` landed), then
`snapshots.sh` wires up Btrfs snapshots (snapper `root`, snap-pac,
`limine-snapper-sync`).

## What it consumes from the repo

At `$RYOKU_REPO` the backend reads:

- `system/packages/base.packages` for the pacstrap set, plus the matching
  section of `system/packages/hardware.packages` for microcode and GPU drivers.
- `system/boot/limine/limine.conf` (branding) and `default.conf` (cmdline
  template with the `@@CMDLINE@@` token), `system/boot/mkinitcpio/ryoku.conf`
  (HOOKS drop-in), and `system/boot/plymouth/ryoku/` (the splash theme). Each
  has a built-in fallback so a dry run works even before those files exist.
- During the `configure` stage (after the chroot config, no separate sentinel) it
  installs the Ryoku desktop from the signed `[ryoku]` pacman repository: it adds
  `[ryoku]` to the target `pacman.conf`, copies the live mirrorlist in, imports the
  release key from `release/packages/ryoku-keyring` (`pacman-key --populate ryoku`),
  `pacman -S`es the desktop set (`ryoku-keyring ryoku-desktop` -- the ryoku-desktop
  umbrella version-pins and pulls every monorepo component), then runs `ryoku
  materialize` as the user to lay
  `~/.config` from `/usr/share/ryoku/config`. A few unpackaged bits are still
  seeded from the payload: the brand assets, the wallpaper collection,
  `ryoku/apps/npm/npmrc`, the neovim `.desktop`/mimeapps editor defaults, and the
  qylock bundle plus `ryoku/lockscreen/{sddm/setup,install-qylock}` (run in the
  chroot); the home is then chowned. Online-gated and best-effort; `RYOKU_DRYRUN`
  is passed through and missing sources are skipped.

The backend enables `sddm`, `NetworkManager`, `bluetooth`, and `rtkit-daemon`.
When `RYOKU_GPU_MODE` is set it applies the pick once here via `ryoku-gpu mode`
(writing the user's `hypr/gpu.lua`); first-login autostart otherwise runs
`ryoku-gpu persist` and `ryoku-monitor`, so those are not run here.
