echo "Repoint Super+V to the image-capable Ryoku clipboard and disable cliphist auto-start"

# The image clipboard is captured by the ambxst ClipboardService (started by the
# shell). Super+V should open that, and the old cliphist watcher is now redundant.
# Seeded configs are never overwritten on existing installs, so the live
# hyprland.conf has to be edited in place here. Only users whose $clipboard is
# still a known Ryoku default are migrated; a customised binding is left alone
# (and cliphist stays enabled for it).

hypr_conf="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprland.conf"
[[ -f $hypr_conf ]] || exit 0

new_clip='$clipboard = sh -lc '\''$HOME/.local/bin/ryoku-shell ipc clipboard open'\'''
old_clip_1='$clipboard = sh -lc '\''cliphist list | fuzzel --dmenu --prompt="Clipboard: " | cliphist decode | wl-copy'\'''
old_clip_2='$clipboard = sh -lc '\''$HOME/.local/bin/ryoku-rebirth-shell ipc call clipboardManager changeVisible'\'''
cliphist_line='exec-once = wl-paste --watch cliphist store'

matches() {
  awk -v needle="$1" '{ t=$0; sub(/^[ \t]+/,"",t); sub(/[ \t]+$/,"",t); if (t==needle) f=1 } END { exit f?0:1 }' "$hypr_conf"
}

if matches "$new_clip"; then
  : # already repointed; still fall through to ensure cliphist is disabled
elif matches "$old_clip_1" || matches "$old_clip_2"; then
  : # eligible to repoint
else
  echo "  \$clipboard is customised: leaving Super+V and cliphist untouched."
  exit 0
fi

tmp_conf=$(mktemp)
awk -v new="$new_clip" -v o1="$old_clip_1" -v o2="$old_clip_2" -v ch="$cliphist_line" '
  function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
  { t = trim($0) }
  t == o1 || t == o2 { print new; next }
  t == ch {
    print "# RYOKU: clipboard history now captured by the image-capable ambxst ClipboardService"
    print "# (started by the shell); Super+V opens it. cliphist auto-start disabled."
    print "# " $0
    next
  }
  { print }
' "$hypr_conf" >"$tmp_conf"

if ! cmp -s "$tmp_conf" "$hypr_conf"; then
  mv "$tmp_conf" "$hypr_conf"
  echo "  Updated $hypr_conf"
else
  rm -f "$tmp_conf"
fi

if command -v hyprctl >/dev/null 2>&1; then
  hyprctl reload >/dev/null 2>&1 || true
fi
