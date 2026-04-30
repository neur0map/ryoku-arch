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

cache_bin="bin/ryoku-wallpaper-cache"
list_bin="bin/ryoku-wallpaper-list"

[[ -x $cache_bin ]] || fail "ryoku-wallpaper-cache should be executable"
[[ -x $list_bin ]] || fail "ryoku-wallpaper-list should be executable"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/config/current/theme/backgrounds" "$tmpdir/config/backgrounds/test"
printf '%s\n' "test" > "$tmpdir/config/current/theme.name"

magick -size 64x36 xc:'#cc3333' "$tmpdir/config/current/theme/backgrounds/red.png"
magick -size 64x36 xc:'#3366cc' "$tmpdir/config/backgrounds/test/blue.jpg"
printf '%s\n' "not an image" > "$tmpdir/config/backgrounds/test/corrupt.png"

RYOKU_PATH="$PWD" \
RYOKU_CONFIG_PATH="$tmpdir/config" \
RYOKU_STATE_PATH="$tmpdir/state" \
  "$cache_bin" rebuild >/dev/null

[[ -f $tmpdir/state/wallpaper/list.jsonl ]] \
  || fail "cache should write list.jsonl"

line_count=$(wc -l < "$tmpdir/state/wallpaper/list.jsonl")
(( line_count == 2 )) || fail "expected two wallpaper rows, got $line_count"

RYOKU_PATH="$PWD" \
RYOKU_CONFIG_PATH="$tmpdir/config" \
RYOKU_STATE_PATH="$tmpdir/state" \
  "$list_bin" --jsonl \
  | jq -se '
      length == 2
      and all(.[]; .source == "local"
        and .type == "image"
        and (.thumb | length > 0)
        and (.hue | type == "number")
        and .hue >= 0)
    ' >/dev/null \
  || fail "list should emit local image rows with hue and thumbnail"

pass "ryoku wallpaper cache"
