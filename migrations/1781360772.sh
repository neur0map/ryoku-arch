echo "Move OSD, notification, and session-menu settings into the typed shell config"

# Stage 1 consolidation (batch 6, extends): OSD, notification, and session-menu settings
# now live in their existing typed GlobalConfig sections (~/.config/ryoku/shell.json).
# NOTE the accessor renames: settings-gui `notifications` -> typed `notifs`; `sessionMenu`
# -> typed `session`. Copy any values the user already set so behaviour is preserved.
# Additive: old settings-gui keys remain until the Settings facade is retired (gated).
src="${XDG_CONFIG_HOME:-$HOME/.config}/ryoku/settings-gui/settings.json"
dst="${XDG_CONFIG_HOME:-$HOME/.config}/ryoku/shell.json"

if ryoku-cmd-missing jq; then
  echo "  jq missing; skipping osd/notifs/session config migration"
  exit 0
fi

[[ -f $src ]] || exit 0
mkdir -p "$(dirname "$dst")"
[[ -f $dst ]] || printf '{}\n' >"$dst"

tmp="$(mktemp)"
if jq --slurpfile s "$src" '
  ($s[0]) as $src
  | (if ($src.osd? // null) != null then .osd = ((.osd // {}) + $src.osd) else . end)
  | (if ($src.notifications? // null) != null then .notifs = ((.notifs // {}) + $src.notifications) else . end)
  | (if ($src.sessionMenu? // null) != null then .session = ((.session // {}) + $src.sessionMenu) else . end)
' "$dst" >"$tmp"; then
  mv "$tmp" "$dst"
else
  rm -f "$tmp"
fi

if ryoku-cmd-present systemctl; then
  systemctl --user restart ryoku-shell.service >/dev/null 2>&1 || true
fi
