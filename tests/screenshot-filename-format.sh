#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_contains() {
  local path="$1"
  local needle="$2"

  grep -qF "$needle" "$path" || fail "$path should contain: $needle"
}

region_qml="shell/modules/regionSelector/RegionSelection.qml"
selector_qml="shell/modules/regionSelector/RegionSelector.qml"
background_qml="shell/modules/background/Background.qml"

assert_contains shell/defaults/config.json '"screenshotNameFormat": "ss-%Y%m%d-%H%M%S"'
assert_contains shell/modules/common/Config.qml 'property string screenshotNameFormat: "ss-%Y%m%d-%H%M%S"'
assert_contains "$region_qml" 'readonly property string screenshotNameFormat'
assert_contains "$region_qml" 'Config.options?.regionSelector?.screenshotNameFormat'
# shellcheck disable=SC2016
assert_contains "$region_qml" 'date +"$_fmt"'
assert_contains "$region_qml" 'screenshotEvents captured'
assert_contains "$region_qml" 'googleLensSearchEngineBaseUrl'
assert_contains shell/modules/settings/ToolsConfig.qml 'Config.setNestedValue("regionSelector.screenshotNameFormat", text)'
assert_contains "$selector_qml" 'root.googleLens = false'
assert_contains "$background_qml" 'GlobalActions.runLauncher(["region", "screenshot"])'

echo "PASS: screenshot filename format preserves screenshot and Lens wiring"
