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

# --- ryoku-wallpaper-pause ---

pause_bin="bin/ryoku-wallpaper-pause"
resume_bin="bin/ryoku-wallpaper-resume"

[[ -x $pause_bin ]] || fail "bin/ryoku-wallpaper-pause should be executable"
[[ -x $resume_bin ]] || fail "bin/ryoku-wallpaper-resume should be executable"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

_bin="$tmpdir/bin"
mkdir -p "$_bin"
_log="$tmpdir/calls.log"
_state="$tmpdir/state"
_xdg="$tmpdir/xdg"
mkdir -p "$_state/wallpaper" "$_xdg/ryoku/settings-gui"

# Stub pkill: log invocations
cat >"$_bin/pkill" <<'EOF'
#!/bin/bash
printf 'pkill %s\n' "$*" >>"$GAMEMODE_LOG"
exit 0
EOF
chmod +x "$_bin/pkill"

# Stub awww: log invocations
cat >"$_bin/awww" <<'EOF'
#!/bin/bash
printf 'awww %s\n' "$*" >>"$GAMEMODE_LOG"
exit 0
EOF
chmod +x "$_bin/awww"

# Stub ryoku-wallpaper-apply to log what it is called with
cat >"$_bin/ryoku-wallpaper-apply" <<'EOF'
#!/bin/bash
printf 'ryoku-wallpaper-apply %s\n' "$*" >>"$GAMEMODE_LOG"
exit 0
EOF
chmod +x "$_bin/ryoku-wallpaper-apply"

# Stub ryoku-cmd-missing: none are missing
cat >"$_bin/ryoku-cmd-missing" <<'EOF'
#!/bin/bash
exit 1
EOF
chmod +x "$_bin/ryoku-cmd-missing"

_run_pause() {
  : >"$_log"
  set +e
  PAUSE_OUT="$(
    GAMEMODE_LOG="$_log" \
    RYOKU_STATE_PATH="$_state" \
    XDG_CONFIG_HOME="$_xdg" \
    PATH="$_bin:$PATH" \
      "$pause_bin" 2>&1
  )"
  PAUSE_STATUS=$?
  set -e
}

_run_resume() {
  : >"$_log"
  set +e
  RESUME_OUT="$(
    GAMEMODE_LOG="$_log" \
    RYOKU_STATE_PATH="$_state" \
    XDG_CONFIG_HOME="$_xdg" \
    PATH="$_bin:$PATH" \
      "$resume_bin" 2>&1
  )"
  RESUME_STATUS=$?
  set -e
}

# --- Test: pause calls stop backends (pkill mpvpaper + awww kill) ---
printf '%s\n' 'video' >"$_state/wallpaper/type.txt"
printf '%s\n' '/tmp/clip.mp4' >"$_state/wallpaper/path.txt"
printf '%s\n' '{"wallpaper":{"pauseOnFullscreen":true}}' >"$_xdg/ryoku/settings-gui/settings.json"

_run_pause
(( PAUSE_STATUS == 0 )) || fail "pause: should exit 0 for video type (out: $PAUSE_OUT)"
grep -q 'pkill' "$_log" \
  || fail "pause: should call pkill to stop mpvpaper (log: $(cat "$_log"))"
grep -q 'awww kill' "$_log" \
  || fail "pause: should call awww kill (log: $(cat "$_log"))"
pass "pause: stops live backends for video type"

# --- Test: pause is no-op when pauseOnFullscreen=false ---
printf '%s\n' '{"wallpaper":{"pauseOnFullscreen":false}}' >"$_xdg/ryoku/settings-gui/settings.json"
_run_pause
(( PAUSE_STATUS == 0 )) || fail "pause/disabled: should exit 0 (out: $PAUSE_OUT)"
grep -q 'pkill' "$_log" \
  && fail "pause/disabled: should NOT call pkill when pauseOnFullscreen=false (log: $(cat "$_log"))"
pass "pause: no-op when pauseOnFullscreen=false"

# --- Test: pause is no-op when type is image ---
printf '%s\n' '{"wallpaper":{"pauseOnFullscreen":true}}' >"$_xdg/ryoku/settings-gui/settings.json"
printf '%s\n' 'image' >"$_state/wallpaper/type.txt"
_run_pause
(( PAUSE_STATUS == 0 )) || fail "pause/image: should exit 0 (out: $PAUSE_OUT)"
grep -q 'pkill' "$_log" \
  && fail "pause/image: should NOT call pkill for static image (log: $(cat "$_log"))"
pass "pause: no-op for static image type"

# --- Test: pause is no-op when type is animated and pausing ---
printf '%s\n' 'animated' >"$_state/wallpaper/type.txt"
_run_pause
(( PAUSE_STATUS == 0 )) || fail "pause/animated: should exit 0 (out: $PAUSE_OUT)"
grep -q 'pkill' "$_log" \
  || fail "pause/animated: should call pkill for animated (live) type (log: $(cat "$_log"))"
pass "pause: stops live backends for animated type"

# --- Test: resume re-applies wallpaper when type is video ---
printf '%s\n' '{"wallpaper":{"pauseOnFullscreen":true}}' >"$_xdg/ryoku/settings-gui/settings.json"
printf '%s\n' 'video' >"$_state/wallpaper/type.txt"
printf '%s\n' '/tmp/clip.mp4' >"$_state/wallpaper/path.txt"
_run_resume
(( RESUME_STATUS == 0 )) || fail "resume/video: should exit 0 (out: $RESUME_OUT)"
grep -q 'ryoku-wallpaper-apply' "$_log" \
  || fail "resume/video: should call ryoku-wallpaper-apply to restore wallpaper (log: $(cat "$_log"))"
grep -q -- '--type video' "$_log" \
  || fail "resume/video: should pass --type video to ryoku-wallpaper-apply (log: $(cat "$_log"))"
pass "resume: re-applies video wallpaper"

# --- Test: resume re-applies when type is animated ---
printf '%s\n' 'animated' >"$_state/wallpaper/type.txt"
printf '%s\n' '/tmp/loop.gif' >"$_state/wallpaper/path.txt"
_run_resume
(( RESUME_STATUS == 0 )) || fail "resume/animated: should exit 0 (out: $RESUME_OUT)"
grep -q -- '--type animated' "$_log" \
  || fail "resume/animated: should pass --type animated (log: $(cat "$_log"))"
pass "resume: re-applies animated wallpaper"

# --- Test: resume is no-op for image type (no re-apply needed) ---
printf '%s\n' 'image' >"$_state/wallpaper/type.txt"
_run_resume
(( RESUME_STATUS == 0 )) || fail "resume/image: should exit 0 (out: $RESUME_OUT)"
grep -q 'ryoku-wallpaper-apply' "$_log" \
  && fail "resume/image: should NOT re-apply for static image (log: $(cat "$_log"))"
pass "resume: no-op for static image type"

# --- Test: resume is no-op when pauseOnFullscreen=false ---
printf '%s\n' '{"wallpaper":{"pauseOnFullscreen":false}}' >"$_xdg/ryoku/settings-gui/settings.json"
printf '%s\n' 'video' >"$_state/wallpaper/type.txt"
_run_resume
(( RESUME_STATUS == 0 )) || fail "resume/disabled: should exit 0 (out: $RESUME_OUT)"
grep -q 'ryoku-wallpaper-apply' "$_log" \
  && fail "resume/disabled: should NOT re-apply when pauseOnFullscreen=false (log: $(cat "$_log"))"
pass "resume: no-op when pauseOnFullscreen=false"

pass "wallpaper-gamemode-pause"
