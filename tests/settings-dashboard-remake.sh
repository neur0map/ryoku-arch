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

dashboard="shell/modules/controlcenter/dashboard/DashboardPane.qml"

assert_not_contains "$dashboard" "GeneralSection {" \
  "dashboard settings should not keep the old general settings section"
assert_not_contains "$dashboard" "PerformanceSection {" \
  "dashboard settings should not keep the old performance section"
assert_not_contains "$dashboard" "InnerBorder" \
  "dashboard settings should not keep the old inset bordered pane frontend"
assert_contains "$dashboard" "component ToggleTile: StyledRect" \
  "dashboard settings should expose compact toggle tiles"
assert_contains "$dashboard" "component RangeTile: StyledRect" \
  "dashboard settings should expose compact range controls"
assert_contains "$dashboard" "component ResourceChip: StyledRect" \
  "dashboard settings should expose resource chips instead of long buttons"
assert_contains "$dashboard" "component DashboardBoard: StyledRect" \
  "dashboard settings should use a compact top board instead of stacked full-width rows"
assert_contains "$dashboard" "component DashboardDock: StyledRect" \
  "dashboard settings should group secondary controls in compact docks"
assert_contains "$dashboard" "component TimingDock: DashboardDock" \
  "dashboard timing controls should be arranged as one compact dock"
assert_contains "$dashboard" "component ResourceDock: DashboardDock" \
  "dashboard resources should be arranged as one compact chip dock"
assert_contains "$dashboard" "columns: flickable.width > 620 ? 5 : 1" \
  "dashboard should keep a multi-column workbench inside the compact settings window"
assert_not_contains "$dashboard" "SettingsDeck {" \
  "dashboard should not render the old generic settings deck"
assert_not_contains "$dashboard" "implicitHeight: 78" \
  "dashboard toggle controls should not keep tall full-width row height"
assert_not_contains "$dashboard" "implicitHeight: 92" \
  "dashboard range controls should not keep tall full-width row height"
assert_not_contains "$dashboard" "columns: width > 760 ? 3 : 1" \
  "dashboard top controls should not collapse to one-column rows at the compact window size"
assert_contains "$dashboard" "GlobalConfig.dashboard.enabled = root.enabled" \
  "dashboard settings should preserve backend enabled writes"
assert_contains "$dashboard" "GlobalConfig.dashboard.showOnHover = root.showOnHover" \
  "dashboard settings should preserve backend hover writes"
assert_contains "$dashboard" "GlobalConfig.dashboard.mediaUpdateInterval = root.mediaUpdateInterval" \
  "dashboard settings should preserve backend media interval writes"
assert_contains "$dashboard" "GlobalConfig.dashboard.resourceUpdateInterval = root.resourceUpdateInterval" \
  "dashboard settings should preserve backend resource interval writes"
assert_contains "$dashboard" "GlobalConfig.dashboard.performance.showNetwork = root.showNetwork" \
  "dashboard settings should preserve backend resource visibility writes"

echo "PASS: tests/settings-dashboard-remake.sh"
