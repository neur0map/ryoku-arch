#!/usr/bin/env bash
# emit the enabled plugin set as one JSON array on stdout. each element merges
# a manifest.json with the user's placement from plugins.json:
#   { "id", "dir", "manifest": {...}, "placement": {...} }
# sources, first wins on duplicate id:
#   $RYOKU_PLUGINS_DIR (dev override, colon-separated)
#   ~/.local/share/ryoku/plugins
# placement + per-plugin settings live in ~/.config/ryoku/plugins.json:
#   { "<id>": { "enabled": bool, "host": "...", "<host>": {...}, "key": "...",
#               "settings": {...} } }
# no entry or enabled=false = skipped. the shell only loads what the user
# actually turned on.
set -euo pipefail

cfg_home="${XDG_CONFIG_HOME:-$HOME/.config}"
data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
user_json="$cfg_home/ryoku/plugins.json"

# --all = every installed plugin (Settings wants that). default = only enabled
# (the runtime wants that).
all=0
[ "${1:-}" = "--all" ] && all=1

user='{}'
# missing / empty / corrupt plugins.json = {}. one bad write must never blank
# the whole installed listing.
if [ -s "$user_json" ]; then
	parsed="$(jq -c '.' "$user_json" 2>/dev/null || true)"
	[ -n "$parsed" ] && [ "$parsed" != "null" ] && user="$parsed"
fi

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
		# runtime mode skips anything the user didn't enable. --all keeps everything.
		enabled="$(jq -r --arg id "$id" '.[$id].enabled // false' <<<"$user")"
		[ "$all" = "1" ] || [ "$enabled" = "true" ] || continue
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
