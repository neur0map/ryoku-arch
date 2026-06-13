echo "Move dock and template settings into the typed shell config"

# Stage 1 consolidation (batch 3): dock layout/pins and theming templates now live
# in the typed GlobalConfig (~/.config/ryoku/shell.json) instead of the settings-gui
# store. Copy any values the user already set so behaviour is preserved. Additive:
# the old settings-gui keys remain until the Settings facade is retired (gated).
src="${XDG_CONFIG_HOME:-$HOME/.config}/ryoku/settings-gui/settings.json"
dst="${XDG_CONFIG_HOME:-$HOME/.config}/ryoku/shell.json"

if ryoku-cmd-missing jq; then
  echo "  jq missing; skipping dock/templates config migration"
  exit 0
fi

[[ -f $src ]] || exit 0
mkdir -p "$(dirname "$dst")"
[[ -f $dst ]] || printf '{}\n' >"$dst"

tmp="$(mktemp)"
if jq --slurpfile s "$src" '
  ($s[0]) as $src
  | (if ($src.dock? // null) != null then .dock = ((.dock // {}) + $src.dock) else . end)
  | (if ($src.templates? // null) != null then .templates = ((.templates // {}) + $src.templates) else . end)
' "$dst" >"$tmp"; then
  mv "$tmp" "$dst"
else
  rm -f "$tmp"
fi

if ryoku-cmd-present systemctl; then
  systemctl --user restart ryoku-shell.service >/dev/null 2>&1 || true
fi
