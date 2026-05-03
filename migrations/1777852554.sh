echo "Re-run Ryoku shell branding to relocate workspaces and weather into the right notch and un-hide indicator slots in the topbar"

if [[ -x $RYOKU_PATH/install/config/ryoku-shell-branding.sh ]]; then
  "$RYOKU_PATH/install/config/ryoku-shell-branding.sh"
fi

systemctl --user daemon-reload >/dev/null 2>&1 || true
