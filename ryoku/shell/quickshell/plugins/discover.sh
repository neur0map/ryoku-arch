#!/usr/bin/env bash
# Emit the enabled plugin set as one JSON array on stdout. Each element merges a
# plugin's manifest.json with the user's placement from plugins.json:
#
#   { "id", "dir", "manifest": {...}, "placement": {...} }
#
# Plugin sources are discovered from (first wins on duplicate id):
#   $RYOKU_PLUGINS_DIR (dev override, colon-separated)
#   ~/.local/share/ryoku/plugins
# User placement + per-plugin settings live in ~/.config/ryoku/plugins.json:
#   { "<id>": { "enabled": bool, "host": "...", "<host>": {...}, "key": "...",
#               "settings": {...} } }
# A plugin with no entry, or enabled=false, is omitted (the shell only loads
# what the user turned on).
set -euo pipefail

cfg_home="${XDG_CONFIG_HOME:-$HOME/.config}"
data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
user_json="$cfg_home/ryoku/plugins.json"

user='{}'
[ -f "$user_json" ] && user="$(jq '. // {}' "$user_json" 2>/dev/null || echo '{}')"

dirs=()
if [ -n "${RYOKU_PLUGINS_DIR:-}" ]; then
	IFS=':' read -r -a extra <<<"$RYOKU_PLUGINS_DIR"
	dirs+=("${extra[@]}")
fi
dirs+=("$data_home/ryoku/plugins")

declare -A seen
out='[]'
for d in "${dirs[@]}"; do
	[ -d "$d" ] || continue
	for m in "$d"/*/manifest.json; do
		[ -f "$m" ] || continue
		pdir="$(dirname "$m")"
		id="$(jq -r '.id // empty' "$m" 2>/dev/null || true)"
		[ -n "$id" ] || continue
		[ -n "${seen[$id]:-}" ] && continue
		seen[$id]=1
		# Skip plugins the user has not enabled.
		enabled="$(jq -r --arg id "$id" '.[$id].enabled // false' <<<"$user")"
		[ "$enabled" = "true" ] || continue
		entry="$(jq -n \
			--arg id "$id" \
			--arg dir "$pdir" \
			--slurpfile man "$m" \
			--argjson place "$(jq --arg id "$id" '.[$id] // {}' <<<"$user")" \
			'{ id: $id, dir: $dir, manifest: $man[0], placement: $place }')"
		out="$(jq --argjson e "$entry" '. + [$e]' <<<"$out")"
	done
done
printf '%s\n' "$out"
