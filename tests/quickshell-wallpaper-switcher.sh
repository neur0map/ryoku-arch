#!/bin/bash
# Static regression checks for the Quickshell wallpaper switcher.

set -e
cd "$(dirname "$0")/.."

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

pass() {
  echo "OK: $1"
}

shell="config/quickshell/ryoku/shell.qml"
popups="config/quickshell/ryoku/vendor/brain-shell/src/state/Popups.qml"
topbar="config/quickshell/ryoku/vendor/brain-shell/src/windows/TopBar.qml"
popup_dismiss="config/quickshell/ryoku/vendor/brain-shell/src/windows/PopupDismiss.qml"
layer="config/quickshell/ryoku/vendor/brain-shell/src/popups/PopupLayer.qml"
wallpaper_popup="config/quickshell/ryoku/vendor/brain-shell/src/popups/WallpaperPopup.qml"
wallpaper_service="config/quickshell/ryoku/vendor/brain-shell/src/services/WallpaperService.qml"
bindings="default/hypr/bindings/utilities.conf"

for path in "$shell" "$popups" "$topbar" "$popup_dismiss" "$layer" "$wallpaper_popup" "$wallpaper_service" "$bindings"; do
  [[ -f $path ]] || fail "$path missing"
done

grep -q 'function toggleWallpaper' "$shell" \
  || fail "shell IPC should expose toggleWallpaper"
grep -q 'BS.Popups.wallpaperOpen = opening' "$shell" \
  || fail "toggleWallpaper should open wallpaper switcher after closing other popups"

grep -q 'property bool wallpaperVisible' "$popups" \
  || fail "Popups should track wallpaper visual presence"
grep -q 'Popups.dashboardVisible || Popups.launcherVisible || Popups.wallpaperVisible' "$topbar" \
  || fail "TopBar should stay visually connected while wallpaper switcher opens"
grep -q 'Popups.launcherOpen || Popups.wallpaperOpen ? WlrKeyboardFocus.None : WlrKeyboardFocus.OnDemand' "$popup_dismiss" \
  || fail "PopupDismiss should not steal keyboard focus from searchable popups"

grep -q 'WallpaperPopup' "$layer" \
  || fail "PopupLayer should instantiate WallpaperPopup"
! grep -q '^[[:space:]]*//[[:space:]]*WallpaperPopup' "$layer" \
  || fail "WallpaperPopup should not remain dormant"

grep -q 'Binding { target: Popups; property: "wallpaperVisible"' "$wallpaper_popup" \
  || fail "WallpaperPopup should expose visual presence to TopBar"
grep -q 'WlrKeyboardFocus.Exclusive' "$wallpaper_popup" \
  || fail "WallpaperPopup should own keyboard focus while open"
grep -q 'attachedEdge: "bottom"' "$wallpaper_popup" \
  || fail "WallpaperPopup should open from the bottom like Brain Shell"
grep -q 'implicitHeight: root.panelHeight + Theme.borderWidth' "$wallpaper_popup" \
  || fail "WallpaperPopup should be a bottom layer surface, not fullscreen"
grep -Eq 'readonly property int panelWidth:[[:space:]]+980' "$wallpaper_popup" \
  || fail "WallpaperPopup should use Brain Shell width"
grep -Eq 'readonly property int panelHeight:[[:space:]]+420' "$wallpaper_popup" \
  || fail "WallpaperPopup should use Brain Shell height"
grep -q 'bottom: true' "$wallpaper_popup" \
  || fail "WallpaperPopup should anchor to the bottom edge"
! grep -q 'top:    true' "$wallpaper_popup" \
  || fail "WallpaperPopup should not be top anchored"
grep -q 'mask: Region { item: maskProxy }' "$wallpaper_popup" \
  || fail "WallpaperPopup should mask clicks to the bottom panel only"
grep -q 'anchors.bottomMargin:     Theme.borderWidth' "$wallpaper_popup" \
  || fail "WallpaperPopup should sit above the Ryoku frame border"
grep -q 'visible: Popups.anyOpen || (ShellState.screenRecord && !ScreenRecService.recording)' "$popup_dismiss" \
  || fail "PopupDismiss should remain responsible for wallpaper outside-click close"
grep -q 'applyActive:' "$wallpaper_popup" \
  || fail "WallpaperPopup should keep explicit apply state"
grep -q 'previewWall !== WallpaperService.currentWall' "$wallpaper_popup" \
  || fail "WallpaperPopup should apply only changed wallpaper previews"
grep -A3 'id: folderBtn' "$wallpaper_popup" | grep -q 'visible: false' \
  || fail "WallpaperPopup should hide unused upstream folder control"
grep -A3 'id: schemeBtn' "$wallpaper_popup" | grep -q 'visible: false' \
  || fail "WallpaperPopup should hide unused upstream scheme control"
grep -q 'Popups.wallpaperOpen = false' "$wallpaper_popup" \
  || fail "Escape/apply should close the wallpaper switcher"

grep -q 'ryoku-theme-bg-set' "$wallpaper_service" \
  || fail "WallpaperService should apply through Ryoku background setter"
! grep -q 'matugen image' "$wallpaper_service" \
  || fail "WallpaperService should not run upstream matugen pipeline"
! grep -q 'awww img' "$wallpaper_service" \
  || fail "WallpaperService should not run upstream awww pipeline"
grep -q '.config/ryoku/current/theme/backgrounds' "$wallpaper_service" \
  || fail "WallpaperService should list active theme backgrounds"
grep -q '.config/ryoku/backgrounds/' "$wallpaper_service" \
  || fail "WallpaperService should list user backgrounds for the active theme"

grep -q 'bindd = SUPER CTRL, SPACE, Theme background menu, exec, ryoku-ipc shell toggle wallpaper' "$bindings" \
  || fail "SUPER+CTRL+SPACE should open the Quickshell wallpaper switcher through ryoku-ipc"
! grep -q 'bindd = SUPER CTRL, SPACE, Theme background menu, exec, qs -c ryoku ipc call popups toggleWallpaper' "$bindings" \
  || fail "SUPER+CTRL+SPACE should no longer call qs directly"

pass "quickshell wallpaper switcher wiring"
