echo "Install ryoku logo font and remove legacy omarchy.ttf"

MARKER="$HOME/.local/state/ryoku/independence-cutover.font.done"

if [[ -f $MARKER ]]; then
  exit 0
fi

USER_FONTS="$HOME/.local/share/fonts"
mkdir -p "$USER_FONTS"

# Drop the legacy omarchy.ttf if present; its family name is "omarchy"
# and Waybar no longer references it.
if [[ -f $USER_FONTS/omarchy.ttf ]]; then
  rm -f "$USER_FONTS/omarchy.ttf"
  echo "  removed legacy $USER_FONTS/omarchy.ttf"
fi

# Install the ryoku logo font (same glyphs, family name rewritten to
# "ryoku" via binary patch of the name table).
if [[ -f $RYOKU_PATH/config/ryoku.ttf ]]; then
  cp "$RYOKU_PATH/config/ryoku.ttf" "$USER_FONTS/"
  fc-cache >/dev/null 2>&1 || true
  echo "  installed $USER_FONTS/ryoku.ttf"
else
  echo "  WARNING: $RYOKU_PATH/config/ryoku.ttf not found; did the update pull complete?"
fi

mkdir -p "$HOME/.local/state/ryoku"
touch "$MARKER"
