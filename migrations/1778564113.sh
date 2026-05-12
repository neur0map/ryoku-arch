echo "Restore ASCII screensaver before idle monitor-off and hibernation"

if [[ -x $RYOKU_PATH/install/config/ryoku-hypridle.sh ]]; then
  "$RYOKU_PATH/install/config/ryoku-hypridle.sh"
else
  mkdir -p "$HOME/.config/hypr"
  if [[ -f $RYOKU_PATH/config/hypr/hypridle.conf ]]; then
    cp "$RYOKU_PATH/config/hypr/hypridle.conf" "$HOME/.config/hypr/hypridle.conf"
  fi
fi

systemctl --user daemon-reload >/dev/null 2>&1 || true
systemctl --user restart hypridle.service >/dev/null 2>&1 || true
