echo "Normalize Ryoku channel state"

STATE_FILE="$HOME/.local/state/ryoku/channel"

if [[ -f $STATE_FILE ]]; then
  current="$(<"$STATE_FILE")"
else
  current=""
fi

case "$current" in
main | unstable-dev)
  echo "  channel already $current"
  ;;
*)
  mkdir -p "$(dirname "$STATE_FILE")"
  printf '%s\n' "main" > "$STATE_FILE"
  echo "  channel: main"
  ;;
esac
