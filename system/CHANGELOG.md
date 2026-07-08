# Changelog: system/

## Unreleased

### Fixed
- `boot/limine/default.conf`: `MAX_SNAPSHOT_ENTRIES` now matches snapper's
  `NUMBER_LIMIT` (10). At 5 every limine-snapper-sync run warned about the
  snapshots it could not list, and the boot menu showed half the rollback
  depth the retention policy keeps.

### Added
- `extras/ryoku-extras-install`: `plugin` bundle items now install (fetched into
  `~/.local/share/ryoku/plugins` via `ryoku-hub extras plugin`) instead of being
  deferred, and report real present/absent state. Removal deletes the plugin's
  files while leaving the user's placement in `plugins.json`.
- `packages/`: base, hardware (per-vendor GPU drivers and microcode), aur, and dev
  package lists.
- `boot/`: Limine config with Ryoku branding, the Plymouth theme, and the
  mkinitcpio hooks.
- `hardware/`: `ryoku-gpu` (picks and pins the strongest GPU), `ryoku-monitor`
  (HiDPI autoscale), the GPU udev rule, and per-vendor driver scripts. GPU and
  monitor settings are written as Hyprland Lua drop-ins.
- `extras/`: the helpers behind the Hub's Extras section (`ryoku-extras-install`
  and the `ryoku-pkg-*` routing wrappers) that install, remove, and report the
  optional bundles from the `ryoku-extras` catalogue.

### Fixed
- `hardware/drivers/nvidia.sh`: keeps an already-installed NVIDIA module
  package instead of forcing a -dkms one next to it. CachyOS ships
  kernel-matched prebuilt modules (`linux-cachyos-nvidia-open`) that conflict
  with `nvidia-open-dkms`, so the old behaviour aborted the whole transaction
  under `--noconfirm`. The initramfs pacman hook also lost its
  `Depends=mkinitcpio` and now probes for limine-mkinitcpio, mkinitcpio, or
  dracut, and prebuilt module packages join its trigger list.
- `hardware/display/ryoku-monitor`: autoscale picked absurd scales inside
  virtual machines. A hypervisor fabricates the guest display's EDID, so the
  px/mm density math ran on fiction (a plausible fake physical size sails past
  the existing zero/absurd-DPI guards straight into the 1.25-2.0 buckets).
  Autoscale now pins the 1x bucket for every output of a VM guest
  (`systemd-detect-virt --vm`) and for `Virtual-*` connectors on bare metal;
  the host window does the real scaling anyway. `RYOKU_MONITOR_VM` overrides
  detection for tests, and `monitors_user.lua` pins still win as before.
- `hardware/gpu/ryoku-gpu-detect`: GPU detection could hang indefinitely. It
  reads NVIDIA VRAM from `nvidia-smi` (and model names from `lspci`), and a
  runtime-suspended or wedged GPU can make `nvidia-smi` block forever, stalling
  `ryoku-gpu detect` and every caller (including the Hub GPU page). The host
  probes now run once, in parallel, under a hard `timeout` (8s default, override
  with `RYOKU_GPU_PROBE_TIMEOUT`): a single pass covers every GPU, so the wait is
  one window instead of one per card and the budget can be generous without
  serialising. A probe that times out degrades to no VRAM/model rather than
  hanging; the GPU is still detected and classified.
