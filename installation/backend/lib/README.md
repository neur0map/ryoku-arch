# installation/backend/lib/

The install steps, sourced by `ryoku-install`. Each file owns one concern and
exposes the functions the entrypoint calls in order.

- `common.sh` Shared helpers: `log` / `step` / `die`, the `run` and `run_sh`
  dry-run wrappers, `run_secret` (redacts stdin secrets), `write_file`,
  `append_file`, `deploy_dir`, and the `part_dev` / `part_num` / `dev_uuid`
  device helpers.
- `preflight.sh` Root, UEFI, and disk-size (>= 32 GiB) checks.
- `disk.sh` GPT partitioning: `whole` (wipe the disk, ESP plus a root that takes
  the rest) or `alongside` (reuse the existing ESP, root in the largest free
  region) for dual-booting Windows.
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
- `bootloader.sh` Limine install and branding: `/boot/limine.conf` (the ESP
  root, the one location `limine-entry-tool` manages; shadowing candidates
  are removed), the EFI binary on the tool-refreshed
  `EFI/limine/limine_x64.efi` path, the initramfs build, the kernel cmdline,
  and enabling services. `ryoku_bootloader_finalize` (after the AUR step)
  retires the flat placeholder entry once `limine-mkinitcpio-hook` owns the
  menu.
- `snapshots.sh` Btrfs snapshots (runs after the AUR step): a snapper `root`
  config, snap-pac registration, the snapper cleanup timer, and
  `limine-snapper-sync` for snapshot boot entries.
