echo "Repair browser opacity and Helium theme defaults"

if [[ -f $RYOKU_PATH/migrations/1779660083.sh ]]; then
  bash "$RYOKU_PATH/migrations/1779660083.sh"
fi

refresh_helper="$RYOKU_PATH/bin/ryoku-refresh-helium-browser"

if [[ -x $refresh_helper ]]; then
  "$refresh_helper" || true
fi
