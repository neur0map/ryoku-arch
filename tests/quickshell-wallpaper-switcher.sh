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
theme_service="config/quickshell/ryoku/vendor/brain-shell/src/services/ThemeService.qml"
font_service="config/quickshell/ryoku/vendor/brain-shell/src/services/FontService.qml"
cursor_service="config/quickshell/ryoku/vendor/brain-shell/src/services/CursorService.qml"
theme_card="config/quickshell/ryoku/vendor/brain-shell/src/popups/ThemeCard.qml"
bindings="default/hypr/bindings/utilities.conf"
restart_shell="bin/ryoku-restart-shell"

for path in "$shell" "$popups" "$topbar" "$popup_dismiss" "$layer" "$wallpaper_popup" "$wallpaper_service" "$theme_service" "$font_service" "$cursor_service" "$theme_card" "$bindings" "$restart_shell"; do
  [[ -f $path ]] || fail "$path missing"
done

grep -q 'function toggleWallpaper' "$shell" \
  || fail "shell IPC should expose toggleWallpaper"
grep -q 'function toggleThemes' "$shell" \
  || fail "shell IPC should expose toggleThemes"
grep -q 'function toggleFonts' "$shell" \
  || fail "shell IPC should expose toggleFonts"
grep -q 'function toggleCursors' "$shell" \
  || fail "shell IPC should expose toggleCursors"
grep -q 'BS.Popups.wallpaperOpen = opening' "$shell" \
  || fail "toggleWallpaper should open wallpaper switcher after closing other popups"
grep -q 'BS.Popups.wallpaperMode = "theme"' "$shell" \
  || fail "toggleThemes should open the shared selector in theme mode"
grep -q 'BS.Popups.wallpaperMode = "font"' "$shell" \
  || fail "toggleFonts should open the shared selector in font mode"
grep -q 'BS.Popups.wallpaperMode = "cursor"' "$shell" \
  || fail "toggleCursors should open the shared selector in cursor mode"

grep -q 'property bool wallpaperVisible' "$popups" \
  || fail "Popups should track wallpaper visual presence"
grep -q 'property string wallpaperMode' "$popups" \
  || fail "Popups should track which appearance selector section is showing"
grep -q 'Popups.dashboardVisible || Popups.launcherVisible || Popups.systemMenuVisible || Popups.settingsMenuVisible' "$topbar" \
  || fail "TopBar should only promote bar-attached popups to overlay"
! grep -q 'Popups.dashboardVisible || Popups.launcherVisible || Popups.wallpaperVisible' "$topbar" \
  || fail "TopBar should not compete with fullscreen wallpaper overlay"
grep -Eq 'WlrLayershell.keyboardFocus: .*Popups.wallpaperOpen.*\\?.*WlrKeyboardFocus.None.*:.*WlrKeyboardFocus.OnDemand' "$popup_dismiss" \
  || fail "PopupDismiss should not steal keyboard focus from searchable popups"
grep -Fq "pkill -f '^qs -c ryoku(\$| )'" "$restart_shell" \
  || fail "ryoku-restart-shell should stop stale qs debug shells before relaunching"

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
grep -Eq 'readonly property int selectorMaxWidth:[[:space:]]+1120' "$wallpaper_popup" \
  || fail "WallpaperPopup should fit the skwd-style bottom selector width"
grep -Eq 'readonly property int selectorHeight:[[:space:]]+480' "$wallpaper_popup" \
  || fail "WallpaperPopup should fit skwd-style slices inside the bottom sheet"
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
grep -q 'ThemeCard' "$wallpaper_popup" \
  || fail "WallpaperPopup should render theme cards in the shared selector"
grep -q 'AppearanceChoiceCard' "$wallpaper_popup" \
  || fail "WallpaperPopup should render font and cursor cards in the shared selector"
grep -q 'property string activeMode' "$wallpaper_popup" \
  || fail "WallpaperPopup should track active appearance mode"
grep -q 'activeMode: content.activeMode' "$wallpaper_popup" \
  || fail "WallpaperPopup should pass active mode into the compact filter bar"
grep -q 'model: WallpaperService.filteredModel' "$wallpaper_popup" \
  || fail "WallpaperPopup should use the filtered model"
grep -q 'model: ThemeService.filteredModel' "$wallpaper_popup" \
  || fail "WallpaperPopup should bind themes to the filtered theme model"
grep -q 'model: FontService.filteredModel' "$wallpaper_popup" \
  || fail "WallpaperPopup should bind fonts to the filtered font model"
grep -q 'model: CursorService.filteredModel' "$wallpaper_popup" \
  || fail "WallpaperPopup should bind cursors to the filtered cursor model"
grep -q 'WallpaperService.rebuildCache()' "$wallpaper_popup" \
  || fail "WallpaperPopup should rebuild cache from the filter bar"
grep -q 'ThemeService.refresh()' "$wallpaper_popup" \
  || fail "WallpaperPopup should refresh themes through ThemeService"
grep -q 'FontService.refresh()' "$wallpaper_popup" \
  || fail "WallpaperPopup should refresh fonts through FontService"
grep -q 'CursorService.refresh()' "$wallpaper_popup" \
  || fail "WallpaperPopup should refresh cursors through CursorService"
grep -q 'ThemeService.applyItem(item)' "$wallpaper_popup" \
  || fail "WallpaperPopup should apply selected themes through ThemeService"
grep -q 'FontService.applyItem(fontItem)' "$wallpaper_popup" \
  || fail "WallpaperPopup should apply selected fonts through FontService"
grep -q 'CursorService.applyItem(cursorItem)' "$wallpaper_popup" \
  || fail "WallpaperPopup should apply selected cursors through CursorService"
grep -q 'Popups.wallpaperOpen = false' "$wallpaper_popup" \
  || fail "Escape/apply should close the wallpaper switcher"

grep -q 'wallpaper", "apply", "--type"' "$wallpaper_service" \
  || fail "WallpaperService should apply through ryoku-ipc"
! grep -q 'matugen image' "$wallpaper_service" \
  || fail "WallpaperService should not run upstream matugen pipeline"
! grep -q 'awww img' "$wallpaper_service" \
  || fail "WallpaperService should not run upstream awww pipeline"
! grep -q 'themeWallpaperDir' "$wallpaper_service" \
  || fail "WallpaperService should not expose bundled theme backgrounds as selector wallpaper sources"
grep -q 'picturesDir + "/Wallpapers"' "$wallpaper_service" \
  || fail "WallpaperService should expose Pictures/Wallpapers as the user wallpaper folder"
grep -q 'theme", "list", "--jsonl"' "$theme_service" \
  || fail "ThemeService should list themes through ryoku-ipc"
grep -q 'theme", "apply"' "$theme_service" \
  || fail "ThemeService should apply themes through ryoku-ipc"
grep -q 'font", "list", "--jsonl"' "$font_service" \
  || fail "FontService should list fonts through ryoku-ipc"
grep -q 'font", "install"' "$font_service" \
  || fail "FontService should install curated fonts through ryoku-ipc"
grep -q 'cursor", "list", "--jsonl"' "$cursor_service" \
  || fail "CursorService should list cursors through ryoku-ipc"
grep -q 'cursor", "install"' "$cursor_service" \
  || fail "CursorService should install curated cursors through ryoku-ipc"
grep -q 'required property var itemData' "$theme_card" \
  || fail "ThemeCard should accept theme model rows"

grep -q 'bindd = SUPER CTRL, SPACE, Appearance menu, exec, ryoku-ipc shell toggle wallpaper' "$bindings" \
  || fail "SUPER+CTRL+SPACE should open the Quickshell appearance selector through ryoku-ipc"
grep -q 'bindd = SUPER SHIFT CTRL, SPACE, Theme menu, exec, ryoku-ipc shell toggle themes' "$bindings" \
  || fail "SUPER+CTRL+SHIFT+SPACE should open the shared selector in theme mode"
! grep -q 'bindd = SUPER CTRL, SPACE, Theme background menu, exec, qs -c ryoku ipc call popups toggleWallpaper' "$bindings" \
  || fail "SUPER+CTRL+SPACE should no longer call qs directly"
! grep -q 'bindd = SUPER SHIFT CTRL, SPACE, Theme menu, exec, ryoku-menu theme' "$bindings" \
  || fail "SUPER+CTRL+SHIFT+SPACE should no longer open the old tofi theme menu"

pass "quickshell wallpaper switcher wiring"
