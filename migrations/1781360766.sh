echo "Enable translucent (glass) shell surfaces by default"

# Transparency is now on by default: the shell's unified blob surface (bar frame +
# panels) becomes translucent and compositor-blurred via the ryoku-drawers layer
# rule. Push the new default onto existing installs by flipping
# appearance.transparency.enabled to true. base/layers (the opacity levels) are
# left untouched so any value the user already tuned is preserved.
config_file="${XDG_CONFIG_HOME:-$HOME/.config}/ryoku/shell.json"

if ryoku-cmd-missing jq; then
  echo "  jq missing; skipping transparency default update"
  exit 0
fi

mkdir -p "$(dirname "$config_file")"
[[ -f $config_file ]] || printf '{}\n' >"$config_file"

tmp="$(mktemp)"
if jq '
  .appearance = (.appearance // {})
  | .appearance.transparency = (.appearance.transparency // {})
  | .appearance.transparency.enabled = true
' "$config_file" >"$tmp"; then
  mv "$tmp" "$config_file"
else
  rm -f "$tmp"
fi

if ryoku-cmd-present systemctl; then
  systemctl --user restart ryoku-shell.service >/dev/null 2>&1 || true
fi
