echo "Refresh ryoku logo font with 力 glyph"

MARKER="$HOME/.local/state/ryoku/independence-cutover.font-glyph.done"

if [[ -f $MARKER ]]; then
  exit 0
fi

USER_FONTS="$HOME/.local/share/fonts"
mkdir -p "$USER_FONTS"

if [[ -f $RYOKU_PATH/config/ryoku.ttf ]]; then
  cp -f "$RYOKU_PATH/config/ryoku.ttf" "$USER_FONTS/ryoku.ttf"
  fc-cache >/dev/null 2>&1 || true
  echo "  refreshed $USER_FONTS/ryoku.ttf"
else
  echo "  WARNING: $RYOKU_PATH/config/ryoku.ttf not found; skipping"
fi

mkdir -p "$HOME/.local/state/ryoku"
touch "$MARKER"
