#!/bin/bash
# Static regression checks for the center-pill toolbox.

set -euo pipefail
cd "$(dirname "$0")/.."

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

pass() {
  echo "OK: $1"
}

active_lines() {
  sed '/^[[:space:]]*\/\//d' "$1"
}

active_has() {
  active_lines "$1" | grep -F -- "$2" >/dev/null
}

active_has_ere() {
  active_lines "$1" | grep -E "$2" >/dev/null
}

shell="config/quickshell/ryoku/shell.qml"
popups="config/quickshell/ryoku/vendor/brain-shell/src/state/Popups.qml"
shell_state="config/quickshell/ryoku/vendor/brain-shell/src/state/ShellState.qml"
topbar="config/quickshell/ryoku/vendor/brain-shell/src/windows/TopBar.qml"
layer="config/quickshell/ryoku/vendor/brain-shell/src/popups/PopupLayer.qml"
toolbox="config/quickshell/ryoku/vendor/brain-shell/src/popups/ToolboxPopup.qml"
mirror="config/quickshell/ryoku/vendor/brain-shell/src/windows/MirrorWindow.qml"
caffeine="config/quickshell/ryoku/vendor/brain-shell/src/services/CaffeineService.qml"
services_qmldir="config/quickshell/ryoku/vendor/brain-shell/src/services/qmldir"
quick_settings="config/quickshell/ryoku/vendor/brain-shell/src/services/home/QuickSettings.qml"
ipc="bin/ryoku-ipc"
bindings="default/hypr/bindings/utilities.conf"
plain_bindings="default/hypr/plain-bindings.conf"
packages="install/ryoku-base.packages"
aur_packages="install/ryoku-aur.packages"

helpers=(
  bin/ryoku-cmd-colorpicker
  bin/ryoku-cmd-ocr
  bin/ryoku-cmd-qr-scan
  bin/ryoku-cmd-google-lens
)

for path in "$shell" "$popups" "$shell_state" "$topbar" "$layer" "$mirror" "$services_qmldir" "$quick_settings" "$ipc" "$bindings" "$plain_bindings" "$packages" "$aur_packages"; do
  [[ -f $path ]] || fail "$path missing"
done

active_has "$shell" 'function toggleToolbox' \
  || fail "shell IPC should expose toggleToolbox"
active_has "$shell" 'BS.Popups.toolboxOpen = opening' \
  || fail "toggleToolbox should open toolbox after closing other popups"
active_has "$shell" 'screen: modelData' \
  || fail "shell should pass the screen into PopupLayer"

active_has "$popups" 'property bool toolboxOpen' \
  || fail "Popups should track toolboxOpen"
active_has "$popups" 'property bool toolboxVisible' \
  || fail "Popups should track toolbox visual presence"
active_has "$popups" 'property bool mirrorOpen' \
  || fail "Popups should track mirrorOpen"
active_has "$popups" 'property string mirrorScreenName' \
  || fail "Popups should track the target mirror screen"
if active_lines "$popups" | awk '/readonly property bool anyOpen:/,/function closeAll/' | grep 'toolboxOpen' >/dev/null; then
  fail "PopupDismiss should not be responsible for toolbox outside-click handling"
fi
if active_lines "$popups" | awk '/readonly property bool anyOpen:/,/function closeAll/' | grep 'launcherOpen' >/dev/null; then
  fail "PopupDismiss should not be responsible for launcher outside-click handling"
fi
active_has "$popups" 'toolboxOpen       = false' \
  || fail "closeAll should close the toolbox"
active_has "$popups" 'mirrorOpen        = false' \
  || fail "closeAll should close the mirror"
active_has "$popups" 'mirrorScreenName  = ""' \
  || fail "closeAll should clear the target mirror screen"

if active_has "$topbar" 'Popups.toolboxVisible'; then
  fail "TopBar should not paint over the icon-only toolbox strip"
fi
if [[ ! -f $toolbox ]] && active_has_ere "$layer" '^[[:space:]]*ToolboxPopup[[:space:]]*\{'; then
  fail "PopupLayer should not instantiate ToolboxPopup before ToolboxPopup.qml exists"
fi
"$ipc" --help | grep "ryoku-ipc shell toggle toolbox" >/dev/null \
  || fail "ryoku-ipc help should document toolbox toggle"
"$ipc" shell command toolbox | grep 'qs -c ryoku ipc call popups toggleToolbox' >/dev/null \
  || fail "ryoku-ipc should print the toolbox IPC command"

grep -q 'bindd = SUPER, S, Toolbox, exec, ryoku-ipc shell toggle toolbox' "$bindings" \
  || fail "SUPER+S should open the toolbox"
active_super_s_count="$({ grep -Rhs '^bindd = SUPER, S,' default/hypr/bindings/*.conf || true; } | wc -l)"
(( active_super_s_count == 1 )) \
  || fail "there should be exactly one active SUPER+S binding in default/hypr/bindings"
if active_has_ere "$plain_bindings" '^bindd = SUPER, S, Toolbox'; then
  fail "plain bindings should not define an active SUPER+S toolbox binding"
fi

for path in "${helpers[@]}"; do
  [[ -f $path ]] || fail "$path missing"
  [[ -x $path ]] || fail "$path should be executable"
  bash -n "$path" || fail "$path has a syntax error"
done

grep -Eq 'mktemp .*ryoku-ocr\.' bin/ryoku-cmd-ocr \
  || fail "OCR helper should use mktemp for screenshots"
grep -Eq 'mktemp .*ryoku-qr\.' bin/ryoku-cmd-qr-scan \
  || fail "QR helper should use mktemp for screenshots"
grep -Eq 'mktemp .*ryoku-google-lens\.' bin/ryoku-cmd-google-lens \
  || fail "Google Lens helper should use mktemp for screenshots"
if grep -q '\$\$.*\.png' bin/ryoku-cmd-ocr bin/ryoku-cmd-qr-scan bin/ryoku-cmd-google-lens; then
  fail "screenshot helpers should not use PID-derived temp filenames"
fi
grep -Eq 'for cmd in .*xdg-open' bin/ryoku-cmd-qr-scan \
  || fail "QR helper should require xdg-open for URL actions"
grep -Fq 'uguu.se as a public URL' bin/ryoku-cmd-google-lens \
  || fail "Google Lens helper should disclose public upload behavior"
grep -Fq 'upload=Upload' bin/ryoku-cmd-google-lens \
  || fail "Google Lens helper should require explicit upload consent"
grep -Fq -- '--connect-timeout 10 --max-time 45' bin/ryoku-cmd-google-lens \
  || fail "Google Lens helper should use curl timeouts"

[[ -f $caffeine ]] || fail "$caffeine missing"
active_has "$caffeine" 'pragma Singleton' \
  || fail "CaffeineService should be a singleton"
active_has "$caffeine" 'systemd-inhibit' \
  || fail "CaffeineService should use systemd-inhibit"
active_has "$caffeine" 'pgrep", "-f", root._inhibitPattern' \
  || fail "CaffeineService should poll existing inhibitor state without a shell wrapper"
active_has "$caffeine" 'pkill", "-f", root._inhibitPattern' \
  || fail "CaffeineService should stop existing inhibitor processes without a shell wrapper"
active_has "$caffeine" '--who=Ryoku' \
  || fail "CaffeineService should use the Ryoku inhibitor identity"
active_has "$caffeine" '--why=Caffeine mode' \
  || fail "CaffeineService should use the Ryoku Caffeine reason"
active_has "$caffeine" '[C]affeine mode' \
  || fail "CaffeineService inhibitor match should be self-excluding"

[[ -f $toolbox ]] || fail "$toolbox missing"

active_toolbox_text="$(active_lines "$toolbox" | tr '\n' ' ')"
grep -Eq 'Binding[[:space:]]*\{[[:space:]]*target:[[:space:]]*Popups;?[[:space:]]*property:[[:space:]]*"toolboxVisible"' <<< "$active_toolbox_text" \
  || fail "ToolboxPopup should expose visual presence"
active_has "$toolbox" 'attachedEdge: "top"' \
  || fail "ToolboxPopup should attach to the topbar"
active_has "$toolbox" 'WlrLayershell.layer: WlrLayer.Overlay' \
  || fail "ToolboxPopup should render above the center pill"
active_has "$toolbox" 'color: Theme.background' \
  || fail "ToolboxPopup should use the same opaque fill as the center pill"
active_has "$toolbox" 'strokeColor: "transparent"' \
  || fail "ToolboxPopup should not draw a separate outline around the center pill"
active_has "$toolbox" 'strokeWidth: 0' \
  || fail "ToolboxPopup should not draw a border around the toolkit strip"
active_has "$toolbox" 'ListModel {' \
  || fail "ToolboxPopup should use stable ListModel roles"
active_has "$toolbox" 'font.family: "Phosphor"' \
  || fail "ToolboxPopup should use the Ambxst Phosphor icon font"
active_has "$toolbox" 'buttonSize: 26' \
  || fail "ToolboxPopup should use compact icon-only buttons"
active_has "$toolbox" 'required property int index' \
  || fail "ToolboxPopup delegate should bind the model index for selected icon state"
active_has "$toolbox" 'separator: true' \
  || fail "ToolboxPopup should keep Ambxst-style separators"
active_has "$toolbox" 'icon: "\ue10e"' \
  || fail "ToolboxPopup should use Ambxst camera icon codepoint"
active_has "$toolbox" 'icon: "\ue292"' \
  || fail "ToolboxPopup should use Ambxst Google icon codepoint"
if active_has "$toolbox" 'label:' || active_has "$toolbox" 'hint:' || active_has "$toolbox" 'Column {'; then
  fail "ToolboxPopup should be an icon-only strip, not a labeled card menu"
fi
for label in "Screenshot" "Open Screenshots" "Screen Recorder" "Open Recordings" "Color Picker" "OCR" "QR Code" "Google Lens" "Mirror" "Caffeine"; do
  active_has "$toolbox" "$label" || fail "ToolboxPopup should include $label"
done
active_has "$toolbox" 'ScreenRecService.recording' \
  || fail "ToolboxPopup should reuse ScreenRecService recording state"
active_has "$toolbox" 'legacyRecording' \
  || fail "ToolboxPopup should track legacy gpu-screen-recorder state"
active_has "$toolbox" '^gpu-screen-recorder' \
  || fail "ToolboxPopup should detect legacy gpu-screen-recorder with pgrep"
active_has "$toolbox" 'ShellState.screenRecord = true' \
  || fail "ToolboxPopup should open the existing recording setup surface"
active_has "$toolbox" 'ScreenRecService.cancelSetup()' \
  || fail "ToolboxPopup should cancel existing recording setup"
active_has "$toolbox" 'ryoku-cmd-screenrecord", "--stop-recording"' \
  || fail "ToolboxPopup should stop legacy gpu-screen-recorder as fallback"
active_has "$toolbox" 'Cancel Setup' \
  || fail "ToolboxPopup should show setup-open recorder state"
active_has "$toolbox" 'RYOKU_SCREENRECORD_DIR' \
  || fail "ToolboxPopup should respect configured recording directory"
active_has "$toolbox" 'XDG_VIDEOS_DIR' \
  || fail "ToolboxPopup should use XDG videos directory as recording fallback"
active_has "config/quickshell/ryoku/vendor/brain-shell/src/services/ScreenRecService.qml" 'RYOKU_SCREENRECORD_DIR' \
  || fail "ScreenRecService should respect configured recording directory"
active_has "config/quickshell/ryoku/vendor/brain-shell/src/services/ScreenRecService.qml" 'XDG_VIDEOS_DIR' \
  || fail "ScreenRecService should use XDG videos directory as recording fallback"
active_has "$toolbox" 'screen_recordings' \
  || fail "ToolboxPopup should include the default Quickshell screen_recordings directory"
if active_has "$toolbox" 'actionDelay'; then
  fail "ToolboxPopup should not depend on a post-close action timer"
fi
active_has "$toolbox" 'function closeToolboxNow' \
  || fail "ToolboxPopup should hide before launching interactive helpers"
active_has "$toolbox" 'actionRunner.running = true' \
  || fail "ToolboxPopup should launch helper commands on the same click"
active_has "$toolbox" 'CaffeineService.toggle()' \
  || fail "ToolboxPopup should toggle shared CaffeineService"
active_has "$toolbox" 'Popups.mirrorOpen = true' \
  || fail "ToolboxPopup should open the mirror window"
active_has "$toolbox" 'Popups.mirrorScreenName = screen ? screen.name : ""' \
  || fail "ToolboxPopup should target the mirror to its screen"

active_has_ere "$layer" '^[[:space:]]*ToolboxPopup[[:space:]]*\{' \
  || fail "PopupLayer should instantiate ToolboxPopup"
active_has "$layer" 'required property var screen' \
  || fail "PopupLayer should require the current screen"
active_has "$layer" 'ToolboxPopup { screen: root.screen }' \
  || fail "PopupLayer should pass screen to ToolboxPopup"

  active_has_ere "$mirror" '^[[:space:]]*Camera[[:space:]]*\{' \
    || fail "MirrorWindow should use QtMultimedia Camera"
  active_has_ere "$mirror" '^[[:space:]]*MediaDevices[[:space:]]*\{' \
    || fail "MirrorWindow should inspect camera availability"
  active_has_ere "$mirror" '^[[:space:]]*VideoOutput[[:space:]]*\{' \
    || fail "MirrorWindow should render a video preview"
  active_has_ere "$mirror" 'xScale:[[:space:]]*-1' \
    || fail "MirrorWindow preview should be mirrored horizontally"
  active_has "$mirror" 'No camera found' \
    || fail "MirrorWindow should show a no-camera state"
  active_has "$mirror" 'camera.errorString' \
    || fail "MirrorWindow should show camera error text"
  active_has "$mirror" 'Popups.mirrorScreenName' \
    || fail "MirrorWindow should use the target mirror screen"
  active_has "$mirror" 'primaryInstance' \
    || fail "MirrorWindow should avoid one active camera per monitor"
  active_has "$mirror" 'Popups.mirrorScreenName !== ""' \
    || fail "MirrorWindow should require an explicit target screen"
  active_has "$mirror" 'active: root.visible && root.hasCamera' \
    || fail "MirrorWindow camera should only activate when visible and available"
  active_has "$mirror" 'Popups.mirrorOpen' \
    || fail "MirrorWindow should be controlled by Popups.mirrorOpen"
  active_has_ere "$layer" '^[[:space:]]*MirrorWindow[[:space:]]*\{' \
    || fail "PopupLayer should instantiate MirrorWindow"
  active_has "$layer" 'MirrorWindow { screen: root.screen }' \
    || fail "PopupLayer should pass screen to MirrorWindow"

grep -q 'singleton CaffeineService 1.0 CaffeineService.qml' "$services_qmldir" \
  || fail "services qmldir should register CaffeineService"
active_has "$quick_settings" 'CaffeineService' \
  || fail "QuickSettings should use shared CaffeineService"
if active_has "$quick_settings" 'property bool caffeineOn'; then
  fail "QuickSettings should not keep separate Caffeine state"
fi

for pkg in libnotify tesseract tesseract-data-eng tesseract-data-spa xdg-user-dirs xdg-utils zbar; do
  grep -qx "$pkg" "$packages" || fail "$pkg should be in ryoku-base packages"
done
grep -qx 'ttf-phosphor-icons' "$aur_packages" \
  || fail "Phosphor icon font package should be in ryoku AUR packages"

grep -q 'hyprpicker' bin/ryoku-cmd-colorpicker \
  || fail "color picker helper should use hyprpicker"
grep -q 'tesseract' bin/ryoku-cmd-ocr \
  || fail "OCR helper should use tesseract"
grep -q 'zbarimg' bin/ryoku-cmd-qr-scan \
  || fail "QR helper should use zbarimg"
grep -Fq 'lens.google.com/uploadbyurl' bin/ryoku-cmd-google-lens \
  || fail "Google Lens helper should open uploadbyurl"
grep -Fq 'https://uguu.se/upload' bin/ryoku-cmd-google-lens \
  || fail "Google Lens helper should upload the selected image"
grep -q 'Uploading selected image' bin/ryoku-cmd-google-lens \
  || fail "Google Lens helper should notify before upload"

pass "toolbox static contract"
