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

# --- ryoku CLI dispatch ---

assert_contains() {
  local haystack="$1" needle="$2" label="$3"
  printf '%s' "$haystack" | grep -qF -- "$needle" || fail "$label: output did not contain '$needle' (got: $haystack)"
  pass "$label"
}

_tmpd="$(mktemp -d)"
trap 'rm -rf "$_tmpd"' EXIT

_bin="$_tmpd/bin"; mkdir -p "$_bin"
_log="$_tmpd/apply.log"
cat >"$_bin/ryoku-wallpaper-apply" <<EOF
#!/bin/bash
echo "APPLY \$*" >>"$_log"
EOF
chmod +x "$_bin/ryoku-wallpaper-apply"

touch "$_tmpd/loop.gif" "$_tmpd/clip.mp4" "$_tmpd/photo.png"

_home="$_tmpd/home"; mkdir -p "$_home"

_run_ryoku() {
  local file="$1"
  : >"$_log"
  HOME="$_home" \
  XDG_STATE_HOME="$_home/.local/state" \
  RYOKU_PATH="$_tmpd/no-ryoku-bin" \
  PATH="$_bin:$PATH" \
    "$ROOT_DIR/shell/scripts/ryoku" wallpaper -f "$file" 2>/dev/null || true
  cat "$_log"
}

_out_gif="$(_run_ryoku "$_tmpd/loop.gif")"
assert_contains "$_out_gif" "--type animated" "gif dispatches animated"

_out_mp4="$(_run_ryoku "$_tmpd/clip.mp4")"
assert_contains "$_out_mp4" "--type video" "mp4 dispatches video"

_out_png="$(_run_ryoku "$_tmpd/photo.png")"
assert_contains "$_out_png" "--type image" "png dispatches image"

pass "ryoku CLI dispatch"
