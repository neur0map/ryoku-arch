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
dismiss="config/quickshell/ryoku/vendor/brain-shell/src/windows/PopupDismiss.qml"
layer="config/quickshell/ryoku/vendor/brain-shell/src/popups/PopupLayer.qml"
toolbox="config/quickshell/ryoku/vendor/brain-shell/src/modules/Center/ToolboxContent.qml"
mirror="config/quickshell/ryoku/vendor/brain-shell/src/windows/MirrorWindow.qml"
screenshot_tool="config/quickshell/ryoku/vendor/brain-shell/src/windows/ScreenshotTool.qml"
screenshot_overlay="config/quickshell/ryoku/vendor/brain-shell/src/windows/ScreenshotOverlay.qml"
screenrecord_tool="config/quickshell/ryoku/vendor/brain-shell/src/windows/ScreenRecordTool.qml"
caffeine="config/quickshell/ryoku/vendor/brain-shell/src/services/CaffeineService.qml"
screenshot_service="config/quickshell/ryoku/vendor/brain-shell/src/services/ScreenshotService.qml"
screenrec_service="config/quickshell/ryoku/vendor/brain-shell/src/services/ScreenRecService.qml"
services_qmldir="config/quickshell/ryoku/vendor/brain-shell/src/services/qmldir"
quick_settings="config/quickshell/ryoku/vendor/brain-shell/src/services/home/QuickSettings.qml"
ipc="bin/ryoku-ipc"
menu="bin/ryoku-menu"
bindings="default/hypr/bindings/utilities.conf"
plain_bindings="default/hypr/plain-bindings.conf"
packages="install/ryoku-base.packages"
aur_packages="install/ryoku-aur.packages"
hypr_apps="default/hypr/apps/system.conf"

helpers=(
  bin/ryoku-cmd-caffeine
  bin/ryoku-cmd-image-edit
  bin/ryoku-cmd-video-edit
  bin/ryoku-cmd-colorpicker
  bin/ryoku-cmd-ocr
  bin/ryoku-cmd-qr-scan
  bin/ryoku-cmd-google-lens
)

for path in "$shell" "$popups" "$shell_state" "$topbar" "$dismiss" "$layer" "$mirror" "$screenshot_tool" "$screenshot_overlay" "$screenrecord_tool" "$screenshot_service" "$screenrec_service" "$services_qmldir" "$quick_settings" "$ipc" "$menu" "$bindings" "$plain_bindings" "$packages" "$aur_packages" "$hypr_apps"; do
  [[ -f $path ]] || fail "$path missing"
done

active_has "$shell" 'function toggleToolbox' \
  || fail "shell IPC should expose toggleToolbox"
active_has "$shell" 'BS.Popups.toolboxOpen = opening' \
  || fail "toggleToolbox should open toolbox after closing other popups"
active_has "$shell" 'function openToolbox' \
  || fail "shell IPC should expose openToolbox for key-driven toolbox sessions"
active_has "$shell" 'function toolboxPrevious' && active_has "$shell" 'function toolboxNext' \
  || fail "shell IPC should expose toolbox keyboard selection actions"
active_has "$shell" 'function toolboxActivate' && active_has "$shell" 'function toolboxClose' \
  || fail "shell IPC should expose toolbox activate and close actions"
active_has "$shell" 'function toggleScreenshot' \
  || fail "shell IPC should expose toggleScreenshot"
active_has "$shell" 'BS.ScreenshotService.startCapture("normal")' \
  || fail "toggleScreenshot should start the screenshot provider"
if active_lines "$shell" | awk '/function toggleScreenshot/,/function toggleScreenRecorder/' | grep -F 'BS.Popups.closeAll()' >/dev/null; then
  fail "toggleScreenshot should not close visible popups before capture"
fi
active_has "$shell" 'function toggleScreenRecorder' \
  || fail "shell IPC should expose toggleScreenRecorder"
active_has "$shell" 'BS.ScreenRecService.initialize()' \
  || fail "toggleScreenRecorder should initialize the recording provider"
if active_lines "$shell" | awk '/function toggleScreenRecorder/,/function toggleWallpaper/' | grep -F 'BS.Popups.closeAll()' >/dev/null; then
  fail "toggleScreenRecorder should not close visible popups before capture"
fi
active_has "$shell" 'screen: modelData' \
  || fail "shell should pass the screen into PopupLayer"

active_has "$popups" 'property bool toolboxOpen' \
  || fail "Popups should track toolboxOpen"
active_has "$popups" 'signal toolboxActionRequested' \
  || fail "Popups should route key-driven toolbox actions"
active_has "$popups" 'function requestToolboxAction' \
  || fail "Popups should expose a toolbox action request helper"
active_has "$popups" 'property bool screenshotToolOpen' \
  || fail "Popups should track screenshotToolOpen"
active_has "$popups" 'property bool screenRecordToolOpen' \
  || fail "Popups should track screenRecordToolOpen"
active_has "$popups" 'property bool mirrorOpen' \
  || fail "Popups should track mirrorOpen"
active_has "$popups" 'property string mirrorScreenName' \
  || fail "Popups should track the target mirror screen"
active_lines "$popups" | awk '/readonly property bool anyOpen:/,/function closeAll/' | grep 'toolboxOpen' >/dev/null \
  || fail "PopupDismiss should close the topbar-hosted toolbox on outside click"
if active_lines "$popups" | awk '/readonly property bool anyOpen:/,/function closeAll/' | grep 'launcherOpen' >/dev/null; then
  fail "PopupDismiss should not be responsible for launcher outside-click handling"
fi
active_has "$popups" 'toolboxOpen       = false' \
  || fail "closeAll should close the toolbox"
active_has "$popups" 'screenshotToolOpen = false' \
  || fail "closeAll should close the screenshot tool"
active_has "$popups" 'screenRecordToolOpen = false' \
  || fail "closeAll should close the screen recorder tool"
active_has "$popups" 'mirrorOpen        = false' \
  || fail "closeAll should close the mirror"
active_has "$popups" 'mirrorScreenName  = ""' \
  || fail "closeAll should clear the target mirror screen"

if active_has_ere "$layer" '^[[:space:]]*ToolboxPopup[[:space:]]*\{'; then
  fail "PopupLayer should not instantiate a separate ToolboxPopup overlay"
fi
active_has "$dismiss" 'Popups.toolboxOpen ? WlrKeyboardFocus.None' \
  || fail "PopupDismiss should not steal keyboard focus from the toolbox"
active_has "$topbar" 'ToolboxContent {' \
  || fail "TopBar should host the toolbox inside the center pill"
active_has "$topbar" 'WlrLayershell.layer: Popups.toolboxOpen' \
  || fail "TopBar should move the focused toolbox surface to the overlay layer"
active_has "$topbar" 'Popups.toolboxOpen' \
  || fail "TopBar should animate the center pill width for toolboxOpen"
active_has "$topbar" 'toolboxContent.implicitWidth + Theme.notchPadding * 2' \
  || fail "TopBar should size the center pill to the toolbox icon row"
active_has "$topbar" 'readonly property bool toolboxMorphActive' \
  || fail "TopBar should keep the morph timing active through close"
active_has "$topbar" 'toolboxContent.opacity > 0' \
  || fail "TopBar should not depend on ToolboxContent visibility for close timing"
active_has "$topbar" 'duration: root.toolboxMorphActive ? Theme.motionExpandDuration + 80 : Theme.animDuration' \
  || fail "TopBar should give the toolbox close animation enough time to merge back"
active_has "$topbar" 'opacity: Popups.toolboxOpen ? 0' \
  || fail "Center content should fade out when the toolbox is open"
active_has "$topbar" 'WlrLayershell.keyboardFocus: Popups.toolboxOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None' \
  || fail "TopBar should take keyboard focus while toolbox is open"
active_has "$topbar" 'FocusScope {' && active_has "$topbar" 'id: toolboxKeyScope' \
  || fail "TopBar should own the toolbox keyboard focus scope"
active_has "$topbar" 'toolboxFocusTimer.restart()' \
  || fail "TopBar should retry toolbox focus after the layer focus changes"
active_has "$topbar" 'toolboxContent.moveSelection(-1)' && active_has "$topbar" 'toolboxContent.moveSelection(1)' \
  || fail "TopBar focus scope should move toolbox selection with arrow keys"
active_has "$topbar" 'toolboxContent.activateCurrent()' \
  || fail "TopBar focus scope should activate the selected toolbox item"
"$ipc" --help | grep "ryoku-ipc shell toggle toolbox" >/dev/null \
  || fail "ryoku-ipc help should document toolbox toggle"
"$ipc" --help | grep "ryoku-ipc shell toolbox open" >/dev/null \
  || fail "ryoku-ipc help should document key-driven toolbox sessions"
"$ipc" shell command toolbox | grep 'ryoku-ipc shell toolbox open' >/dev/null \
  || fail "ryoku-ipc should print the key-driven toolbox command"
"$ipc" --help | grep "ryoku-ipc shell toggle screenshot" >/dev/null \
  || fail "ryoku-ipc help should document screenshot toggle"
"$ipc" --help | grep "ryoku-ipc shell toggle screen-record" >/dev/null \
  || fail "ryoku-ipc help should document screen recorder toggle"
"$ipc" shell command screenshot | grep 'qs -c ryoku ipc call popups toggleScreenshot' >/dev/null \
  || fail "ryoku-ipc should print the screenshot provider IPC command"
"$ipc" shell command screen-record | grep 'qs -c ryoku ipc call popups toggleScreenRecorder' >/dev/null \
  || fail "ryoku-ipc should print the screen recorder provider IPC command"

grep -q 'bindd = SUPER, S, Toolbox, exec, ryoku-ipc shell toolbox open' "$bindings" \
  || fail "SUPER+S should open the toolbox"
grep -q '^submap = toolbox$' "$bindings" \
  || fail "SUPER+S toolbox should use a Hyprland submap for arrow selection"
grep -q 'bindd = , RIGHT, Next toolbox tool, exec, ryoku-ipc shell toolbox next' "$bindings" \
  || fail "toolbox submap should move right to the next tool"
grep -q 'bindd = , LEFT, Previous toolbox tool, exec, ryoku-ipc shell toolbox previous' "$bindings" \
  || fail "toolbox submap should move left to the previous tool"
grep -q 'bindd = , RETURN, Activate toolbox tool, exec, ryoku-ipc shell toolbox activate' "$bindings" \
  || fail "toolbox submap should activate the selected tool with Return"
grep -q 'bindd = , ESCAPE, Close toolbox, exec, ryoku-ipc shell toolbox close' "$bindings" \
  || fail "toolbox submap should close with Escape"
grep -q 'bindd = , PRINT, Screenshot, exec, ryoku-ipc shell toggle screenshot' "$bindings" \
  || fail "PRINT should open the screenshot provider"
grep -q 'bindd = ALT, PRINT, Screenrecording, exec, ryoku-ipc shell toggle screen-record' "$bindings" \
  || fail "ALT+PRINT should open the screen recorder provider"
grep -q 'bindd = SUPER CTRL, C, Screenshot, exec, ryoku-ipc shell toggle screenshot' "$bindings" \
  || fail "SUPER+CTRL+C should open the screenshot provider"
if grep -q 'ryoku-menu capture' "$bindings"; then
  fail "SUPER+CTRL+C should not open the old capture menu"
fi
active_super_s_count="$({ grep -Rhs '^bindd = SUPER, S,' default/hypr/bindings/*.conf || true; } | wc -l)"
(( active_super_s_count == 2 )) \
  || fail "there should be one global and one toolbox-submap SUPER+S binding in default/hypr/bindings"
if active_has_ere "$plain_bindings" '^bindd = SUPER, S, Toolbox'; then
  fail "plain bindings should not define an active SUPER+S toolbox binding"
fi

for path in "${helpers[@]}"; do
  [[ -f $path ]] || fail "$path missing"
  [[ -x $path ]] || fail "$path should be executable"
  bash -n "$path" || fail "$path has a syntax error"
done
bash -n "$menu" || fail "$menu has a syntax error"
[[ ! -f bin/ryoku-cmd-screenshot ]] || fail "legacy Omarchy screenshot helper should be removed"
if active_has "$menu" 'ryoku-cmd-screenshot'; then
  fail "ryoku-menu should not launch the legacy screenshot helper"
fi

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
grep -Fq -- '--file IMAGE' bin/ryoku-cmd-qr-scan \
  || fail "QR helper should accept an image from the screenshot provider"
grep -Fq 'Uploading selected screenshot and opening Google Lens' bin/ryoku-cmd-google-lens \
  || fail "Google Lens helper should disclose automatic screenshot upload"
grep -Fq -- '--file IMAGE' bin/ryoku-cmd-google-lens \
  || fail "Google Lens helper should accept an image from the screenshot provider"
if grep -Fq 'upload=Upload' bin/ryoku-cmd-google-lens; then
  fail "Google Lens helper should not wait for a notification action before opening Lens"
fi
grep -Fq -- '--connect-timeout 10 --max-time 45' bin/ryoku-cmd-google-lens \
  || fail "Google Lens helper should use curl timeouts"

[[ -f $caffeine ]] || fail "$caffeine missing"
active_has "$caffeine" 'pragma Singleton' \
  || fail "CaffeineService should be a singleton"
active_has "$caffeine" 'ryoku-cmd-caffeine", "status"' \
  || fail "CaffeineService should read status from the caffeine helper"
active_has "$caffeine" 'ryoku-cmd-caffeine", "start"' \
  || fail "CaffeineService should start caffeine through the helper"
active_has "$caffeine" 'ryoku-cmd-caffeine", "stop"' \
  || fail "CaffeineService should stop caffeine through the helper"
active_has "$caffeine" 'root.active = true' \
  || fail "CaffeineService should keep the old optimistic active state after start"
grep -q 'systemd-inhibit' bin/ryoku-cmd-caffeine \
  || fail "caffeine helper should keep a systemd idle/sleep inhibitor"
grep -q 'pkill -x hypridle' bin/ryoku-cmd-caffeine \
  || fail "caffeine helper should stop hypridle while caffeine is active"
grep -q 'setsid uwsm-app -- hypridle' bin/ryoku-cmd-caffeine \
  || fail "caffeine helper should restore hypridle when it was running before caffeine"
grep -q 'ryoku-caffeine-inhibit' bin/ryoku-cmd-caffeine \
  || fail "caffeine helper should use a stable inhibitor process name"

[[ -f $toolbox ]] || fail "$toolbox missing"

active_has "$toolbox" 'ListModel {' \
  || fail "ToolboxContent should use stable ListModel roles"
active_has "$toolbox" 'font.family: "Phosphor"' \
  || fail "ToolboxContent should use the Phosphor icon font"
active_has "$toolbox" 'buttonSize: 26' \
  || fail "ToolboxContent should use compact icon-only buttons"
active_has "$toolbox" 'required property int index' \
  || fail "ToolboxContent delegate should bind the model index for selected icon state"
active_has "$toolbox" 'separator: true' \
  || fail "ToolboxContent should keep grouped separators"
active_has "$toolbox" 'icon: "\ue10e"' \
  || fail "ToolboxContent should use the camera icon codepoint"
active_has "$toolbox" 'icon: "\ue292"' \
  || fail "ToolboxContent should use the Google icon codepoint"
if active_has "$toolbox" 'label:' || active_has "$toolbox" 'hint:' || active_has "$toolbox" 'Column {'; then
  fail "ToolboxContent should be an icon-only strip, not a labeled card menu"
fi
for label in "Screenshot" "Open Screenshots" "Screen Recorder" "Open Recordings" "Color Picker" "OCR" "QR Code" "Google Lens" "Mirror" "Caffeine"; do
  active_has "$toolbox" "$label" || fail "ToolboxContent should include $label"
done
active_has "$toolbox" 'ScreenRecService.recording' \
  || fail "ToolboxContent should reuse ScreenRecService recording state"
active_has "$toolbox" 'legacyRecording' \
  || fail "ToolboxContent should track legacy gpu-screen-recorder state"
active_has "$toolbox" '^gpu-screen-recorder' \
  || fail "ToolboxContent should detect legacy gpu-screen-recorder with pgrep"
active_has "$toolbox" 'ScreenshotService.startCapture("normal")' \
  || fail "ToolboxContent should open the screenshot provider"
active_has "$toolbox" 'ScreenshotService.startCapture("qr")' \
  || fail "ToolboxContent should scan QR codes through the screenshot provider"
active_has "$toolbox" 'ScreenshotService.startCapture("lens")' \
  || fail "ToolboxContent should open Google Lens through the screenshot provider"
active_has "$toolbox" 'Popups.screenshotToolOpen = true' \
  || fail "ToolboxContent should show the screenshot tool"
if active_has "$toolbox" 'runProcess(["ryoku-cmd-qr-scan"])' || active_has "$toolbox" 'runProcess(["ryoku-cmd-google-lens"])'; then
  fail "ToolboxContent should not launch QR/Lens through the old direct screenshot helpers"
fi
active_has "$toolbox" 'Popups.screenRecordToolOpen = true' \
  || fail "ToolboxContent should open the recording provider"
active_has "$toolbox" 'Popups.screenRecordToolOpen = false' \
  || fail "ToolboxContent should cancel the recording provider"
active_has "$toolbox" 'readonly property color activeFill' \
  || fail "ToolboxContent should define a visible active fill for persistent tools"
active_has "$toolbox" 'toolItem.active' \
  || fail "ToolboxContent should render persistent active tool state"
active_has "$toolbox" 'activeIconColor' \
  || fail "ToolboxContent should keep active icons readable against active fill"
active_has "$toolbox" 'selectionAccentColor: "#F25623"' \
  || fail "ToolboxContent should keep brand accents for selection fills"
active_has "$toolbox" 'idleIconColor: "#ffffff"' \
  || fail "ToolboxContent idle icons should be white"
active_has "$toolbox" 'selectedIconColor: idleIconColor' \
  || fail "ToolboxContent selected icons should stay white"
active_has "$toolbox" 'id: selectionCursor' \
  || fail "ToolboxContent should render a moving keyboard selection cursor"
active_has "$toolbox" 'id: cursorTrailNear' && active_has "$toolbox" 'id: cursorTrailFar' \
  || fail "ToolboxContent should animate a cursor trail behind selection changes"
active_has "$toolbox" 'focus: Popups.toolboxOpen' \
  || fail "ToolboxContent should focus itself while open"
active_has "$toolbox" 'Qt.callLater(function() { root.forceActiveFocus() })' \
  || fail "ToolboxContent should request active focus when opened"
active_has "$toolbox" 'function moveSelection' \
  || fail "ToolboxContent should support keyboard selection movement"
active_has "$toolbox" 'onToolboxActionRequested' \
  || fail "ToolboxContent should accept key-driven selection actions from IPC"
active_has "$toolbox" 'function activateCurrent' \
  || fail "ToolboxContent should activate the selected tool from the keyboard"
active_has "$toolbox" 'Qt.Key_Left' && active_has "$toolbox" 'Qt.Key_Right' \
  || fail "ToolboxContent should support horizontal arrow-key selection"
active_has "$toolbox" 'Qt.Key_Up' && active_has "$toolbox" 'Qt.Key_Down' \
  || fail "ToolboxContent should support vertical arrow-key selection aliases"
active_has "$toolbox" 'Qt.Key_Return' && active_has "$toolbox" 'Qt.Key_Space' \
  || fail "ToolboxContent should activate selected tool with Return or Space"
active_has "$toolbox" 'Qt.Key_Escape' \
  || fail "ToolboxContent should close with Escape"
active_has "$toolbox" 'hyprctl", "dispatch", "submap", "reset"' \
  || fail "ToolboxContent should reset the Hyprland toolbox submap when it closes"
active_has "$toolbox" 'ryoku-cmd-screenrecord", "--stop-recording"' \
  || fail "ToolboxContent should stop legacy gpu-screen-recorder as fallback"
active_has "$toolbox" 'Cancel Recorder' \
  || fail "ToolboxContent should show setup-open recorder state"
active_has "$toolbox" 'RYOKU_SCREENRECORD_DIR' \
  || fail "ToolboxContent should respect configured recording directory"
active_has "$toolbox" 'XDG_VIDEOS_DIR' \
  || fail "ToolboxContent should use XDG videos directory as recording fallback"
active_has "$screenrec_service" 'RYOKU_SCREENRECORD_DIR' \
  || fail "ScreenRecService should respect configured recording directory"
active_has "$screenrec_service" 'XDG_VIDEOS_DIR' \
  || fail "ScreenRecService should use XDG videos directory as recording fallback"
active_has "$toolbox" 'screen_recordings' \
  || fail "ToolboxContent should include the default Quickshell screen_recordings directory"
if active_has "$toolbox" 'actionDelay'; then
  fail "ToolboxContent should not depend on a post-close action timer"
fi
active_has "$toolbox" 'function closeToolbox' \
  || fail "ToolboxContent should close the pill before launching interactive helpers"
active_has "$toolbox" 'visible: true' \
  || fail "ToolboxContent should stay alive while hidden so pending actions can fire"
active_has "$toolbox" 'id: actionStartTimer' \
  || fail "ToolboxContent should keep internal delayed actions through close"
active_has "$toolbox" 'interval: Theme.motionExpandDuration + 120' \
  || fail "ToolboxContent should launch helper commands after the pill has collapsed"
active_has "$toolbox" 'Popups.toolboxOpen = false' \
  || fail "ToolboxContent should collapse the actual center pill"
active_has "$toolbox" 'sleep 0.45; exec \"$@\"' \
  || fail "ToolboxContent should start external helpers on the first click after a close delay"
active_has "$toolbox" 'actionRunner.running = true' \
  || fail "ToolboxContent should launch helper commands from a single click"
active_has "$toolbox" 'CaffeineService.toggle()' \
  || fail "ToolboxContent should toggle shared CaffeineService"
active_has "$toolbox" 'Popups.mirrorOpen = true' \
  || fail "ToolboxContent should open the mirror window"
active_has "$toolbox" 'Popups.mirrorScreenName = screen ? screen.name : ""' \
  || fail "ToolboxContent should target the mirror to its screen"

active_has "$layer" 'required property var screen' \
  || fail "PopupLayer should require the current screen"
active_has "$layer" 'ScreenshotTool { screen: root.screen }' \
  || fail "PopupLayer should instantiate ScreenshotTool for each screen"
active_has "$layer" 'ScreenshotOverlay { screen: root.screen }' \
  || fail "PopupLayer should instantiate ScreenshotOverlay for each screen"
active_has "$layer" 'ScreenRecordTool { screen: root.screen }' \
  || fail "PopupLayer should instantiate ScreenRecordTool for each screen"

active_has "$screenshot_service" 'grim -o' \
  || fail "ScreenshotService should capture monitor screenshots with grim outputs"
active_has "$screenshot_service" 'grim -g' \
  || fail "ScreenshotService should capture selected regions directly with grim"
active_has "$screenshot_service" 'devicePixelRatio' \
  || fail "ScreenshotService should use Quickshell devicePixelRatio for scaled monitors"
active_has "$screenshot_service" 'signal captureReady()' \
  || fail "ScreenshotService should make the screenshot overlay ready without waiting for a pre-freeze"
active_has "$screenshot_service" 'wl-copy --type image/png' \
  || fail "ScreenshotService should copy screenshots to the clipboard"
active_has "$screenshot_service" 'RYOKU_SCREENSHOT_DIR' \
  || fail "ScreenshotService should respect the configured screenshot directory"
active_has "$screenshot_service" 'Screenshots' \
  || fail "ScreenshotService should use the Screenshots subdirectory by default"
active_has "$screenshot_service" 'property string lensPath: "/tmp/image.png"' \
  || fail "ScreenshotService should use the Google Lens handoff path"
active_has "$screenshot_service" 'captureMode === "lens"' \
  || fail "ScreenshotService should handle Google Lens capture mode"
active_has "$screenshot_service" 'captureMode === "qr"' \
  || fail "ScreenshotService should handle QR capture mode"
active_has "$screenshot_service" 'ryoku-cmd-google-lens", "--file"' \
  || fail "ScreenshotService should hand Lens captures to the Lens helper"
active_has "$screenshot_service" 'ryoku-cmd-qr-scan", "--file"' \
  || fail "ScreenshotService should hand QR captures to the QR helper"
active_has "$screenshot_tool" 'ScreenshotService.processRegion' \
  || fail "ScreenshotTool should save selected regions through ScreenshotService"
active_has "$screenshot_tool" 'ScreenshotService.processMonitorScreen' \
  || fail "ScreenshotTool should save monitor captures through ScreenshotService"
active_has "$screenshot_overlay" 'function onImageSaved' \
  || fail "ScreenshotOverlay should react to saved screenshots"
active_has "$screenshot_overlay" 'ryoku-cmd-image-edit' \
  || fail "ScreenshotOverlay should open screenshots in the image editor"
active_has "$screenshot_overlay" 'Edit with Gradia' \
  || fail "ScreenshotOverlay should label the image editor action"

active_has "$screenrec_service" 'gpu-screen-recorder' \
  || fail "ScreenRecService should use the gpu-screen-recorder provider"
if active_has "$screenrec_service" 'wl-screenrec'; then
  fail "ScreenRecService should not use the old wl-screenrec provider"
fi
active_has "$screenrec_service" '-w portal' \
  || fail "ScreenRecService should support the portal recording provider"
active_has "$screenrec_service" '-w region' \
  || fail "ScreenRecService should support the region recording provider"
active_has "$screenrec_service" 'default_output' \
  || fail "ScreenRecService should support output audio"
active_has "$screenrec_service" 'default_input' \
  || fail "ScreenRecService should support input audio"
active_has "$screenrec_service" 'pkill -SIGINT -f' && active_has "$screenrec_service" '^gpu-screen-recorder' \
  || fail "ScreenRecService should stop gpu-screen-recorder with SIGINT"
active_has "$screenrec_service" 'ryoku-cmd-video-edit' \
  || fail "ScreenRecService should expose a video editor action after recording"
active_has "$screenrec_service" 'Kdenlive' \
  || fail "ScreenRecService should pair recordings with the configured video editor"
active_has "$screenrecord_tool" 'ScreenRecorder unavailable' \
  || fail "ScreenRecordTool should show a provider availability error"
active_has "$screenrecord_tool" 'id: startRecordTimer' \
  || fail "ScreenRecordTool should delay recording startup until its overlay closes"
active_has "$screenrecord_tool" 'function queueRecording' \
  || fail "ScreenRecordTool should queue recordings through one close-before-start path"
active_has "$screenrecord_tool" 'queueRecording("region"' \
  || fail "ScreenRecordTool should queue region recordings through ScreenRecService"
active_has "$screenrecord_tool" 'queueRecording("portal"' \
  || fail "ScreenRecordTool should queue portal recordings through ScreenRecService"

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
grep -q 'singleton ScreenshotService 1.0 ScreenshotService.qml' "$services_qmldir" \
  || fail "services qmldir should register ScreenshotService"
active_has "$quick_settings" 'CaffeineService' \
  || fail "QuickSettings should use shared CaffeineService"
if active_has "$quick_settings" 'property bool caffeineOn'; then
  fail "QuickSettings should not keep separate Caffeine state"
fi

for pkg in ffmpeg gpu-screen-recorder kdenlive libnotify pipewire playerctl tesseract tesseract-data-eng tesseract-data-spa wireplumber x264 xdg-user-dirs xdg-utils zbar; do
  grep -qx "$pkg" "$packages" || fail "$pkg should be in ryoku-base packages"
done
grep -qx 'gradia' "$aur_packages" \
  || fail "Gradia image editor should be in ryoku AUR packages"
grep -qx 'ttf-phosphor-icons' "$aur_packages" \
  || fail "Phosphor icon font package should be in ryoku AUR packages"

grep -q 'gradia' bin/ryoku-cmd-image-edit \
  || fail "image edit helper should prefer Gradia"
grep -q 'be.alexandervanhee.gradia' bin/ryoku-cmd-image-edit \
  || fail "image edit helper should fall back to the Gradia Flatpak id"
grep -q 'kdenlive' bin/ryoku-cmd-video-edit \
  || fail "video edit helper should prefer Kdenlive"
grep -q 'be.alexandervanhee.gradia' "$hypr_apps" \
  || fail "Hyprland media window rules should include Gradia"
grep -q 'org.kde.kdenlive' "$hypr_apps" \
  || fail "Hyprland media window rules should include Kdenlive"
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
grep -q 'xdg-open "https://lens.google.com/uploadbyurl?url=$encoded_url"' bin/ryoku-cmd-google-lens \
  || fail "Google Lens helper should automatically open the browser after upload"

pass "toolbox static contract"
