# installation/backend/lib/

The install steps, sourced by `ryoku-install`. Each file owns one concern and
exposes the functions the orchestrator calls in order. Every destructive or
system command routes through the `run` / `run_sh` / `run_secret` wrappers in
`common.sh`, so `RYOKU_DRYRUN=1` prints the whole plan without touching a disk.

## Per-file reference

The **sentinel** column is the `@@RYOKU_STEP <id>` the TUI watches while the
file's functions run; `-` means the file runs outside a sentinelled stage
(a helper library, a preflight gate, or a post-stage step).

| File | Sentinel | What it does | What it writes | Failure behavior |
|---|---|---|---|---|
| `common.sh` | - | `log`/`step`/`die`, the `run`/`run_sh`/`run_secret` dry-run wrappers, `write_file`/`append_file`/`deploy_dir`, and the `part_dev`/`part_num`/`dev_uuid` device helpers. | Nothing of its own; `write_file` writes the caller's target. | Library. `die` aborts non-zero; `run` prints under dry-run. |
| `preflight.sh` | `preflight` | Gates before any disk write: root, UEFI, Secure Boot off, `RYOKU_DISK` a whole disk >= 32 GiB, the repo payload present. | Nothing. | Fatal `die` with firmware/guidance text; dry-run narrates and returns. |
| `disk.sh` | `partition` | Partitions the target: `whole` (wipe, fresh GPT ESP + root) or `alongside` (dedicated Ryoku ESP + root in the largest free region, Windows ESP untouched); frees a busy disk, wipes stale signatures, measures free space. | GPT table on `RYOKU_DISK`; sets `ESP_DEV` / `ROOT_PART`. | Fatal. Hard safety proves each new partition before any `wipefs`/`mkfs` and aborts otherwise. |
| `luks.sh` | `partition` | Optional LUKS2 on the root partition; opens it as `/dev/mapper/root`. | LUKS2 header on `ROOT_PART` (when encrypting); sets `ROOT_DEV` / `LUKS_PART`. | Fatal `die` on a missing passphrase or an unsafe `ROOT_PART`. |
| `filesystem.sh` | `filesystems`, `mount` | `mkfs.vfat` the ESP + `mkfs.btrfs` root, create the subvolumes, mount them under `/mnt`, build the optional swapfile in `@swap`. | Filesystems on `ESP_DEV`/`ROOT_DEV`, the `/mnt` mounts, `/mnt/swap/swapfile`. | Fatal. |
| `pacstrap.sh` | `pacstrap` | Assembles the package set (base + profile hardware + dev + Broadcom when a `14e4:` device is present), waits on the keyring, `pacstrap -K`, writes `fstab`. On failure regenerates the mirrorlist from the next tier and retries once with `--needed`. | The base system into `/mnt`; `/mnt/etc/fstab`. | Fatal `die` only after the `--needed` retry also fails (message lists the tiers tried + the failing mirror URL). |
| `mirrors.sh` | `pacstrap` | Bounded four-tier mirror prep before `pacstrap`: reflector, else the mirror-status API, else the shipped list, plus emergency mirrors appended to every tier; also sets `ParallelDownloads` + `DisableDownloadTimeout` in the install-time `pacman.conf`. | The live `/etc/pacman.d/mirrorlist` and `/etc/pacman.conf`, in place. | Best-effort; never aborts. Any failure keeps the shipped list. |
| `chroot.sh` | `configure` | In-target config: locale, keymap, timezone, hostname, user, sudo, initramfs `HOOKS`, crypttab; masks + restores the snap-pac pacman hooks that abort in a chroot. | `/mnt/etc/*` (`locale.conf`, `vconsole.conf`, `hostname`, the user, `sudoers.d`, `mkinitcpio.conf.d/ryoku.conf`, `crypttab`). | Fatal for config; the hook mask/restore is best-effort. |
| `deploy.sh` | `configure` | Adds `[ryoku]`, copies the live mirrorlist, imports the release key, `pacman -S ryoku-keyring ryoku-desktop`, runs `ryoku materialize`, seeds the unpackaged bits (brand assets, wallpapers, `~/.npmrc`, editor defaults, qylock + SDDM theme). | `/mnt/etc/pacman.conf`, the target keyring, the desktop packages, `~/.config`, the seeds. | Online: a failed desktop install is fatal (there is no CLI to recover with). Offline: skipped. Keyring/seed steps best-effort. |
| `network.sh` | `configure`, `preflight` | Carries the live wifi into the target (iwd backend pin + `.nmconnection` keyfiles); and, at preflight, gates DNS and HTTP reach before the disk is touched. | `/mnt/etc/NetworkManager/conf.d` + `system-connections`; the live resolver (heal only). | `ryoku_network` best-effort; `ryoku_ensure_dns`/`ryoku_ensure_mirrors` are fatal at preflight (before the disk), by design. |
| `drivers.sh` | `configure` | Copies each per-vendor GPU driver script into the target and runs it in the chroot; the scripts self-gate on the detected GPU and are idempotent. | Driver packages + (via `nvidia.sh`) the NVIDIA early-KMS `MODULES` drop-in. | Fatal wrapper, but the scripts self-gate so running all of them is safe. |
| `bootloader.sh` | `bootloader` (+ post-AUR finalize) | Installs and brands Limine, builds the kernel cmdline, writes the ESP-root `limine.conf`, drops the Limine EFI binary + registers NVRAM, adds a Windows chainload entry, and after the AUR step repoints the menu at the tool-managed UKI tree. | `/mnt/boot/limine.conf`, `/etc/default/limine`, `mkinitcpio.conf.d/ryoku-vmd.conf`, the EFI binaries, the NVRAM entry. | Fatal for the core install; `efibootmgr` and the ESP >= 64 MiB path are best-effort; `finalize` is atomic file surgery. |
| `aur.sh` | - | Bootstraps `yay` (AUR clone, else the GitHub release binary), builds `aur.packages` as the unprivileged user. | The AUR packages; a transient NOPASSWD sudoers drop-in + `resolv.conf`, both removed after. | Best-effort: always returns 0. Offline or a failed build is a warning. |
| `snapshots.sh` | - | Snapper `root` config (written by hand, no `snapperd`), snap-pac registration, the cleanup timer, `limine-snapper-sync`. | `/mnt/etc/snapper/configs/root`, `/etc/conf.d/snapper`, the service enables. | Best-effort; `limine-snapper-sync` enable warns if absent. No `@snapshots` subvol = no-op. |

## Wave-2/3 helpers, by owning file

- **reclaim** -- `disk.sh` `ryoku_reclaim_leftovers`: before measuring free space,
  `alongside` deletes any *unmounted* partitions labeled exactly `ryoku`/`ryokuboot`
  from a prior failed run, in one atomic `sgdisk -d`, so retries never stack.
- **secureboot** -- `preflight.sh` `ryoku_secureboot_enabled`: reads the last byte
  of the `SecureBoot` efivar; preflight dies when it is on (Limine is unsigned)
  unless `RYOKU_ALLOW_SECUREBOOT=1`.
- **clock-skew** -- `network.sh` `ryoku_fix_clock_skew`: when a mirror probe fails,
  reads the server clock over an unverified `curl` and, if the system clock is off
  by more than a day, sets it from the `Date` header and re-probes (best-effort).
- **vmd** -- `bootloader.sh` `ryoku_boot_vmd`: when the live kernel has the Intel
  VMD module loaded (`/sys/module/vmd`), writes `MODULES+=(vmd)` into the target
  initramfs so the installed system can still find its NVMe at boot.
- **resume** -- `bootloader.sh` `ryoku_cmdline` and `chroot.sh` `ryoku_cfg_initramfs`:
  with a swapfile, adds `resume=`/`resume_offset=` to the cmdline and the `resume`
  hook after `encrypt` in `HOOKS`, so hibernation works.

## Trap and failure protocol

`ryoku-install` sets an EXIT trap that acts only on a non-zero status (a clean
finish is untouched, and `@@RYOKU_DONE` still prints only on success). On failure
it names the stage from `RYOKU_STAGE` (which `step` records), restores the masked
snap-pac hooks, flushes to disk, and -- unlike the clean path -- **leaves `/mnt`
mounted** so the partial tree and `/var/log/ryoku-install.log` can be inspected.
