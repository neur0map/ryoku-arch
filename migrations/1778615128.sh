echo "Add Mod+Z and Mod+X Niri focus keybinds"

niri_binds="${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.d/70-binds.kdl"
default_niri_binds="$RYOKU_PATH/config/niri/config.d/70-binds.kdl"

if [[ -f $niri_binds ]]; then
  add_z=0
  add_x=0
  grep -qE '^[[:space:]]*Mod\+Z([[:space:]]|\{)' "$niri_binds" || add_z=1
  grep -qE '^[[:space:]]*Mod\+X([[:space:]]|\{)' "$niri_binds" || add_x=1

  if (( add_z || add_x )); then
    temp_file=$(mktemp)
    awk -v add_z="$add_z" -v add_x="$add_x" '
      /Mod\+Right[[:space:]]*\{[[:space:]]*focus-column-right;/ && ! inserted {
        print
        if (add_z) {
          print "    Mod+Z     { focus-column-left; }"
        }
        if (add_x) {
          print "    Mod+X     { focus-column-right; }"
        }
        inserted = 1
        next
      }
      { print }
      END {
        if (!inserted) {
          if (add_z) {
            print "    Mod+Z     { focus-column-left; }"
          }
          if (add_x) {
            print "    Mod+X     { focus-column-right; }"
          }
        }
      }
    ' "$niri_binds" >"$temp_file"
    mv "$temp_file" "$niri_binds"
  fi
elif [[ -f $default_niri_binds ]]; then
  mkdir -p "$(dirname "$niri_binds")"
  cp "$default_niri_binds" "$niri_binds"
fi

if ryoku-cmd-present niri; then
  niri msg action load-config-file >/dev/null 2>&1 || true
fi
