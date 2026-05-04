echo "Install hypridle + hyprlock (replaces swayidle for race-immune lid-close lock on niri) and qt6 fractional-scale workaround drop-in"

if ! pacman -Q hypridle >/dev/null 2>&1 || ! pacman -Q hyprlock >/dev/null 2>&1; then
  sudo pacman -S --needed --noconfirm hypridle hyprlock
fi

if [[ -x $RYOKU_PATH/install/config/ryoku-hypridle.sh ]]; then
  "$RYOKU_PATH/install/config/ryoku-hypridle.sh"
fi

# Re-apply branding so iNiR's Idle.qml gets patched to skip its swayidle spawn
if [[ -x $RYOKU_PATH/install/config/ryoku-shell-branding.sh ]]; then
  "$RYOKU_PATH/install/config/ryoku-shell-branding.sh"
fi

# Stop the now-unused swayidle process if it's still running
pkill -x swayidle >/dev/null 2>&1 || true

systemctl --user daemon-reload >/dev/null 2>&1 || true
systemctl --user restart inir.service >/dev/null 2>&1 || true
