echo "Promote battery monitor to Ryoku unit"

if [[ -f ~/.config/systemd/user/omarchy-battery-monitor.timer ]]; then
  systemctl --user disable --now omarchy-battery-monitor.timer 2>/dev/null || true
fi

if ls /sys/class/power_supply/BAT* &>/dev/null; then
  mkdir -p ~/.config/systemd/user

  if [[ -f $RYOKU_PATH/config/systemd/user/ryoku-battery-monitor.service ]]; then
    cp "$RYOKU_PATH/config/systemd/user/ryoku-battery-monitor."* ~/.config/systemd/user/
    systemctl --user daemon-reload
    systemctl --user enable --now ryoku-battery-monitor.timer || true
  fi
fi
