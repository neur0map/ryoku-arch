echo "Install Ryoku session resume recovery"

if [[ -x $RYOKU_PATH/install/config/session-recover.sh ]]; then
  "$RYOKU_PATH/install/config/session-recover.sh"
fi

if [[ -x $RYOKU_PATH/install/config/ryoku-shell-branding.sh ]]; then
  "$RYOKU_PATH/install/config/ryoku-shell-branding.sh"
fi

systemctl --user daemon-reload >/dev/null 2>&1 || true
