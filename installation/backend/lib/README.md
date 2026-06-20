# installation/backend/lib/

The install steps, sourced by `ryoku-install`. Each file owns one concern and
exposes the functions the entrypoint calls in order.

- `common.sh` Shared helpers: `log` / `step` / `die`, the `run` and `run_sh`
  dry-run wrappers, `run_secret` (redacts stdin secrets), `write_file`,
  `append_file`, `deploy_dir`, and the `part_dev` / `dev_uuid` device helpers.
- `preflight.sh` Root, UEFI, and disk-size (>= 32 GiB) checks.
- `disk.sh` GPT partitioning: ESP plus a root partition (whole-disk strategy).
- `luks.sh` Optional LUKS2 encryption of the root partition.
- `filesystem.sh` mkfs for the ESP and Btrfs, the subvolume layout, mounting,
  and the optional swapfile.
- `pacstrap.sh` Installs the base system and writes `fstab`.
- `chroot.sh` In-target config: locale, keymap, timezone, hostname, user, sudo,
  initramfs HOOKS, and crypttab.
- `deploy.sh` Desktop install (runs in the `configure` stage): add the `[ryoku]`
  repo, trust its key, `pacman -S` the Ryoku packages, run `ryoku materialize`,
  then seed the unpackaged bits (brand assets, wallpapers, `~/.npmrc`, the editor
  defaults, and the qylock + SDDM theme).
- `bootloader.sh` Limine install and branding, the initramfs build, the kernel
  cmdline, and enabling services.
- `snapshots.sh` Btrfs snapshots (runs after the AUR step): a snapper `root`
  config, snap-pac registration, the snapper cleanup timer, and
  `limine-snapper-sync` for snapshot boot entries.
