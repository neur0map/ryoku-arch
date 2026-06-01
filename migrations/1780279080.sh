echo "Stop hardcoding the eDP-1 1.25 scale; keep XWayland apps crisp via force_zero_scaling"

# Two changes that together fix blurry/pixelated XWayland apps (Helium, web-apps) on
# HiDPI/fractional laptop panels:
#   1. Drop the shipped hardcoded "monitor = eDP-1, preferred, 0x0, 1.25" default so the
#      panel falls through to the auto-scale catch-all instead of a baked-in fractional
#      scale. Per-output layouts written by Settings > Display use an explicit
#      "<WxH>@<Hz>, <X>x<Y>, <scale>" form and never match this exact line, so a user's
#      own monitor choices are preserved.
#   2. Enable xwayland:force_zero_scaling so XWayland clients render at native pixel
#      density (no XWayland-side bitmap upscale at fractional scale).
# Idempotent: the sed only matches the exact distro default, and the block is appended
# only when force_zero_scaling is absent.

hypr_dir="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
monitors_conf="$hypr_dir/monitors.conf"
hypr_conf="$hypr_dir/hyprland.conf"

if [[ -f $monitors_conf ]]; then
  sed -i '/^monitor = eDP-1, preferred, 0x0, 1\.25$/d' "$monitors_conf"
fi

if [[ -f $hypr_conf ]] && ! grep -q 'force_zero_scaling' "$hypr_conf"; then
  cat >>"$hypr_conf" <<'EOF'

xwayland {
  # Render XWayland clients at native pixel density so Chromium/Electron apps on
  # XWayland (Helium, web-apps) stay crisp under fractional/HiDPI monitor scale.
  force_zero_scaling = true
}
EOF
fi

if command -v hyprctl >/dev/null 2>&1; then
  hyprctl reload >/dev/null 2>&1 || true
fi
