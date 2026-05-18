#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_contains() {
  local path="$1"
  local needle="$2"

  grep -qF "$needle" "$ROOT_DIR/$path" || fail "$path should contain: $needle"
}

for key in weather media powerButtons hintText; do
  assert_contains "shell/defaults/config.json" "\"$key\": true"
done

assert_contains "shell/modules/common/Config.qml" "property JsonObject widgets: JsonObject"
assert_contains "shell/modules/common/Config.qml" "property bool weather: true"
assert_contains "shell/modules/common/Config.qml" "property bool media: true"
assert_contains "shell/modules/common/Config.qml" "property bool powerButtons: true"
assert_contains "shell/modules/common/Config.qml" "property bool hintText: true"

for surface in \
  shell/modules/lock/LockSurface.qml \
  shell/modules/waffle/lock/WaffleLockSurface.qml \
  shell/modules/waffle/lock/WaffleLockSurfaceSafe.qml; do
  assert_contains "$surface" "readonly property bool showWeather: Config.options?.lock?.widgets?.weather ?? true"
  assert_contains "$surface" "readonly property bool showMedia: Config.options?.lock?.widgets?.media ?? true"
  assert_contains "$surface" "readonly property bool showPowerButtons: Config.options?.lock?.widgets?.powerButtons ?? true"
  assert_contains "$surface" "readonly property bool showHintText: Config.options?.lock?.widgets?.hintText ?? true"
  assert_contains "$surface" "root.showWeather &&"
  assert_contains "$surface" "root.showMedia &&"
  assert_contains "$surface" "visible: root.showHintText && opacity > 0"
  assert_contains "$surface" "opacity: root.showHintText ? hintOpacity : 0"
  assert_contains "$surface" "visible: root.showPowerButtons"
done

assert_contains "shell/modules/settings/GeneralConfig.qml" 'title: Translation.tr("Widgets")'
assert_contains "shell/modules/settings/GeneralConfig.qml" 'Config.setNestedValue("lock.widgets.weather", checked)'
assert_contains "shell/modules/settings/GeneralConfig.qml" 'Config.setNestedValue("lock.widgets.media", checked)'
assert_contains "shell/modules/settings/GeneralConfig.qml" 'Config.setNestedValue("lock.widgets.powerButtons", checked)'
assert_contains "shell/modules/settings/GeneralConfig.qml" 'Config.setNestedValue("lock.widgets.hintText", checked)'

echo "PASS: lock widget visibility controls are wired"
