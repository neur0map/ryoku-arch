#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

vendor="config/quickshell/ryoku/vendor/noctalia-shell"
runtime="config/quickshell/ryoku/Noctalia"
shell_qml="config/quickshell/ryoku/shell.qml"
settings_window="$runtime/Modules/Panels/Settings/SettingsPanelWindow.qml"

[[ -f $vendor/UPSTREAM.md ]] || fail "Noctalia vendor metadata should exist"
[[ -f $vendor/LICENSE ]] || fail "Noctalia MIT license should be copied"
grep -q 'https://github.com/noctalia-dev/noctalia-shell' "$vendor/UPSTREAM.md" \
  || fail "UPSTREAM should record the Noctalia repository"
grep -q '9f8dd48c8df5ab1f7f87ddf9842627e1e5682186' "$vendor/UPSTREAM.md" \
  || fail "UPSTREAM should pin the reviewed Noctalia commit"
grep -q 'MIT License' "$vendor/LICENSE" \
  || fail "Noctalia license should be MIT"

[[ -f $vendor/upstream/Modules/Panels/Settings/SettingsPanelWindow.qml ]] \
  || fail "Upstream Noctalia settings window should be vendored"
[[ -f $vendor/upstream/Modules/Panels/Settings/SettingsContent.qml ]] \
  || fail "Upstream Noctalia settings content should be vendored"
[[ -f $vendor/upstream/Modules/Panels/Settings/Tabs/Connections/WifiSubTab.qml ]] \
  || fail "Upstream Noctalia Wi-Fi subtab should be vendored"
[[ -f $vendor/upstream/Modules/Panels/Settings/Tabs/Connections/BluetoothSubTab.qml ]] \
  || fail "Upstream Noctalia Bluetooth subtab should be vendored"

[[ -f $runtime/Modules/Panels/Settings/SettingsPanelWindow.qml ]] \
  || fail "Runtime Noctalia settings window should exist"
[[ -f $runtime/Modules/Panels/Settings/SettingsContent.qml ]] \
  || fail "Runtime Noctalia settings content should exist"
[[ -f $runtime/Services/UI/RyokuSettingsPanelService.qml ]] \
  || fail "Ryoku settings panel service should exist"
[[ -f $runtime/Services/Ryoku/RyokuFeatureAvailability.qml ]] \
  || fail "Ryoku feature availability service should exist"

grep -q 'import qs.Noctalia.Commons' "$settings_window" \
  || fail "Runtime settings window should import the Noctalia runtime namespace"
! rg -n '^import qs\.(Commons|Widgets|Services|Modules|Assets)' "$runtime" \
  || fail "Runtime Noctalia files should not import the upstream root namespace"
rg -n 'import qs.Noctalia' "$runtime" >/dev/null \
  || fail "Runtime Noctalia files should use qs.Noctalia imports"

grep -q 'SettingsPanelWindow' "$shell_qml" \
  || fail "Ryoku shell should instantiate the Noctalia settings window"
grep -q 'toggleLegacySettingsMenu' "$shell_qml" \
  || fail "Ryoku shell should keep a legacy settings-menu route"
grep -q 'openSettingsRoute' "$shell_qml" \
  || fail "Ryoku shell should route settings subtabs through IPC"
! rg -n 'PluginRegistry\.init|TelemetryService|UpdateService|SetupWizard|shouldOpenSetupWizard' "$shell_qml" "$runtime" \
  || fail "Ryoku should not bootstrap Noctalia autonomous services"
! rg -n 'ShellRoot|PluginRegistry\.init|TelemetryService|UpdateService|SetupWizard|shouldOpenSetupWizard' "$runtime" \
  || fail "Noctalia runtime should not include full shell bootstrap code"

grep -Eq 'implicitWidth:[[:space:]]+840|panelWidth:[[:space:]]+840|width:[[:space:]]+840' "$settings_window" \
  || fail "Settings panel should preserve Noctalia's 840px visual width"
grep -Eq 'implicitHeight:[[:space:]]+910|panelHeight:[[:space:]]+910|height:[[:space:]]+910' "$settings_window" \
  || fail "Settings panel should preserve Noctalia's 910px visual height"
rg -U '(^|\n)[^\n]*(implicitWidth|panelWidth|width)[[:space:]]*:[[:space:]]*Math\.min\([\s\S]{0,240}(screen\.width|availableGeometry[\s\S]{0,40}width)' "$settings_window" >/dev/null \
  || fail "Settings panel should cap width to available screen geometry"
rg -U '(^|\n)[^\n]*(implicitHeight|panelHeight|height)[[:space:]]*:[[:space:]]*Math\.min\([\s\S]{0,240}(screen\.height|availableGeometry[\s\S]{0,40}height)' "$settings_window" >/dev/null \
  || fail "Settings panel should cap height to available screen geometry"

for tab in General UserInterface ColorScheme Wallpaper Bar Dock DesktopWidgets ControlCenter Launcher Notifications OSD LockScreen SessionMenu Idle Audio Display Connections Location System Plugins Hooks About; do
  grep -q "SettingsPanel.Tab.$tab" "$runtime/Modules/Panels/Settings/SettingsContent.qml" \
    || fail "Settings tab $tab should remain present"
done

grep -q 'featureAvailable' "$runtime/Modules/Panels/Settings/SettingsContent.qml" \
  || fail "Settings content should consult feature availability"
grep -q 'enabled:.*featureAvailable' "$runtime/Modules/Panels/Settings/SettingsContent.qml" \
  || fail "Unavailable settings controls should be disabled"
grep -q 'searchable' "$runtime/Modules/Panels/Settings/SettingsContent.qml" \
  || fail "Unavailable settings pages should remain searchable"
! grep -q 'tabIndexForId(entry.tab)' "$runtime/Modules/Panels/Settings/SettingsContent.qml" \
  || fail "Settings search entries should use their tab index directly"
grep -q 'tabsModel\[entry.tab\]' "$runtime/Modules/Panels/Settings/SettingsContent.qml" \
  || fail "Settings search metadata should resolve from the entry tab index"
rg -U 'sourceComponent:[[:space:]]+root\.tabsModel\[index\]\?\.featureAvailable[[:space:]]*\?[[:space:]]*root\.tabsModel\[index\]\?\.source[[:space:]]*:[[:space:]]*null' "$runtime/Modules/Panels/Settings/SettingsContent.qml" >/dev/null \
  || fail "Unavailable settings pages should not instantiate unsupported tab components"
grep -q 'requestedTabIndex' "$runtime/Modules/Panels/Settings/SettingsContent.qml" \
  || fail "Settings content should support initializing from a search tab index"
! rg -n 'requestedTab[[:space:]]*=[[:space:]]*(entry|requestedEntry)\.tab' "$settings_window" "$runtime/Modules/Panels/Settings/SettingsPanel.qml" \
  || fail "Search entry opens should not treat entry.tab index as a tab enum"
rg -U 'tabsModel\[tabIndex\]\?\.featureAvailable[[:space:]]*===[[:space:]]*false[\s\S]{0,260}_pendingSubTab[[:space:]]*=[[:space:]]*-1' "$runtime/Modules/Panels/Settings/SettingsContent.qml" >/dev/null \
  || fail "Unavailable search navigation should clear pending subtab state"
grep -q 'property var _commandCache' "$runtime/Services/Ryoku/RyokuCommand.qml" \
  || fail "Ryoku command presence checks should cache results"
grep -q 'property var _pendingChecks' "$runtime/Services/Ryoku/RyokuCommand.qml" \
  || fail "Ryoku command presence checks should preserve concurrent callbacks"
grep -q 'property var _checkQueue' "$runtime/Services/Ryoku/RyokuCommand.qml" \
  || fail "Ryoku command presence checks should serialize the shared process"

grep -q 'ryoku/noctalia-settings/settings.json' "$runtime/Commons/Settings.qml" \
  || fail "Runtime settings should use a Ryoku-owned settings path"
grep -q 'ryoku/noctalia-settings/state.json' "$runtime/Services/UI/RyokuSettingsPanelService.qml" \
  || fail "Panel state should use a Ryoku-owned state path"

grep -q 'legacy-settings-menu' bin/ryoku-ipc \
  || fail "ryoku-ipc should expose the legacy settings-menu route"
grep -q 'settings-menu wifi' bin/ryoku-ipc \
  || fail "ryoku-ipc should expose a Wi-Fi settings route"
grep -q 'settings-menu bluetooth' bin/ryoku-ipc \
  || fail "ryoku-ipc should expose a Bluetooth settings route"

grep -q 'SUPER ALT, SPACE' default/hypr/bindings/utilities.conf \
  || fail "Super+Alt+Space binding should remain declared"
grep -q 'ryoku-ipc shell toggle settings-menu' default/hypr/bindings/utilities.conf \
  || fail "Super+Alt+Space should open the new settings panel"
grep -q 'settings-menu wifi' default/hypr/bindings/utilities.conf \
  || fail "Wi-Fi shortcut should open the settings Wi-Fi subtab"
grep -q 'settings-menu bluetooth' default/hypr/bindings/utilities.conf \
  || fail "Bluetooth shortcut should open the settings Bluetooth subtab"
