#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

if ! command -v jq >/dev/null 2>&1; then
  echo "SKIP: jq not available"
  exit 0
fi

bash -n "$ROOT_DIR/bin/ryoku-monitor" || fail "ryoku-monitor has a syntax error"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
stub="$tmp/bin"
mkdir -p "$stub"

# Stub hyprctl: serve the test's monitor topology for `monitors all -j`, and accept any
# `keyword monitor` apply (so a non-refused apply exits 0).
cat >"$stub/hyprctl" <<EOF
#!/bin/bash
case "\$*" in
  "monitors all -j") cat "$tmp/mons.json" ;;
  "keyword monitor "*) echo ok; exit 0 ;;
  *) exit 0 ;;
esac
EOF
chmod +x "$stub/hyprctl"

apply_rc() {
  local rc=0
  PATH="$stub:$PATH" RYOKU_PATH="$ROOT_DIR" \
    "$ROOT_DIR/bin/ryoku-monitor" apply "$1" >/dev/null 2>&1 || rc=$?
  echo "$rc"
}

# A. The only active output may not be disabled (would blank the session) -> exit 2.
printf '%s\n' '[{"name":"eDP-1","disabled":false}]' >"$tmp/mons.json"
rc="$(apply_rc "eDP-1, disable")"
(( rc == 2 )) || fail "should refuse disabling the only active monitor (got rc=$rc)"

# B. Disabling one of two active outputs is allowed -> proceeds (exit 0).
printf '%s\n' '[{"name":"eDP-1","disabled":false},{"name":"DP-1","disabled":false}]' >"$tmp/mons.json"
rc="$(apply_rc "DP-1, disable")"
(( rc == 0 )) || fail "disabling one of two active monitors should proceed (got rc=$rc)"

# C. A normal (non-disable) apply is never blocked -> proceeds (exit 0).
printf '%s\n' '[{"name":"eDP-1","disabled":false}]' >"$tmp/mons.json"
rc="$(apply_rc "eDP-1, 2560x1440@60, 0x0, 1")"
(( rc == 0 )) || fail "a normal monitor apply should proceed (got rc=$rc)"

# D. Disabling an already-disabled output never reduces the active count -> proceeds.
printf '%s\n' '[{"name":"eDP-1","disabled":false},{"name":"DP-1","disabled":true}]' >"$tmp/mons.json"
rc="$(apply_rc "DP-1, disable")"
(( rc == 0 )) || fail "disabling an already-disabled output should proceed (got rc=$rc)"

echo "PASS: ryoku-monitor refuses to disable the only active monitor"
