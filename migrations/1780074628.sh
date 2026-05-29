echo "Move Hyprland monitor config into a managed monitors.conf (Settings > Display)"

# ryoku now manages monitor layout in ~/.config/hypr/monitors.conf, sourced by
# hyprland.conf, so the Display settings tab can edit resolution/refresh/scale/etc.
# Fresh installs ship this layout; existing users have monitor= lines inline in
# hyprland.conf, so move them into monitors.conf and add the source line.
# Idempotent: skip once hyprland.conf already sources monitors.conf.

hypr_dir="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
hypr_conf="$hypr_dir/hyprland.conf"
monitors_conf="$hypr_dir/monitors.conf"

[[ -f $hypr_conf ]] || exit 0

if grep -qE 'monitors\.conf' "$hypr_conf"; then
  echo "  hyprland.conf already sources monitors.conf; nothing to do."
  exit 0
fi

# Create monitors.conf from the user's existing monitor= lines, unless one already
# exists (e.g. written by ryoku-monitor) which we must not clobber.
if [[ ! -f $monitors_conf ]]; then
  {
    printf '%s\n' "# Managed by Ryoku Display settings (ryoku-monitor)."
    printf '%s\n' "# Edits here may be overwritten; use Settings > Display."
    printf '\n'
    if grep -qE '^[[:space:]]*monitor[[:space:]]*=' "$hypr_conf"; then
      grep -E '^[[:space:]]*monitor[[:space:]]*=' "$hypr_conf"
    else
      printf '%s\n' "monitor = , highrr, auto, auto"
    fi
  } >"$monitors_conf"
  echo "  Created $monitors_conf"
fi

# Drop inline monitor= lines and add the source after the colors.conf source line
# (falling back to appending it if that line is absent).
tmp="$(mktemp)"
awk '
  BEGIN { added = 0 }
  /^[[:space:]]*monitor[[:space:]]*=/ { next }
  {
    print
    if (!added && $0 ~ /colors\.conf/) {
      print "# Monitor layout is managed by Ryoku Display settings (Settings > Display)."
      print "source = ~/.config/hypr/monitors.conf"
      added = 1
    }
  }
  END {
    if (!added) {
      print "source = ~/.config/hypr/monitors.conf"
    }
  }
' "$hypr_conf" >"$tmp" && mv "$tmp" "$hypr_conf"
echo "  Updated $hypr_conf to source monitors.conf"

if command -v hyprctl >/dev/null 2>&1; then
  hyprctl reload >/dev/null 2>&1 || true
fi
