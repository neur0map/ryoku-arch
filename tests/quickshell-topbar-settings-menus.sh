#!/bin/bash
# Static regression checks for the topbar-attached settings menus.

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
control_panel="config/quickshell/ryoku/vendor/brain-shell/src/modules/Left/ControlPanel.qml"
popup_dismiss="config/quickshell/ryoku/vendor/brain-shell/src/windows/PopupDismiss.qml"
layer="config/quickshell/ryoku/vendor/brain-shell/src/popups/PopupLayer.qml"
system_popup="config/quickshell/ryoku/vendor/brain-shell/src/popups/SystemMenuPopup.qml"
settings_popup="config/quickshell/ryoku/vendor/brain-shell/src/popups/SettingsMenuPopup.qml"
dotfiles_popup="config/quickshell/ryoku/vendor/brain-shell/src/popups/DotfilesHubPopup.qml"
ipc="bin/ryoku-ipc"
bindings="default/hypr/bindings/utilities.conf"

for path in "$shell" "$popups" "$topbar" "$control_panel" "$popup_dismiss" "$layer" "$system_popup" "$settings_popup" "$dotfiles_popup" "$ipc" "$bindings"; do
  [[ -f $path ]] || fail "$path missing"
done

grep -q 'function toggleSystemMenu' "$shell" \
  || fail "shell IPC should expose toggleSystemMenu"
grep -q 'function toggleSettingsMenu' "$shell" \
  || fail "shell IPC should expose toggleSettingsMenu"
grep -q 'function toggleDotfiles' "$shell" \
  || fail "shell IPC should expose toggleDotfiles"
grep -q 'BS.Popups.systemMenuOpen = opening' "$shell" \
  || fail "toggleSystemMenu should open system menu after closing other popups"
grep -q 'BS.Popups.settingsMenuOpen = opening' "$shell" \
  || fail "toggleSettingsMenu should open settings menu after closing other popups"
grep -q 'BS.Popups.dotfilesOpen = opening' "$shell" \
  || fail "toggleDotfiles should open the dotfiles hub after closing other popups"

grep -q 'property bool systemMenuOpen' "$popups" \
  || fail "Popups should track systemMenuOpen"
grep -q 'property bool settingsMenuOpen' "$popups" \
  || fail "Popups should track settingsMenuOpen"
grep -q 'property bool dotfilesOpen' "$popups" \
  || fail "Popups should track dotfilesOpen"
grep -q 'property bool systemMenuVisible' "$popups" \
  || fail "Popups should track system menu visual presence"
grep -q 'property bool settingsMenuVisible' "$popups" \
  || fail "Popups should track settings menu visual presence"
grep -q 'property bool dotfilesVisible' "$popups" \
  || fail "Popups should track dotfiles hub visual presence"
! awk '/readonly property bool anyOpen:/,/function closeAll/' "$popups" | grep -q 'systemMenuOpen' \
  || fail "PopupDismiss should not be responsible for system menu outside-click handling"
! awk '/readonly property bool anyOpen:/,/function closeAll/' "$popups" | grep -q 'settingsMenuOpen' \
  || fail "PopupDismiss should not be responsible for settings menu outside-click handling"
grep -q 'systemMenuOpen     = false' "$popups" \
  || fail "closeAll should close the system menu"
grep -q 'settingsMenuOpen   = false' "$popups" \
  || fail "closeAll should close the settings menu"
grep -q 'dotfilesOpen       = false' "$popups" \
  || fail "closeAll should close the dotfiles hub"

grep -q 'Popups.dashboardVisible || Popups.launcherVisible || Popups.systemMenuVisible || Popups.settingsMenuVisible' "$topbar" \
  || fail "TopBar should stay on overlay while topbar menus animate"
grep -q 'Popups.systemMenuOpen' "$control_panel" \
  || fail "left topbar control should toggle the new system menu"
grep -q 'SystemMenuPopup' "$layer" \
  || fail "PopupLayer should instantiate SystemMenuPopup"
grep -q 'SettingsMenuPopup' "$layer" \
  || fail "PopupLayer should instantiate SettingsMenuPopup"
grep -q 'DotfilesHubPopup' "$layer" \
  || fail "PopupLayer should instantiate DotfilesHubPopup"

grep -q 'ListModel {' "$system_popup" \
  || fail "SystemMenuPopup should use stable ListModel roles for visible labels"
grep -q 'Binding { target: Popups; property: "systemMenuVisible"' "$system_popup" \
  || fail "SystemMenuPopup should expose visual presence"
grep -Eq 'readonly property int menuWidth:[[:space:]]+306' "$system_popup" \
  || fail "SystemMenuPopup should stay compact"
grep -Eq 'readonly property int menuHeight:[[:space:]]+270' "$system_popup" \
  || fail "SystemMenuPopup should stay slim"
grep -q 'width: root.fullCardWidth' "$system_popup" \
  || fail "SystemMenuPopup should not expand into an oversized drawer"
grep -q 'anchors.left: parent.left' "$system_popup" \
  || fail "SystemMenuPopup should open from the left topbar"
grep -q 'attachedEdge: "top"' "$system_popup" \
  || fail "SystemMenuPopup should attach to the topbar"
grep -q 'ryoku-launch-screensaver' "$system_popup" \
  || fail "SystemMenuPopup should keep the screensaver action"
grep -q 'ryoku-lock-screen' "$system_popup" \
  || fail "SystemMenuPopup should keep the lock action"
grep -q 'systemctl", "suspend"' "$system_popup" \
  || fail "SystemMenuPopup should keep the suspend action"
grep -q 'systemctl", "hibernate"' "$system_popup" \
  || fail "SystemMenuPopup should keep the hibernate action"
grep -q 'ryoku-launch-floating-terminal-with-presentation", "ryoku-update"' "$system_popup" \
  || fail "SystemMenuPopup should expose the update action"
grep -q 'ryoku-snapshot", "create"' "$system_popup" \
  || fail "SystemMenuPopup should expose the snapshot action"
grep -q 'showConfirm' "$system_popup" \
  || fail "SystemMenuPopup should confirm destructive power actions"
grep -q 'onClicked: Popups.closeAll()' "$system_popup" \
  || fail "SystemMenuPopup should own outside-click dismissal"
grep -q 'required property string label' "$system_popup" \
  || fail "SystemMenuPopup delegates should bind labels from stable ListModel roles"
grep -q 'iconBadge' "$system_popup" \
  || fail "SystemMenuPopup should render styled icon badges"

grep -q 'ListModel {' "$settings_popup" \
  || fail "SettingsMenuPopup should use stable ListModel roles for visible labels"
grep -q 'Binding { target: Popups; property: "settingsMenuVisible"' "$settings_popup" \
  || fail "SettingsMenuPopup should expose visual presence"
grep -Eq 'readonly property int menuWidth:[[:space:]]+300' "$settings_popup" \
  || fail "SettingsMenuPopup should stay compact"
grep -Eq 'readonly property int menuHeight:[[:space:]]+184' "$settings_popup" \
  || fail "SettingsMenuPopup should stay slim"
grep -q 'width: root.fullCardWidth' "$settings_popup" \
  || fail "SettingsMenuPopup should not expand into an oversized drawer"
grep -q 'anchors.right: parent.right' "$settings_popup" \
  || fail "SettingsMenuPopup should open from the right topbar pill"
grep -q 'attachedEdge: "top"' "$settings_popup" \
  || fail "SettingsMenuPopup should attach to the topbar"
grep -q 'Popups.dotfilesOpen = true' "$settings_popup" \
  || fail "SettingsMenuPopup should open the dotfiles hub"
grep -q 'ryoku-launch-audio' "$settings_popup" \
  || fail "SettingsMenuPopup should expose audio controls"
grep -q 'ryoku-launch-wifi' "$settings_popup" \
  || fail "SettingsMenuPopup should expose Wi-Fi controls"
grep -q 'ryoku-launch-bluetooth' "$settings_popup" \
  || fail "SettingsMenuPopup should expose Bluetooth controls"
grep -q 'ryoku-launch-tui", "btop"' "$settings_popup" \
  || fail "SettingsMenuPopup should expose activity"
! grep -q 'action: "apps"' "$settings_popup" \
  || fail "SettingsMenuPopup should not expose the launcher"
! grep -q 'action: "wallpaper"' "$settings_popup" \
  || fail "SettingsMenuPopup should not expose wallpapers"
! grep -q 'action: "theme"' "$settings_popup" \
  || fail "SettingsMenuPopup should not expose themes"
! grep -q 'action: "update"' "$settings_popup" \
  || fail "SettingsMenuPopup should not expose update"
! grep -q 'action: "system"' "$settings_popup" \
  || fail "SettingsMenuPopup should not expose power"
grep -q 'onClicked: Popups.closeAll()' "$settings_popup" \
  || fail "SettingsMenuPopup should own outside-click dismissal"
grep -q 'required property string label' "$settings_popup" \
  || fail "SettingsMenuPopup delegates should bind labels from stable ListModel roles"
grep -q 'iconBadge' "$settings_popup" \
  || fail "SettingsMenuPopup should render styled icon badges"
! grep -q 'modelData && modelData.label' "$settings_popup" \
  || fail "SettingsMenuPopup should not render blank modelData fallbacks"

grep -q 'Binding { target: Popups; property: "dotfilesVisible"' "$dotfiles_popup" \
  || fail "DotfilesHubPopup should expose visual presence"
grep -q 'WlrLayershell.layer: WlrLayer.Overlay' "$dotfiles_popup" \
  || fail "DotfilesHubPopup should use a centered overlay layer"
grep -q 'id: hyprFiles' "$dotfiles_popup" \
  || fail "DotfilesHubPopup should group Hyprland files"
grep -q 'id: categoryRail' "$dotfiles_popup" \
  || fail "DotfilesHubPopup should provide a category rail"
grep -q 'id: fileList' "$dotfiles_popup" \
  || fail "DotfilesHubPopup should render files in a dedicated list pane"
grep -q 'Dotfile Control' "$dotfiles_popup" \
  || fail "DotfilesHubPopup should use a branded hero header"
grep -q 'Edit these files carefully' "$dotfiles_popup" \
  || fail "DotfilesHubPopup should show the config risk notice"
grep -q '.config/hypr/hyprland.conf' "$dotfiles_popup" \
  || fail "DotfilesHubPopup should include Hyprland main config"
grep -q '.config/hypr/monitors.conf' "$dotfiles_popup" \
  || fail "DotfilesHubPopup should include monitor config"
grep -q '.config/quickshell/ryoku/config/Config.qml' "$dotfiles_popup" \
  || fail "DotfilesHubPopup should include Quickshell config"
grep -q '.config/ghostty/config' "$dotfiles_popup" \
  || fail "DotfilesHubPopup should include terminal config"
grep -q 'ryoku-launch-editor' "$dotfiles_popup" \
  || fail "DotfilesHubPopup should open dotfiles in the configured editor"
grep -q 'Keys.onEscapePressed: Popups.closeAll()' "$dotfiles_popup" \
  || fail "DotfilesHubPopup should close with Escape"
grep -q 'onClicked: Popups.closeAll()' "$dotfiles_popup" \
  || fail "DotfilesHubPopup should close on outside click"
! grep -q 'height: parent.height - y' "$dotfiles_popup" \
  || fail "DotfilesHubPopup should not size scroll content from y"

"$ipc" --help | grep -q "ryoku-ipc shell toggle system-menu" \
  || fail "ryoku-ipc help should document system-menu toggle"
"$ipc" --help | grep -q "ryoku-ipc shell toggle settings-menu" \
  || fail "ryoku-ipc help should document settings-menu toggle"
"$ipc" --help | grep -q "ryoku-ipc shell toggle dotfiles" \
  || fail "ryoku-ipc help should document dotfiles toggle"
"$ipc" shell command system-menu | grep -q 'qs -c ryoku ipc call popups toggleSystemMenu' \
  || fail "ryoku-ipc should print the system-menu IPC command"
"$ipc" shell command settings-menu | grep -q 'qs -c ryoku ipc call popups toggleSettingsMenu' \
  || fail "ryoku-ipc should print the settings-menu IPC command"
"$ipc" shell command dotfiles | grep -q 'qs -c ryoku ipc call popups toggleDotfiles' \
  || fail "ryoku-ipc should print the dotfiles IPC command"

grep -q 'bindd = SUPER, ESCAPE, System menu, exec, ryoku-ipc shell toggle system-menu' "$bindings" \
  || fail "SUPER+ESC should open the Quickshell system menu"
grep -q 'bindld = , XF86PowerOff, Power menu, exec, ryoku-ipc shell toggle system-menu' "$bindings" \
  || fail "hardware power key should open the Quickshell system menu"
grep -q 'bindd = SUPER CTRL ALT, SPACE, Ryoku settings menu, exec, ryoku-ipc shell toggle settings-menu' "$bindings" \
  || fail "SUPER+CTRL+ALT+SPACE should open the Quickshell settings menu"
grep -q 'bindd = SUPER ALT, SPACE, Ryoku menu, exec, ryoku-ipc shell toggle settings-menu' "$bindings" \
  || fail "SUPER+ALT+SPACE should no longer open the old Omarchy picker"
! grep -q 'bindd = SUPER, ESCAPE, System menu, exec, ryoku-menu system' "$bindings" \
  || fail "SUPER+ESC should no longer open the old Omarchy picker"
! grep -q 'bindld = , XF86PowerOff, Power menu, exec, ryoku-menu system' "$bindings" \
  || fail "hardware power key should no longer open the old Omarchy picker"

grep -q 'Popups.launcherOpen || Popups.wallpaperOpen ? WlrKeyboardFocus.None : WlrKeyboardFocus.OnDemand' "$popup_dismiss" \
  || fail "PopupDismiss keyboard focus behavior should remain searchable-popup safe"

pass "quickshell topbar settings menus"
