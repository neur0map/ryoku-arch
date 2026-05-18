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

apply_bin="bin/ryoku-wallpaper-apply"

[[ -x $apply_bin ]] || fail "bin/ryoku-wallpaper-apply should be executable"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/ryoku/bin" "$tmpdir/config/current" "$tmpdir/state" "$tmpdir/path"
mkdir -p "$tmpdir/xdg-config/ryoku-shell"
printf '%s\n' '{"background":{}}' >"$tmpdir/xdg-config/ryoku-shell/config.json"

cat >"$tmpdir/ryoku/bin/ryoku-theme-bg-set" <<'EOF'
#!/bin/bash
mkdir -p "$(dirname "$APPLY_ARGS")"
printf '%s\n' "$@" >"$APPLY_ARGS"
EOF
chmod +x "$tmpdir/ryoku/bin/ryoku-theme-bg-set"

cat >"$tmpdir/ryoku/bin/ryoku-cmd-missing" <<'EOF'
#!/bin/bash
for cmd in "$@"; do
  if [[ $cmd == "mpvpaper" ]]; then
    exit 0
  fi
done
exit 1
EOF
chmod +x "$tmpdir/ryoku/bin/ryoku-cmd-missing"

cat >"$tmpdir/ryoku/bin/ryoku-cmd-present" <<'EOF'
#!/bin/bash
exit 1
EOF
chmod +x "$tmpdir/ryoku/bin/ryoku-cmd-present"

cat >"$tmpdir/ryoku/bin/pkill" <<'EOF'
#!/bin/bash
printf '%s\n' "$@" >>"$PKILL_ARGS"
exit 0
EOF
chmod +x "$tmpdir/ryoku/bin/pkill"

run_apply() {
  rm -f "$tmpdir/apply.args" "$tmpdir/pkill.args"
  set +e
  APPLY_OUTPUT="$(
    APPLY_ARGS="$tmpdir/apply.args" \
    PKILL_ARGS="$tmpdir/pkill.args" \
    RYOKU_PATH="$tmpdir/ryoku" \
    RYOKU_CONFIG_PATH="$tmpdir/config" \
    RYOKU_STATE_PATH="$tmpdir/state" \
    XDG_CONFIG_HOME="$tmpdir/xdg-config" \
    PATH="$tmpdir/ryoku/bin:$PATH" \
      "$apply_bin" "$@" 2>&1
  )"
  APPLY_STATUS=$?
  set -e
}

assert_json_error() {
  local description="$1"
  local expected_status="$2"

  (( APPLY_STATUS == expected_status )) \
    || fail "$description should exit $expected_status, got $APPLY_STATUS"
  printf '%s\n' "$APPLY_OUTPUT" | jq -e '.ok == false and (.error | length > 0)' >/dev/null \
    || fail "$description should emit JSON error"
}

run_apply
assert_json_error "missing args" 2

run_apply --type audio "$tmpdir/song.mp3"
assert_json_error "unknown type" 2

run_apply --type image "$tmpdir/missing image.jpg"
assert_json_error "missing image" 1

video="$tmpdir/video with spaces.mp4"
: >"$video"
run_apply --type video "$video"
(( APPLY_STATUS == 0 )) || fail "video apply should succeed through Ryoku wallpaper config"
printf '%s\n' "$APPLY_OUTPUT" | jq -e --arg path "$video" '.ok == true and .type == "video" and .path == $path' >/dev/null \
  || fail "video apply should emit JSON OK"
[[ ! -f $tmpdir/pkill.args ]] \
  || fail "video apply should not launch or stop legacy wallpaper processes"
[[ ! -f $tmpdir/apply.args ]] \
  || fail "video apply should not pass the video file to ryoku-theme-bg-set"
jq -e --arg path "$video" '.background.wallpaperPath == $path and .background.thumbnailPath == ""' \
  "$tmpdir/xdg-config/ryoku-shell/config.json" >/dev/null \
  || fail "video apply should persist video wallpaper path without a poster"

image="$tmpdir/image with spaces.jpg"
: >"$image"
run_apply --type image "$image"
(( APPLY_STATUS == 0 )) || fail "image apply should succeed with stubbed theme setter"
printf '%s\n' "$APPLY_OUTPUT" | jq -e --arg path "$image" '.ok == true and .type == "image" and .path == $path' >/dev/null \
  || fail "image apply should emit JSON OK"

line_count=$(wc -l < "$tmpdir/apply.args")
(( line_count == 1 )) || fail "image path should be passed to ryoku-theme-bg-set as one argument"
[[ $(<"$tmpdir/apply.args") == "$image" ]] \
  || fail "image path with spaces should be preserved for ryoku-theme-bg-set"

direct_config="$tmpdir/direct-config"
direct_xdg="$tmpdir/direct-xdg"
direct_image="$tmpdir/direct image.jpg"
: >"$direct_image"
mkdir -p "$direct_config" "$direct_xdg/ryoku-shell" "$direct_xdg/illogical-impulse"
printf '%s\n' '{"background":{}}' >"$direct_xdg/ryoku-shell/config.json"
printf '%s\n' '{"background":{}}' >"$direct_xdg/illogical-impulse/config.json"

RYOKU_PATH="$PWD" \
RYOKU_CONFIG_PATH="$direct_config" \
XDG_CONFIG_HOME="$direct_xdg" \
PATH="$tmpdir/ryoku/bin:$PATH" \
  bin/ryoku-theme-bg-set "$direct_image"

jq -e '.background.wallpaperPath | endswith("/current/background")' \
  "$direct_xdg/illogical-impulse/config.json" >/dev/null \
  || fail "image setter should update a real legacy shell config when it is the active config"
jq -e '.background.wallpaperPath == null' \
  "$direct_xdg/ryoku-shell/config.json" >/dev/null \
  || fail "image setter should not update a different inactive shell config"

rm -rf "$direct_xdg/illogical-impulse"
ln -s "$direct_xdg/ryoku-shell" "$direct_xdg/illogical-impulse"

RYOKU_PATH="$PWD" \
RYOKU_CONFIG_PATH="$direct_config" \
XDG_CONFIG_HOME="$direct_xdg" \
PATH="$tmpdir/ryoku/bin:$PATH" \
  bin/ryoku-theme-bg-set "$direct_image"

jq -e '.background.wallpaperPath | endswith("/current/background")' \
  "$direct_xdg/ryoku-shell/config.json" >/dev/null \
  || fail "image setter should update the Ryoku config when legacy path is a symlink"

pass "ryoku wallpaper apply"
