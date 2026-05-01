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

assert_file_has() {
  local needle="$1"
  local message="$2"

  grep -Fq "$needle" "$settings_popup" || fail "$message"
}

model_block() {
  local model_id="$1"

  awk -v model_id="$model_id" '
    $0 ~ "id: " model_id { printing = 1 }
    printing { print }
    printing && /^  }$/ { exit }
  ' "$settings_popup"
}

assert_model_action() {
  local model_id="$1"
  local label="$2"
  local action="$3"
  local block

  block="$(model_block "$model_id")"
  [[ -n $block ]] || fail "SettingsMenuPopup should define $model_id"
  grep -F "label: \"$label\"" <<< "$block" | grep -Fq "action: \"$action\"" \
    || fail "SettingsMenuPopup $model_id should map $label to $action"
}

assert_model_lacks_label() {
  local model_id="$1"
  local label="$2"
  local block

  block="$(model_block "$model_id")"
  [[ -n $block ]] || fail "SettingsMenuPopup should define $model_id"
  ! grep -Fq "label: \"$label\"" <<< "$block" \
    || fail "SettingsMenuPopup $model_id should not expose label: $label"
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
grep -q 'function toggleLegacySettingsMenu' "$shell" \
  || fail "shell IPC should expose toggleLegacySettingsMenu"
grep -q 'function toggleDotfiles' "$shell" \
  || fail "shell IPC should expose toggleDotfiles"
grep -q 'BS.Popups.systemMenuOpen = opening' "$shell" \
  || fail "toggleSystemMenu should open system menu after closing other popups"
grep -q 'BS.Popups.legacySettingsMenuOpen = opening' "$shell" \
  || fail "toggleLegacySettingsMenu should open the legacy settings menu after closing other popups"
grep -q 'BS.Popups.dotfilesOpen = opening' "$shell" \
  || fail "toggleDotfiles should open the dotfiles hub after closing other popups"

grep -q 'property bool systemMenuOpen' "$popups" \
  || fail "Popups should track systemMenuOpen"
grep -q 'property bool legacySettingsMenuOpen' "$popups" \
  || fail "Brain Shell settings popup should be guarded by legacy settings-menu state"
grep -q 'property string legacySettingsMenuRequestedPage' "$popups" \
  || fail "Popups should track the requested legacy settings menu page"
grep -q 'property string legacySettingsMenuRequestedSubpage' "$popups" \
  || fail "Popups should track the requested legacy settings menu subpage"
grep -q 'function requestLegacySettingsMenuPage(page, subpage)' "$popups" \
  || fail "Popups should expose a legacy settings menu page request helper"
grep -q 'property bool dotfilesOpen' "$popups" \
  || fail "Popups should track dotfilesOpen"
grep -q 'property bool systemMenuVisible' "$popups" \
  || fail "Popups should track system menu visual presence"
grep -q 'property bool legacySettingsMenuVisible' "$popups" \
  || fail "Popups should track legacy settings menu visual presence"
grep -q 'property bool dotfilesVisible' "$popups" \
  || fail "Popups should track dotfiles hub visual presence"
! awk '/readonly property bool anyOpen:/,/function closeAll/' "$popups" | grep -q 'systemMenuOpen' \
  || fail "PopupDismiss should not be responsible for system menu outside-click handling"
! awk '/readonly property bool anyOpen:/,/function closeAll/' "$popups" | grep -q 'legacySettingsMenuOpen' \
  || fail "PopupDismiss should not be responsible for legacy settings menu outside-click handling"
grep -q 'systemMenuOpen     = false' "$popups" \
  || fail "closeAll should close the system menu"
grep -q 'legacySettingsMenuOpen = false' "$popups" \
  || fail "closeAll should close the legacy settings menu"
grep -q 'dotfilesOpen       = false' "$popups" \
  || fail "closeAll should close the dotfiles hub"

grep -q 'Popups.dashboardVisible || Popups.launcherVisible || Popups.systemMenuVisible || Popups.legacySettingsMenuVisible' "$topbar" \
  || fail "TopBar should stay on overlay while topbar menus animate"
grep -q 'Popups.systemMenuOpen' "$control_panel" \
  || fail "left topbar control should toggle the new system menu"
grep -q 'SystemMenuPopup' "$layer" \
  || fail "PopupLayer should instantiate SystemMenuPopup"
grep -q 'legacySettingsMenuOpen' "$layer" \
  || fail "Legacy settings popup should be mounted through the legacy popup state"
grep -q 'DotfilesHubPopup' "$layer" \
  || fail "PopupLayer should instantiate DotfilesHubPopup"

grep -q 'ListModel {' "$system_popup" \
  || fail "SystemMenuPopup should use stable ListModel roles for visible labels"
grep -q 'Binding { target: Popups; property: "systemMenuVisible"' "$system_popup" \
  || fail "SystemMenuPopup should expose visual presence"
grep -Eq 'readonly property int menuWidth:[[:space:]]+292' "$system_popup" \
  || fail "SystemMenuPopup should stay compact"
grep -Eq 'readonly property int menuHeight:[[:space:]]+232' "$system_popup" \
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
grep -q 'id: headerRule' "$system_popup" \
  || fail "SystemMenuPopup should render a restrained header rule"
! grep -q 'iconBadge' "$system_popup" \
  || fail "SystemMenuPopup should avoid oversized icon badges"

grep -q 'ListModel {' "$settings_popup" \
  || fail "SettingsMenuPopup should use stable ListModel roles for visible labels"
grep -q 'Binding { target: Popups; property: "legacySettingsMenuVisible"' "$settings_popup" \
  || fail "SettingsMenuPopup should expose legacy visual presence"
grep -q 'property bool windowVisible: false' "$settings_popup" \
  || fail "SettingsMenuPopup should preserve the popup window through close animation"
grep -q 'property real openProgress: Popups.legacySettingsMenuOpen ? 1 : 0' "$settings_popup" \
  || fail "SettingsMenuPopup should animate from legacy popup open state"
grep -q 'id: closeTimer' "$settings_popup" \
  || fail "SettingsMenuPopup should delay window unmapping until close animation ends"
grep -q 'onTriggered: root.windowVisible = false' "$settings_popup" \
  || fail "SettingsMenuPopup close timer should unmap the popup window"
grep -Eq 'readonly property int menuWidth:[[:space:]]+456' "$settings_popup" \
  || fail "SettingsMenuPopup should use the control center width"
grep -Eq 'readonly property int menuHeight:[[:space:]]+520' "$settings_popup" \
  || fail "SettingsMenuPopup should use the control center height"
grep -q 'anchors.right: parent.right' "$settings_popup" \
  || fail "SettingsMenuPopup should open from the right topbar pill"
grep -q 'attachedEdge: "top"' "$settings_popup" \
  || fail "SettingsMenuPopup should attach to the topbar"
grep -q 'property string currentPage: "home"' "$settings_popup" \
  || fail "SettingsMenuPopup should default to the home page"
grep -q 'property string currentSubpage: ""' "$settings_popup" \
  || fail "SettingsMenuPopup should default to no subpage"
grep -q 'function openPage(page, subpage)' "$settings_popup" \
  || fail "SettingsMenuPopup should expose route page navigation"
grep -q 'function openRequestedRoute()' "$settings_popup" \
  || fail "SettingsMenuPopup should consume requested routes"
grep -q 'root.openRequestedRoute()' "$settings_popup" \
  || fail "SettingsMenuPopup should apply requested routes when opening"
grep -q 'Popups.legacySettingsMenuRequestedPage' "$settings_popup" \
  || fail "SettingsMenuPopup should read requested legacy page state"
grep -q 'Popups.legacySettingsMenuRequestedSubpage' "$settings_popup" \
  || fail "SettingsMenuPopup should read requested legacy subpage state"
grep -q 'id: quickControlsModel' "$settings_popup" \
  || fail "SettingsMenuPopup should define quick controls for the home view"
grep -q 'id: nativeSectionsModel' "$settings_popup" \
  || fail "SettingsMenuPopup should define native sections for the home view"
page_stack_block="$(awk '
  /id: pageStack/ { printing = 1 }
  printing { print }
  printing && /Column \{/ { exit }
' "$settings_popup")"
[[ -n $page_stack_block ]] \
  || fail "SettingsMenuPopup should render pages in a stable page stack"
grep -q 'width: parent.width' <<< "$page_stack_block" \
  || fail "SettingsMenuPopup page stack should use stable parent width"
grep -q 'height: parent.height - header.height - 10' <<< "$page_stack_block" \
  || fail "SettingsMenuPopup page stack should use stable parent-relative height"
grep -q 'clip: true' <<< "$page_stack_block" \
  || fail "SettingsMenuPopup page stack should clip transitioning pages"
grep -q 'text: "Control center"' "$settings_popup" \
  || fail "SettingsMenuPopup home view should title the control center"
grep -q 'function pageModel()' "$settings_popup" \
  || fail "SettingsMenuPopup should expose the route-selected page model"
grep -q 'model: root.pageModel()' "$settings_popup" \
  || fail "SettingsMenuPopup should render route-selected actions"
grep -q 'function runAction(action)' "$settings_popup" \
  || fail "SettingsMenuPopup should route leaf actions"
grep -q 'function openAppearance(mode)' "$settings_popup" \
  || fail "SettingsMenuPopup should open native appearance modes"
grep -q 'currentPage === "share"' "$settings_popup" \
  || fail "SettingsMenuPopup should render a share route"
grep -q 'currentSubpage === "hardware"' "$settings_popup" \
  || fail "SettingsMenuPopup should render the hardware setup route"
grep -q 'currentSubpage === "remove-javascript") return removeJavascriptActions' "$settings_popup" \
  || fail "SettingsMenuPopup should render remove JavaScript actions on the remove JavaScript route"
grep -q 'currentSubpage === "remove-php") return removePhpActions' "$settings_popup" \
  || fail "SettingsMenuPopup should render remove PHP actions on the remove PHP route"
grep -q 'currentSubpage === "remove-elixir") return removeElixirActions' "$settings_popup" \
  || fail "SettingsMenuPopup should render remove Elixir actions on the remove Elixir route"
grep -q 'width: root.fullCardWidth' "$settings_popup" \
  || fail "SettingsMenuPopup should size from the topbar notch geometry"
grep -q 'Popups.dotfilesOpen = true' "$settings_popup" \
  || fail "SettingsMenuPopup should open the dotfiles hub"
for label in "Wi-Fi" "Bluetooth" "Airplane Mode" "Hotspot" "Night Light" "Focus Mode" "Do Not Disturb" "Filter"; do
  grep -q "label: \"$label\"" "$settings_popup" \
    || fail "SettingsMenuPopup should expose quick control label: $label"
done
grep -q 'function wifiStatusText()' "$settings_popup" \
  || fail "SettingsMenuPopup should expose Wi-Fi status text"
grep -q 'function bluetoothStatusText()' "$settings_popup" \
  || fail "SettingsMenuPopup should expose Bluetooth status text"
grep -q 'function quickActive(action)' "$settings_popup" \
  || fail "SettingsMenuPopup should calculate active quick control state"
grep -q 'function runQuickAction(action)' "$settings_popup" \
  || fail "SettingsMenuPopup should route quick control actions"
grep -q 'function pollQuickControls()' "$settings_popup" \
  || fail "SettingsMenuPopup should poll quick control state"
grep -q 'property bool active: root.quickActive(action)' "$settings_popup" \
  || fail "SettingsMenuPopup quick tiles should bind active state"
grep -q 'property string status:' "$settings_popup" \
  || fail "SettingsMenuPopup quick tiles should expose status text"
grep -q 'onClicked: root.runQuickAction(action)' "$settings_popup" \
  || fail "SettingsMenuPopup quick tiles should run quick actions on click"
grep -q 'root.pollQuickControls()' "$settings_popup" \
  || fail "SettingsMenuPopup should poll quick controls when opened or on timer"
grep -q 'nmcli radio wifi' "$settings_popup" \
  || fail "SettingsMenuPopup should read and toggle Wi-Fi radio state"
grep -q 'ACTIVE,SSID' "$settings_popup" \
  || fail "SettingsMenuPopup should read the active Wi-Fi SSID"
grep -q 'bluetoothctl show' "$settings_popup" \
  || fail "SettingsMenuPopup should read Bluetooth powered state"
grep -q 'bluetoothctl devices Connected' "$settings_popup" \
  || fail "SettingsMenuPopup should read connected Bluetooth device state"
grep -q 'bluetoothctl power' "$settings_popup" \
  || fail "SettingsMenuPopup should toggle Bluetooth power"
grep -q 'Soft blocked: no' "$settings_popup" \
  || fail "SettingsMenuPopup should read rfkill soft-block state"
grep -q 'rfkill block all' "$settings_popup" \
  || fail "SettingsMenuPopup should enable airplane mode with rfkill"
grep -q 'rfkill unblock all' "$settings_popup" \
  || fail "SettingsMenuPopup should disable airplane mode with rfkill"
grep -q 'BrainShellHotspot' "$settings_popup" \
  || fail "SettingsMenuPopup should manage the BrainShell hotspot connection"
grep -q 'nmcli device wifi hotspot' "$settings_popup" \
  || fail "SettingsMenuPopup should start hotspots with nmcli"
grep -q 'nmcli device disconnect' "$settings_popup" \
  || fail "SettingsMenuPopup should stop hotspots by disconnecting the Wi-Fi device"
grep -q 'pgrep -x hyprsunset' "$settings_popup" \
  || fail "SettingsMenuPopup should read Night Light state"
grep -q 'hyprsunset' "$settings_popup" \
  || fail "SettingsMenuPopup should control Night Light with hyprsunset"
grep -q 'pkill hyprsunset' "$settings_popup" \
  || fail "SettingsMenuPopup should stop Night Light with pkill"
grep -q 'hyprctl getoption general:gaps_in' "$settings_popup" \
  || fail "SettingsMenuPopup should read Focus Mode inner gaps"
grep -q 'hyprctl getoption general:gaps_out' "$settings_popup" \
  || fail "SettingsMenuPopup should read Focus Mode outer gaps"
grep -q 'hyprctl keyword general:gaps_in' "$settings_popup" \
  || fail "SettingsMenuPopup should apply Focus Mode gaps"
grep -q 'hyprctl keyword general:gaps_out' "$settings_popup" \
  || fail "SettingsMenuPopup should apply and restore Focus Mode outer gaps"
grep -q 'focusOwnedByControlCenter' "$settings_popup" \
  || fail "SettingsMenuPopup should track whether it owns Focus Mode"
grep -q 'focusLabel' "$settings_popup" \
  || fail "SettingsMenuPopup should expose Focus Mode external status"
grep -q '!root.focusOwnedByControlCenter' "$settings_popup" \
  || fail "SettingsMenuPopup should not restore external Focus Mode gaps"
grep -q 'case "focus-toggle": return root.focusLabel' "$settings_popup" \
  || fail "SettingsMenuPopup should surface Focus Mode external status"
grep -q 'ShellState.wifiOn' "$settings_popup" \
  || fail "SettingsMenuPopup should mirror Wi-Fi state to ShellState"
grep -q 'ShellState.btPowered' "$settings_popup" \
  || fail "SettingsMenuPopup should mirror Bluetooth power to ShellState"
grep -q 'ShellState.btConnected' "$settings_popup" \
  || fail "SettingsMenuPopup should mirror Bluetooth connection state to ShellState"
grep -q 'ShellState.hotspot' "$settings_popup" \
  || fail "SettingsMenuPopup should mirror hotspot state to ShellState"
grep -q 'hotspotOwnedByControlCenter' "$settings_popup" \
  || fail "SettingsMenuPopup should track whether it owns Hotspot"
grep -q 'hotspotConfigPath' "$settings_popup" \
  || fail "SettingsMenuPopup should load Hotspot config from a stable path"
grep -q 'hotspot.json' "$settings_popup" \
  || fail "SettingsMenuPopup should use the existing Hotspot JSON config"
grep -q 'function shellQuote(value)' "$settings_popup" \
  || fail "SettingsMenuPopup should shell-quote dynamic Hotspot values"
grep -q 'root.shellQuote(root.hotspotSSID)' "$settings_popup" \
  || fail "SettingsMenuPopup should quote Hotspot SSID in shell commands"
grep -q 'root.shellQuote(root.hotspotPassword)' "$settings_popup" \
  || fail "SettingsMenuPopup should quote Hotspot password in shell commands"
grep -q '!root.hotspotOwnedByControlCenter' "$settings_popup" \
  || fail "SettingsMenuPopup should not stop externally owned Hotspot sessions"
grep -q 'ShellState.dnd = !ShellState.dnd' "$settings_popup" \
  || fail "SettingsMenuPopup should toggle Do Not Disturb directly"
grep -q 'hyprshade", "ls"' "$settings_popup" \
  || fail "SettingsMenuPopup should list filters with hyprshade"
grep -q 'hyprshade", "on"' "$settings_popup" \
  || fail "SettingsMenuPopup should enable filters with hyprshade"
grep -q 'hyprshade", "off"' "$settings_popup" \
  || fail "SettingsMenuPopup should disable filters with hyprshade"
! grep -q 'brightnessctl' "$settings_popup" \
  || fail "SettingsMenuPopup should not own brightness controls"
! grep -q 'CaffeineService' "$settings_popup" \
  || fail "SettingsMenuPopup should not own Caffeine controls"
! grep -q 'ScreenRecService' "$settings_popup" \
  || fail "SettingsMenuPopup should not own screen capture controls"
for label in "Learn" "Share" "Style" "Setup" "Manage" "About"; do
  grep -q "label: \"$label\"" "$settings_popup" \
    || fail "SettingsMenuPopup should expose native section label: $label"
done
for label in "Keybindings" "Omarchy Manual" "Hyprland" "Arch" "Helix" "Bash"; do
  grep -q "label: \"$label\"" "$settings_popup" \
    || fail "SettingsMenuPopup should expose Learn label: $label"
done
for label in "Clipboard" "File" "Folder"; do
  grep -q "label: \"$label\"" "$settings_popup" \
    || fail "SettingsMenuPopup should expose Share label: $label"
done
for label in "Theme" "Font" "Background" "Hyprland look and feel" "Screensaver text" "About text"; do
  grep -q "label: \"$label\"" "$settings_popup" \
    || fail "SettingsMenuPopup should expose Style label: $label"
done
for label in "Audio" "Wi-Fi setup" "Bluetooth setup" "Power Profile" "System Sleep" "Monitors" "DNS" "Security" "Config" "Hardware"; do
  grep -q "label: \"$label\"" "$settings_popup" \
    || fail "SettingsMenuPopup should expose Setup label: $label"
done
for label in "Fingerprint" "Fido2" "Defaults" "Hyprland config" "Hypridle" "Hyprlock" "Hyprsunset" "Swayosd" "Launcher" "Waybar" "XCompose" "Laptop Display"; do
  grep -q "label: \"$label\"" "$settings_popup" \
    || fail "SettingsMenuPopup should expose Setup child label: $label"
done
for label in "Package" "AUR" "Web App" "TUI" "Service" "Style pack" "Development" "Editor" "Terminal" "AI" "Windows" "Gaming"; do
  grep -q "label: \"$label\"" "$settings_popup" \
    || fail "SettingsMenuPopup should expose Manage install label: $label"
done
for label in "Package" "Web App" "TUI" "Development" "Preinstalls" "Dictation" "Theme" "Windows" "Fingerprint" "Fido2"; do
  grep -q "label: \"$label\"" "$settings_popup" \
    || fail "SettingsMenuPopup should expose Manage remove label: $label"
done
for label in "Ryoku" "Channel" "Config refresh" "Extra Themes" "Process" "Hardware restart" "Firmware" "Password" "Timezone" "Time" "Rollback to Omarchy"; do
  grep -q "label: \"$label\"" "$settings_popup" \
    || fail "SettingsMenuPopup should expose Manage maintain label: $label"
done

while IFS='|' read -r model label action; do
  [[ -n $model ]] || continue
  assert_model_action "$model" "$label" "$action"
done <<'EOF'
learnActions|Keybindings|learn-keybindings
learnActions|Omarchy Manual|learn-omarchy
learnActions|Hyprland|learn-hyprland
learnActions|Arch|learn-arch
learnActions|Helix|learn-helix
learnActions|Bash|learn-bash
shareActions|Clipboard|share-clipboard
shareActions|File|share-file
shareActions|Folder|share-folder
styleActions|Theme|style-theme
styleActions|Font|style-font
styleActions|Background|style-background
styleActions|Hyprland look and feel|edit-hypr-look
styleActions|Screensaver text|edit-screensaver-text
styleActions|About text|edit-about-text
setupActions|Audio|setup-audio
setupActions|Wi-Fi setup|setup-wifi
setupActions|Bluetooth setup|setup-bluetooth
setupActions|Power Profile|page-power-profile
setupActions|System Sleep|page-system-sleep
setupActions|Monitors|edit-monitors
setupActions|DNS|setup-dns
setupActions|Security|page-security
setupActions|Config|page-config
setupActions|Hardware|page-hardware
setupPowerProfileActions|Performance|power-performance
setupPowerProfileActions|Balanced|power-balanced
setupPowerProfileActions|Power Saver|power-saver
setupSystemSleepActions|Suspend toggle|sleep-suspend-toggle
setupSystemSleepActions|Hibernate setup|sleep-hibernate-setup
setupSystemSleepActions|Hibernate removal|sleep-hibernate-remove
setupSecurityActions|Fingerprint|setup-fingerprint
setupSecurityActions|Fido2|setup-fido2
setupConfigActions|Dotfiles Hub|config-dotfiles
setupConfigActions|Defaults|edit-defaults
setupConfigActions|Hyprland config|edit-hyprland
setupConfigActions|Hypridle|edit-hypridle
setupConfigActions|Hyprlock|edit-hyprlock
setupConfigActions|Hyprsunset|edit-hyprsunset
setupConfigActions|Swayosd|edit-swayosd
setupConfigActions|Launcher|edit-launcher
setupConfigActions|Waybar|edit-waybar
setupConfigActions|XCompose|edit-xcompose
setupHardwareActions|Laptop Display|hardware-laptop-display
setupHardwareActions|Hybrid GPU|hardware-hybrid-gpu
setupHardwareActions|Touchpad|hardware-touchpad
manageInstallActions|Package|install-package
manageInstallActions|AUR|install-aur
manageInstallActions|Web App|install-webapp
manageInstallActions|TUI|install-tui
manageInstallActions|Service|page-install-service
manageInstallActions|Style pack|page-install-style
manageInstallActions|Development|page-install-development
manageInstallActions|Editor|page-install-editor
manageInstallActions|Terminal|page-install-terminal
manageInstallActions|AI|page-install-ai
manageInstallActions|Windows|install-windows
manageInstallActions|Gaming|page-install-gaming
manageRemoveActions|Package|remove-package
manageRemoveActions|Web App|remove-webapp
manageRemoveActions|TUI|remove-tui
manageRemoveActions|Development|page-remove-development
manageRemoveActions|Preinstalls|remove-preinstalls
manageRemoveActions|Dictation|remove-dictation
manageRemoveActions|Theme|remove-theme
manageRemoveActions|Windows|remove-windows
manageRemoveActions|Fingerprint|remove-fingerprint
manageRemoveActions|Fido2|remove-fido2
manageMaintainActions|Ryoku|maintain-ryoku
manageMaintainActions|Channel|page-maintain-channel
manageMaintainActions|Config refresh|page-maintain-config
manageMaintainActions|Extra Themes|maintain-extra-themes
manageMaintainActions|Process|page-maintain-process
manageMaintainActions|Hardware restart|page-maintain-hardware
manageMaintainActions|Firmware|maintain-firmware
manageMaintainActions|Password|page-maintain-password
manageMaintainActions|Timezone|maintain-timezone
manageMaintainActions|Time|maintain-time
manageMaintainActions|Rollback to Omarchy|maintain-rollback
aboutActions|Launch About|about-launch
aboutActions|Open about text|about-open-text
EOF

for label in "Theme removal" "Fingerprint removal" "Fido2 removal"; do
  assert_model_lacks_label "manageRemoveActions" "$label"
done

while IFS='|' read -r model label action; do
  [[ -n $model ]] || continue
  assert_model_action "$model" "$label" "$action"
done <<'EOF'
installServiceActions|Dropbox|install-service-dropbox
installServiceActions|Tailscale|install-service-tailscale
installServiceActions|NordVPN|install-service-nordvpn
installServiceActions|ONCE|install-service-once
installServiceActions|Bitwarden|install-service-bitwarden
installServiceActions|Chromium Account|install-service-chromium
installStyleActions|Theme|install-style-theme
installStyleActions|Background|install-style-background
installStyleActions|Font|page-install-font
installFontActions|Cascadia Mono|font-cascadia
installFontActions|Meslo LG Mono|font-meslo
installFontActions|Fira Code|font-fira
installFontActions|Victor Code|font-victor
installFontActions|Bitstream Vera Mono|font-bitstream
installFontActions|Iosevka|font-iosevka
developmentActions|Ruby on Rails|install-dev-ruby
developmentActions|Docker DB|install-dev-docker-dbs
developmentActions|JavaScript|page-install-javascript
developmentActions|Go|install-dev-go
developmentActions|PHP|page-install-php
developmentActions|Python|install-dev-python
developmentActions|Elixir|page-install-elixir
developmentActions|Zig|install-dev-zig
developmentActions|Rust|install-dev-rust
developmentActions|Java|install-dev-java
developmentActions|.NET|install-dev-dotnet
developmentActions|OCaml|install-dev-ocaml
developmentActions|Clojure|install-dev-clojure
developmentActions|Scala|install-dev-scala
javascriptActions|Node.js|install-dev-node
javascriptActions|Bun|install-dev-bun
javascriptActions|Deno|install-dev-deno
phpActions|PHP|install-dev-php
phpActions|Laravel|install-dev-laravel
phpActions|Symfony|install-dev-symfony
elixirActions|Elixir|install-dev-elixir
elixirActions|Phoenix|install-dev-phoenix
removeJavascriptActions|Node.js|remove-dev-node
removeJavascriptActions|Bun|remove-dev-bun
removeJavascriptActions|Deno|remove-dev-deno
removePhpActions|PHP|remove-dev-php
removePhpActions|Laravel|remove-dev-laravel
removePhpActions|Symfony|remove-dev-symfony
removeElixirActions|Elixir|remove-dev-elixir
removeElixirActions|Phoenix|remove-dev-phoenix
installEditorActions|VSCode|editor-vscode
installEditorActions|Cursor|editor-cursor
installEditorActions|Zed|editor-zed
installEditorActions|Sublime Text|editor-sublime
installEditorActions|Helix|editor-helix
installEditorActions|Emacs|editor-emacs
installTerminalActions|Alacritty|terminal-alacritty
installTerminalActions|Ghostty|terminal-ghostty
installTerminalActions|Kitty|terminal-kitty
installAiActions|Dictation|ai-dictation
installAiActions|LM Studio|ai-lmstudio
installAiActions|Ollama|ai-ollama
installAiActions|Crush|ai-crush
installGamingActions|Steam|gaming-steam
installGamingActions|NVIDIA GeForce NOW|gaming-geforce-now
installGamingActions|RetroArch|gaming-retroarch
installGamingActions|Minecraft|gaming-minecraft
installGamingActions|Xbox Controller|gaming-xbox
removeDevelopmentActions|Ruby on Rails|remove-dev-ruby
removeDevelopmentActions|JavaScript|page-remove-javascript
removeDevelopmentActions|Go|remove-dev-go
removeDevelopmentActions|PHP|page-remove-php
removeDevelopmentActions|Python|remove-dev-python
removeDevelopmentActions|Elixir|page-remove-elixir
removeDevelopmentActions|Zig|remove-dev-zig
removeDevelopmentActions|Rust|remove-dev-rust
removeDevelopmentActions|Java|remove-dev-java
removeDevelopmentActions|.NET|remove-dev-dotnet
removeDevelopmentActions|OCaml|remove-dev-ocaml
removeDevelopmentActions|Clojure|remove-dev-clojure
removeDevelopmentActions|Scala|remove-dev-scala
maintainChannelActions|Stable|channel-stable
maintainChannelActions|RC|channel-rc
maintainChannelActions|Edge|channel-edge
maintainChannelActions|Dev|channel-dev
maintainConfigActions|Hyprland|refresh-hyprland
maintainConfigActions|Hypridle|refresh-hypridle
maintainConfigActions|Hyprlock|refresh-hyprlock
maintainConfigActions|Hyprsunset|refresh-hyprsunset
maintainConfigActions|Plymouth|refresh-plymouth
maintainConfigActions|Swayosd|refresh-swayosd
maintainConfigActions|Tmux|refresh-tmux
maintainConfigActions|Launcher|refresh-launcher
maintainConfigActions|Waybar|refresh-waybar
maintainProcessActions|Hypridle|restart-hypridle
maintainProcessActions|Hyprsunset|restart-hyprsunset
maintainProcessActions|Mako|restart-mako
maintainProcessActions|Swayosd|restart-swayosd
maintainProcessActions|Launcher|restart-launcher
maintainProcessActions|Waybar|restart-waybar
maintainHardwareActions|Audio|restart-audio
maintainHardwareActions|Wi-Fi|restart-wifi
maintainHardwareActions|Bluetooth|restart-bluetooth
maintainHardwareActions|Trackpad|restart-trackpad
maintainPasswordActions|Drive Encryption|password-drive
maintainPasswordActions|User|password-user
EOF

for needle in \
  'root.runCommand(["ryoku-menu-keybindings"])' \
  'https://learn.omacom.io/2/the-omarchy-manual' \
  'https://wiki.hypr.land/' \
  'https://wiki.archlinux.org/title/Main_page' \
  'https://docs.helix-editor.com/' \
  'https://devhints.io/bash' \
  'root.openAppearance("theme")' \
  'root.openAppearance("font")' \
  'root.openAppearance("wallpaper")' \
  'root.editFile(root.homeDir + "/.config/hypr/looknfeel.conf")' \
  'root.editFile(root.ryokuConfigPath + "/branding/screensaver.txt")' \
  'root.editFile(root.ryokuConfigPath + "/branding/about.txt")' \
  'root.runCommand(["ryoku-launch-about"])' \
  'root.runCommand(["ryoku-launch-audio"])' \
  'root.runCommand(["ryoku-launch-wifi"])' \
  'root.runCommand(["ryoku-launch-bluetooth"])' \
  'root.runCommand(["powerprofilesctl", "set", "performance"])' \
  'root.runCommand(["powerprofilesctl", "set", "balanced"])' \
  'root.runCommand(["powerprofilesctl", "set", "power-saver"])' \
  'root.runTerminal("ryoku-toggle-suspend")' \
  'root.runTerminal("ryoku-hibernation-setup")' \
  'root.runTerminal("ryoku-hibernation-remove")' \
  'root.editFile(root.homeDir + "/.config/hypr/monitors.conf")' \
  'root.runTerminal("ryoku-setup-dns")' \
  'root.runTerminal("ryoku-setup-fingerprint")' \
  'root.runTerminal("ryoku-setup-fido2")' \
  'root.editFile(root.homeDir + "/.config/uwsm/default")' \
  'root.editFile(root.homeDir + "/.config/hypr/hyprland.conf")' \
  'root.editFile(root.homeDir + "/.config/hypr/hypridle.conf")' \
  'root.editFile(root.homeDir + "/.config/hypr/hyprlock.conf")' \
  'root.editFile(root.homeDir + "/.config/hypr/hyprsunset.conf")' \
  'root.editFile(root.homeDir + "/.config/swayosd/config.toml")' \
  'root.editFile(root.ryokuConfigPath + "/tofi/config")' \
  'root.editFile(root.homeDir + "/.config/waybar/config.jsonc")' \
  'root.editFile(root.homeDir + "/.XCompose")' \
  'root.runCommand(["ryoku-hyprland-monitor-internal", "toggle"])' \
  'root.runTerminal("ryoku-toggle-hybrid-gpu")' \
  'root.runCommand(["ryoku-toggle-touchpad"])' \
  'root.runTerminal("ryoku-pkg-install")' \
  'root.runTerminal("ryoku-pkg-aur-install")' \
  'root.runTerminal("ryoku-webapp-install")' \
  'root.runTerminal("ryoku-tui-install")' \
  'root.runTerminal("ryoku-windows-vm install")' \
  'root.runTerminal("ryoku-pkg-remove")' \
  'root.runTerminal("ryoku-webapp-remove")' \
  'root.runTerminal("ryoku-tui-remove")' \
  'root.runTerminal("ryoku-remove-preinstalls")' \
  'root.runTerminal("ryoku-voxtype-remove")' \
  'root.runTerminal("ryoku-theme-remove")' \
  'root.runTerminal("ryoku-windows-vm remove")' \
  'root.runTerminal("ryoku-setup-fingerprint --remove")' \
  'root.runTerminal("ryoku-setup-fido2 --remove")' \
  'root.runTerminal("ryoku-update")' \
  'root.runTerminal("ryoku-theme-update")' \
  'root.runTerminal("ryoku-update-firmware")' \
  'root.runTerminal("ryoku-tz-select")' \
  'root.runTerminal("ryoku-update-time")' \
  'root.runTerminal("ryoku-rollback")' \
  '$HOME/.local/state/ryoku/migration-state.txt' \
  'action === "maintain-rollback" ? root.rollbackAvailable' \
  '"install-service-dropbox": "ryoku-install-dropbox"' \
  '"install-service-tailscale": "ryoku-install-tailscale"' \
  '"install-service-nordvpn": "ryoku-install-nordvpn"' \
  '"install-service-once": "ryoku-install-once"' \
  '"install-service-bitwarden": "ryoku-pkg-add bitwarden bitwarden-cli && setsid gtk-launch bitwarden"' \
  '"install-service-chromium": "ryoku-install-chromium-google-account"' \
  '"install-style-theme": "ryoku-theme-install"' \
  '"install-style-background": "ryoku-theme-bg-install"' \
  '"font-cascadia": "ryoku-pkg-add ttf-cascadia-mono-nerd && sleep 2 && ryoku-font-set '\''CaskaydiaMono Nerd Font'\''"' \
  '"font-meslo": "ryoku-pkg-add ttf-meslo-nerd && sleep 2 && ryoku-font-set '\''MesloLGL Nerd Font'\''"' \
  '"font-fira": "ryoku-pkg-add ttf-firacode-nerd && sleep 2 && ryoku-font-set '\''FiraCode Nerd Font'\''"' \
  '"font-victor": "ryoku-pkg-add ttf-victor-mono-nerd && sleep 2 && ryoku-font-set '\''VictorMono Nerd Font'\''"' \
  '"font-bitstream": "ryoku-pkg-add ttf-bitstream-vera-mono-nerd && sleep 2 && ryoku-font-set '\''BitstromWera Nerd Font'\''"' \
  '"font-iosevka": "ryoku-pkg-add ttf-iosevka-nerd && sleep 2 && ryoku-font-set '\''Iosevka Nerd Font Mono'\''"' \
  '"install-dev-docker-dbs": "ryoku-install-docker-dbs"' \
  '"editor-vscode": "ryoku-install-vscode"' \
  '"terminal-alacritty": "ryoku-install-terminal alacritty"' \
  '"terminal-ghostty": "ryoku-install-terminal ghostty"' \
  '"terminal-kitty": "ryoku-install-terminal kitty"' \
  '"ai-dictation": "ryoku-voxtype-install"' \
  '"ai-lmstudio": "ryoku-pkg-add lmstudio-bin"' \
  '"ai-ollama": "ryoku-pkg-add ollama"' \
  '"ai-crush": "ryoku-pkg-add crush-bin"' \
  '"gaming-steam": "ryoku-install-steam"' \
  '"gaming-geforce-now": "ryoku-install-geforce-now"' \
  '"gaming-retroarch": "ryoku-pkg-aur-install retroarch retroarch-assets libretro libretro-fbneo"' \
  '"gaming-minecraft": "ryoku-pkg-add minecraft-launcher && setsid gtk-launch minecraft-launcher"' \
  '"gaming-xbox": "ryoku-install-xbox-controllers"' \
  '"channel-stable": "ryoku-channel-set stable"' \
  '"channel-rc": "ryoku-channel-set rc"' \
  '"channel-edge": "ryoku-channel-set edge"' \
  '"channel-dev": "ryoku-channel-set dev"' \
  '"refresh-hyprland": "ryoku-refresh-hyprland"' \
  '"refresh-hypridle": "ryoku-refresh-hypridle"' \
  '"refresh-hyprlock": "ryoku-refresh-hyprlock"' \
  '"refresh-hyprsunset": "ryoku-refresh-hyprsunset"' \
  '"refresh-plymouth": "ryoku-refresh-plymouth"' \
  '"refresh-swayosd": "ryoku-refresh-swayosd"' \
  '"refresh-tmux": "ryoku-refresh-tmux"' \
  '"refresh-waybar": "ryoku-refresh-waybar"' \
  '"restart-hypridle": "ryoku-restart-hypridle"' \
  '"restart-hyprsunset": "ryoku-restart-hyprsunset"' \
  '"restart-mako": "ryoku-restart-mako"' \
  '"restart-launcher": "notify-send '\''Launcher'\'' '\''Tofi has no daemon; nothing to restart.'\''"' \
  '"restart-swayosd": "ryoku-restart-swayosd"' \
  '"restart-waybar": "ryoku-restart-waybar"' \
  '"restart-audio": "ryoku-restart-pipewire"' \
  '"restart-wifi": "ryoku-restart-wifi"' \
  '"restart-bluetooth": "ryoku-restart-bluetooth"' \
  '"restart-trackpad": "ryoku-restart-trackpad"' \
  '"password-drive": "ryoku-drive-set-password"' \
  '"password-user": "passwd"' \
  'command = command.replace("ryoku-install-dev-env", "ryoku-remove-dev-env")'; do
  assert_file_has "$needle" "SettingsMenuPopup should include Task 4 action mapping: $needle"
done

for language in ruby go python zig rust java dotnet ocaml clojure scala node bun deno php laravel symfony elixir phoenix; do
  assert_file_has "ryoku-install-dev-env $language" "SettingsMenuPopup should install development environment: $language"
done
for language in ruby go python zig rust java dotnet ocaml clojure scala; do
  assert_file_has "\"remove-dev-$language\": \"ryoku-remove-dev-env $language\"" "SettingsMenuPopup should remove development environment: $language"
done
for language in node bun deno php laravel symfony elixir phoenix; do
  assert_file_has "\"remove-dev-$language\": \"ryoku-remove-dev-env $language\"" "SettingsMenuPopup should remove child development environment: $language"
done

grep -q 'ryoku-cmd-share", "clipboard"' "$settings_popup" \
  || fail "SettingsMenuPopup should map clipboard sharing to ryoku-cmd-share"
grep -q 'ryoku-menu-keybindings' "$settings_popup" \
  || fail "SettingsMenuPopup should keep keybindings as a native leaf action"
grep -q 'ryoku-launch-audio' "$settings_popup" \
  || fail "SettingsMenuPopup should launch audio setup natively"
grep -q 'ryoku-launch-wifi' "$settings_popup" \
  || fail "SettingsMenuPopup should launch Wi-Fi setup natively"
grep -q 'ryoku-launch-bluetooth' "$settings_popup" \
  || fail "SettingsMenuPopup should launch Bluetooth setup natively"
grep -q 'ryoku-launch-editor' "$settings_popup" \
  || fail "SettingsMenuPopup should open config leaves in the configured editor"
grep -q 'ryoku-cmd-share file' "$settings_popup" \
  || fail "SettingsMenuPopup should map file sharing to the floating share command"
grep -q 'ryoku-cmd-share folder' "$settings_popup" \
  || fail "SettingsMenuPopup should map folder sharing to the floating share command"
grep -q 'ryoku-hyprland-monitor-internal", "toggle"' "$settings_popup" \
  || fail "SettingsMenuPopup should map laptop display hardware control"
grep -q 'ryoku-toggle-hybrid-gpu' "$settings_popup" \
  || fail "SettingsMenuPopup should map hybrid GPU hardware control"
grep -q 'ryoku-toggle-touchpad' "$settings_popup" \
  || fail "SettingsMenuPopup should map touchpad hardware control"
grep -q 'label: "Maintain"' "$settings_popup" \
  || fail "SettingsMenuPopup should scaffold the Manage maintain tab"
grep -q 'label: "Dotfiles Hub"' "$settings_popup" \
  || fail "SettingsMenuPopup should scaffold Dotfiles Hub config access"
for label in "Apps" "Activity" "Caffeine" "Screen Capture" "Volume" "Brightness" "Shutdown" "Restart" "Log Out"; do
  ! grep -q "label: \"$label\"" "$settings_popup" \
    || fail "SettingsMenuPopup should not expose label: $label"
done
! grep -Eq 'label: "Suspend";.*action: "suspend"' "$settings_popup" \
  || fail "SettingsMenuPopup should not expose an immediate suspend action"
grep -q 'onClicked: Popups.closeAll()' "$settings_popup" \
  || fail "SettingsMenuPopup should own outside-click dismissal"
grep -q 'Keys.onEscapePressed: Popups.closeAll()' "$settings_popup" \
  || fail "SettingsMenuPopup should close on Escape through Popups.closeAll"
grep -q 'required property string label' "$settings_popup" \
  || fail "SettingsMenuPopup delegates should bind labels from stable ListModel roles"
grep -q 'id: headerRule' "$settings_popup" \
  || fail "SettingsMenuPopup should render a restrained header rule"
! grep -q 'iconBadge' "$settings_popup" \
  || fail "SettingsMenuPopup should avoid oversized icon badges"
! grep -q 'modelData && modelData.label' "$settings_popup" \
  || fail "SettingsMenuPopup should not render blank modelData fallbacks"
! grep -q 'ryoku-menu share' "$settings_popup" \
  || fail "SettingsMenuPopup should not call the legacy share menu"
! grep -Eq 'ryoku-menu (learn|setup|install|remove|update)' "$settings_popup" \
  || fail "SettingsMenuPopup should not call legacy page navigation menus"
! grep -q 'ryoku-menu hardware' "$settings_popup" \
  || fail "SettingsMenuPopup should not call the legacy hardware menu"
! grep -q 'ryoku-menu toggle' "$settings_popup" \
  || fail "SettingsMenuPopup should not call the legacy toggle menu"

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
grep -q 'Modify at your own risk' "$dotfiles_popup" \
  || fail "DotfilesHubPopup should show the config risk notice"
grep -q 'id: searchBar' "$dotfiles_popup" \
  || fail "DotfilesHubPopup should include a compact search bar"
grep -q 'id: searchInput' "$dotfiles_popup" \
  || fail "DotfilesHubPopup should expose a stable search input"
grep -q 'function fileMatches' "$dotfiles_popup" \
  || fail "DotfilesHubPopup should filter visible rows from search text"
grep -q 'function refreshSearchResults' "$dotfiles_popup" \
  || fail "DotfilesHubPopup should rebuild global search results"
grep -q 'id: searchFiles' "$dotfiles_popup" \
  || fail "DotfilesHubPopup should keep a global search result model"
grep -q 'root.searchQuery.trim() === "" ? root.activeModel() : searchFiles' "$dotfiles_popup" \
  || fail "DotfilesHubPopup should search across every section"
grep -q 'height: row.matchesSearch ? 54 : 0' "$dotfiles_popup" \
  || fail "DotfilesHubPopup should collapse rows that do not match search"
! grep -q 'id: sectionCount' "$dotfiles_popup" \
  || fail "DotfilesHubPopup should not use count badges in the category rail"
! grep -q 'id: fileIcon' "$dotfiles_popup" \
  || fail "DotfilesHubPopup should avoid oversized row icons"
grep -q '.config/hypr/hyprland.conf' "$dotfiles_popup" \
  || fail "DotfilesHubPopup should include Hyprland main config"
grep -q '.config/hypr/monitors.conf' "$dotfiles_popup" \
  || fail "DotfilesHubPopup should include monitor config"
grep -q '.config/hypr/xdph.conf' "$dotfiles_popup" \
  || fail "DotfilesHubPopup should include desktop portal config"
grep -q '.config/quickshell/ryoku/config/Config.qml' "$dotfiles_popup" \
  || fail "DotfilesHubPopup should include Quickshell config"
grep -q '.config/swayosd/style.css' "$dotfiles_popup" \
  || fail "DotfilesHubPopup should include OSD styling"
grep -q '.config/hyprland-preview-share-picker/config.yaml' "$dotfiles_popup" \
  || fail "DotfilesHubPopup should include share picker config"
grep -q '.config/uwsm/env' "$dotfiles_popup" \
  || fail "DotfilesHubPopup should include session environment config"
grep -q '.config/waybar/config.jsonc' "$dotfiles_popup" \
  || fail "DotfilesHubPopup should include legacy Waybar config"
grep -q '.config/waybar/style.css' "$dotfiles_popup" \
  || fail "DotfilesHubPopup should include legacy Waybar styling"
grep -q '.config/fontconfig/fonts.conf' "$dotfiles_popup" \
  || fail "DotfilesHubPopup should include fontconfig customization"
grep -q '.config/environment.d/fcitx.conf' "$dotfiles_popup" \
  || fail "DotfilesHubPopup should include input method environment config"
grep -q '.XCompose' "$dotfiles_popup" \
  || fail "DotfilesHubPopup should include XCompose customization"
grep -q '.config/ghostty/config' "$dotfiles_popup" \
  || fail "DotfilesHubPopup should include terminal config"
grep -q '.config/starship.toml' "$dotfiles_popup" \
  || fail "DotfilesHubPopup should include prompt config"
grep -q '.config/lazygit/config.yml' "$dotfiles_popup" \
  || fail "DotfilesHubPopup should include Lazygit config"
optional_agent_path='.config/open''code/open''code.json'
! grep -q "$optional_agent_path" "$dotfiles_popup" \
  || fail "DotfilesHubPopup should not include optional coding-agent config by default"
grep -q '.config/voxtype/config.toml' "$dotfiles_popup" \
  || fail "DotfilesHubPopup should include voice input config"
grep -q '.config/chromium-flags.conf' "$dotfiles_popup" \
  || fail "DotfilesHubPopup should include Chromium flags"
grep -q '.config/brave-flags.conf' "$dotfiles_popup" \
  || fail "DotfilesHubPopup should include Brave flags"
grep -q '.config/imv/config' "$dotfiles_popup" \
  || fail "DotfilesHubPopup should include image viewer config"
grep -q '.config/wiremix/wiremix.toml' "$dotfiles_popup" \
  || fail "DotfilesHubPopup should include audio mixer config"
grep -q '.config/mimeapps.list' "$dotfiles_popup" \
  || fail "DotfilesHubPopup should include default app chooser config"
grep -q '.config/xdg-terminals.list' "$dotfiles_popup" \
  || fail "DotfilesHubPopup should include default terminal list"
grep -q '.config/ryoku/hooks/battery-low' "$dotfiles_popup" \
  || fail "DotfilesHubPopup should include battery hook"
grep -q '.config/ryoku/hooks/font-set' "$dotfiles_popup" \
  || fail "DotfilesHubPopup should include font hook"
grep -q '.config/ryoku/branding/about.txt' "$dotfiles_popup" \
  || fail "DotfilesHubPopup should include branding text"
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
"$ipc" --help | grep -q "ryoku-ipc shell toggle legacy-settings-menu" \
  || fail "ryoku-ipc help should document legacy settings-menu toggle"
"$ipc" --help | grep -q "ryoku-ipc shell toggle dotfiles" \
  || fail "ryoku-ipc help should document dotfiles toggle"
"$ipc" shell command system-menu | grep -q 'qs -c ryoku ipc call popups toggleSystemMenu' \
  || fail "ryoku-ipc should print the system-menu IPC command"
"$ipc" shell command legacy-settings-menu | grep -q 'qs -c ryoku ipc call popups toggleLegacySettingsMenu' \
  || fail "ryoku-ipc should print the legacy settings-menu IPC command"
"$ipc" shell command dotfiles | grep -q 'qs -c ryoku ipc call popups toggleDotfiles' \
  || fail "ryoku-ipc should print the dotfiles IPC command"

grep -q 'bindd = SUPER, ESCAPE, System menu, exec, ryoku-ipc shell toggle system-menu' "$bindings" \
  || fail "SUPER+ESC should open the Quickshell system menu"
grep -q 'bindld = , XF86PowerOff, Power menu, exec, ryoku-ipc shell toggle system-menu' "$bindings" \
  || fail "hardware power key should open the Quickshell system menu"
! grep -q 'bindd = SUPER, ESCAPE, System menu, exec, ryoku-menu system' "$bindings" \
  || fail "SUPER+ESC should no longer open the old Omarchy picker"
! grep -q 'bindld = , XF86PowerOff, Power menu, exec, ryoku-menu system' "$bindings" \
  || fail "hardware power key should no longer open the old Omarchy picker"
! grep -q 'ryoku-menu toggle' "$bindings" \
  || fail "bindings should no longer use ryoku-menu toggle"
! grep -q 'ryoku-menu hardware' "$bindings" \
  || fail "bindings should no longer use ryoku-menu hardware"
! grep -q 'ryoku-menu share' "$bindings" \
  || fail "bindings should no longer use ryoku-menu share"

grep -q 'Popups.launcherOpen || Popups.wallpaperOpen || Popups.toolboxOpen ? WlrKeyboardFocus.None : WlrKeyboardFocus.OnDemand' "$popup_dismiss" \
  || fail "PopupDismiss keyboard focus behavior should remain searchable-popup safe"

pass "quickshell topbar settings menus"
