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
assert_not_contains "shell/modules/controlcenter/NavRail.qml" "text: item.entry.description" \
  "settings navigation should use compact pane entries without bulky descriptions"
assert_not_contains "shell/modules/controlcenter/NavRail.qml" "component CategoryItem" \
  "settings navigation should no longer be the old four category buttons"
assert_contains "shell/modules/controlcenter/ControlCenter.qml" "implicitWidth: Math.min(screen.width * 0.62, 1220)" \
  "settings window should default to a compact width"
assert_contains "shell/modules/controlcenter/ControlCenter.qml" "implicitHeight: Math.min(screen.height * 0.58, 820)" \
  "settings window should default to a compact height"
assert_not_contains "shell/modules/controlcenter/ControlCenter.qml" "screen.width * 0.84" \
  "settings window should not keep the old oversized width"
assert_not_contains "shell/modules/controlcenter/ControlCenter.qml" "screen.height * 0.78" \
  "settings window should not keep the old oversized height"
assert_contains "shell/modules/controlcenter/ControlCenter.qml" "ColumnLayout {" \
  "settings frame should use a top-navigation column layout"
assert_not_contains "shell/modules/controlcenter/ControlCenter.qml" "columns: 2" \
  "settings frame should not keep the old left-sidebar grid"
assert_not_contains "shell/modules/controlcenter/ControlCenter.qml" "implicitWidth: navRail.implicitWidth" \
  "settings navigation should not reserve a fixed left rail"
assert_contains "shell/modules/controlcenter/NavRail.qml" "implicitHeight: navLayout.implicitHeight + Tokens.padding.normal * 2" \
  "settings navigation should be a compact top strip"
assert_contains "shell/modules/controlcenter/NavRail.qml" "readonly property string activeGroup" \
  "settings navigation should pivot around registry groups in the top strip"
assert_contains "shell/modules/controlcenter/NavRail.qml" "component GroupPill: StyledRect" \
  "settings navigation should expose compact group pills"
assert_contains "shell/modules/controlcenter/NavRail.qml" "component PaneChip: StyledRect" \
  "settings navigation should expose compact pane chips"
assert_contains "shell/modules/controlcenter/NavRail.qml" "contentWidth: paneStrip.implicitWidth" \
  "settings pane choices should use a horizontal strip"
assert_not_contains "shell/modules/controlcenter/NavRail.qml" "component PaneItem" \
  "settings navigation should not keep the old vertical pane item"
assert_not_contains "shell/modules/controlcenter/NavRail.qml" "text: item.entry.description" \
  "settings navigation should not keep bulky description rows"

assert_not_contains "shell/modules/controlcenter/Panes.qml" "relatedFlickable" \
  "settings pane chrome should not duplicate top navigation tabs"
assert_not_contains "shell/modules/controlcenter/Panes.qml" "root.session.active = tab.modelData.label" \
  "settings pane chrome should not own pane navigation anymore"
assert_contains "shell/modules/controlcenter/Panes.qml" "color: Colours.palette.m3surfaceContainerLow" \
  "settings viewport should avoid the old over-blurred transparent surface"
assert_contains "shell/modules/controlcenter/Panes.qml" "id: activePaneLoader" \
  "settings panes should load the active pane directly"
assert_contains "shell/modules/controlcenter/Panes.qml" "activePaneLoader.setSource(root.activeComponent, {" \
  "settings pane switching should preserve existing pane backend properties"
assert_not_contains "shell/modules/controlcenter/Panes.qml" "model: PaneRegistry.count" \
  "settings panes should not keep the old stacked scrolling frontend"
assert_not_contains "shell/modules/controlcenter/Panes.qml" "y: -root.session.activeIndex * viewport.height" \
  "settings pane switching should not look like vertical scrolling"
assert_not_contains "shell/modules/controlcenter/Panes.qml" "Behavior on y" \
  "settings pane switching should not animate by scrolling the stack"

assert_contains "shell/modules/controlcenter/WindowFactory.qml" "color: Colours.palette.m3surface" \
  "floating settings window should use an opaque base surface"
assert_contains "shell/modules/controlcenter/WindowTitle.qml" "color: Colours.palette.m3surfaceContainer" \
  "floating settings title bar should use an opaque base surface"
assert_contains "shell/modules/controlcenter/components/SettingsHeader.qml" "color: Colours.palette.m3surfaceContainerHigh" \
  "shared settings headers should use compact material header cards"

echo "PASS: tests/settings-controlcenter-redesign.sh"
