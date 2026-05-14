echo "Refresh qylock previews"

QYLOCK_DIR="$HOME/.local/share/qylock"
PREVIEW_HELPER="$RYOKU_PATH/bin/ryoku-refresh-qylock-previews"

if [[ -x $PREVIEW_HELPER && -d $QYLOCK_DIR/themes ]]; then
  "$PREVIEW_HELPER" "$QYLOCK_DIR" || true
fi
