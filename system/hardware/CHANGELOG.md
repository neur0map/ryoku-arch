# Changelog: system/hardware/

## Unreleased

### Added
- `display/ryoku-monitor`: a GUI/profile surface for Ryoku Settings. `list` prints
  the connected monitors (identity, modes, layout) as JSON; `apply JSON` applies an
  explicit layout live and persists it with the chosen modes (not highrr); `save
  NAME JSON`/`load NAME`/`profiles`/`rm NAME` manage named layout profiles under
  `~/.config/ryoku/monitors/`. Profiles match on monitor hardware identity
  (make|model|serial), so they survive connector renames, and `autoscale` applies
  a matching profile at login/hotplug, falling back to DPI scaling when none fits
  (`--no-profile` forces DPI). Fixture mode (`RYOKU_MONITOR_JSON`) now skips the
  hyprctl requirement so the path is testable without a live compositor.
- `display/ryoku-monitor`: `mirror`, `extend`, and `toggle` subcommands to
  duplicate displays or lay them side by side (driven by `Super + P`). Live
  changes now go through `hyprctl eval` (the `hl.monitor` API), since the Lua
  config manager rejects `hyprctl keyword`; this also makes `autoscale` apply
  scaling live, including on hotplug, instead of only on the next login.
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
- `leds/ryoku-leds`: reads the current wallust Hyprland palette and applies the
  active accent to OpenRGB-compatible keyboards and attached lighting devices via
  generic OpenRGB mode/color controls. Missing or unsupported RGB hardware is
  non-fatal.
- `audio/ryoku-mic`: caps the default microphone at its Base Volume (0 dB
  hardware gain) so codecs that map a 100% source to maximum analog gain do not
  clip speech into distortion. Reads the level from the device and only lowers an
  over-amplified mic, never raising a quiet one. Launched from Hyprland autostart.
- `drivers/nvidia.sh`, `drivers/intel.sh`, `drivers/amd.sh`, `drivers/vulkan.sh`:
  per-vendor, hardware-gated, idempotent install scripts with a `RYOKU_DRYRUN=1`
  print mode. NVIDIA uses the open modules on Turing and newer and the
  proprietary modules otherwise.

### Fixed
- `display/ryoku-monitor`: write each output's refresh as `highrr` instead of the
  live rate, and settle the refresh after applying scale. A panel whose
  DisplayPort link first comes up at a low refresh (common on a discrete GPU at
  cold boot) no longer has that low rate captured back into the drop-in and locked
  in; every monitor now holds its highest refresh across reboots.
- `display/ryoku-monitor`: `autoscale` now lays the displays in one flush,
  non-overlapping row. It applies each scale first (Hyprland snaps a scale to one
  that yields whole logical pixels, so 1.5 on a 2560 panel becomes 1.6), then
  positions every output from the accepted logical widths rather than the live or
  "auto" x. A freshly plugged display lands exactly beside the laptop instead of
  overlapping it, which a stale position could do once the scales differed.
- `drivers/nvidia.sh`: also write the early-KMS modprobe option
  (`nvidia_drm modeset=1`) and the initramfs `MODULES`, which are mandatory for a
  working NVIDIA Wayland session. Detection-gated, so they apply whenever an
  NVIDIA GPU is present, not only on the amd-nvidia profile.
- `gpu/ryoku-gpu`: let shellcheck follow the sourced detect helper from any cwd.
- `power/ryoku-idle`: ignore defunct `hypridle` zombies when deciding whether the
  idle daemon is already running, so a dead first start cannot block a restart.
