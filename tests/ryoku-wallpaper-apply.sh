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

# Stub out system poster tools so they don't run on empty fixture files.
cat >"$tmpdir/ryoku/bin/ffmpegthumbnailer" <<'EOF'
#!/bin/bash
exit 1
EOF
chmod +x "$tmpdir/ryoku/bin/ffmpegthumbnailer"

cat >"$tmpdir/ryoku/bin/awww" <<'EOF'
#!/bin/bash
exit 0
EOF
chmod +x "$tmpdir/ryoku/bin/awww"

cat >"$tmpdir/ryoku/bin/mpvpaper" <<'EOF'
#!/bin/bash
exit 0
EOF
chmod +x "$tmpdir/ryoku/bin/mpvpaper"

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

# --- Backend dispatch: animated, video launch, image teardown, type.txt ---

_log="$tmpdir/launcher.log"
_bin2="$tmpdir/bin2"
mkdir -p "$_bin2"

# Stub launchers that log their argv
for _cmd in awww awww-daemon mpvpaper; do
  cat >"$_bin2/$_cmd" <<EOF
#!/bin/bash
printf '%s\n' "$_cmd \$*" >>"$_log"
exit 0
EOF
  chmod +x "$_bin2/$_cmd"
done

# Stub pkill to log argv
cat >"$_bin2/pkill" <<'EOF'
#!/bin/bash
printf 'pkill %s\n' "$*" >>"$LAUNCHER_LOG"
exit 0
EOF
chmod +x "$_bin2/pkill"

# Stub poster tools (ffmpegthumbnailer: touch file at arg after -o; convert: touch last arg)
cat >"$_bin2/ffmpegthumbnailer" <<'EOF'
#!/bin/bash
while (( $# > 0 )); do
  if [[ $1 == -o ]]; then touch "$2"; exit 0; fi
  shift
done
exit 0
EOF
chmod +x "$_bin2/ffmpegthumbnailer"

cat >"$_bin2/convert" <<'EOF'
#!/bin/bash
touch "${@: -1}"
exit 0
EOF
chmod +x "$_bin2/convert"

_state2="$tmpdir/state2"
_config2="$tmpdir/config2"
_xdg2="$tmpdir/xdg2"
mkdir -p "$_state2" "$_xdg2/ryoku-shell"
printf '%s\n' '{"background":{}}' >"$_xdg2/ryoku-shell/config.json"

run_apply2() {
  : >"$_log"
  set +e
  APPLY2_OUTPUT="$(
    LAUNCHER_LOG="$_log" \
    APPLY_ARGS="$tmpdir/apply2.args" \
    RYOKU_PATH="$tmpdir/ryoku" \
    RYOKU_CONFIG_PATH="$_config2" \
    RYOKU_STATE_PATH="$_state2" \
    XDG_CONFIG_HOME="$_xdg2" \
    HOME="$tmpdir/home2" \
    PATH="$_bin2:$tmpdir/ryoku/bin:$PATH" \
      "$apply_bin" "$@" 2>&1
  )"
  APPLY2_STATUS=$?
  set -e
}

# Test: animated type
gif="$tmpdir/loop.gif"
touch "$gif"
run_apply2 --type animated "$gif"
(( APPLY2_STATUS == 0 )) \
  || fail "animated apply should succeed (output: $APPLY2_OUTPUT)"
grep -q 'awww img' "$_log" \
  || fail "animated apply should invoke awww img (log: $(cat "$_log"))"
[[ -f $_state2/wallpaper/type.txt ]] \
  || fail "animated apply should create type.txt"
[[ $(<"$_state2/wallpaper/type.txt") == "animated" ]] \
  || fail "animated apply should write 'animated' to type.txt"

# Test: video type launches mpvpaper
mp4="$tmpdir/clip.mp4"
touch "$mp4"
run_apply2 --type video "$mp4"
(( APPLY2_STATUS == 0 )) \
  || fail "video apply should succeed (output: $APPLY2_OUTPUT)"
grep -q 'mpvpaper' "$_log" \
  || fail "video apply should invoke mpvpaper (log: $(cat "$_log"))"
[[ $(<"$_state2/wallpaper/type.txt") == "video" ]] \
  || fail "video apply should write 'video' to type.txt"

# Test: image type tears down live backends (pkill + awww kill)
png="$tmpdir/photo.png"
touch "$png"
run_apply2 --type image "$png"
(( APPLY2_STATUS == 0 )) \
  || fail "image apply should succeed (output: $APPLY2_OUTPUT)"
grep -q 'pkill' "$_log" \
  || fail "image apply should invoke pkill (teardown) (log: $(cat "$_log"))"
grep -q 'awww kill' "$_log" \
  || fail "image apply should invoke awww kill (teardown) (log: $(cat "$_log"))"
[[ $(<"$_state2/wallpaper/type.txt") == "image" ]] \
  || fail "image apply should write 'image' to type.txt"

# Regression: symlink dir created for animated when current/ does not pre-exist
_config3="$tmpdir/config3"
_state3="$tmpdir/state3"
_xdg3="$tmpdir/xdg3"
mkdir -p "$_state3" "$_xdg3/ryoku-shell"
printf '%s\n' '{"background":{}}' >"$_xdg3/ryoku-shell/config.json"

gif2="$tmpdir/loop2.gif"
touch "$gif2"
set +e
SYMLINK_OUTPUT="$(
  LAUNCHER_LOG="$tmpdir/symlink.log" \
  RYOKU_PATH="$tmpdir/ryoku" \
  RYOKU_CONFIG_PATH="$_config3" \
  RYOKU_STATE_PATH="$_state3" \
  XDG_CONFIG_HOME="$_xdg3" \
  HOME="$tmpdir/home3" \
  PATH="$_bin2:$tmpdir/ryoku/bin:$PATH" \
    "$apply_bin" --type animated "$gif2" 2>&1
)"
SYMLINK_STATUS=$?
set -e
(( SYMLINK_STATUS == 0 )) \
  || fail "animated symlink-dir regression: should succeed (output: $SYMLINK_OUTPUT)"
printf '%s\n' "$SYMLINK_OUTPUT" | jq -e '.ok == true' >/dev/null \
  || fail "animated symlink-dir regression: should emit JSON ok:true"
[[ -e $_config3/current/background ]] \
  || fail "animated symlink-dir regression: \$RYOKU_CONFIG_PATH/current/background symlink should exist"

pass "backend dispatch + symlink regression"

# --- Settings-driven behavior: videoMuted / swwwTransition / liveWallpaperEnabled ---

_settings_bin="$tmpdir/settings-bin"
_settings_state="$tmpdir/settings-state"
_settings_config="$tmpdir/settings-config"
_settings_xdg="$tmpdir/settings-xdg"
_settings_log="$tmpdir/settings.log"
mkdir -p "$_settings_bin" "$_settings_state" "$_settings_xdg/noctalia" "$_settings_xdg/ryoku-shell"
printf '%s\n' '{"background":{}}' >"$_settings_xdg/ryoku-shell/config.json"

for _cmd in awww awww-daemon; do
  cat >"$_settings_bin/$_cmd" <<EOF
#!/bin/bash
printf '%s\n' "$_cmd \$*" >>"$_settings_log"
exit 0
EOF
  chmod +x "$_settings_bin/$_cmd"
done

cat >"$_settings_bin/mpvpaper" <<'EOF'
#!/bin/bash
printf 'mpvpaper %s\n' "$*" >>"$SETTINGS_LOG"
exit 0
EOF
chmod +x "$_settings_bin/mpvpaper"

cat >"$_settings_bin/pkill" <<'EOF'
#!/bin/bash
exit 0
EOF
chmod +x "$_settings_bin/pkill"

cat >"$_settings_bin/ffmpegthumbnailer" <<'EOF'
#!/bin/bash
exit 1
EOF
chmod +x "$_settings_bin/ffmpegthumbnailer"

_settings_gif="$tmpdir/settings-test.gif"
_settings_mp4="$tmpdir/settings-test.mp4"
touch "$_settings_gif" "$_settings_mp4"

run_settings() {
  : >"$_settings_log"
  set +e
  SETTINGS_OUT="$(
    SETTINGS_LOG="$_settings_log" \
    RYOKU_PATH="$tmpdir/ryoku" \
    RYOKU_CONFIG_PATH="$_settings_config" \
    RYOKU_STATE_PATH="$_settings_state" \
    XDG_CONFIG_HOME="$_settings_xdg" \
    HOME="$tmpdir/settings-home" \
    PATH="$_settings_bin:$tmpdir/ryoku/bin:$PATH" \
      "$apply_bin" "$@" 2>&1
  )"
  SETTINGS_STATUS=$?
  set -e
}

# Test: videoMuted=false → mpvpaper called WITHOUT no-audio
printf '%s\n' '{"wallpaper":{"videoMuted":false}}' >"$_settings_xdg/noctalia/settings.json"
run_settings --type video "$_settings_mp4"
(( SETTINGS_STATUS == 0 )) \
  || fail "settings/videoMuted=false: video apply should succeed (out: $SETTINGS_OUT)"
grep -q 'mpvpaper' "$_settings_log" \
  || fail "settings/videoMuted=false: mpvpaper should be invoked (log: $(cat "$_settings_log"))"
grep -q 'no-audio' "$_settings_log" \
  && fail "settings/videoMuted=false: mpvpaper opts should NOT include no-audio"
pass "settings/videoMuted=false: mpvpaper omits no-audio"

# Test: videoMuted=true → mpvpaper called WITH no-audio
printf '%s\n' '{"wallpaper":{"videoMuted":true}}' >"$_settings_xdg/noctalia/settings.json"
run_settings --type video "$_settings_mp4"
(( SETTINGS_STATUS == 0 )) \
  || fail "settings/videoMuted=true: video apply should succeed (out: $SETTINGS_OUT)"
grep -q 'no-audio' "$_settings_log" \
  || fail "settings/videoMuted=true: mpvpaper opts should include no-audio (log: $(cat "$_settings_log"))"
pass "settings/videoMuted=true: mpvpaper includes no-audio"

# Test: swwwTransition="fade" → awww img called with --transition-type fade
printf '%s\n' '{"wallpaper":{"swwwTransition":"fade"}}' >"$_settings_xdg/noctalia/settings.json"
run_settings --type animated "$_settings_gif"
(( SETTINGS_STATUS == 0 )) \
  || fail "settings/swwwTransition=fade: animated apply should succeed (out: $SETTINGS_OUT)"
grep -q -- '--transition-type fade' "$_settings_log" \
  || fail "settings/swwwTransition=fade: awww should pass --transition-type fade (log: $(cat "$_settings_log"))"
pass "settings/swwwTransition=fade: awww img passes --transition-type fade"

# Test: liveWallpaperEnabled=false → animated falls back to static (awww img NOT invoked)
printf '%s\n' '{"wallpaper":{"liveWallpaperEnabled":false}}' >"$_settings_xdg/noctalia/settings.json"
run_settings --type animated "$_settings_gif"
(( SETTINGS_STATUS == 0 )) \
  || fail "settings/liveWallpaperEnabled=false: animated apply should succeed (out: $SETTINGS_OUT)"
grep -q 'awww img' "$_settings_log" \
  && fail "settings/liveWallpaperEnabled=false: awww img should NOT be invoked when live disabled"
pass "settings/liveWallpaperEnabled=false: animated does not invoke awww img"

# Test: liveWallpaperEnabled=false → video falls back (mpvpaper NOT invoked)
printf '%s\n' '{"wallpaper":{"liveWallpaperEnabled":false}}' >"$_settings_xdg/noctalia/settings.json"
run_settings --type video "$_settings_mp4"
(( SETTINGS_STATUS == 0 )) \
  || fail "settings/liveWallpaperEnabled=false: video apply should succeed (out: $SETTINGS_OUT)"
grep -q 'mpvpaper' "$_settings_log" \
  && fail "settings/liveWallpaperEnabled=false: mpvpaper should NOT be invoked when live disabled"
pass "settings/liveWallpaperEnabled=false: video does not invoke mpvpaper"

pass "settings-driven behavior"

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
