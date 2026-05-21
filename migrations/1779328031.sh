echo "Set shell glass transparency default to 70 percent"

config_file="${XDG_CONFIG_HOME:-$HOME/.config}/ryoku-shell/config.json"

if [[ ! -f $config_file ]]; then
  exit 0
fi

if ryoku-cmd-missing jq; then
  echo "  jq missing; skipping shell glass config update"
  exit 0
fi

tmp_file="$(mktemp)"
if jq '
  .appearance.transparency.enable = true
  | .appearance.transparency.automatic = false
  | .appearance.transparency.backgroundTransparency = 0.70
' "$config_file" >"$tmp_file"; then
  mv "$tmp_file" "$config_file"
else
  rm -f "$tmp_file"
  echo "  failed to update shell glass transparency"
fi
