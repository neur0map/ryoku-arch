#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT_DIR"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_contains() {
  local path="$1"
  local needle="$2"
  local message="$3"

  grep -Fq -- "$needle" "$path" || fail "$message"
}

assert_not_contains() {
  local path="$1"
  local needle="$2"
  local message="$3"

  if grep -Fq -- "$needle" "$path"; then
    fail "$message"
  fi
}

assert_executable() {
  local path="$1"

  [[ -x $path ]] || fail "$path should be executable"
}

assert_executable bin/ryoku-cmd-screenrecord
bash -n bin/ryoku-cmd-screenrecord shell/scripts/ryoku

assert_contains shell/services/Recorder.qml '["ryoku-cmd-screenrecord", "--stop"]' \
  "Recorder service should stop through the real screen recorder command"
assert_contains shell/services/Recorder.qml '["ryoku-cmd-screenrecord", "--pause"]' \
  "Recorder service should pause through the real screen recorder command"
assert_contains shell/services/Recorder.qml '["ryoku-cmd-screenrecord", ...root.startArgs]' \
  "Recorder service should start through the real screen recorder command"
assert_not_contains shell/services/Recorder.qml '["ryoku", "record"' \
  "Recorder service should not call the stale ryoku record bridge"

assert_contains install/ryoku-base.packages 'gpu-screen-recorder' \
  "Fresh installs should include gpu-screen-recorder"
assert_contains install/ryoku-base.packages 'wf-recorder' \
  "Fresh installs should include wf-recorder for the multi-GPU capture fallback"
assert_contains install/ryoku-base.packages 'slurp' \
  "Fresh installs should include slurp for region selection"

if ! grep -Rqs 'Repair shell screen recorder command wiring' migrations; then
  fail "A global screen recorder fix should ship a migration for existing installs"
fi

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT
mkdir -p "$tmp_dir/bin" "$tmp_dir/videos" "$tmp_dir/home"

cat >"$tmp_dir/bin/gpu-screen-recorder" <<'SH'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$*" >>"$RYOKU_TEST_RECORDER_ARGS"
SH

cat >"$tmp_dir/bin/wf-recorder" <<'SH'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$*" >>"$RYOKU_TEST_WF_ARGS"
SH

cat >"$tmp_dir/bin/slurp" <<'SH'
#!/bin/bash
set -euo pipefail
printf '%s\n' "${RYOKU_TEST_SLURP_OUTPUT:-10,20 300x200}"
SH

# Pattern-aware so the script can tell which backend owns a live recording.
cat >"$tmp_dir/bin/pgrep" <<'SH'
#!/bin/bash
set -euo pipefail
printf 'pgrep %s\n' "$*" >>"$RYOKU_TEST_SIGNAL_LOG"
args="$*"
if [[ $args == *gpu-screen-recorder* && ${RYOKU_TEST_GSR_RUNNING:-false} == "true" ]]; then
  printf '1234\n'
  exit 0
fi
if [[ $args == *wf-recorder* && ${RYOKU_TEST_WF_RUNNING:-false} == "true" ]]; then
  printf '1235\n'
  exit 0
fi
exit 1
SH

cat >"$tmp_dir/bin/pkill" <<'SH'
#!/bin/bash
set -euo pipefail
printf 'pkill %s\n' "$*" >>"$RYOKU_TEST_SIGNAL_LOG"
SH

cat >"$tmp_dir/bin/hyprctl" <<'SH'
#!/bin/bash
set -euo pipefail
case "$*" in
*"monitors -j"*) printf '%s' '[{"name":"DP-5","focused":true}]' ;;
*) printf '' ;;
esac
SH

cat >"$tmp_dir/bin/pactl" <<'SH'
#!/bin/bash
set -euo pipefail
case "${1:-}" in
get-default-sink) printf 'test_sink\n' ;;
get-default-source) printf 'test_source\n' ;;
*) ;;
esac
SH

cat >"$tmp_dir/bin/notify-send" <<'SH'
#!/bin/bash
exit 0
SH

chmod +x "$tmp_dir/bin/"*

# ── gpu-screen-recorder backend ──────────────────────────────────────────────

run_gsr() {
  local running="$1"
  shift

  : >"$tmp_dir/recorder.args"
  : >"$tmp_dir/signals.log"
  PATH="$tmp_dir/bin:$PATH" \
  HOME="$tmp_dir/home" \
  RYOKU_PATH="$ROOT_DIR" \
  RYOKU_SCREENRECORD_BACKEND=gsr \
  RYOKU_SHELL_RECORDINGS_DIR="$tmp_dir/videos" \
  RYOKU_TEST_RECORDER_ARGS="$tmp_dir/recorder.args" \
  RYOKU_TEST_SIGNAL_LOG="$tmp_dir/signals.log" \
  RYOKU_TEST_GSR_RUNNING="$running" \
    bash bin/ryoku-cmd-screenrecord "$@" >/dev/null
}

run_gsr false --fullscreen
assert_contains "$tmp_dir/recorder.args" '-w screen' \
  "Fullscreen recording should capture the screen directly"
grep -Eq -- "-o $tmp_dir/videos/recording_[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}\\.[0-9]{2}\\.[0-9]{2}\\.mp4" "$tmp_dir/recorder.args" \
  || fail "Recordings should be written into the shell recordings directory"

run_gsr false -sr
assert_contains "$tmp_dir/recorder.args" '-w region' \
  "Region recording should select gpu-screen-recorder's region mode"
assert_contains "$tmp_dir/recorder.args" '-region 300x200+10+20' \
  "Region recording should pass slurp geometry via -region"
assert_contains "$tmp_dir/recorder.args" '-a default_output' \
  "Sound recording should include desktop audio"

run_gsr true --pause
assert_contains "$tmp_dir/signals.log" 'pkill -USR2 -f (^|/)gpu-screen-recorder( |$)' \
  "Pause should toggle gpu-screen-recorder with SIGUSR2"

run_gsr true --stop
assert_contains "$tmp_dir/signals.log" 'pkill -INT -f (^|/)gpu-screen-recorder( |$)' \
  "Stop should save the recording with SIGINT"

run_gsr true
assert_contains "$tmp_dir/signals.log" 'pkill -INT -f (^|/)gpu-screen-recorder( |$)' \
  "Legacy record toggle with no args should stop an active recording"

# ── wf-recorder fallback (multi-GPU: display on a non-primary GPU) ────────────

run_wf() {
  local running="$1"
  shift

  : >"$tmp_dir/wf.args"
  : >"$tmp_dir/signals.log"
  PATH="$tmp_dir/bin:$PATH" \
  HOME="$tmp_dir/home" \
  RYOKU_PATH="$ROOT_DIR" \
  RYOKU_SCREENRECORD_BACKEND=wf \
  RYOKU_SHELL_RECORDINGS_DIR="$tmp_dir/videos" \
  RYOKU_TEST_WF_ARGS="$tmp_dir/wf.args" \
  RYOKU_TEST_SIGNAL_LOG="$tmp_dir/signals.log" \
  RYOKU_TEST_WF_RUNNING="$running" \
    bash bin/ryoku-cmd-screenrecord "$@" >/dev/null
}

# Explicit codec keeps the wf invocation deterministic (skips the
# hardware/software negotiation), so we can assert the capture wiring.
run_wf_codec() {
  local running="$1"
  shift

  : >"$tmp_dir/wf.args"
  : >"$tmp_dir/signals.log"
  PATH="$tmp_dir/bin:$PATH" \
  HOME="$tmp_dir/home" \
  RYOKU_PATH="$ROOT_DIR" \
  RYOKU_SCREENRECORD_BACKEND=wf \
  RYOKU_SCREENRECORD_WF_CODEC=libx264 \
  RYOKU_SHELL_RECORDINGS_DIR="$tmp_dir/videos" \
  RYOKU_TEST_WF_ARGS="$tmp_dir/wf.args" \
  RYOKU_TEST_SIGNAL_LOG="$tmp_dir/signals.log" \
  RYOKU_TEST_WF_RUNNING="$running" \
    bash bin/ryoku-cmd-screenrecord "$@" >/dev/null
}

run_wf_codec false -s
assert_contains "$tmp_dir/wf.args" '-o DP-5' \
  "wf-recorder fullscreen should target the focused output"
assert_contains "$tmp_dir/wf.args" '--audio=test_sink.monitor' \
  "wf-recorder sound should capture the default sink monitor"
assert_contains "$tmp_dir/wf.args" '-c libx264' \
  "wf-recorder should honour an explicit codec override"
grep -Eq -- "-f $tmp_dir/videos/recording_[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}\\.[0-9]{2}\\.[0-9]{2}\\.mp4" "$tmp_dir/wf.args" \
  || fail "wf-recorder should write into the shell recordings directory"

run_wf_codec false -sr
assert_contains "$tmp_dir/wf.args" '-g 10,20 300x200' \
  "wf-recorder region should pass slurp geometry via -g"

# Default (no codec): prefer GPU VAAPI, fall back to libx264 when the hardware
# encoder can't start. The fake wf-recorder exits immediately, so both attempts
# are recorded.
: >"$tmp_dir/wf.args"
: >"$tmp_dir/signals.log"
PATH="$tmp_dir/bin:$PATH" \
HOME="$tmp_dir/home" \
RYOKU_PATH="$ROOT_DIR" \
RYOKU_SCREENRECORD_BACKEND=wf \
RYOKU_SCREENRECORD_WF_DEVICE=/dev/dri/renderD128 \
RYOKU_SHELL_RECORDINGS_DIR="$tmp_dir/videos" \
RYOKU_TEST_WF_ARGS="$tmp_dir/wf.args" \
RYOKU_TEST_SIGNAL_LOG="$tmp_dir/signals.log" \
  bash bin/ryoku-cmd-screenrecord --fullscreen >/dev/null
assert_contains "$tmp_dir/wf.args" '-c h264_vaapi' \
  "wf-recorder should attempt GPU (VAAPI) encoding first"
assert_contains "$tmp_dir/wf.args" '-c libx264' \
  "wf-recorder should fall back to libx264 when hardware encoding fails to start"

run_wf true --pause
assert_not_contains "$tmp_dir/signals.log" 'pkill -USR2' \
  "wf-recorder has no pause; the script should not signal a recorder"

run_wf true --stop
assert_contains "$tmp_dir/signals.log" 'pkill -INT -f (^|/)wf-recorder( |$)' \
  "Stop should finalize a wf-recorder recording with SIGINT"

# ── compatibility bridge ─────────────────────────────────────────────────────

bridge_root="$tmp_dir/bridge-root"
mkdir -p "$bridge_root/bin"
cat >"$bridge_root/bin/ryoku-cmd-screenrecord" <<'SH'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$*" >"$RYOKU_TEST_BRIDGE_ARGS"
SH
chmod +x "$bridge_root/bin/ryoku-cmd-screenrecord"

RYOKU_PATH="$bridge_root" \
HOME="$tmp_dir/home" \
RYOKU_TEST_BRIDGE_ARGS="$tmp_dir/bridge.args" \
  bash shell/scripts/ryoku record -r
assert_contains "$tmp_dir/bridge.args" '-r' \
  "ryoku record should remain a compatibility bridge to ryoku-cmd-screenrecord"

echo "PASS: screen recording command records via gpu-screen-recorder with a wf-recorder fallback"
