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
[[ -f $runtime/Services/Ryoku/RyokuThemeActions.qml ]] \
  || fail "Ryoku theme settings actions should exist"
[[ -f $runtime/Services/Ryoku/RyokuWallpaperActions.qml ]] \
  || fail "Ryoku wallpaper settings actions should exist"
[[ -f $runtime/Services/Ryoku/RyokuSessionActions.qml ]] \
  || fail "Ryoku session settings actions should exist"
grep -q 'singleton RyokuThemeActions 1.0 RyokuThemeActions.qml' "$runtime/Services/Ryoku/qmldir" \
  || fail "Ryoku theme actions should be exported from qmldir"
grep -q 'singleton RyokuWallpaperActions 1.0 RyokuWallpaperActions.qml' "$runtime/Services/Ryoku/qmldir" \
  || fail "Ryoku wallpaper actions should be exported from qmldir"
grep -q 'singleton RyokuSessionActions 1.0 RyokuSessionActions.qml' "$runtime/Services/Ryoku/qmldir" \
  || fail "Ryoku session actions should be exported from qmldir"
grep -q 'ryoku-theme-refresh' "$runtime/Services/Ryoku/RyokuThemeActions.qml" \
  || fail "Ryoku theme actions should refresh theme templates"
grep -q 'ryoku-ipc.*shell.*toggle.*themes' "$runtime/Services/Ryoku/RyokuThemeActions.qml" \
  || fail "Ryoku theme actions should open the Ryoku theme picker"
grep -q 'ryoku-ipc.*shell.*toggle.*wallpaper' "$runtime/Services/Ryoku/RyokuWallpaperActions.qml" \
  || fail "Ryoku wallpaper actions should open the Ryoku wallpaper picker"
! rg -U 'function openWallhaven\(\)[\s\S]{0,160}ryoku-ipc", "wallpaper", "wallhaven"\][\s\S]{0,80}' "$runtime/Services/Ryoku/RyokuWallpaperActions.qml" >/dev/null \
  || fail "Ryoku wallpaper actions should not call bare invalid Wallhaven IPC"
rg -U 'function openWallhaven\(\)[\s\S]{0,160}openWallpaperPicker\(\)' "$runtime/Services/Ryoku/RyokuWallpaperActions.qml" >/dev/null \
  || fail "Ryoku Wallhaven action should route to the wallpaper picker UI"
grep -q 'ryoku-ipc.*wallpaper.*cache.*rebuild' "$runtime/Services/Ryoku/RyokuWallpaperActions.qml" \
  || fail "Ryoku wallpaper actions should rebuild wallpaper cache"
grep -q 'ryoku-lock-screen' "$runtime/Services/Ryoku/RyokuSessionActions.qml" \
  || fail "Ryoku session actions should lock through Ryoku"
grep -q 'ryoku-system-logout' "$runtime/Services/Ryoku/RyokuSessionActions.qml" \
  || fail "Ryoku session actions should logout through Ryoku"
grep -q 'ryoku-system-reboot' "$runtime/Services/Ryoku/RyokuSessionActions.qml" \
  || fail "Ryoku session actions should reboot through Ryoku"
grep -q 'ryoku-system-shutdown' "$runtime/Services/Ryoku/RyokuSessionActions.qml" \
  || fail "Ryoku session actions should power off through Ryoku"

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
! rg -n '(panelWidth|panelHeight|implicitWidth|implicitHeight):.*Style\.uiScaleRatio' "$settings_window" \
  || fail "Settings panel outer geometry should not scale beyond Noctalia's logical size"
grep -q 'PanelWindow' "$settings_window" \
  || fail "Settings panel should use a supported layer-shell host for compositor-level centering"
! grep -q 'title:' "$settings_window" \
  || fail "Settings PanelWindow should not assign FloatingWindow-only title"
! rg -n '(^|[[:space:]])[xy][[:space:]]*:' "$settings_window" \
  || fail "Settings panel should not assign unsupported FloatingWindow x/y properties"
grep -q 'anchors.centerIn: parent' "$settings_window" \
  || fail "Settings panel content should be centered in its screen host"
grep -q 'mask: Region' "$settings_window" \
  || fail "Settings panel should not leave a full-screen input region active around the centered panel"
grep -q 'availablePanelWidth:.*width - 24' "$settings_window" \
  || fail "Settings panel should derive available width from the screen-sized host"
grep -q 'availablePanelHeight:.*height - 24' "$settings_window" \
  || fail "Settings panel should derive available height from the screen-sized host"
grep -q 'width: Math.min(root.panelWidth, root.availablePanelWidth)' "$settings_window" \
  || fail "Settings panel should cap width to available screen geometry"
grep -q 'height: Math.min(root.panelHeight, root.availablePanelHeight)' "$settings_window" \
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

grep -q 'RyokuThemeActions' "$runtime/Modules/Panels/Settings/Tabs/ColorScheme/ColorsSubTab.qml" \
  || fail "Color scheme page should use Ryoku theme actions"
grep -q 'RyokuThemeActions.refreshTheme' "$runtime/Modules/Panels/Settings/Tabs/ColorScheme/ColorsSubTab.qml" \
  || fail "Color scheme page should expose Ryoku theme refresh"
grep -q 'RyokuThemeActions.openThemePicker' "$runtime/Modules/Panels/Settings/Tabs/ColorScheme/ColorsSubTab.qml" \
  || fail "Color scheme page should expose the Ryoku theme picker"
grep -q 'enabled:.*RyokuThemeActions.wallpaperColorControlsAvailable' "$runtime/Modules/Panels/Settings/Tabs/ColorScheme/ColorsSubTab.qml" \
  || fail "Wallpaper-derived color controls should stay visible but disabled"
grep -q 'RyokuThemeActions.templateControlsAvailable' "$runtime/Modules/Panels/Settings/Tabs/ColorScheme/TemplatesSubTab.qml" \
  || fail "Template controls should stay visible but disabled"

grep -q 'RyokuWallpaperActions' "$runtime/Modules/Panels/Settings/Tabs/Wallpaper/GeneralSubTab.qml" \
  || fail "Wallpaper page should use Ryoku wallpaper actions"
grep -q 'RyokuWallpaperActions.openWallpaperPicker' "$runtime/Modules/Panels/Settings/Tabs/Wallpaper/GeneralSubTab.qml" \
  || fail "Wallpaper page should expose Ryoku wallpaper picker"
grep -q 'RyokuWallpaperActions.openWallhaven' "$runtime/Modules/Panels/Settings/Tabs/Wallpaper/GeneralSubTab.qml" \
  || fail "Wallpaper page should expose Wallhaven"
grep -q 'RyokuWallpaperActions.rebuildCache' "$runtime/Modules/Panels/Settings/Tabs/Wallpaper/GeneralSubTab.qml" \
  || fail "Wallpaper page should expose cache rebuild"
rg -U 'NTextInputButton[[:space:]]*\{[\s\S]{0,160}id:[[:space:]]+monitorDirInput[\s\S]{0,180}enabled:[[:space:]]+root\.noctaliaWallpaperControlsAvailable' "$runtime/Modules/Panels/Settings/Tabs/Wallpaper/GeneralSubTab.qml" >/dev/null \
  || fail "Nested monitor-specific wallpaper directory controls should stay visible but disabled"
grep -q 'RyokuWallpaperActions.noctaliaWallpaperControlsAvailable' "$runtime/Modules/Panels/Settings/Tabs/Wallpaper/LookAndFeelSubTab.qml" \
  || fail "Unavailable wallpaper look controls should stay visible but disabled"
grep -q 'RyokuWallpaperActions.noctaliaWallpaperControlsAvailable' "$runtime/Modules/Panels/Settings/Tabs/Wallpaper/AutomationSubTab.qml" \
  || fail "Unavailable wallpaper automation controls should stay visible but disabled"

grep -q 'ryoku-volume' "$runtime/Services/Media/AudioService.qml" \
  || fail "Audio service should use the existing Ryoku volume backend"
grep -q 'wpctl' "$runtime/Services/Media/AudioService.qml" \
  || fail "Audio service should read local PipeWire volume state"
grep -q 'property var _volumeCommandQueue' "$runtime/Services/Media/AudioService.qml" \
  || fail "Audio service should queue rapid Ryoku volume commands"
grep -q 'runNextVolumeCommand' "$runtime/Services/Media/AudioService.qml" \
  || fail "Audio service should drain queued Ryoku volume commands"
grep -q 'advancedControlsAvailable' "$runtime/Modules/Panels/Settings/Tabs/Audio/DevicesSubTab.qml" \
  || fail "Advanced audio device controls should stay visible but disabled"
grep -q 'advancedControlsAvailable' "$runtime/Modules/Panels/Settings/Tabs/Audio/VisualizerSubTab.qml" \
  || fail "Advanced audio visualizer controls should stay visible but disabled"

grep -q 'Quickshell.screens' "$runtime/Modules/Panels/Settings/Tabs/Display/BrightnessSubTab.qml" \
  || fail "Display page should expose local monitor status"
grep -q 'monitorMutationsAvailable' "$runtime/Modules/Panels/Settings/Tabs/Display/BrightnessSubTab.qml" \
  || fail "Display mutation controls should be explicitly disabled"
grep -q 'monitorMutationsAvailable' "$runtime/Modules/Panels/Settings/Tabs/Display/NightLightSubTab.qml" \
  || fail "Night light mutation controls should be explicitly disabled"

grep -q 'RyokuSessionActions' "$runtime/Modules/Panels/Settings/Tabs/SessionMenu/SessionMenuTab.qml" \
  || fail "Session settings should use Ryoku session action safety"
grep -q 'RyokuSessionActions.isSafeAction' "$runtime/Modules/Panels/Settings/Tabs/SessionMenu/SessionMenuTab.qml" \
  || fail "Session settings should only enable safe Ryoku session actions"
grep -q 'ryokuManagedCommand' "$runtime/Modules/Panels/Settings/Tabs/SessionMenu/SessionMenuTab.qml" \
  || fail "Session entry dialog should receive a Ryoku-managed command flag"
grep -q 'property bool ryokuManagedCommand' "$runtime/Modules/Panels/Settings/Tabs/SessionMenu/SessionMenuEntrySettingsDialog.qml" \
  || fail "Session entry dialog should expose a Ryoku-managed command flag"
rg -U 'NTextInput[[:space:]]*\{[\s\S]{0,180}id:[[:space:]]+commandInput[\s\S]{0,220}enabled:[[:space:]]+!root\.ryokuManagedCommand' "$runtime/Modules/Panels/Settings/Tabs/SessionMenu/SessionMenuEntrySettingsDialog.qml" >/dev/null \
  || fail "Ryoku-managed session commands should be visible but not editable"
rg -U 'NIconButtonHot[[:space:]]*\{[\s\S]{0,220}visible:[^\n]*Settings\.data\.sessionMenu\.enableCountdown[\s\S]{0,220}enabled:[[:space:]]+modelData\.safeAction[[:space:]]+!==[[:space:]]+false' "$runtime/Modules/Panels/Settings/Tabs/SessionMenu/ActionsSubTab.qml" >/dev/null \
  || fail "Unsupported session countdown toggles should be disabled"
grep -q 'RyokuFeatureAvailability.unavailableReason' "$runtime/Modules/Panels/Settings/Tabs/Idle/IdleTab.qml" \
  || fail "Idle settings should stay visible but disabled with an unavailable reason"

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
