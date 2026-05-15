echo "Backfill Ryoku main channel state file"

STATE_FILE="$HOME/.local/state/ryoku/channel"

if [[ -f $STATE_FILE ]]; then
  exit 0
fi

mkdir -p "$HOME/.local/state/ryoku"

channel="main"

printf '%s\n' "$channel" >"$STATE_FILE"
echo "  channel: $channel"
