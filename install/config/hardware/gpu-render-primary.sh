# Pin the strongest GPU as Hyprland's primary render device on multi-GPU
# machines (e.g. a discrete Radeon/GeForce beside the CPU's integrated GPU), so
# the desktop renders on the powerful GPU instead of the weak iGPU a monitor may
# be wired to. ryoku-gpu is a no-op on single-GPU machines and on laptops (where
# Hyprland's iGPU-first default is better for battery), so this is safe to run
# unconditionally. Non-fatal: a missing tool or udev hiccup must not abort the
# install.

if command -v ryoku-gpu >/dev/null 2>&1; then
  # Boot-stable, colon-free /dev/dri symlinks by PCI slot (needs root; the
  # installer already holds a cached sudo credential at this point).
  ryoku-gpu install-udev || echo "ryoku-gpu: udev rule install skipped/failed (non-fatal)"
  # Write ~/.config/hypr/gpu.conf (+ source line, + uwsm env) for the strongest GPU.
  ryoku-gpu persist || echo "ryoku-gpu: persist skipped/failed (non-fatal)"
fi
