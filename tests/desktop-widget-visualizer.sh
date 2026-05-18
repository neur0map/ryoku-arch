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

assert_not_contains() {
  local path="$1"
  local needle="$2"

  ! grep -qF "$needle" "$ROOT_DIR/$path" || fail "$path should not contain: $needle"
}

widget="shell/modules/background/widgets/visualizer/VisualizerWidget.qml"

[[ -f $ROOT_DIR/$widget ]] || fail "missing visualizer widget"
[[ -f $ROOT_DIR/shell/modules/background/widgets/visualizer/qmldir ]] || fail "missing visualizer qmldir"

assert_contains "shell/defaults/config.json" '"visualizer": {'
assert_contains "shell/modules/common/Config.qml" "property JsonObject visualizer: JsonObject"
assert_contains "shell/modules/background/Background.qml" "import qs.modules.background.widgets.visualizer"
assert_contains "shell/modules/background/Background.qml" "sourceComponent: VisualizerWidget"
assert_contains "shell/modules/settings/BackgroundConfig.qml" 'title: Translation.tr("Widget: Visualizer")'
assert_contains "$widget" 'configEntryName: "visualizer"'
assert_contains "$widget" "CavaProcess"
assert_contains "$widget" "CavaVisualizer"
assert_contains "$widget" "Appearance.ryokuEverywhere"
assert_not_contains "$widget" "Appearance.inir"
assert_not_contains "$widget" "inirEverywhere"
assert_not_contains "$widget" "snowarch"

echo "PASS: desktop visualizer widget is wired for Ryoku"
