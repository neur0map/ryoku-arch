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

settings="shell/modules/controlcenter/launcher/Settings.qml"
pane="shell/modules/controlcenter/launcher/LauncherPane.qml"

assert_not_contains "$settings" "SectionContainer" \
  "launcher settings should not keep generic section containers"
assert_not_contains "$settings" "SectionHeader" \
  "launcher settings should not keep generic section headers"
assert_not_contains "$settings" "ToggleRow" \
  "launcher settings should not keep long toggle rows"
assert_not_contains "$settings" "PropertyRow" \
  "launcher settings should not keep read-only property rows"
assert_not_contains "$pane" "SwitchRow" \
  "launcher app details should not keep long switch rows"

assert_contains "$settings" "component LauncherConsole: StyledRect" \
  "launcher settings should expose a compact launcher console"
assert_contains "$settings" "component LauncherToggle: StyledRect" \
  "launcher settings should expose compact launcher toggle tiles"
assert_contains "$settings" "component LauncherMetric: StyledRect" \
  "launcher settings should expose compact read-only metrics"
assert_contains "$settings" "component FuzzyLane: StyledRect" \
  "launcher settings should expose fuzzy search lanes"
assert_contains "$pane" "component LauncherAppRail: ColumnLayout" \
  "launcher should expose a compact app rail instead of a padded generic left pane"
assert_contains "$pane" "component AppDetailsWorkbench: StyledRect" \
  "launcher app details should use a compact workbench"
assert_contains "$pane" "component AppFlagChip: StyledRect" \
  "launcher app details should expose compact app flag chips"
assert_contains "$pane" "leftWidthRatio: 0.34" \
  "launcher should not reserve half of the compact settings window for the app list"
assert_contains "$pane" "leftMinimumWidth: 300" \
  "launcher app list should fit the compact window"
assert_contains "$settings" "Layout.minimumWidth: 200" \
  "launcher settings preview should leave enough room for readable toggle tiles"
assert_contains "$settings" "visible: tile.width > 150" \
  "launcher toggle detail text should collapse before it clips"
assert_not_contains "$pane" "implicitSize: Tokens.font.size.extraLarge * 3 * 2" \
  "launcher app details should not keep the oversized centered app icon"

assert_contains "$settings" "GlobalConfig.launcher.enabled = checked" \
  "launcher settings should preserve enabled backend writes"
assert_contains "$settings" "GlobalConfig.launcher.showOnHover = checked" \
  "launcher settings should preserve hover backend writes"
assert_contains "$settings" "GlobalConfig.launcher.useFuzzy.apps = checked" \
  "launcher settings should preserve fuzzy app backend writes"
assert_contains "$settings" "GlobalConfig.launcher.enableDangerousActions = checked" \
  "launcher settings should preserve dangerous action backend writes"
assert_contains "$pane" "GlobalConfig.launcher.favouriteApps = favouriteApps" \
  "launcher app details should preserve favourite backend writes"
assert_contains "$pane" "GlobalConfig.launcher.hiddenApps = hiddenApps" \
  "launcher app details should preserve hidden backend writes"

echo "PASS: tests/settings-launcher-control-remake.sh"
