#!/usr/bin/env bash
# Migrate users off the removed Three-Island bar style.
#  bar.cornerStyle == 4 becomes 0 (Hug). Other values left alone.
#  Strip orphaned bar.dynamicIsland.states and .statePrecedence keys.
#  Strip bar.modules.secPulse and the bar.secPulse block.
#  bar.dynamicIsland.tools.* (the Mod+S toolkit schema) is preserved.
# Idempotent.

set -euo pipefail

echo "Retire the three-island bar style and orphaned secPulse keys"

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
CFG="$CONFIG_HOME/ryoku-shell/config.json"

if [[ ! -f "$CFG" ]]; then
    echo "  no config at $CFG, skipping"
    exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "  jq not available, skipping" >&2
    exit 0
fi

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

jq '
    (if (.bar.cornerStyle? == 4) then .bar.cornerStyle = 0 else . end)
    | del(.bar.dynamicIsland.states)
    | del(.bar.dynamicIsland.statePrecedence)
    | del(.bar.modules.secPulse)
    | del(.bar.secPulse)
' "$CFG" > "$TMP"

if ! cmp -s "$CFG" "$TMP"; then
    cp "$TMP" "$CFG"
    echo "  patched $CFG"
else
    echo "  $CFG already clean"
fi
