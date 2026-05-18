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

assert_contains shell/defaults/config.json '"wallpapers": {'
assert_contains shell/defaults/config.json '"directory": ""'
assert_contains shell/modules/common/Config.qml 'property JsonObject wallpapers: JsonObject'
assert_contains shell/modules/common/Directories.qml 'Config.options?.wallpapers?.directory'
assert_contains shell/services/Wallpapers.qml 'Qt.resolvedUrl(Directories.wallpapersPath)'
assert_contains shell/modules/sidebarLeft/widgets/QuickWallpaper.qml 'readonly property string wallpapersPath: Directories.wallpapersPath'
assert_contains shell/modules/settings/BackgroundConfig.qml 'Config.setNestedValue("wallpapers.directory", text)'
assert_contains shell/modules/settings/BackgroundConfig.qml 'title: Translation.tr("Wallpapers folder")'

echo "PASS: wallpaper directory config is wired"
