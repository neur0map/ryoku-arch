echo "Default display scale 1.25 (auto over-zoomed to 2x on hiDPI) + scale Helium to match"

hypr_dir="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
monitors_conf="$hypr_dir/monitors.conf"

# The catch-all shipped 'auto', which Hyprland resolves to 2x (200%) on high-DPI
# laptop panels -- too zoomed. Bump the unconfigured default to an explicit 1.25.
# Only the shipped default line is touched; per-output overrides a user set in
# Settings > Display are left alone.
if [[ -f $monitors_conf ]]; then
  sed -i -E 's|^monitor = , highrr, auto, auto$|monitor = , highrr, auto, 1.25|' "$monitors_conf"
fi

# Regenerate the Helium launcher so it passes Chromium a device-scale-factor
# matching the monitor scale. Helium runs under XWayland (force_zero_scaling),
# so without this it renders tiny on a scaled panel.
if [[ -x $RYOKU_PATH/bin/ryoku-refresh-helium-browser ]]; then
  "$RYOKU_PATH/bin/ryoku-refresh-helium-browser" || true
fi

if command -v hyprctl >/dev/null 2>&1; then
  hyprctl reload >/dev/null 2>&1 || true
fi
