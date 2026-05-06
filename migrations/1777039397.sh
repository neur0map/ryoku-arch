echo "Retire Plymouth background color migration"

MARKER="$HOME/.local/state/ryoku/independence-cutover.plymouth-bg.done"

if [[ -f $MARKER ]]; then
  exit 0
fi

mkdir -p "$HOME/.local/state/ryoku"
touch "$MARKER"
echo "  Plymouth background color migration retired; keeping current assets"
