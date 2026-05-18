#!/bin/bash
set -euo pipefail

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

require_rg() {
  local pattern=$1
  local path=$2
  rg -q -- "$pattern" "$path" || fail "missing pattern in $path: $pattern"
}

require_rg 'property int revision' shell/modules/common/Config.qml
require_rg 'function _bumpRevision' shell/modules/common/Config.qml
require_rg 'function getNestedValue' shell/modules/common/Config.qml
require_rg 'root\.revision;' shell/modules/common/Config.qml
require_rg 'fileWriteTimer\.restart\(\);' shell/modules/common/Config.qml
require_rg 'root\._bumpRevision\(\);' shell/modules/common/Config.qml

require_rg 'customWidgetData' shell/modules/common/Config.qml
require_rg 'customWidgetDataSynced' shell/modules/common/Config.qml
require_rg 'background.*widgets.*custom' shell/modules/common/Config.qml
require_rg 'root\.customWidgetData = raw\?\.' shell/modules/common/Config.qml
require_rg 'Config\.customWidgetDataSynced' shell/services/CustomWidgets.qml

require_rg 'Config\.getNestedValue' shell/modules/background/widgets/AbstractBackgroundWidget.qml
require_rg 'Config\.getNestedValue' shell/modules/settings/DesktopWidgetsConfig.qml
require_rg 'Config\.getNestedValue' shell/services/CustomWidgets.qml

echo "desktop widget config persistence wiring ok"
