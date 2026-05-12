echo "Repair incomplete Helium browser migration"

STATE_DIR="${RYOKU_STATE_PATH:-$HOME/.local/state/ryoku}/migrations"
if [[ ! -f $STATE_DIR/1778617021.sh && ! -f $STATE_DIR/skipped/1778617021.sh ]]; then
  echo "Helium browser migration is still pending; skipping repair migration"
  exit 0
fi

ryoku-default-app-migrate browser helium
