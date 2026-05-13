echo "Allow Qt XCB fallback for bundled apps"

niri_env="$HOME/.config/niri/config.d/40-environment.kdl"
if [[ -f $niri_env ]]; then
  sed -i 's/QT_QPA_PLATFORM "wayland"/QT_QPA_PLATFORM "wayland;xcb"/' "$niri_env"
fi

systemd_env="$HOME/.config/environment.d/ryoku-shell.conf"
if [[ -f $systemd_env ]]; then
  sed -i 's/^QT_QPA_PLATFORM=wayland$/QT_QPA_PLATFORM=wayland;xcb/' "$systemd_env"
fi

export QT_QPA_PLATFORM="wayland;xcb"
systemctl --user set-environment QT_QPA_PLATFORM="$QT_QPA_PLATFORM" >/dev/null 2>&1 || true
systemctl --user import-environment QT_QPA_PLATFORM >/dev/null 2>&1 || true
dbus-update-activation-environment QT_QPA_PLATFORM >/dev/null 2>&1 || true
