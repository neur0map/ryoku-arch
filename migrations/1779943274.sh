echo "Float and center the Ryoku control center window (class ryoku-control)"

hypr_conf="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprland.conf"
rules=(
  "windowrule = match:class ^(ryoku-control)\$, float true"
  "windowrule = match:class ^(ryoku-control)\$, size 1280 720"
  "windowrule = match:class ^(ryoku-control)\$, center true"
)

if [[ -f $hypr_conf ]]; then
  tmp_conf=$(mktemp)
  cp "$hypr_conf" "$tmp_conf"
  for rule in "${rules[@]}"; do
    next_conf=$(mktemp)
    grep -Fxv "$rule" "$tmp_conf" >"$next_conf" || true
    mv "$next_conf" "$tmp_conf"
  done
  mv "$tmp_conf" "$hypr_conf"
  for rule in "${rules[@]}"; do
    printf '%s\n' "$rule" >>"$hypr_conf"
  done
fi

if command -v hyprctl >/dev/null 2>&1; then
  hyprctl reload >/dev/null 2>&1 || true
fi
