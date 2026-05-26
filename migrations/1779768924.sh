echo "Launch Helium through XWayland to avoid black Wayland omnibox"

if [[ -x $RYOKU_PATH/bin/ryoku-refresh-helium-browser ]]; then
  "$RYOKU_PATH/bin/ryoku-refresh-helium-browser" || true
fi

if [[ -f $RYOKU_PATH/migrations/1779660083.sh ]]; then
  bash "$RYOKU_PATH/migrations/1779660083.sh"
fi
