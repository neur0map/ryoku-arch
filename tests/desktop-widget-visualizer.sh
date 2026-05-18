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
old_prefix="i""nir"
old_owner="snow""arch"

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
assert_contains "$widget" "fillOpacity:"
assert_contains "$widget" 'readonly property string vizType: Config.getNestedValue("background.widgets.visualizer.vizType", "bars")'
assert_contains "$widget" 'readonly property int waveOpacity: Config.getNestedValue("background.widgets.visualizer.waveOpacity", -1)'
assert_contains "$widget" 'visible: root.vizType === "bars"'
assert_contains "$widget" 'visible: root.vizType === "wave"'
assert_contains "shell/defaults/config.json" '"waveOpacity": -1'
assert_contains "shell/defaults/config.json" '"visualizerType": "wave"'
assert_contains "shell/defaults/config.json" '"visualizerPosition": "bottom"'
assert_contains "shell/modules/common/Config.qml" 'property string visualizerType: "wave"'
assert_contains "shell/modules/common/Config.qml" 'property string visualizerPosition: "bottom"'
assert_contains "shell/modules/settings/DesktopWidgetsConfig.qml" "background.widgets.mediaControls.visualizerType"
assert_contains "shell/modules/settings/DesktopWidgetsConfig.qml" "background.widgets.mediaControls.visualizerPosition"
assert_contains "shell/modules/common/widgets/WaveVisualizer.qml" "property real fillOpacity"
assert_contains "shell/modules/common/widgets/WaveVisualizer.qml" "onFillOpacityChanged"
assert_contains "shell/modules/common/widgets/WaveVisualizer.qml" "root.fillOpacity"
assert_contains "shell/modules/common/widgets/WaveVisualizer.qml" "Appearance.ryokuEverywhere"
for preset in AlbumArtPlayer ClassicPlayer CompactPlayer FullPlayer MinimalPlayer VisualizerPlayer; do
  preset_path="shell/modules/mediaControls/presets/${preset}.qml"
  assert_contains "$preset_path" "readonly property string vizType"
  assert_contains "$preset_path" "readonly property string vizPosition"
  assert_contains "$preset_path" "CavaVisualizer"
  assert_contains "$preset_path" 'visible: root.vizType === "bars" && root.vizPosition !== "none"'
done
assert_not_contains "$widget" "Appearance.$old_prefix"
assert_not_contains "$widget" "${old_prefix}Everywhere"
assert_not_contains "$widget" "$old_owner"
assert_not_contains "shell/modules/common/widgets/WaveVisualizer.qml" "Appearance.$old_prefix"
assert_not_contains "shell/modules/common/widgets/WaveVisualizer.qml" "${old_prefix}Everywhere"
assert_not_contains "shell/modules/common/widgets/WaveVisualizer.qml" "$old_owner"

echo "PASS: desktop visualizer widget is wired for Ryoku"
