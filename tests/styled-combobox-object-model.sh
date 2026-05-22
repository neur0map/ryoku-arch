#!/bin/bash

set -euo pipefail
cd "$(dirname "$0")/.."

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"

  grep -Eq "$pattern" "$file" || fail "$message"
}

combo="shell/modules/common/widgets/StyledComboBox.qml"
display_configurator="shell/modules/settings/NiriDisplayConfigurator.qml"

assert_contains "$combo" 'readonly property string _selectedText' \
  "StyledComboBox should derive visible text for object-array models"
assert_contains "$combo" 'root\.model\[root\.currentIndex\]' \
  "StyledComboBox should read the selected model entry directly"
assert_contains "$combo" 'modelItem\[root\.textRole\]' \
  "StyledComboBox should use textRole for object-array selected text"
assert_contains "$combo" 'ColorUtils\.ensureReadable\(.*_bgColor' \
  "StyledComboBox text should stay readable against its own background"
assert_contains "$display_configurator" 'function displayActionTextColor' \
  "Display action buttons should calculate contrast-safe label colors"
assert_contains "$display_configurator" 'ColorUtils\.ensureReadable\(.*buttonColor' \
  "Display action labels should be readable on active and disabled button colors"

echo "PASS: StyledComboBox object-model visibility checks"
