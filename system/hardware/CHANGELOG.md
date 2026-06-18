# Changelog: system/hardware/

## Unreleased

### Added
- `gpu/ryoku-gpu`: ranks every DRM GPU (eGPU over discrete over integrated, then
  by VRAM) and pins the strongest as Hyprland's primary renderer. Subcommands
  `detect`, `order`, `persist`, `disable`, `install-udev`, `status`. Pins the
  discrete GPU on desktops and external GPUs anywhere; keeps the iGPU primary on
  laptops for battery (override with `RYOKU_GPU_FORCE=1`). Writes a Lua drop-in
  (`~/.config/hypr/gpu.lua`) using the `hl` API.
- `gpu/ryoku-gpu-detect`: sourced detection helpers (GPU records, VRAM recovery,
  classification, laptop vs desktop). NVIDIA is always discrete; an AMD/Intel APU
  is integrated when its VRAM is a fully CPU-visible UMA carveout at or under
  8 GiB; a discrete card needs at least 2 GiB. Override seams make it testable
  against a synthesized `/sys` tree.
- `gpu/90-ryoku-gpu.rules`: udev rule creating boot-stable, colon-free
  `/dev/dri/ryoku-gpu-<pci-slot>` symlinks so `AQ_DRM_DEVICES` can reference GPUs
  by slot.
- `display/ryoku-monitor`: DPI-derived per-monitor scaling (buckets at 1x, 1.25,
  1.5, 1.75, 2x) with `GDK_SCALE` kept in step (integer only when every monitor
  agrees on a whole scale of 2 or more, else 1). `autoscale` applies live through
  `hyprctl` and writes `~/.config/hypr/monitors.lua`; `persist` saves the current
  layout. Catch-all monitor rule written last for hotplug.
- `power/ryoku-hw-laptop`: shared laptop/desktop detector using DMI chassis type,
  battery presence, and lid switches.
- `power/ryoku-idle`: laptop-only `hypridle` launcher for Ryoku's dim, lock,
  display-off, and suspend policy.
- `drivers/nvidia.sh`, `drivers/intel.sh`, `drivers/amd.sh`, `drivers/vulkan.sh`:
  per-vendor, hardware-gated, idempotent install scripts with a `RYOKU_DRYRUN=1`
  print mode. NVIDIA uses the open modules on Turing and newer and the
  proprietary modules otherwise.

### Fixed
- `drivers/nvidia.sh`: also write the early-KMS modprobe option
  (`nvidia_drm modeset=1`) and the initramfs `MODULES`, which are mandatory for a
  working NVIDIA Wayland session. Detection-gated, so they apply whenever an
  NVIDIA GPU is present, not only on the amd-nvidia profile.
- `gpu/ryoku-gpu`: let shellcheck follow the sourced detect helper from any cwd.
- `power/ryoku-idle`: ignore defunct `hypridle` zombies when deciding whether the
  idle daemon is already running, so a dead first start cannot block a restart.
