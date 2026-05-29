echo "Float and center the GUI update terminal (windowrule for class ryoku-update)"

# GUI actions (Update now, channel switch, MedEvac) now open a small centered floating
# terminal tagged with the ryoku-update window class. New installs get the windowrule
# from config/hypr/hyprland.conf; existing users' hyprland.conf is user-owned and not
# overwritten, so inject it here. Idempotent: skip if already present.

hypr_conf="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprland.conf"
[[ -f $hypr_conf ]] || exit 0

if grep -qE '^windowrule = match:class \^\(ryoku-update\)\$' "$hypr_conf"; then
  echo "  ryoku-update windowrule already present; nothing to do."
  exit 0
fi

{
  printf '\n'
  printf '%s\n' 'windowrule = match:class ^(ryoku-update)$, float true'
  printf '%s\n' 'windowrule = match:class ^(ryoku-update)$, size 900 560'
  printf '%s\n' 'windowrule = match:class ^(ryoku-update)$, center true'
} >>"$hypr_conf"
echo "  Added ryoku-update windowrule to $hypr_conf"

if command -v hyprctl >/dev/null 2>&1; then
  hyprctl reload >/dev/null 2>&1 || true
fi
