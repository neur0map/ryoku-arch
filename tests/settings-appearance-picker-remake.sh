#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local needle="$2"
  local message="$3"

  grep -Fq "$needle" "$ROOT_DIR/$file" || fail "$message"
}

assert_not_contains() {
  local file="$1"
  local needle="$2"
  local message="$3"

  ! grep -Fq "$needle" "$ROOT_DIR/$file" || fail "$message"
}

assert_before() {
  local file="$1"
  local first="$2"
  local second="$3"
  local message="$4"
  local first_line second_line

  first_line="$(grep -Fn "$first" "$ROOT_DIR/$file" | head -n1 | cut -d: -f1)"
  second_line="$(grep -Fn "$second" "$ROOT_DIR/$file" | head -n1 | cut -d: -f1)"
  [[ -n $first_line && -n $second_line ]] || fail "$message"
  (( first_line < second_line )) || fail "$message"
}

pane="shell/modules/controlcenter/appearance/AppearancePane.qml"

assert_not_contains "$pane" "SplitPaneLayout" \
  "appearance should not keep the old split pane layout"
assert_not_contains "$pane" "CollapsibleSection" \
  "appearance should not keep drawer-style sections"
assert_not_contains "$pane" "ThemeModeSection" \
  "appearance should not keep a drawer for one theme toggle"
assert_not_contains "$pane" "unfold_more" \
  "appearance should not keep expand-all drawer controls"

assert_contains "$pane" "component HeroPreview: StyledRect" \
  "appearance should start with a compact wallpaper preview"
assert_contains "$pane" "component AppearanceBoard: StyledRect" \
  "appearance should use a compact board with wallpaper and mode controls"
assert_contains "$pane" "component AppearanceStudio: StyledRect" \
  "appearance should use one top-level studio surface instead of separated floating islands"
assert_contains "$pane" "function setRandomWallpaper(): void" \
  "appearance picker should expose a real random wallpaper action"
assert_contains "$pane" "component ToneDock: AppearanceDock" \
  "appearance should group tone choices in a compact dock"
assert_contains "$pane" "component TuningDock: AppearanceDock" \
  "appearance should group tuning controls in a compact dock"
assert_contains "$pane" "component WallpaperDock: AppearanceDock" \
  "appearance should keep wallpaper picking in a compact dock"
assert_not_contains "$pane" "component SettingsDeck" \
  "appearance should not keep generic settings deck cards"
assert_not_contains "$pane" "SettingsDeck {" \
  "appearance should not render generic settings deck cards"
assert_not_contains "$pane" "PickerBoard {" \
  "appearance should not render the previous vertical picker board"
assert_not_contains "$pane" "PickerSection {" \
  "appearance should not render the previous section stack"
assert_not_contains "$pane" "component PickerBoard: StyledRect" \
  "appearance should remove the unused old picker board implementation"
assert_not_contains "$pane" "component PickerSection: ColumnLayout" \
  "appearance should remove the unused old picker section implementation"
assert_not_contains "$pane" "Layout.columnSpan: flickable.width > 720 ? 3 : 1" \
  "appearance should not split wallpaper into a narrow island at the compact window size"
assert_contains "$pane" "component ModeCard: StyledRect" \
  "appearance should use light and dark mode cards"
assert_contains "$pane" "component VariantPill: StyledRect" \
  "appearance should use compact variant chips"
assert_contains "$pane" "component SchemeSwatch: StyledRect" \
  "appearance should use compact scheme swatches"
assert_contains "$pane" "component CompactToggle: StyledRect" \
  "appearance should use compact toggles instead of long rows"
assert_contains "$pane" "component CompactRange: StyledRect" \
  "appearance should use compact range controls instead of long slider sections"
assert_contains "$pane" "WallpaperGrid {" \
  "appearance should keep wallpaper picking directly in the page"
assert_not_contains "$pane" "Layout.preferredHeight: 360" \
  "appearance should not keep the tall wallpaper block"
assert_contains "shell/modules/controlcenter/components/WallpaperGrid.qml" "property bool compact: false" \
  "wallpaper grid should expose a compact picker mode"
assert_contains "shell/modules/controlcenter/components/WallpaperGrid.qml" "readonly property int compactCellWidth" \
  "wallpaper grid compact mode should reduce thumbnail width"
assert_contains "$pane" "compact: true" \
  "appearance should use the dense wallpaper picker grid"

assert_contains "$pane" "Colours.setMode" \
  "appearance should preserve light and dark backend behavior"
assert_contains "$pane" "Wallpapers.setWallpaper(entry.path)" \
  "appearance random action should use the wallpaper service backend"
assert_contains "$pane" "Quickshell.execDetached([\"ryoku\", \"scheme\", \"set\", \"-v\", variant])" \
  "appearance should preserve variant backend behavior"
assert_contains "$pane" "Quickshell.execDetached([\"ryoku\", \"scheme\", \"set\", \"-n\", name, \"-f\", flavour])" \
  "appearance should preserve scheme backend behavior"
assert_contains "$pane" "GlobalConfig.appearance.transparency.enabled = root.transparencyEnabled" \
  "appearance should preserve transparency backend writes"
assert_contains "$pane" "GlobalConfig.appearance.font.family.sans = root.fontFamilySans" \
  "appearance should preserve font backend writes"
assert_contains "$pane" "GlobalConfig.background.desktopClock.position = root.desktopClockPosition" \
  "appearance should preserve desktop clock position writes"

echo "PASS: tests/settings-appearance-picker-remake.sh"
