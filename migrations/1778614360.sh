echo "Make ASCII screensaver use Ryoku terminal settings and fullscreen Niri windows"

if [[ -x $RYOKU_PATH/install/config/ryoku-hypridle.sh ]]; then
  "$RYOKU_PATH/install/config/ryoku-hypridle.sh"
else
  mkdir -p "$HOME/.config/hypr"
  if [[ -f $RYOKU_PATH/config/hypr/hypridle.conf ]]; then
    cp "$RYOKU_PATH/config/hypr/hypridle.conf" "$HOME/.config/hypr/hypridle.conf"
  fi
fi

niri_rules="${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.d/30-window-rules.kdl"
if [[ -f $niri_rules ]] && ! grep -q 'org\.ryoku\.screensaver' "$niri_rules"; then
  cat >>"$niri_rules" <<'EOF'

// Ryoku screensaver: match Omarchy's full-screen terminal screensaver behavior.
window-rule {
    match app-id="org.ryoku.screensaver"
    open-fullscreen true
    open-focused true
    geometry-corner-radius 0
    opacity 1.0
}
EOF
elif [[ ! -f $niri_rules && -f $RYOKU_PATH/config/niri/config.d/30-window-rules.kdl ]]; then
  mkdir -p "$(dirname "$niri_rules")"
  cp "$RYOKU_PATH/config/niri/config.d/30-window-rules.kdl" "$niri_rules"
fi

systemctl --user daemon-reload >/dev/null 2>&1 || true
systemctl --user restart hypridle.service >/dev/null 2>&1 || true
niri msg action load-config-file >/dev/null 2>&1 || true
