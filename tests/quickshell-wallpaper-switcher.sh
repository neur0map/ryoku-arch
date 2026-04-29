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
grep -q 'attachedEdge: "top"' "$wallpaper_popup" \
  || fail "WallpaperPopup should attach visually to the topbar"
grep -q 'readonly property int panelWidth:  620' "$wallpaper_popup" \
  || fail "WallpaperPopup should use compact width"
grep -q 'readonly property int panelHeight: 300' "$wallpaper_popup" \
  || fail "WallpaperPopup should use compact height"
grep -q 'bottom: true' "$wallpaper_popup" \
  || fail "WallpaperPopup should own outside-click area"
grep -q 'onClicked: Popups.closeAll()' "$wallpaper_popup" \
  || fail "WallpaperPopup should close on outside click"
! grep -q 'mask: Region' "$wallpaper_popup" \
  || fail "WallpaperPopup should not mask away its outside-click area"
grep -q 'applyActive:' "$wallpaper_popup" \
  || fail "WallpaperPopup should keep explicit apply state"
grep -q 'previewWall !== WallpaperService.currentWall' "$wallpaper_popup" \
  || fail "WallpaperPopup should apply only changed wallpaper previews"
grep -q 'visible: false' "$wallpaper_popup" \
  || fail "WallpaperPopup should hide unused upstream folder/scheme controls"
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

grep -q 'bindd = SUPER CTRL, SPACE, Theme background menu, exec, qs -c ryoku ipc call popups toggleWallpaper' "$bindings" \
  || fail "SUPER+CTRL+SPACE should open the Quickshell wallpaper switcher"
! grep -q 'bindd = SUPER CTRL, SPACE, Theme background menu, exec, ryoku-menu background' "$bindings" \
  || fail "SUPER+CTRL+SPACE should no longer use the old tofi background picker"

pass "quickshell wallpaper switcher wiring"
