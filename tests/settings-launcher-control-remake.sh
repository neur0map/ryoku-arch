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
assert_contains "$pane" "component AppFlagChip: StyledRect" \
  "launcher app details should expose compact app flag chips"

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
