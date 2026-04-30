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
grep -q 'Popups.dashboardVisible || Popups.launcherVisible ? WlrLayer.Overlay : WlrLayer.Top' "$topbar" \
  || fail "TopBar should only promote bar-attached popups to overlay"
! grep -q 'Popups.dashboardVisible || Popups.launcherVisible || Popups.wallpaperVisible' "$topbar" \
  || fail "TopBar should not compete with fullscreen wallpaper overlay"
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
grep -q 'implicitHeight: root.overlayHeight' "$wallpaper_popup" \
  || fail "WallpaperPopup should expose fullscreen overlay height"
grep -q 'attachedEdge: "bottom"' "$wallpaper_popup" \
  || fail "WallpaperPopup should attach the selector to the bottom edge"
grep -Eq 'readonly property int selectorMaxWidth:[[:space:]]+1040' "$wallpaper_popup" \
  || fail "WallpaperPopup should use a slimmer selector width"
grep -Eq 'readonly property int selectorHeight:[[:space:]]+380' "$wallpaper_popup" \
  || fail "WallpaperPopup should use a slimmer selector height"
grep -q 'y: Popups.wallpaperOpen ? parent.height - height : parent.height + Theme.borderWidth' "$wallpaper_popup" \
  || fail "WallpaperPopup should slide up from the bottom"
! grep -q 'id: scrim' "$wallpaper_popup" \
  || fail "WallpaperPopup should not use a dimming fullscreen scrim"
! grep -q 'Behavior on opacity' "$wallpaper_popup" \
  || fail "WallpaperPopup should not fade in or out"
! grep -q 'scale: Popups.wallpaperOpen' "$wallpaper_popup" \
  || fail "WallpaperPopup should not scale-fade"
grep -q 'top:    true' "$wallpaper_popup" \
  || fail "WallpaperPopup should anchor to the top edge"
grep -q 'bottom: true' "$wallpaper_popup" \
  || fail "WallpaperPopup should anchor to the bottom edge"
grep -q 'onClicked: Popups.wallpaperOpen = false' "$wallpaper_popup" \
  || fail "WallpaperPopup should close from fullscreen outside clicks"
grep -q 'visible: Popups.anyOpen || (ShellState.screenRecord && !ScreenRecService.recording)' "$popup_dismiss" \
  || fail "PopupDismiss should still track popup visual state for shared dismissal wiring"
grep -q 'WallpaperFilterBar' "$wallpaper_popup" \
  || fail "WallpaperPopup should use the SKWD filter bar"
grep -q 'WallpaperSkewCard' "$wallpaper_popup" \
  || fail "WallpaperPopup should use skewed wallpaper cards"
grep -q 'WallpaperSettingsPane' "$wallpaper_popup" \
  || fail "WallpaperPopup should expose selector settings"
grep -q 'model: WallpaperService.filteredModel' "$wallpaper_popup" \
  || fail "WallpaperPopup should use the filtered model"
grep -q 'WallpaperService.rebuildCache()' "$wallpaper_popup" \
  || fail "WallpaperPopup should rebuild cache from the filter bar"
grep -q 'Popups.wallpaperOpen = false' "$wallpaper_popup" \
  || fail "Escape/apply should close the wallpaper switcher"

grep -q 'wallpaper", "apply", "--type"' "$wallpaper_service" \
  || fail "WallpaperService should apply through ryoku-ipc"
! grep -q 'matugen image' "$wallpaper_service" \
  || fail "WallpaperService should not run upstream matugen pipeline"
! grep -q 'awww img' "$wallpaper_service" \
  || fail "WallpaperService should not run upstream awww pipeline"
grep -q '.config/ryoku/current/theme/backgrounds' "$wallpaper_service" \
  || fail "WallpaperService should list active theme backgrounds"
grep -q 'picturesDir + "/Wallpapers"' "$wallpaper_service" \
  || fail "WallpaperService should expose Pictures/Wallpapers as the user wallpaper folder"

grep -q 'bindd = SUPER CTRL, SPACE, Theme background menu, exec, ryoku-ipc shell toggle wallpaper' "$bindings" \
  || fail "SUPER+CTRL+SPACE should open the Quickshell wallpaper switcher through ryoku-ipc"
! grep -q 'bindd = SUPER CTRL, SPACE, Theme background menu, exec, qs -c ryoku ipc call popups toggleWallpaper' "$bindings" \
  || fail "SUPER+CTRL+SPACE should no longer call qs directly"

pass "quickshell wallpaper switcher wiring"
