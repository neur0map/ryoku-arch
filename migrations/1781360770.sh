echo "Move calendar and color-scheme settings into the typed shell config"

# Stage 1 consolidation (batch 4): clock/calendar cards and color-scheme / dark-mode /
# matugen settings now live in the typed GlobalConfig (~/.config/ryoku/shell.json)
# instead of the settings-gui store. Copy any values the user already set so behaviour
# is preserved. Additive: the old settings-gui keys remain until the Settings facade is
# retired (a separately-gated step).
src="${XDG_CONFIG_HOME:-$HOME/.config}/ryoku/settings-gui/settings.json"
dst="${XDG_CONFIG_HOME:-$HOME/.config}/ryoku/shell.json"

if ryoku-cmd-missing jq; then
  echo "  jq missing; skipping calendar/color-scheme config migration"
  exit 0
fi

[[ -f $src ]] || exit 0
mkdir -p "$(dirname "$dst")"
[[ -f $dst ]] || printf '{}\n' >"$dst"

tmp="$(mktemp)"
if jq --slurpfile s "$src" '
  ($s[0]) as $src
  | (if ($src.calendar? // null) != null then .calendar = ((.calendar // {}) + $src.calendar) else . end)
  | (if ($src.colorSchemes? // null) != null then .colorSchemes = ((.colorSchemes // {}) + $src.colorSchemes) else . end)
' "$dst" >"$tmp"; then
  mv "$tmp" "$dst"
else
  rm -f "$tmp"
fi

if ryoku-cmd-present systemctl; then
  systemctl --user restart ryoku-shell.service >/dev/null 2>&1 || true
fi
