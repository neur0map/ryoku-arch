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

# --- scheme source resolution: live types use poster, image uses raw path ---

_stmp="$(mktemp -d)"
trap 'rm -rf "$_stmp"' EXIT

_sbin="$_stmp/bin"; mkdir -p "$_sbin"
_slog="$_stmp/scheme.log"

# Stub ryoku-wallpaper-to-scheme: log the source path and emit minimal valid JSON
cat >"$_sbin/ryoku-wallpaper-to-scheme" <<'EOF'
#!/bin/bash
echo "SCHEMESRC $1" >>"$SCHEME_LOG"
printf '{"name":"wallpaper","flavour":"wallpaper","mode":"dark","variant":"tonalspot","colours":{"primary_paletteKeyColor":"F25623"}}\n'
EOF
chmod +x "$_sbin/ryoku-wallpaper-to-scheme"

_shome="$_stmp/home"; mkdir -p "$_shome"
_sstate="$_shome/.local/state/ryoku-shell/wallpaper"
_sconfig="$_shome/.config/ryoku/current"
mkdir -p "$_sstate" "$_sconfig"

# Create a real poster file the symlink will point at
touch "$_stmp/poster.jpg"

# Case A: live type (video): scheme source must be the poster, not the raw mp4
touch "$_stmp/clip.mp4"
printf '%s\n' "$_stmp/clip.mp4" >"$_sstate/path.txt"
printf '%s\n' "video" >"$_sstate/type.txt"
ln -nsf "$_stmp/poster.jpg" "$_sconfig/background"

: >"$_slog"
SCHEME_LOG="$_slog" \
HOME="$_shome" \
XDG_STATE_HOME="$_shome/.local/state" \
RYOKU_PATH="$_stmp/no-ryoku-bin" \
PATH="$_sbin:$PATH" \
  "$ROOT_DIR/shell/scripts/ryoku" scheme from-wallpaper >/dev/null 2>/dev/null || true

_src_live="$(grep '^SCHEMESRC ' "$_slog" | head -n1 | sed 's/^SCHEMESRC //')"
[[ -n "$_src_live" ]] \
  || fail "scheme source for video type must not be empty"
[[ "$_src_live" != "$_stmp/clip.mp4" ]] \
  || fail "scheme source for video type must NOT be the raw mp4 (got: $_src_live)"
printf '%s' "$_src_live" | grep -qF "$_stmp/poster.jpg" \
  || fail "scheme source for video type must be the poster (got: $_src_live)"
pass "video wallpaper: scheme source is poster"

# Case B: animated type, same poster routing
touch "$_stmp/loop.gif"
printf '%s\n' "$_stmp/loop.gif" >"$_sstate/path.txt"
printf '%s\n' "animated" >"$_sstate/type.txt"

: >"$_slog"
SCHEME_LOG="$_slog" \
HOME="$_shome" \
XDG_STATE_HOME="$_shome/.local/state" \
RYOKU_PATH="$_stmp/no-ryoku-bin" \
PATH="$_sbin:$PATH" \
  "$ROOT_DIR/shell/scripts/ryoku" scheme from-wallpaper >/dev/null 2>/dev/null || true

_src_anim="$(grep '^SCHEMESRC ' "$_slog" | head -n1 | sed 's/^SCHEMESRC //')"
[[ "$_src_anim" != "$_stmp/loop.gif" ]] \
  || fail "scheme source for animated type must NOT be the raw gif (got: $_src_anim)"
printf '%s' "$_src_anim" | grep -qF "$_stmp/poster.jpg" \
  || fail "scheme source for animated type must be the poster (got: $_src_anim)"
pass "animated wallpaper: scheme source is poster"

# Case C: image type: scheme source must be the raw image path
_real_png="$_stmp/photo.png"
touch "$_real_png"
printf '%s\n' "$_real_png" >"$_sstate/path.txt"
printf '%s\n' "image" >"$_sstate/type.txt"

: >"$_slog"
SCHEME_LOG="$_slog" \
HOME="$_shome" \
XDG_STATE_HOME="$_shome/.local/state" \
RYOKU_PATH="$_stmp/no-ryoku-bin" \
PATH="$_sbin:$PATH" \
  "$ROOT_DIR/shell/scripts/ryoku" scheme from-wallpaper >/dev/null 2>/dev/null || true

_src_img="$(grep '^SCHEMESRC ' "$_slog" | head -n1 | sed 's/^SCHEMESRC //')"
[[ "$_src_img" == "$_real_png" ]] \
  || fail "scheme source for image type must be the raw image path (got: $_src_img)"
pass "image wallpaper: scheme source is raw path"
