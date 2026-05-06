echo "Retire Greek Noir default color theme migration"

MARKER="$HOME/.local/state/ryoku/independence-cutover.greek-noir.done"

if [[ -f $MARKER ]]; then
  exit 0
fi

mkdir -p "$HOME/.local/state/ryoku"
touch "$MARKER"
echo "  Greek Noir migration retired; keeping the current theme"
