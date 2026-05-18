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

assert_contains shell/defaults/config.json '"downloadPath": {'
assert_contains shell/modules/common/Config.qml 'property JsonObject downloadPath: JsonObject'
assert_contains shell/modules/common/Directories.qml 'Config.options?.sidebar?.booru?.downloadPath?.sfw || Directories.wallpapersPath'
assert_contains shell/modules/common/Directories.qml 'Config.options?.sidebar?.booru?.downloadPath?.nsfw'
assert_contains shell/modules/settings/InterfaceConfig.qml 'title: Translation.tr("Booru download paths")'
assert_contains shell/modules/settings/InterfaceConfig.qml 'Config.setNestedValue("sidebar.booru.downloadPath.sfw", text)'
assert_contains shell/modules/settings/InterfaceConfig.qml 'Config.setNestedValue("sidebar.booru.downloadPath.nsfw", text)'

echo "PASS: booru download paths are configurable"
