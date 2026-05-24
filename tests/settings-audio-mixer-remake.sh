#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local needle="$2"
  local message="$3"

  grep -Fq "$needle" "$ROOT_DIR/$file" || fail "$message"
}

assert_not_contains() {
  local file="$1"
  local needle="$2"
  local message="$3"

  ! grep -Fq "$needle" "$ROOT_DIR/$file" || fail "$message"
}

pane="shell/modules/controlcenter/audio/AudioPane.qml"

assert_not_contains "$pane" "CollapsibleSection" \
  "audio should not keep collapsible generic device sections"
assert_not_contains "$pane" "SectionContainer" \
  "audio should not keep generic section cards"
assert_not_contains "$pane" "SectionHeader" \
  "audio should not keep generic section headers"
assert_not_contains "$pane" "StyledInputField" \
  "audio mixer should not rely on percentage input boxes"

assert_contains "$pane" "component MixerDeck: StyledRect" \
  "audio should expose a compact mixer deck"
assert_contains "$pane" "component AudioWorkbench: StyledRect" \
  "audio should expose a single compact audio workbench"
assert_contains "$pane" "component DeviceMatrix: StyledRect" \
  "audio should expose a compact multi-column device matrix"
assert_contains "$pane" "component DeviceToken: StyledRect" \
  "audio should expose compact device tokens"
assert_contains "$pane" "component VolumeStrip: StyledRect" \
  "audio should expose volume strip controls"
assert_contains "$pane" "component StreamStrip: StyledRect" \
  "audio should expose application stream strips"
assert_contains "$pane" "component MuteButton: StyledRect" \
  "audio should expose icon mute controls"
assert_contains "$pane" "columns: root.width > 620 ? 2 : 1" \
  "audio should switch to side-by-side workbench columns in the compact window"
assert_contains "$pane" "columns: deviceGrid.width > 360 ? 2 : 1" \
  "audio device choices should not stay as long single-column rows"
assert_not_contains "$pane" "implicitHeight: 54" \
  "audio tokens should not keep tall rows for one device name"

assert_contains "$pane" "Audio.setAudioSink(modelData)" \
  "audio should preserve output device selection backend"
assert_contains "$pane" "Audio.setAudioSource(modelData)" \
  "audio should preserve input device selection backend"
assert_contains "$pane" "Audio.setVolume(value)" \
  "audio should preserve output volume backend"
assert_contains "$pane" "Audio.setSourceVolume(value)" \
  "audio should preserve input volume backend"
assert_contains "$pane" "Audio.setStreamVolume(modelData, value)" \
  "audio should preserve stream volume backend"
assert_contains "$pane" "Audio.setStreamMuted(modelData, !Audio.getStreamMuted(modelData))" \
  "audio should preserve stream mute backend"
assert_contains "$pane" "Audio.sink.audio.muted = !Audio.sink.audio.muted" \
  "audio should preserve output mute backend"
assert_contains "$pane" "Audio.source.audio.muted = !Audio.source.audio.muted" \
  "audio should preserve input mute backend"

echo "PASS: tests/settings-audio-mixer-remake.sh"
