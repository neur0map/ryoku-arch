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

assert_contains "shell/modules/controlcenter/NavRail.qml" "property string searchText" \
  "settings navigation should expose a search query"
assert_contains "shell/modules/controlcenter/NavRail.qml" "StyledTextField" \
  "settings navigation should use the shared text field for search"
assert_contains "shell/modules/controlcenter/NavRail.qml" "function paneMatches" \
  "settings navigation should filter real panes, not just groups"
assert_contains "shell/modules/controlcenter/NavRail.qml" "for (let groupIndex = 0; groupIndex < PaneRegistry.groups.length; groupIndex++)" \
  "settings navigation should group filtered panes by registry groups"
assert_contains "shell/modules/controlcenter/NavRail.qml" "model: root.filteredPanes" \
  "settings navigation should render filtered pane entries"
assert_contains "shell/modules/controlcenter/NavRail.qml" "PaneRegistry.groupDescription" \
  "settings navigation should keep group context visible"
assert_contains "shell/modules/controlcenter/NavRail.qml" "text: item.entry.description" \
  "settings navigation should show pane-specific descriptions"
assert_not_contains "shell/modules/controlcenter/NavRail.qml" "component CategoryItem" \
  "settings navigation should no longer be the old four category buttons"

assert_contains "shell/modules/controlcenter/Panes.qml" "readonly property string relatedLabel" \
  "settings pane chrome should name related panes without owning backend state"
assert_contains "shell/modules/controlcenter/Panes.qml" "root.session.active = tab.modelData.label" \
  "settings pane tabs should preserve existing Session routing"
assert_contains "shell/modules/controlcenter/Panes.qml" "color: Colours.palette.m3surfaceContainerLow" \
  "settings viewport should avoid the old over-blurred transparent surface"

assert_contains "shell/modules/controlcenter/WindowFactory.qml" "color: Colours.palette.m3surface" \
  "floating settings window should use an opaque base surface"
assert_contains "shell/modules/controlcenter/WindowTitle.qml" "color: Colours.palette.m3surfaceContainer" \
  "floating settings title bar should use an opaque base surface"
assert_contains "shell/modules/controlcenter/components/SettingsHeader.qml" "color: Colours.palette.m3surfaceContainerHigh" \
  "shared settings headers should use compact material header cards"

echo "PASS: tests/settings-controlcenter-redesign.sh"
