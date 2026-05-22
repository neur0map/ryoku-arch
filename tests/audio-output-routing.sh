#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
GENERAL_QML="$ROOT_DIR/shell/modules/settings/GeneralConfig.qml"
AUDIO_DEFAULT="$ROOT_DIR/bin/ryoku-cmd-audio-default"
AUDIO_JACK="$ROOT_DIR/bin/ryoku-cmd-audio-jack"
AUDIO_DEFAULT_SHELL="$ROOT_DIR/shell/scripts/ryoku-cmd-audio-default"
AUDIO_JACK_SHELL="$ROOT_DIR/shell/scripts/ryoku-cmd-audio-jack"
AUDIO_SWITCH="$ROOT_DIR/bin/ryoku-cmd-audio-switch"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_contains() {
  local path="$1"
  local pattern="$2"
  local message="$3"

  rg -q "$pattern" "$path" || fail "$message"
}

[[ -f $GENERAL_QML ]] || fail "missing GeneralConfig.qml"
[[ -x $AUDIO_DEFAULT ]] || fail "missing executable ryoku-cmd-audio-default"
[[ -x $AUDIO_JACK ]] || fail "missing executable ryoku-cmd-audio-jack"
[[ -x $AUDIO_DEFAULT_SHELL ]] || fail "missing executable shell ryoku-cmd-audio-default"
[[ -x $AUDIO_JACK_SHELL ]] || fail "missing executable shell ryoku-cmd-audio-jack"

assert_contains "$GENERAL_QML" 'AppLauncher\.launch\("volumeMixer"\)' \
  "Settings audio card should open the built-in volume mixer/device selector"
assert_contains "$GENERAL_QML" 'Quickshell\.shellPath\("scripts/" \+ name\)' \
  "Settings audio card should run synced shell helpers from the active shell runtime"
assert_contains "$GENERAL_QML" 'Translation\.tr\("Use mini-jack"\)' \
  "Settings audio card should label the mini-jack action clearly"
assert_contains "$AUDIO_SWITCH" 'ryoku-cmd-audio-default" "\$next_sink_name"' \
  "Audio output cycling should use the robust default-sink setter"
assert_contains "$AUDIO_DEFAULT_SHELL" 'pw-metadata -n default 0 default.audio.sink' \
  "Default-sink setter should repair stale WirePlumber runtime metadata"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

stub_root="$tmp_dir/ryoku"
stub_bin="$stub_root/bin"
mkdir -p "$stub_bin"
printf '%s\n' "alsa_output.hdmi" >"$tmp_dir/default_sink"
: >"$tmp_dir/calls.log"

cat >"$stub_bin/ryoku-cmd-present" <<'STUB'
#!/bin/bash
command -v "$1" >/dev/null 2>&1
STUB
chmod +x "$stub_bin/ryoku-cmd-present"

cat >"$stub_bin/pactl" <<'STUB'
#!/bin/bash
state_file="${TEST_AUDIO_STATE:?}"
calls_file="${TEST_AUDIO_CALLS:?}"

if [[ ${1:-} == "-f" && ${2:-} == "json" && ${3:-} == "list" && ${4:-} == "sinks" ]]; then
  cat <<'JSON'
[
  {
    "name": "alsa_output.hdmi",
    "description": "HDMI",
    "mute": false,
    "volume": {"front-left": {"value_percent": "100%"}},
    "ports": [],
    "properties": {"object.id": "62", "alsa.card": "1"}
  },
  {
    "name": "alsa_output.pci-0000_65_00.6.analog-stereo",
    "description": "Ryzen HD Audio Controller Analog Stereo",
    "mute": false,
    "volume": {"front-left": {"value_percent": "100%"}},
    "ports": [
      {"name": "analog-output-speaker", "availability": "unknown"},
      {"name": "analog-output-headphones", "availability": "not available"}
    ],
    "properties": {"object.id": "34", "alsa.card": "2"}
  }
]
JSON
elif [[ ${1:-} == "get-default-sink" ]]; then
  cat "$state_file"
elif [[ ${1:-} == "set-default-sink" ]]; then
  printf 'pactl set-default-sink %s\n' "${2:-}" >>"$calls_file"
elif [[ ${1:-} == "set-sink-port" ]]; then
  printf 'pactl set-sink-port %s %s\n' "${2:-}" "${3:-}" >>"$calls_file"
else
  exit 2
fi
STUB
chmod +x "$stub_bin/pactl"

cat >"$stub_bin/wpctl" <<'STUB'
#!/bin/bash
printf 'wpctl %s\n' "$*" >>"${TEST_AUDIO_CALLS:?}"
STUB
chmod +x "$stub_bin/wpctl"

cat >"$stub_bin/pw-metadata" <<'STUB'
#!/bin/bash
printf 'pw-metadata %s\n' "$*" >>"${TEST_AUDIO_CALLS:?}"
if [[ ${1:-} == "-n" && ${2:-} == "default" && ${4:-} == "default.audio.sink" ]]; then
  sink="${5:-}"
  sink="${sink#*\"name\":\"}"
  sink="${sink%%\"*}"
  printf '%s\n' "$sink" >"${TEST_AUDIO_STATE:?}"
fi
STUB
chmod +x "$stub_bin/pw-metadata"

cat >"$stub_bin/amixer" <<'STUB'
#!/bin/bash
printf 'amixer %s\n' "$*" >>"${TEST_AUDIO_CALLS:?}"
STUB
chmod +x "$stub_bin/amixer"

cat >"$stub_bin/notify-send" <<'STUB'
#!/bin/bash
printf 'notify-send %s\n' "$*" >>"${TEST_AUDIO_CALLS:?}"
STUB
chmod +x "$stub_bin/notify-send"

cat >"$stub_bin/ryoku-shell" <<'STUB'
#!/bin/bash
printf 'ryoku-shell %s\n' "$*" >>"${TEST_AUDIO_CALLS:?}"
STUB
chmod +x "$stub_bin/ryoku-shell"

TEST_AUDIO_STATE="$tmp_dir/default_sink" \
TEST_AUDIO_CALLS="$tmp_dir/calls.log" \
RYOKU_PATH="$stub_root" \
PATH="$stub_bin:$PATH" \
  "$AUDIO_DEFAULT" "alsa_output.pci-0000_65_00.6.analog-stereo" >/dev/null

[[ $(<"$tmp_dir/default_sink") == "alsa_output.pci-0000_65_00.6.analog-stereo" ]] || \
  fail "default-sink helper should repair the active PipeWire metadata when wpctl leaves HDMI selected"
rg -q 'pw-metadata -n default 0 default.audio.sink' "$tmp_dir/calls.log" || \
  fail "default-sink helper should call pw-metadata fallback"

printf '%s\n' "alsa_output.hdmi" >"$tmp_dir/default_sink"
: >"$tmp_dir/calls.log"

TEST_AUDIO_STATE="$tmp_dir/default_sink" \
TEST_AUDIO_CALLS="$tmp_dir/calls.log" \
RYOKU_PATH="$stub_root" \
PATH="$stub_bin:$PATH" \
  "$AUDIO_JACK" >/dev/null

rg -q 'pactl set-sink-port alsa_output\.pci-0000_65_00\.6\.analog-stereo analog-output-headphones' "$tmp_dir/calls.log" || \
  fail "mini-jack helper should force the analog headphone route"
rg -q 'amixer -c 2 set Headphone 100% unmute' "$tmp_dir/calls.log" || \
  fail "mini-jack helper should unmute the ALSA headphone mixer"
[[ $(<"$tmp_dir/default_sink") == "alsa_output.pci-0000_65_00.6.analog-stereo" ]] || \
  fail "mini-jack helper should make the analog sink default"

echo "PASS: audio output routing helpers and settings controls"
