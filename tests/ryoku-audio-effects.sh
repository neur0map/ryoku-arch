#!/bin/bash
# Regression checks for Ryoku dashboard audio effects integration.

set -euo pipefail
cd "$(dirname "$0")/.."

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

pass() {
  echo "OK: $1"
}

tmp="${TMPDIR:-/tmp}/ryoku-audio-effects-test.$$"
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/home" "$tmp/state" "$tmp/data" "$tmp/run"

run_helper() {
  HOME="$tmp/home" \
  XDG_STATE_HOME="$tmp/state" \
  XDG_DATA_HOME="$tmp/data" \
  XDG_RUNTIME_DIR="$tmp/run" \
  RYOKU_AUDIO_EFFECTS_NO_LIVE=1 \
    bin/ryoku-audio-effects "$@"
}

json_value() {
  jq -er "$1" "$2"
}

run_helper eq-set 1 12
run_helper eq-set 5 -7
run_helper eq-set 10 99

preset="$tmp/data/easyeffects/output/Ryoku Dashboard.json"
legacy_preset="$tmp/home/.config/easyeffects/output/Ryoku Dashboard.json"

[[ -f $preset ]] || fail "XDG EasyEffects output preset should be written"
[[ -f $legacy_preset ]] || fail "legacy EasyEffects output preset should be written"

[[ $(json_value '.output.equalizer["num-bands"]' "$preset") == "32" ]] \
  || fail "equalizer preset should use the 32-band EasyEffects layout"
[[ $(json_value '.output.equalizer.left.band0.gain' "$preset") == "12" ]] \
  || fail "slider 1 should map to band0 at +12 dB"
[[ $(json_value '.output.equalizer.left.band12.gain' "$preset") == "-7" ]] \
  || fail "slider 5 should map negative gain to band12"
[[ $(json_value '.output.equalizer.right.band12.gain' "$preset") == "-7" ]] \
  || fail "right channel should mirror slider 5 negative gain"
[[ $(json_value '.output.equalizer.left.band27.gain' "$preset") == "12" ]] \
  || fail "slider 10 should clamp high gain to +12 dB on band27"
[[ $(json_value '.output.equalizer.left.band1.gain' "$preset") == "0" ]] \
  || fail "non-slider bands should remain flat"
[[ $(json_value '.output.equalizer.left.band31.frequency' "$preset") == "24000" ]] \
  || fail "32-band preset should include the highest EasyEffects band"

state_json="$(run_helper state)"
printf '%s\n' "$state_json" | jq -e '.eqBands == [12,0,0,0,-7,0,0,0,0,12]' >/dev/null \
  || fail "state should expose persisted EQ bands as JSON"

pass "ryoku audio effects"
