# system/hardware/

Drivers and hardware setup. The job here is simple to state: use the best GPU,
make the screen look right, and install the right driver for whatever vendor is
in the machine.

## What's here

- `gpu/` Picks the strongest GPU and pins it as Hyprland's main renderer.
  - `ryoku-gpu` The command. `detect` lists every GPU strongest first and names
    the chosen primary; `persist` writes the Hyprland pin; `install-udev`
    installs the stable device names; `status` shows the current state;
    `disable` clears the pin.
  - `ryoku-gpu-detect` The detection helper the command sources. It reads the
    GPUs from the kernel and ranks them. Kept separate so it is easy to test.
  - `90-ryoku-gpu.rules` A udev rule that gives every GPU a stable, predictable
    name under `/dev/dri` so the pin keeps working across reboots.
- `display/`
  - `ryoku-monitor` Sets each monitor's scale from its real pixel density, so a
    dense laptop panel is zoomed and a normal external screen is left alone.
    `autoscale` applies it live and saves it; `persist` just saves the current
    layout.
- `power/`
  - `ryoku-hw-laptop` Classifies the host as laptop or desktop from DMI chassis
    type, battery presence, and lid switches. It is shared by GPU and idle policy.
  - `ryoku-idle` Starts `hypridle` only on laptops, using Ryoku's dim/lock/DPMS/
    suspend timeouts.
- `leds/`
  - `ryoku-leds` Applies the current wallust accent color to OpenRGB-compatible
    keyboards and attached lighting devices. It is best-effort: missing OpenRGB,
    unsupported devices, or permission failures never block login or wallpaper
    changes.
- `audio/`
  - `ryoku-mic` Caps the default microphone at its Base Volume (the level the
    device reports as 0 dB hardware gain, no amplification) so a codec that runs
    capture far hotter than unity does not clip speech into distortion. A mic
    already at or below unity is left alone. Launched from Hyprland autostart for
    Voxtype dictation and the pill voice visualizer.
- `network/`
  - `ryoku-wifi-powersave` Disables, then restores, 802.11 power-save on every
    WiFi device for the shell's Game Mode, via `iw`, so the radio stays fully awake
    for lower, steadier latency. It saves each device's prior state and reverts it;
    no reconnect and no throughput cap. Runs as root through pkexec.
  - `49-ryoku-wifi-powersave.rules` A polkit rule that lets the active wheel user
    run exactly that helper without a password, so the Game Mode toggle stays one click.
- `drivers/` One install script per vendor: `nvidia.sh`, `intel.sh`, `amd.sh`,
  and `vulkan.sh`. Each one checks whether its hardware is present and installs
  only what that hardware needs.

## How the strongest GPU is chosen

Many machines have two GPUs: a fast discrete card (NVIDIA or AMD) next to the
slower one built into the CPU. If the desktop renders on the slow one it feels
sluggish even on a fast screen. `ryoku-gpu` ranks the GPUs (an external GPU beats
a discrete card, which beats an integrated one) and makes the strongest one
Hyprland's primary renderer through `AQ_DRM_DEVICES`. Every GPU stays in the
list, so a monitor plugged into a different GPU still works.

On a laptop the integrated GPU stays primary by default, because that is easier
on the battery and is what Hyprland itself recommends. An external GPU is always
preferred (you plugged it in on purpose). To force the discrete GPU on a laptop,
run `RYOKU_GPU_FORCE=1 ryoku-gpu persist`.

## How display scaling works

`ryoku-monitor` measures each monitor's pixel density (resolution against its
physical size) and picks a scale from a small set of steps, from 1x for normal
screens up to 2x for very dense panels. Nothing is hardcoded per model, so a new
monitor is handled sensibly the first time it is plugged in. GTK and older apps
get a matching `GDK_SCALE` so they stay crisp too.

## Laptop idle policy

`ryoku-idle start` is launched from Hyprland autostart. On desktops it exits
without starting anything. On laptops it starts `hypridle` with
`~/.config/hypr/hypridle.conf`: 5 minutes dims, 10 minutes locks, 11 minutes
powers displays down, and 30 minutes suspends. The shell's Keep Awake toggle uses
Wayland idle inhibition, so hypridle stays paused while that toggle is on.

## How mic normalization works

Some laptop codecs let the analog capture gain reach its maximum (often +30 dB)
at a 100% source volume, which clips every word into broken audio. `ryoku-mic`
reads the default source's Base Volume, the device's own 0 dB hardware-gain
point, and lowers the source to it when it is running hotter. Nothing is
hardcoded per model: a mic that is already at or below unity is untouched, so a
well-behaved codec is a no-op.

## Per-vendor drivers

- NVIDIA: the open kernel modules on recent cards (Turing and newer), the
  proprietary ones on older cards, plus the userspace and video-acceleration
  bits.
- Intel: the modern media driver, the video runtime, and the Vulkan driver.
- AMD: the open Mesa stack and its Vulkan driver. No extra blob is needed.
- Vulkan: the vendor-neutral loader that every Vulkan app talks to.

The driver scripts are safe to run more than once (already-installed packages
are skipped), and they do nothing when their hardware is not present. Set
`RYOKU_DRYRUN=1` to print what would be installed without changing anything.

## How the installer uses this

The install backend runs the driver scripts for the detected hardware, installs
the GPU udev rule, and writes the first GPU pin and monitor scale so the very
first login already renders on the right GPU at the right size.

## Tools assumed present

`lspci` (GPU model names and the NVIDIA generation check) and `udevadm` (loading
the GPU rule) are expected on the target. `nvidia-smi` is optional and only fills
in the NVIDIA VRAM figure. `hyprctl` and `jq` are needed for live display
changes. `pacman` does the installing. `pactl` (PipeWire-Pulse) reads and sets
the microphone base volume for `ryoku-mic`. `iw` toggles WiFi power-save for
`ryoku-wifi-powersave`.
