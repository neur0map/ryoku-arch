echo "Move wallpaper, app-launcher, and hook settings into the typed shell config"

# Stage 1 consolidation (batch 7): wallpaper, app-launcher, and user-hook settings now
# live in typed GlobalConfig (~/.config/ryoku/shell.json). NOTE the accessor rename:
# settings-gui `appLauncher` -> typed `launcher`. Copy any values the user already set so
# behaviour is preserved. Additive: old settings-gui keys remain until the Settings facade
# is retired (a separately-gated step).
src="${XDG_CONFIG_HOME:-$HOME/.config}/ryoku/settings-gui/settings.json"
dst="${XDG_CONFIG_HOME:-$HOME/.config}/ryoku/shell.json"

if ryoku-cmd-missing jq; then
  echo "  jq missing; skipping wallpaper/launcher/hooks config migration"
  exit 0
fi

[[ -f $src ]] || exit 0
mkdir -p "$(dirname "$dst")"
[[ -f $dst ]] || printf '{}\n' >"$dst"

tmp="$(mktemp)"
if jq --slurpfile s "$src" '
  ($s[0]) as $src
  | (if ($src.wallpaper? // null) != null then .wallpaper = ((.wallpaper // {}) + $src.wallpaper) else . end)
  | (if ($src.appLauncher? // null) != null then .launcher = ((.launcher // {}) + $src.appLauncher) else . end)
  | (if ($src.hooks? // null) != null then .hooks = ((.hooks // {}) + $src.hooks) else . end)
' "$dst" >"$tmp"; then
  mv "$tmp" "$dst"
else
  rm -f "$tmp"
fi

if ryoku-cmd-present systemctl; then
  systemctl --user restart ryoku-shell.service >/dev/null 2>&1 || true
fi
