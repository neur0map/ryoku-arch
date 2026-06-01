echo "Reconcile wallpaper type.txt into the shell state dir so colours follow the wallpaper"

# The wallpaper-colour pipeline reads path.txt + type.txt from the shell state dir
# (~/.local/state/ryoku-shell/wallpaper), but type.txt was being written to
# ~/.local/state/ryoku/wallpaper. The reader's copy stayed stale, so wallpaper-derived
# colours picked the wrong source (e.g. an old poster, or a raw video file the image
# extractor cannot read) and stopped following the wallpaper. Re-derive type.txt next to
# path.txt, drop the misplaced copy, and regenerate the scheme so it heals immediately.

shell_state="${XDG_STATE_HOME:-$HOME/.local/state}/ryoku-shell/wallpaper"
old_state="${XDG_STATE_HOME:-$HOME/.local/state}/ryoku/wallpaper"

# The misplaced copy was never read by the colour pipeline; remove it to avoid confusion.
rm -f "$old_state/type.txt"

if [[ -s $shell_state/path.txt ]]; then
  wp="$(head -n1 "$shell_state/path.txt")"
  case "${wp,,}" in
    *.mp4|*.mkv|*.mov|*.webm|*.avi) t=video ;;
    *.gif)                          t=animated ;;
    *)                              t=image ;;
  esac
  mkdir -p "$shell_state"
  printf '%s\n' "$t" >"$shell_state/type.txt"

  # Regenerate colours now so they match without needing a wallpaper switch (best-effort;
  # the shell also re-derives from the wallpaper on its next start).
  if command -v ryoku >/dev/null 2>&1; then
    ryoku scheme from-wallpaper >/dev/null 2>&1 || true
  fi
fi
