#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

pass() {
  echo "OK: $1"
}

assert_eq() {
  local got="$1" expected="$2" label="$3"
  [[ $got == "$expected" ]] || fail "$label: expected '$expected', got '$got'"
}

source "$ROOT_DIR/lib/wallpaper-backends.sh"

assert_eq "$(ryoku_wp_type /x/photo.PNG)"   "image"    "PNG -> image"
assert_eq "$(ryoku_wp_type /x/photo.jpeg)"  "image"    "jpeg -> image"
assert_eq "$(ryoku_wp_type /x/loop.gif)"    "animated" "gif -> animated"
assert_eq "$(ryoku_wp_type /x/clip.mp4)"    "video"    "mp4 -> video"
assert_eq "$(ryoku_wp_type /x/clip.WEBM)"   "video"    "WEBM -> video"
assert_eq "$(ryoku_wp_type /x/unknown.txt)" "image"    "unknown -> image fallback"

state="$(mktemp -d)"
trap 'rm -rf "$state"' EXIT
export RYOKU_STATE_PATH="$state"
ryoku_wp_write_type animated
[[ -f $state/wallpaper/type.txt ]] \
  || fail "ryoku_wp_write_type should create \$RYOKU_STATE_PATH/wallpaper/type.txt"
assert_eq "$(< "$state/wallpaper/type.txt")" "animated" "type.txt content"

pass "wallpaper-backends"
