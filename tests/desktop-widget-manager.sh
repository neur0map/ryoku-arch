#!/bin/bash
set -euo pipefail

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

require_file() {
  local path=$1
  [[ -f $path ]] || fail "missing $path"
}

require_rg() {
  local pattern=$1
  local path=$2
  rg -q -- "$pattern" "$path" || fail "missing pattern in $path: $pattern"
}

reject_rg() {
  local pattern=$1
  local path=$2
  if rg -q -- "$pattern" "$path"; then
    rg -n -- "$pattern" "$path" >&2
    fail "unexpected pattern in $path: $pattern"
  fi
}

require_file shell/modules/background/widgets/WidgetManagerPanel.qml
require_file shell/modules/background/widgets/ManifestPopover.qml
require_file shell/modules/settings/DesktopWidgetsConfig.qml
require_file shell/modules/background/widgets/battery/BatteryWidget.qml
require_file shell/modules/background/widgets/systemMonitor/SystemMonitorWidget.qml
require_file shell/modules/background/widgets/battery/qmldir
require_file shell/modules/background/widgets/systemMonitor/qmldir

require_rg 'property bool widgetEditMode' shell/GlobalStates.qml
require_rg 'target: "background"' shell/modules/background/Background.qml
require_rg 'function toggleEditMode' shell/modules/background/Background.qml
require_rg 'WidgetManagerPanel' shell/modules/background/Background.qml
require_rg 'ManifestPopover' shell/modules/background/widgets/AbstractBackgroundWidget.qml
require_rg 'readonly property bool isString' shell/modules/background/widgets/ManifestPopover.qml
require_rg 'readonly property bool hasOptions' shell/modules/background/widgets/ManifestPopover.qml
require_rg 'function optionValue' shell/modules/background/widgets/ManifestPopover.qml
require_rg 'function numericValue' shell/modules/background/widgets/ManifestPopover.qml
require_rg 'keyDelegate\.writeConfigValue\(optionButton\.optionValue\)' shell/modules/background/widgets/ManifestPopover.qml
require_rg 'keyDelegate\.isString && !keyDelegate\.hasOptions' shell/modules/background/widgets/ManifestPopover.qml
reject_rg 'cfgType !== "bool"' shell/modules/background/widgets/ManifestPopover.qml
reject_rg 'Number\(keyDelegate\.currentVal' shell/modules/background/widgets/ManifestPopover.qml
require_rg 'systemMonitor' shell/modules/background/Background.qml
require_rg 'battery' shell/modules/background/Background.qml
require_rg 'CustomWidgets\.widgets' shell/modules/background/Background.qml

require_rg 'ResizeHandle' shell/modules/background/widgets/AbstractBackgroundWidget.qml
require_rg '_snapZones' shell/modules/background/widgets/AbstractBackgroundWidget.qml
require_rg 'Config\.setNestedValues' shell/modules/background/widgets/AbstractBackgroundWidget.qml
require_rg '_freeModeOverflowGuard' shell/modules/background/widgets/AbstractBackgroundWidget.qml
require_rg 'settingsOverlayRequestedPage = 14' shell/modules/background/widgets/AbstractBackgroundWidget.qml
require_rg '--color-only' shell/scripts/images/least_busy_region.py
require_rg '--position-x' shell/scripts/images/least_busy_region.py
require_rg '--position-y' shell/scripts/images/least_busy_region.py
require_rg '"brightness"' shell/scripts/images/least_busy_region.py
require_rg 'IPC_II_TARGETS=\(background customWidgets overlay\)' shell/scripts/lib/ipc-registry.sh
reject_rg 'IPC_WAFFLE_TARGETS=\(background customWidgets' shell/scripts/lib/ipc-registry.sh
require_rg 'Family: ii' shell/docs/IPC.md

require_rg 'DesktopWidgetsConfig\.qml' shell/modules/settings/SettingsOverlay.qml
require_rg '\[background\]="toggleEditMode"' shell/scripts/lib/ipc-registry.sh
require_rg 'toggleEditMode' shell/scripts/lib/ipc-registry.sh

echo "desktop widget manager wiring ok"
