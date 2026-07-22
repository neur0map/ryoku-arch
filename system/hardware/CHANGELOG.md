# Changelog: system/hardware/

## Unreleased

### Added
- `ddc/`: external-monitor brightness over DDC/CI. `ryoku-i2c.conf` loads the
  `i2c-dev` module (`/etc/modules-load.d/`) so `ddcutil` can open `/dev/i2c-*`, and
  `60-ryoku-i2c.rules` grants the active-session user access (`uaccess`, no group
  setup). Drives the pill DISPLAY faders and the new `XF86MonBrightness` keys
  (`ryoku-cmd-brightness`). Shipped to `/etc` + `/usr/lib/udev` by `ryoku-desktop`.

### Security
- `display/ryoku-monitor`: `apply_specs` now renders monitor string fields
  (`output`, `mode`, `position`, `mirror`) through jq's `@json`, which emits a
  properly escaped quoted literal, before interpolating them into the
  `hl.monitor({ ... })` Lua passed to `hyprctl eval`. The incoming layout JSON
  (from a saved profile or the Hub) could otherwise carry a value with an
  embedded `"` that broke out of the Lua string and injected code into the
  eval. Connector names from the kernel can't contain quotes, so the live path
  was not reachable, but user-supplied profile JSON is; the escape closes it
  with no behaviour change (empty/absent fields still render as `""`).

### Added
- `power/ryoku-clamshell`: macOS-style clamshell (closed-lid) mode for laptops.
  A laptop-only daemon (autostarted from Hyprland, like `ryoku-idle`) holds a
  systemd `handle-lid-switch` inhibitor while the machine is on AC power AND an
  external display is connected, so closing the lid keeps the session running on
  the external instead of suspending; it drops the inhibitor (and suspends if the
  lid is already shut) the moment either condition is lost. The `lid` subcommand,
  driven by the Hyprland lid-switch bind (`hypr/modules/lid.lua`), blanks the
  internal panel on close when an external is present and restores the layout on
  open. Event-driven via `udevadm monitor` (power_supply + drm), no polling.
- `power/logind-ryoku-lid.conf`: a logind drop-in (shipped by `ryoku-desktop` to
  `/etc/systemd/logind.conf.d/10-ryoku-lid.conf`) that sets `HandleLidSwitch`,
  `HandleLidSwitchExternalPower`, and `HandleLidSwitchDocked` all to `suspend`, so
  logind suspends on lid close in every case and `ryoku-clamshell` is the sole
  thing that keeps a closed lid awake -- power AND an external display, matching
  macOS (the default `docked=ignore` would keep it awake on battery too).
- `display/ryoku-monitor`: the Settings paths carry per-output colour management.
  `list` reports each monitor's `cm` (from Hyprland's `colorManagementPreset`,
  normalised to srgb/wide/hdr) and its SDR brightness; `apply`/`save`/`load` write
  `cm` with the bit depth it implies (sRGB -> 8-bit, Wide/HDR -> 10-bit) and, in
  HDR, `sdrbrightness`, into the `hl.monitor({ ... })` calls and the persisted
  layout. The colour spec is written on every enabled monitor rather than omitted
  at its default, so switching a display out of HDR live actually clears the
  10-bit / raised-brightness state instead of leaving it stuck. Covered by
  `tests/monitor-profiles.sh`.
- `gpu/ryoku-gpu-lib32`: installs the 32-bit (lib32) GPU userspace for the
  detected hardware, so 32-bit and Proton/DXVK games render on the real GPU
  instead of falling back to software. The base install and the 64-bit driver
  scripts are multilib-free; this runs after `[multilib]` is enabled (the Gaming
  bundle orders its `requires` as multilib, then gpu-lib32) and, reusing
  `ryoku-gpu-detect`, maps each GPU's loaded DRM driver to its Vulkan ICD
  (`amdgpu`/`radeon` -> `lib32-vulkan-radeon`, `i915`/`xe` ->
  `lib32-vulkan-intel`, `nvidia` -> `lib32-nvidia-utils`, `nouveau` ->
  `lib32-vulkan-nouveau`) on a `lib32-mesa` + `lib32-vulkan-icd-loader`
  baseline. A hybrid box gets both ICDs, Mesa once. Idempotent (pacman
  `--needed`), `RYOKU_DRYRUN=1` prints the plan. Shipped to `/usr/bin` by the
  `ryoku-desktop` hardware glob (and to `~/.local/bin` by the dev deploy);
  covered by `tests/gpu-lib32.sh`.
- `network/ryoku-wifi-powersave` + `network/49-ryoku-wifi-powersave.rules`: a
  privileged helper that disables, and later restores, 802.11 power-save on every
  WiFi device for Game Mode, via `iw` with no reconnect and no throughput cap,
  saving each device's prior state. A polkit rule authorizes exactly this program
  for the active wheel user without a password, so the deck toggle stays one click.
  The `ryoku-desktop` PKGBUILD installs the helper to `/usr/bin` and the rule under
  `/usr/share/polkit-1/rules.d`. Covered by `tests/wifi-powersave.sh`.
- `display/ryoku-monitor`: a `settle` subcommand re-asserts each output's intended
  mode so a display recovers in place when a cold-boot or post-upgrade link comes
  up advertising only a fallback resolution (e.g. 800x600) that Hyprland's
  `highrr`/`preferred` then pins. It generalises the old refresh-only settle to
  resolution too, reads intent from `monitors.lua` (so an explicit Ryoku Settings
  pick is restored, never overridden, and `monitors_user.lua` pins are skipped),
  and powers both `ryoku doctor` and the login/hotplug/Settings `autoscale` path.
  `settle --check` reports drift (exit 1) without changing anything.
- `gpu/ryoku-gpu`: a `detect --json` machine-readable GPU list and a `mode
  hybrid|performance|passthrough` switch (passthrough pins the iGPU alone, freeing
  the dGPU for a VM). Both feed the new Ryoku Settings -> GPU page and its
  Looking-Glass passthrough VM.
- `display/ryoku-monitor`: honours a hand-written `~/.config/hypr/monitors_user.lua`.
  Any output pinned there is left out of the generated `monitors.lua` and skipped
  by `autoscale` (scale and position), so a manually forced panel (a wrong/fake
  EDID that needs a custom mode or modeline) is never fought by auto-detection.
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
- `display/ryoku-monitor`: connecting a second monitor no longer throws Hyprland
  errors or resets the display you already tuned. The hotplug catch-all brings an
  unknown display up at `preferred` (always valid on an untrained link) instead of
  `highrr` (which errored until the link resolved; autoscale + settle still raise
  it to highrr afterwards). And the autoscale DPI pass now skips displays already
  configured in Ryoku Settings (the applied layout), so plugging in a new screen
  DPI-scales only the new one and leaves the existing display's chosen scale
  alone (fixture-covered in `tests/monitor-profiles.sh`).
- `audio/ryoku-eq`: the equalizer no longer splits the volume, and toggling it
  never silences or jumps audio that was already playing. Node volumes multiply
  along `app -> ryoku.eq.sink -> ryoku.eq.out -> hardware`, so enabling the EQ
  (which makes `ryoku.eq.sink` the default) used to force that sink to 100% while
  the real level stayed on the hardware sink: a second, hidden volume the OSD,
  the mixer, and the volume keys could no longer reach. Enable now carries the
  current master level onto `ryoku.eq.sink` and pins the hardware leg at unmuted
  unity, so `@DEFAULT_AUDIO_SINK@` stays the one global volume every control
  reads and writes and the toggle never jumps the level; disable carries it back
  onto the hardware sink before repointing the default. Enable still pulls any
  stream on the old default across, and disable still moves every stream off
  `ryoku.eq.sink` before killing the filter chain (tearing the sink out from
  under a live stream made clients like mpv and browsers cork themselves, heard
  as audio that never came back). Full playing->enable->disable cycles stay
  audible under one continuous volume (verified live), and the crash-recovery
  self-heal is unchanged.
- `display/ryoku-monitor`: the Settings paths (`apply`, `save`, `load`) now
  snap every explicit scale to the nearest Hyprland-valid value for its mode (a
  1/120 multiple dividing width and height to whole logical pixels), the same
  rule `autoscale` already applied. A stale draft or an old profile carrying
  e.g. 1.5 for a 1280x720 mode was sent raw: Hyprland drew the "Invalid scale"
  overlay, picked its own value, and the invalid number was still written to
  monitors.lua and the applied layout, so the overlay came back at every login.
  `list` now also emits per-resolution `scaleLadders` (the valid scales between
  0.5x and 3x that keep at least a 640x360 logical desktop: a 720p panel tops
  out at 2x, and the odd 1366x768 offers exactly 0.5/0.67/1/2) for the Hub's
  scale stepper, and the shared snap searches 0.25x-6x so a deliberate sub-1x
  choice on a small panel survives instead of being forced up. Covered by
  `tests/monitor-profiles.sh` (snap on apply/save/load, ladder contents).
- `drivers/nvidia.sh`: on the stock `linux` kernel install the PREBUILT
  `nvidia-open` (matched to the kernel, so there is no DKMS build to fail on a
  fresh kernel) instead of `nvidia-open-dkms`; custom kernels still use `-dkms` +
  headers. The mkinitcpio `MODULES` drop-in is written only when `modinfo` finds
  the module for an installed kernel, so a missing or failed build can no longer
  force a broken initramfs (the machine boots on the integrated GPU). Pre-Turing
  cards -- which the open module cannot drive, and whose proprietary packages are
  gone from the repos -- are skipped with a pointer to the AUR legacy driver
  instead of pulling a package that no longer exists.
- `display/ryoku-monitor`: write each output's refresh as `highrr` instead of the
  live rate, and settle the refresh after applying scale. A panel whose
  DisplayPort link first comes up at a low refresh (common on a discrete GPU at
  cold boot) no longer has that low rate captured back into the drop-in and locked
  in; every monitor now holds its highest refresh across reboots.
- `display/ryoku-monitor`: `autoscale` now snaps each DPI-derived scale to the
  nearest Hyprland-valid value for the panel (a 1/120 multiple dividing both
  width and height to whole pixels) before applying it. Hyprland rejects any
  other scale outright with an "Invalid scale" error overlay (1.5 on a 2560 panel
  is 1706.67px), so the raw DPI bucket spammed the screen with errors on many
  panels; now a 2560x1600 laptop gets 1.6, a 4K panel keeps 1.5, a 1080p stays 1x.
- `display/ryoku-monitor`: `autoscale` lays the displays in one flush,
  non-overlapping row, positioning every output from its real (accepted) logical
  width rather than the live or "auto" x. A freshly plugged display lands exactly
  beside the laptop instead of overlapping it, which a stale position could do
  once the scales differed (the overlap also tripped Hyprland's "layout set up
  incorrectly" overlay).
- `drivers/nvidia.sh`: also write the early-KMS modprobe option
  (`nvidia_drm modeset=1`) and the initramfs `MODULES`, which are mandatory for a
  working NVIDIA Wayland session. Detection-gated, so they apply whenever an
  NVIDIA GPU is present, not only on the amd-nvidia profile.
- `gpu/ryoku-gpu`: let shellcheck follow the sourced detect helper from any cwd.
- `power/ryoku-idle`: ignore defunct `hypridle` zombies when deciding whether the
  idle daemon is already running, so a dead first start cannot block a restart.
