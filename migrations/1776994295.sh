echo "Drop [omarchy] pacman repo"

MARKER="$HOME/.local/state/ryoku/independence-cutover.pacman.done"

if [[ -f $MARKER ]]; then
  exit 0
fi

PACMAN_CONF="/etc/pacman.conf"
BAK="$PACMAN_CONF.ryoku.bak"
TMP="$PACMAN_CONF.ryoku.tmp"

if ! grep -q '^\[omarchy\]' "$PACMAN_CONF"; then
  echo "  [omarchy] already absent from $PACMAN_CONF"
  mkdir -p "$HOME/.local/state/ryoku"
  touch "$MARKER"
  exit 0
fi

ryoku-snapshot create || true

# Preserve original for manual rollback
[[ -f $BAK ]] || sudo cp -f "$PACMAN_CONF" "$BAK"

# Atomic rewrite removing only the [omarchy] section. User-added
# sections (chaotic-aur, endeavouros, local repos, etc.) are preserved
# verbatim because the awk only drops lines inside the [omarchy] block.
sudo awk '
  BEGIN { drop = 0 }
  /^\[omarchy\]/ { drop = 1; next }
  /^\[/ { drop = 0 }
  drop == 0 { print }
' "$PACMAN_CONF" | sudo tee "$TMP" >/dev/null

# Validate the new config parses
if ! sudo pacman-conf --config "$TMP" >/dev/null 2>&1; then
  echo "  generated $TMP did not parse; leaving original in place" >&2
  sudo rm -f "$TMP"
  exit 1
fi

sudo mv -f "$TMP" "$PACMAN_CONF"
sudo pacman -Syy

# User chose to drop hyprland-preview-share-picker with the repo
if pacman -Qi hyprland-preview-share-picker &>/dev/null; then
  echo "  removing hyprland-preview-share-picker"
  sudo pacman -R --noconfirm hyprland-preview-share-picker || true
fi

# tobi-try: unknown purpose, not in AUR. Drop.
if pacman -Qi tobi-try &>/dev/null; then
  echo "  removing tobi-try"
  sudo pacman -R --noconfirm tobi-try || true
fi

mkdir -p "$HOME/.local/state/ryoku"
touch "$MARKER"

echo "  [omarchy] dropped; backup at $BAK"
