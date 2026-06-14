echo "Move manual backlight device mappings into the typed shell config"

# Stage 1 consolidation: the brightness card's per-output backlight device
# overrides lived under the legacy settings-gui `brightness` domain; they now
# live in typed GlobalConfig.services (~/.config/ryoku/shell.json). Copy the
# mappings the user already configured so their choices survive.
src="${XDG_CONFIG_HOME:-$HOME/.config}/ryoku/settings-gui/settings.json"
dst="${XDG_CONFIG_HOME:-$HOME/.config}/ryoku/shell.json"

if ryoku-cmd-missing jq; then
  echo "  jq missing; skipping brightness config migration"
  exit 0
fi

[[ -f $src ]] || exit 0
mkdir -p "$(dirname "$dst")"
[[ -f $dst ]] || printf '{}\n' >"$dst"

tmp="$(mktemp)"
if jq --slurpfile s "$src" '
  ($s[0].brightness // {}) as $b
  | .services = ((.services // {})
      + ($b
         | {backlightDeviceMappings}
         | with_entries(select(.value != null))))
' "$dst" >"$tmp"; then
  mv "$tmp" "$dst"
else
  rm -f "$tmp"
fi

if ryoku-cmd-present systemctl; then
  systemctl --user restart ryoku-shell.service >/dev/null 2>&1 || true
fi
