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

require_rg 'property bool _writeInFlight' shell/modules/common/Config.qml
require_rg 'property bool _pendingReload' shell/modules/common/Config.qml
require_rg 'function _completeWrite' shell/modules/common/Config.qml
require_rg 'function _completeSavedWrite' shell/modules/common/Config.qml
require_rg 'function _failWrite' shell/modules/common/Config.qml
require_rg 'onSaved: root\._completeSavedWrite\(\)' shell/modules/common/Config.qml
require_rg 'onSaveFailed: error => root\._failWrite\(error\)' shell/modules/common/Config.qml
require_rg 'root\._writeInFlight = true;' shell/modules/common/Config.qml
require_rg 'root\._writeInFlight = false;' shell/modules/common/Config.qml
require_rg 'if \(root\._writeInFlight\)' shell/modules/common/Config.qml
require_rg 'root\._pendingReload = true;' shell/modules/common/Config.qml
require_rg 'root\._finishPendingReload\(\);' shell/modules/common/Config.qml
require_rg 'fileReloadTimer\.stop\(\);' shell/modules/common/Config.qml

require_rg 'function _prepareCustomInject' shell/modules/common/Config.qml
require_rg 'function _injectCustomDataSync' shell/modules/common/Config.qml
require_rg 'configFileView\.setText\(JSON\.stringify' shell/modules/common/Config.qml
require_rg 'rawConfigReader' shell/modules/common/Config.qml
require_rg 'root\._syncVarProperties\(\);' shell/modules/common/Config.qml

echo "config write adapter persistence guards ok"
