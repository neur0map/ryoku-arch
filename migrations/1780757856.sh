echo "Add the Super+X plugins-menu leader keybind"

conf="$HOME/.config/hypr/hyprland.conf"
lua="$HOME/.config/hypr/hyprland.lua"
old="$HOME/.config/hypr/ryoku-plugins.conf"

# Drop the earlier sourced-conf attempt (HyprMod runs Hyprland in Lua mode, where it was
# never read). Plugin shortcuts are now an in-shell menu opened by one leader bind.
[[ -f $old ]] && rm -f "$old"
if [[ -f $conf ]]; then
  sed -i '\#source = ~/.config/hypr/ryoku-plugins.conf#d' "$conf"
fi

# HyprMod's Lua config: add the leader via hl.bind, before the user's require("custom").
if [[ -f $lua ]] && ! grep -q "ipc plugins toggle" "$lua"; then
  line='hl.bind("SUPER + X", hl.dsp.exec_cmd("sh -lc '\''$HOME/.local/bin/ryoku-shell ipc plugins toggle'\''"))'
  if grep -q 'require("custom")' "$lua"; then
    awk -v ins="$line" '/require\("custom"\)/ && !done { print ins; done = 1 } { print }' "$lua" > "$lua.tmp" && mv "$lua.tmp" "$lua"
  else
    printf '%s\n' "$line" >> "$lua"
  fi
fi

# Legacy conf installs: add the equivalent bind.
if [[ -f $conf ]] && ! grep -q "ipc plugins toggle" "$conf"; then
  printf '\nbind = SUPER, X, exec, sh -lc '\''$HOME/.local/bin/ryoku-shell ipc plugins toggle'\''\n' >> "$conf"
fi
