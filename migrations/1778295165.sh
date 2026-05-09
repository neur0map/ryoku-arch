#!/usr/bin/env bash
# Add "hosts" to the user's right-sidebar enabledWidgets so the new
# Hosts editor tab appears for users who already had a curated config
# from before the tab existed. Idempotent. Per docs/ui-patterns.md:198-204:
# additive entries get appended only if missing, never replacing the
# user's full list, never seeding a list when none exists (the QML
# runtime fallback handles brand-new users).

set -euo pipefail

echo "Add hosts tab to right-sidebar enabledWidgets"

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

# Three cases:
#   1. enabledWidgets is missing entirely:   leave alone, runtime fallback handles it
#   2. enabledWidgets contains "hosts":      no-op, idempotent
#   3. enabledWidgets exists without "hosts": append-only

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

jq '
    if (.sidebar.right.enabledWidgets // null) == null then
        .
    elif (.sidebar.right.enabledWidgets | index("hosts")) then
        .
    else
        .sidebar.right.enabledWidgets += ["hosts"]
    end
' "$CFG" > "$TMP"

if ! cmp -s "$CFG" "$TMP"; then
    cp "$TMP" "$CFG"
    echo "  appended hosts to enabledWidgets in $CFG"
else
    echo "  no change needed (key missing or already contains hosts)"
fi
