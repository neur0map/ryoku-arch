echo "Move clipboard, network, and night-light settings into the typed shell config"

# Stage 1 consolidation backfill: the clipboard, network/Bluetooth, and night-light
# domains are now read from typed GlobalConfig (~/.config/ryoku/shell.json); their live
# consumers no longer read the legacy settings-gui store. These were repointed in code
# without a migration, so copy any values the user already set (keys are 1:1 with the
# typed sections) to preserve behaviour. Additive: legacy settings-gui keys remain.
src="${XDG_CONFIG_HOME:-$HOME/.config}/ryoku/settings-gui/settings.json"
dst="${XDG_CONFIG_HOME:-$HOME/.config}/ryoku/shell.json"

if ryoku-cmd-missing jq; then
  echo "  jq missing; skipping clipboard/network/night-light config migration"
  exit 0
fi

[[ -f $src ]] || exit 0
mkdir -p "$(dirname "$dst")"
[[ -f $dst ]] || printf '{}\n' >"$dst"

tmp="$(mktemp)"
if jq --slurpfile s "$src" '
  ($s[0]) as $src
  | (if ($src.clipboard? // null) != null then .clipboard = ((.clipboard // {}) + $src.clipboard) else . end)
  | (if ($src.network? // null) != null then .network = ((.network // {}) + $src.network) else . end)
  | (if ($src.nightLight? // null) != null then .nightLight = ((.nightLight // {}) + $src.nightLight) else . end)
' "$dst" >"$tmp"; then
  mv "$tmp" "$dst"
else
  rm -f "$tmp"
fi

if ryoku-cmd-present systemctl; then
  systemctl --user restart ryoku-shell.service >/dev/null 2>&1 || true
fi
