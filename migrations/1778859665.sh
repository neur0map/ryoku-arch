echo "Collapse Ryoku channel state to main"

STATE_FILE="$HOME/.local/state/ryoku/channel"

if [[ -f $STATE_FILE ]]; then
  current="$(<"$STATE_FILE")"
else
  current=""
fi

if [[ $current != "main" ]]; then
  mkdir -p "$(dirname "$STATE_FILE")"
  printf '%s\n' "main" > "$STATE_FILE"
  echo "  channel: main"
else
  echo "  channel already main"
fi
