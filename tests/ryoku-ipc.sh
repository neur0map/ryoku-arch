#!/bin/bash

set -euo pipefail
cd "$(dirname "$0")/.."

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

pass() {
  echo "OK: $1"
}

ipc="bin/ryoku-ipc"

[[ -f $ipc ]] || fail "bin/ryoku-ipc missing"
[[ -x $ipc ]] || fail "bin/ryoku-ipc should be executable"

"$ipc" --help | grep -q "ryoku-ipc shell toggle wallpaper" \
  || fail "help should document shell wallpaper toggle"
"$ipc" --help | grep -q "ryoku-ipc wallpaper list --jsonl" \
  || fail "help should document wallpaper list JSONL"
"$ipc" --help | grep -q "ryoku-ipc wallpaper wallhaven search" \
  || fail "help should document wallhaven search"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/config/current/theme/backgrounds" "$tmpdir/config/backgrounds/test"
printf '%s\n' "test" > "$tmpdir/config/current/theme.name"

RYOKU_PATH="$PWD" \
RYOKU_CONFIG_PATH="$tmpdir/config" \
RYOKU_STATE_PATH="$tmpdir/state" \
  "$ipc" wallpaper settings get --json \
  | jq -e '.wallpaper_dirs | length >= 2' >/dev/null \
  || fail "settings get should emit wallpaper dirs as JSON"

RYOKU_PATH="$PWD" \
RYOKU_CONFIG_PATH="$tmpdir/config" \
RYOKU_STATE_PATH="$tmpdir/state" \
  "$ipc" shell command wallpaper \
  | grep -q 'qs -c ryoku ipc call popups toggleWallpaper' \
  || fail "shell command wallpaper should print the Quickshell IPC command"

pass "ryoku-ipc contract"
