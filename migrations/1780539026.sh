echo "Fix stuck cursor: disable hyprcursor for the XCursor-only Bibata theme"

# Bibata is XCursor-only (no hyprcursor manifest); pointing hyprcursor at it left
# the pointer stuck on the last shape after a hover. Drop the HYPRCURSOR env from
# hyprland.conf and force XCursor instead.
hypr="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprland.conf"
if [[ -f $hypr ]]; then
  sed -i -e '/^env = HYPRCURSOR_THEME/d' -e '/^env = HYPRCURSOR_SIZE/d' "$hypr"
  if ! grep -q '^cursor:enable_hyprcursor' "$hypr"; then
    if grep -q '^env = XCURSOR_SIZE' "$hypr"; then
      sed -i '/^env = XCURSOR_SIZE/a cursor:enable_hyprcursor = false' "$hypr"
    else
      printf '\ncursor:enable_hyprcursor = false\n' >>"$hypr"
    fi
  fi
fi

# Apply to the running session so the cursor unsticks without a relogin.
hyprctl keyword cursor:enable_hyprcursor false >/dev/null 2>&1 || true
hyprctl setcursor Bibata-Modern-Classic 24 >/dev/null 2>&1 || true
