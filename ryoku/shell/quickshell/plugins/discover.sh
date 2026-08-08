#!/usr/bin/env bash
# emit the enabled plugin set as one JSON array on stdout. each element merges
# a manifest.json with the user's placement from plugins.json. Installed-tree
# entries also require their Store receipt, whose version is authoritative:
#   { "id", "dir", "version", "manifest": {...}, "placement": {...} }
# sources, first wins on duplicate id:
#   $RYOKU_PLUGINS_DIR (dev override, colon-separated, no receipt required)
#   ~/.local/share/ryoku/plugins (receipt-owned Store products only)
# placement + per-plugin settings live in ~/.config/ryoku/plugins.json:
#   { "<id>": { "enabled": bool, "host": "...", "<host>": {...}, "key": "...",
#               "settings": {...} } }
# no entry or enabled=false = skipped. the shell only loads what the user
# actually turned on.
set -euo pipefail

cfg_home="${XDG_CONFIG_HOME:-$HOME/.config}"
data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
state_root="$state_home/ryoku/store"
index_json='[]'
[ ! -s "$state_root/plugins.json" ] || index_json="$(jq -c 'if type == "array" then . else [] end' "$state_root/plugins.json" 2>/dev/null || printf '[]')"
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
installed_root="$data_home/ryoku/plugins"
dirs+=("$installed_root")

declare -A seen
out='[]'
for d in "${dirs[@]}"; do
	[ -d "$d" ] || continue
	for m in "$d"/*/manifest.json; do
		[ -f "$m" ] || continue
		pdir="$(dirname "$m")"
		id="$(jq -r '.id // empty' "$m" 2>/dev/null || true)"
		[ -n "$id" ] || continue
		[[ "$id" =~ ^[a-z0-9][a-z0-9-]*$ ]] || continue
		version="$(jq -r '.version // empty' "$m" 2>/dev/null || true)"
		if [ "$d" = "$installed_root" ]; then
			receipt="$state_home/ryoku/store/plugins/$id.json"
			[ -f "$receipt" ] || continue
			version="$(jq -r --arg id "$id" \
				'select(.category == "plugins" and .id == $id and .destination == ("ryoku/plugins/" + $id)) | .version // empty' \
				"$receipt" 2>/dev/null || true)"
			[ -n "$version" ] || continue
			row="$(jq -c --arg id "$id" --arg version "$version" \
				'[.[] | select(.id == $id and .version == $version)][0] // empty' <<<"$index_json")"
			[ -n "$row" ] || continue
			view="$(jq -r '.view // empty' <<<"$row")"
			[[ "$view" =~ ^plugin-views/$id/[a-f0-9]{64}$ ]] || continue
			pdir="$state_root/$view"
			m="$pdir/manifest.json"
			[ -f "$m" ] || continue
			[ "$(jq -r '.id // empty' "$m" 2>/dev/null || true)" = "$id" ] || continue
		fi
		[ -n "${seen[$id]:-}" ] && continue
		seen[$id]=1
		# runtime mode skips anything the user didn't enable. --all keeps everything.
		enabled="$(jq -r --arg id "$id" '.[$id].enabled // false' <<<"$user")"
		[ "$all" = "1" ] || [ "$enabled" = "true" ] || continue
		entry="$(jq -n \
			--arg id "$id" \
			--arg dir "$pdir" \
			--arg version "$version" \
			--slurpfile man "$m" \
			--argjson place "$(jq --arg id "$id" '.[$id] // {}' <<<"$user")" \
			'{ id: $id, dir: $dir, version: $version, manifest: $man[0], placement: $place }')"
		out="$(jq --argjson e "$entry" '. + [$e]' <<<"$out")"
	done
done
printf '%s\n' "$out"
