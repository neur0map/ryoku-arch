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

assert_contains "$pane" "Colours.setMode" \
  "appearance should preserve light and dark backend behavior"
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
