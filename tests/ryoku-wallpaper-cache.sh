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

wallpaper_dir="$tmpdir/Pictures/Wallpapers"
mkdir -p "$tmpdir/config/current/theme/backgrounds" "$tmpdir/config/backgrounds/test" "$wallpaper_dir"
printf '%s\n' "test" > "$tmpdir/config/current/theme.name"

magick -size 64x36 xc:'#cc3333' "$tmpdir/config/current/theme/backgrounds/red.png"
magick -size 64x36 xc:'#3366cc' "$tmpdir/config/backgrounds/test/blue.jpg"
magick -size 64x36 xc:'#33cc66' "$wallpaper_dir/green.webp"
printf '%s\n' "not an image" > "$tmpdir/config/backgrounds/test/corrupt.png"

RYOKU_PATH="$PWD" \
RYOKU_CONFIG_PATH="$tmpdir/config" \
RYOKU_STATE_PATH="$tmpdir/state" \
RYOKU_WALLPAPER_DIR="$wallpaper_dir" \
  "$cache_bin" rebuild >/dev/null

[[ -f $tmpdir/state/wallpaper/list.jsonl ]] \
  || fail "cache should write list.jsonl"

line_count=$(wc -l < "$tmpdir/state/wallpaper/list.jsonl")
(( line_count == 3 )) || fail "expected three wallpaper rows, got $line_count"

RYOKU_PATH="$PWD" \
RYOKU_CONFIG_PATH="$tmpdir/config" \
RYOKU_STATE_PATH="$tmpdir/state" \
RYOKU_WALLPAPER_DIR="$wallpaper_dir" \
  "$list_bin" --jsonl \
  | jq -se '
      length == 3
      and all(.[]; .source == "local"
        and .type == "image"
        and (.thumb | length > 0)
        and (.hue | type == "number")
        and .hue >= 0)
      and any(.[]; .path | endswith("/Pictures/Wallpapers/green.webp"))
    ' >/dev/null \
  || fail "list should emit local image rows with hue and thumbnail"

magick -size 64x36 xc:'#6633cc' "$wallpaper_dir/moved-in.png"

RYOKU_PATH="$PWD" \
RYOKU_CONFIG_PATH="$tmpdir/config" \
RYOKU_STATE_PATH="$tmpdir/state" \
RYOKU_WALLPAPER_DIR="$wallpaper_dir" \
  "$list_bin" --jsonl \
  | jq -se 'length == 4 and any(.[]; .path | endswith("/Pictures/Wallpapers/moved-in.png"))' >/dev/null \
  || fail "list should refresh when a wallpaper is moved into Pictures/Wallpapers"

pass "ryoku wallpaper cache"
