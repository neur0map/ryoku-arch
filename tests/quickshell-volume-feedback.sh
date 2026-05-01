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
window="config/quickshell/ryoku/vendor/brain-shell/src/windows/VolumeFeedbackWindow.qml"
day="config/quickshell/ryoku/vendor/brain-shell/src/modules/Gap/DayWidget.qml"
toast="config/quickshell/ryoku/vendor/brain-shell/src/modules/Gap/VolumeToast.qml"
state="config/quickshell/ryoku/vendor/brain-shell/src/state/VolumeFeedback.qml"
qmldir="config/quickshell/ryoku/vendor/brain-shell/src/qmldir"
shell="config/quickshell/ryoku/shell.qml"
popup_layer="config/quickshell/ryoku/vendor/brain-shell/src/popups/PopupLayer.qml"
media="default/hypr/bindings/media.conf"
volume="bin/ryoku-volume"

[[ -f $topbar ]] || fail "$topbar missing"
[[ -f $window ]] || fail "$window missing"
[[ -f $day ]] || fail "$day missing"
[[ -f $toast ]] || fail "$toast missing"
[[ -f $state ]] || fail "$state missing"
[[ -f $qmldir ]] || fail "$qmldir missing"
[[ -f $shell ]] || fail "$shell missing"
[[ -f $popup_layer ]] || fail "$popup_layer missing"
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
! grep -q 'VolumeToast {' "$topbar" \
  || fail "TopBar should not host the transient volume toast"
! grep -q 'volumeFeedbackDropHeight' "$topbar" \
  || fail "TopBar should not resize for volume feedback"
grep -q 'implicitHeight: ShellState.focusMode ? Theme.borderWidth : Theme.notchHeight' "$topbar" \
  || fail "TopBar height should remain stable during volume feedback"

grep -q 'VolumeFeedbackWindow { screen: root.screen }' "$popup_layer" \
  || fail "PopupLayer should mount the separate volume feedback window"
grep -q 'PanelWindow {' "$window" \
  || fail "Volume feedback should use a separate panel surface"
grep -q 'exclusionMode: ExclusionMode.Ignore' "$window" \
  || fail "Volume feedback window should not reserve space"
grep -q 'WlrLayershell.layer: WlrLayer.Overlay' "$window" \
  || fail "Volume feedback window should render above the bar"
grep -q 'ShellState.topBarCWidth' "$window" \
  || fail "Volume feedback window should calculate the center gap from topbar state"
grep -q 'ShellState.topBarRWidth' "$window" \
  || fail "Volume feedback window should calculate the right gap from topbar state"
grep -q 'VolumeToast {' "$window" \
  || fail "Volume feedback window should host the toast"
grep -q 'active: VolumeFeedback.visible && root.canShow' "$window" \
  || fail "Volume feedback window should gate the toast on keyboard-volume feedback"

grep -q 'font.family: "iA Writer Quattro S"' "$day" \
  || fail "Day widget should use the rice-style display font"
grep -q 'Qt.formatDateTime(new Date(), "dddd").toUpperCase()' "$day" \
  || fail "Day widget should render the weekday"

grep -q 'Quickshell.Services.Pipewire' "$toast" \
  || fail "Volume toast should read PipeWire audio state"
grep -q 'import "../../services/home/."' "$toast" \
  || fail "Volume toast should import shared home components"
grep -q 'WaveBar {' "$toast" \
  || fail "Volume toast should use the animated WaveBar"
grep -q 'PopupShape {' "$toast" \
  || fail "Volume toast should render as a topbar extension shape"
grep -q 'y: active ? Theme.notchHeight - 8 : -height - 2' "$toast" \
  || fail "Volume toast should slide down from the topbar"
grep -q 'Behavior on y' "$toast" \
  || fail "Volume toast should animate with a vertical slide"
! grep -q 'Behavior on opacity' "$toast" \
  || fail "Volume toast should not fade in"
! grep -q 'Behavior on scale' "$toast" \
  || fail "Volume toast should not scale in"
grep -q 'implicitWidth: 150' "$toast" \
  || fail "Volume toast should stay compact"
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
