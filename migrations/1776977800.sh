echo "Swap pacman mirrorlist to upstream Arch"

source "$HOME/.local/share/ryoku/lib/runtime-env.sh" 2>/dev/null || source "$HOME/.local/share/omarchy/lib/runtime-env.sh"

channel="$(ryoku-channel-current)"
src="$RYOKU_PATH/default/pacman/mirrorlist-$channel"
dst="/etc/pacman.d/mirrorlist"
bak="$dst.ryoku.bak"
tmp="$dst.ryoku.tmp"

if [[ ! -r $src ]]; then
  echo "  source mirrorlist missing: $src" >&2
  exit 1
fi

# Already on the Ryoku mirrorlist? Skip.
if ! grep -q 'omarchy\.org' "$dst" 2>/dev/null; then
  echo "  mirrorlist already on upstream Arch; no-op"
  mkdir -p "$RYOKU_STATE_PATH"
  [[ -f $RYOKU_STATE_PATH/independence-cutover.started ]] || touch "$RYOKU_STATE_PATH/independence-cutover.started"
  exit 0
fi

# Backup original (first run only)
if [[ ! -f $bak ]]; then
  sudo cp -f "$dst" "$bak"
fi

# Atomic write
sudo cp -f "$src" "$tmp"
sudo mv -f "$tmp" "$dst"

# Force DB refresh against the new mirrors
if ! sudo pacman -Syy; then
  echo "  pacman -Syy failed against new mirrors; restore the backup if needed:" >&2
  echo "    sudo cp -f $bak $dst && sudo pacman -Syy" >&2
  exit 1
fi

mkdir -p "$RYOKU_STATE_PATH"
touch "$RYOKU_STATE_PATH/independence-cutover.started"

echo "  channel: $channel"
echo "  backup:  $bak"
