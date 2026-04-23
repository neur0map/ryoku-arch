echo "Backfill Ryoku channel state file"

STATE_FILE="$HOME/.local/state/ryoku/channel"

if [[ -f $STATE_FILE ]]; then
  exit 0
fi

mkdir -p "$HOME/.local/state/ryoku"

channel="stable"
if [[ -r /etc/pacman.d/mirrorlist ]]; then
  if grep -q "https://rc-mirror\." /etc/pacman.d/mirrorlist; then
    channel="rc"
  elif grep -q "https://mirror\." /etc/pacman.d/mirrorlist && ! grep -q "https://stable-mirror\." /etc/pacman.d/mirrorlist; then
    channel="edge"
  fi
fi

printf '%s\n' "$channel" >"$STATE_FILE"
echo "  channel: $channel"
