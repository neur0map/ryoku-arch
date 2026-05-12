echo "Restore Mod+S toolkit keybind"

niri_binds="${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.d/70-binds.kdl"
default_niri_binds="$RYOKU_PATH/config/niri/config.d/70-binds.kdl"
ryoku_shell_launcher="$HOME/.local/bin/ryoku-shell"

if [[ ! -x $ryoku_shell_launcher ]]; then
  ryoku_shell_launcher="ryoku-shell"
fi

if [[ -f $niri_binds ]] && ! grep -qE 'Mod\+S[[:space:]]*\{[[:space:]]*spawn .*"toolsMode"[[:space:]]+"toggle"' "$niri_binds"; then
  temp_file=$(mktemp)
  awk -v launcher="$ryoku_shell_launcher" '
    /Mod\+Shift\+S[[:space:]]*\{/ && ! inserted {
      print "    // Toolkit pill (Mod+S)."
      printf "    Mod+S { spawn \"%s\" \"toolsMode\" \"toggle\"; }\n\n", launcher
      inserted = 1
    }
    { print }
    END {
      if (!inserted) {
        print ""
        print "    // Toolkit pill (Mod+S)."
        printf "    Mod+S { spawn \"%s\" \"toolsMode\" \"toggle\"; }\n", launcher
      }
    }
  ' "$niri_binds" >"$temp_file"
  mv "$temp_file" "$niri_binds"
elif [[ ! -f $niri_binds && -f $default_niri_binds ]]; then
  mkdir -p "$(dirname "$niri_binds")"
  cp "$default_niri_binds" "$niri_binds"
fi

if ryoku-cmd-present niri; then
  niri msg action load-config-file >/dev/null 2>&1 || true
fi
