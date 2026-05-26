echo "Move Obsidian Hyprland keybind away from Super+O"

hypr_conf="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprland.conf"
old_bind="bind = SUPER, O, exec, \$obsidianNotes"
new_bind="bind = SUPER ALT, O, exec, \$obsidianNotes"

if [[ -f $hypr_conf ]]; then
  if grep -Fxq "$old_bind" "$hypr_conf"; then
    new_present=0
    wrote_new=0
    tmp_file="$(mktemp)"

    if grep -Fxq "$new_bind" "$hypr_conf"; then
      new_present=1
    fi

    while IFS= read -r line; do
      if [[ $line == "bind = SUPER, O, exec, \$obsidianNotes" ]]; then
        if (( ! new_present && ! wrote_new )); then
          printf '%s\n' "$new_bind"
          wrote_new=1
        fi
      else
        printf '%s\n' "$line"
      fi
    done <"$hypr_conf" >"$tmp_file"

    cat "$tmp_file" >"$hypr_conf"
    rm -f "$tmp_file"
  fi
fi

if ryoku-cmd-present hyprctl; then
  hyprctl reload >/dev/null 2>&1 || true
fi
