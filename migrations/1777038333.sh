echo "Detach LocalSend when launched from tofi/app selector"

MARKER="$HOME/.local/state/ryoku/independence-cutover.localsend-launch.done"

if [[ -f $MARKER ]]; then
  exit 0
fi

# Only needed when the system-level desktop entry ships a bare
# 'Exec=localsend' (AUR package default). Our override adds setsid so
# the Flutter app survives after tofi-drun exits.
SRC=/usr/share/applications/localsend.desktop
DST="$HOME/.local/share/applications/localsend.desktop"

if [[ ! -f $SRC ]]; then
  mkdir -p "$HOME/.local/state/ryoku"
  touch "$MARKER"
  exit 0
fi

mkdir -p "$(dirname "$DST")"

if [[ -f $DST ]] && grep -q '^Exec=setsid localsend' "$DST"; then
  echo "  override already in place at $DST"
else
  echo "  writing $DST"
  sed 's|^Exec=localsend|Exec=setsid localsend|' "$SRC" > "$DST"
  update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true
fi

# Tofi caches its app list at ~/.cache/tofi-drun and does not revalidate
# on .desktop-file changes; drop the cache so the next tofi-drun picks
# up the override above.
if [[ -f $HOME/.cache/tofi-drun ]]; then
  echo "  clearing ~/.cache/tofi-drun"
  rm -f "$HOME/.cache/tofi-drun"
fi

mkdir -p "$HOME/.local/state/ryoku"
touch "$MARKER"
