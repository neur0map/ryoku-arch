echo "Pin the strongest GPU as Hyprland's primary render device on multi-GPU machines"

# On a multi-GPU desktop (a discrete Radeon/GeForce beside the CPU's integrated
# GPU), Hyprland renders on whichever GPU drives the connected display. When the
# monitor is wired to the weak iGPU, the whole desktop renders there while the
# dGPU idles -> high-refresh sessions thrash the iGPU's tiny VRAM and feel
# sub-60Hz. ryoku-gpu pins the discrete GPU as the primary renderer via a
# ~/.config/hypr/gpu.conf sourced by hyprland.conf. Fresh installs ship this;
# bring existing installs in line. Idempotent.

hypr_dir="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
hypr_conf="$hypr_dir/hyprland.conf"
gpu_conf="$hypr_dir/gpu.conf"
source_line="source = ~/.config/hypr/gpu.conf"

# Nothing to do without the managed Hyprland config.
[[ -f $hypr_conf ]] || exit 0

# Ship the managed gpu.conf placeholder so the new `source =` line never points
# at a missing file. Never clobber an existing one -- it may already hold a pin.
if [[ ! -f $gpu_conf ]]; then
  if [[ -f $RYOKU_PATH/config/hypr/gpu.conf ]]; then
    cp "$RYOKU_PATH/config/hypr/gpu.conf" "$gpu_conf"
  else
    printf '# Managed by ryoku-gpu.\n' >"$gpu_conf"
  fi
fi

# Source gpu.conf right after the first machine include so it loads before
# custom.conf (user overrides win on duplicate env). Idempotent.
if ! grep -qxF "$source_line" "$hypr_conf"; then
  tmp="$(mktemp)"
  awk -v line="$source_line" '
    { print }
    !ins && substr($0, 1, 24) == "source = ~/.config/hypr/" { print line; ins = 1 }
    END { if (!ins) print line }
  ' "$hypr_conf" >"$tmp" && cat "$tmp" >"$hypr_conf"
  rm -f "$tmp"
fi

# Populate the pin on multi-GPU desktops (no-op on single-GPU and laptops).
# Best-effort: a missing tool or udev hiccup must not fail the migration.
if command -v ryoku-gpu >/dev/null 2>&1; then
  ryoku-gpu install-udev || true
  ryoku-gpu persist || true
fi

# Make the new source line valid in the running session. The AQ_DRM_DEVICES env
# itself is only read at compositor start, so the render-device switch needs a
# Hyprland login to take effect.
if command -v hyprctl >/dev/null 2>&1; then
  hyprctl reload >/dev/null 2>&1 || true
fi
