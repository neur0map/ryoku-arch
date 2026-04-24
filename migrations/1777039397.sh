echo "Refresh Plymouth background to Greek Noir (#171717)"

MARKER="$HOME/.local/state/ryoku/independence-cutover.plymouth-bg.done"

if [[ -f $MARKER ]]; then
  exit 0
fi

if ! command -v plymouth-set-default-theme >/dev/null 2>&1; then
  mkdir -p "$HOME/.local/state/ryoku"
  touch "$MARKER"
  exit 0
fi

# Only need to refresh if the installed script still carries the old
# Tokyo Night background constants. ryoku-refresh-plymouth copies the
# assets and rebuilds the UKI.
if [[ -f /usr/share/plymouth/themes/ryoku/ryoku.script ]] \
   && grep -q '0.101, 0.105, 0.149' /usr/share/plymouth/themes/ryoku/ryoku.script; then
  echo "  reinstalling theme + rebuilding UKI"
  ryoku-refresh-plymouth
else
  echo "  theme already on new background colors"
fi

mkdir -p "$HOME/.local/state/ryoku"
touch "$MARKER"
