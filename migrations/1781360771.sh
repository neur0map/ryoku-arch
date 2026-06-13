echo "Move system-monitor settings into the typed shell config"

# Stage 1 consolidation (batch 5): system-monitor thresholds + colors + external-monitor
# command now live in the typed GlobalConfig (~/.config/ryoku/shell.json) instead of the
# settings-gui store. Copy any values the user already set so behaviour is preserved.
# Additive: the old settings-gui keys remain until the Settings facade is retired (gated).
src="${XDG_CONFIG_HOME:-$HOME/.config}/ryoku/settings-gui/settings.json"
dst="${XDG_CONFIG_HOME:-$HOME/.config}/ryoku/shell.json"

if ryoku-cmd-missing jq; then
  echo "  jq missing; skipping system-monitor config migration"
  exit 0
fi

[[ -f $src ]] || exit 0
clip="$(jq -c '.systemMonitor // empty' "$src" 2>/dev/null)"
[[ -n $clip ]] || exit 0

mkdir -p "$(dirname "$dst")"
[[ -f $dst ]] || printf '{}\n' >"$dst"

tmp="$(mktemp)"
if jq --argjson c "$clip" '.systemMonitor = ((.systemMonitor // {}) + $c)' "$dst" >"$tmp"; then
  mv "$tmp" "$dst"
else
  rm -f "$tmp"
fi

if ryoku-cmd-present systemctl; then
  systemctl --user restart ryoku-shell.service >/dev/null 2>&1 || true
fi
