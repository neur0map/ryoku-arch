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
  shift
  if rg -q -- "$pattern" "$@"; then
    rg -n -- "$pattern" "$@" >&2
    fail "unexpected legacy naming pattern: $pattern"
  fi
}

require_file shell/services/CustomWidgets.qml
require_file shell/defaults/widgets/WIDGET-SDK.md
require_file shell/defaults/widgets/example-widget/ExampleWidget.qml
require_file shell/defaults/widgets/example-widget/widget.json

require_rg 'readonly property string widgetsDir: .*Directories\.configPath.*ryoku-shell/widgets' shell/services/CustomWidgets.qml
require_rg 'target: "customWidgets"' shell/services/CustomWidgets.qml
require_rg 'function create\(name: string\)' shell/services/CustomWidgets.qml
require_rg 'function remove\(widgetId: string\)' shell/services/CustomWidgets.qml
require_rg 'function installExample\(\)' shell/services/CustomWidgets.qml
require_rg 'function _isValidSlug' shell/services/CustomWidgets.qml
require_rg '\^\[A-Za-z0-9_-\]\+\$' shell/services/CustomWidgets.qml
require_rg 'Invalid .* Use only letters, numbers, underscore, and dash' shell/services/CustomWidgets.qml
require_rg '"create-widget", root\.widgetsDir, _createProcess\.widgetName, _createProcess\.pascalName' shell/services/CustomWidgets.qml
require_rg '"remove-widget", root\.widgetsDir, _removeProcess\.widgetId' shell/services/CustomWidgets.qml
require_rg 'rm -rf -- "[$]dir"' shell/services/CustomWidgets.qml
require_rg 'command: \["python3", "-c"' shell/services/CustomWidgets.qml
require_rg 'json\.load\(manifest_file\)' shell/services/CustomWidgets.qml
require_rg 'Skipping malformed manifest' shell/services/CustomWidgets.qml
require_rg 'entries\.append' shell/services/CustomWidgets.qml
require_rg 'function _isValidQmlBasename' shell/services/CustomWidgets.qml
require_rg '\^\[A-Za-z0-9_-\]\+\\\.qml\$' shell/services/CustomWidgets.qml
require_rg 'main must be a simple \.qml file name' shell/services/CustomWidgets.qml
require_rg 'root\._mainQmlFile\(entry\.id, m\)' shell/services/CustomWidgets.qml
reject_rg 'rm -rf "\$\{root\.widgetsDir\}' shell/services/CustomWidgets.qml
reject_rg 'result="\\\["' shell/services/CustomWidgets.qml
require_rg 'setSource\(modelData\.qmlPath' shell/modules/background/Background.qml
require_rg '_readConfigKey' shell/defaults/widgets/example-widget/ExampleWidget.qml
require_rg 'Config\.setNestedValue' shell/defaults/widgets/example-widget/ExampleWidget.qml

old_token='i''nir'
reject_rg "\\b${old_token}\\b|${old_token^^}|DankMaterialShell|dms" \
  shell/services/CustomWidgets.qml \
  shell/defaults/widgets/WIDGET-SDK.md \
  shell/defaults/widgets/example-widget/ExampleWidget.qml \
  shell/defaults/widgets/example-widget/widget.json \
  shell/modules/background/Background.qml \
  shell/modules/background/widgets/WidgetManagerPanel.qml \
  shell/modules/background/widgets/AbstractBackgroundWidget.qml

echo "custom widget loader wiring ok"
