#!/bin/bash
# Static checks for the keyboard-volume topbar feedback.

set -euo pipefail
cd "$(dirname "$0")/.."

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

pass() {
  echo "OK: $1"
}

topbar="config/quickshell/ryoku/vendor/brain-shell/src/windows/TopBar.qml"
day="config/quickshell/ryoku/vendor/brain-shell/src/modules/Gap/DayWidget.qml"
toast="config/quickshell/ryoku/vendor/brain-shell/src/modules/Gap/VolumeToast.qml"
state="config/quickshell/ryoku/vendor/brain-shell/src/state/VolumeFeedback.qml"
qmldir="config/quickshell/ryoku/vendor/brain-shell/src/qmldir"
shell="config/quickshell/ryoku/shell.qml"
media="default/hypr/bindings/media.conf"
volume="bin/ryoku-volume"

[[ -f $topbar ]] || fail "$topbar missing"
[[ -f $day ]] || fail "$day missing"
[[ -f $toast ]] || fail "$toast missing"
[[ -f $state ]] || fail "$state missing"
[[ -f $qmldir ]] || fail "$qmldir missing"
[[ -f $shell ]] || fail "$shell missing"
[[ -f $media ]] || fail "$media missing"
[[ -x $volume ]] || fail "$volume missing or not executable"

bash -n "$volume" || fail "ryoku-volume should be valid bash"

grep -q 'singleton VolumeFeedback state/VolumeFeedback.qml' "$qmldir" \
  || fail "VolumeFeedback should be exported as a singleton"
grep -q 'target: "volume"' "$shell" \
  || fail "shell IPC should expose a volume target"
grep -q 'function flash(): void' "$shell" \
  || fail "volume IPC should expose a flash function"
grep -q 'BS.VolumeFeedback.show()' "$shell" \
  || fail "volume IPC should show the feedback surface"

grep -q 'import "../modules/Gap/"' "$topbar" \
  || fail "TopBar should import gap widgets"
grep -q 'id: leftGap' "$topbar" \
  || fail "TopBar should reserve the left gap"
grep -q 'DayWidget {' "$topbar" \
  || fail "TopBar should mount the day widget"
grep -q 'id: rightGap' "$topbar" \
  || fail "TopBar should reserve the right gap"
grep -q 'VolumeToast {' "$topbar" \
  || fail "TopBar should mount the volume toast"
grep -q 'VolumeFeedback.visible' "$topbar" \
  || fail "TopBar should gate the toast on keyboard-volume feedback"

grep -q 'font.family: "iA Writer Quattro S"' "$day" \
  || fail "Day widget should use the rice-style display font"
grep -q 'Qt.formatDateTime(new Date(), "dddd").toUpperCase()' "$day" \
  || fail "Day widget should render the weekday"

grep -q 'Quickshell.Services.Pipewire' "$toast" \
  || fail "Volume toast should read PipeWire audio state"
grep -q 'Timer {' "$toast" \
  || fail "Volume toast should auto-hide"
grep -q 'VolumeFeedback.hide()' "$toast" \
  || fail "Volume toast should hide through shared state"

grep -q 'XF86AudioRaiseVolume, Volume up, exec, ryoku-volume up' "$media" \
  || fail "volume up key should use ryoku-volume"
grep -q 'XF86AudioLowerVolume, Volume down, exec, ryoku-volume down' "$media" \
  || fail "volume down key should use ryoku-volume"
grep -q 'XF86AudioMute, Mute, exec, ryoku-volume mute-toggle' "$media" \
  || fail "mute key should use ryoku-volume"
! grep -q 'XF86AudioRaiseVolume.*ryoku-swayosd-client --output-volume' "$media" \
  || fail "volume up should not use SwayOSD"
! grep -q 'XF86AudioLowerVolume.*ryoku-swayosd-client --output-volume' "$media" \
  || fail "volume down should not use SwayOSD"
! grep -q 'XF86AudioMute.*ryoku-swayosd-client --output-volume' "$media" \
  || fail "mute should not use SwayOSD"

grep -q 'wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@' "$volume" \
  || fail "ryoku-volume should clamp output volume to 100%"
grep -q 'qs -c ryoku ipc call volume flash' "$volume" \
  || fail "ryoku-volume should notify Quickshell"

pass "quickshell volume feedback"
