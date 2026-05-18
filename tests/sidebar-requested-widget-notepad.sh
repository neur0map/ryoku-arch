#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_contains() {
  local path="$1"
  local needle="$2"

  grep -qF "$needle" "$path" || fail "$path should contain: $needle"
}

assert_not_contains() {
  local path="$1"
  local needle="$2"

  ! grep -qF "$needle" "$path" || fail "$path should not contain: $needle"
}

global_states="shell/GlobalStates.qml"
tool_registry="shell/modules/bar/threeIsland/dynamicIsland/tools/ToolRegistry.qml"
bottom_group="shell/modules/sidebarRight/BottomWidgetGroup.qml"
compact_sidebar="shell/modules/sidebarRight/CompactSidebarRightContent.qml"
notepad_widget="shell/modules/sidebarRight/notepad/NotepadWidget.qml"

assert_contains "$global_states" "property string sidebarRightRequestedWidget: \"\""

assert_contains "$tool_registry" "GlobalStates.sidebarRightRequestedWidget = \"notepad\""
assert_not_contains "$tool_registry" "Persistent.states.sidebar.bottomGroup.tab = 2"

assert_contains "$bottom_group" "function handleRequestedWidget(): void"
assert_contains "$bottom_group" "const w = GlobalStates.sidebarRightRequestedWidget"
assert_contains "$bottom_group" "const idx = root.tabs.findIndex(t => t.type === w)"
assert_contains "$bottom_group" "root.setCollapsed(false)"
assert_contains "$bottom_group" "Persistent.states.sidebar.bottomGroup.tab = idx"
assert_contains "$bottom_group" "GlobalStates.sidebarRightRequestedWidget = \"\""
assert_contains "$bottom_group" "function onSidebarRightRequestedWidgetChanged()"

assert_contains "$compact_sidebar" "function handleRequestedWidget(): void"
assert_contains "$compact_sidebar" "const idx = root.sections.findIndex(s => s.id === w)"
assert_contains "$compact_sidebar" "if (idx !== -1) root.activeSection = idx"
assert_contains "$compact_sidebar" "GlobalStates.sidebarRightRequestedWidget = \"\""
assert_contains "$compact_sidebar" "function onSidebarRightRequestedWidgetChanged()"

assert_contains "$notepad_widget" "selectionColor: Appearance.angelEverywhere ? Appearance.angel.colPrimary"
assert_contains "$notepad_widget" ": Appearance.ryokuEverywhere ? Appearance.ryoku.colPrimary"
assert_contains "$notepad_widget" "selectedTextColor: Appearance.angelEverywhere ? Appearance.angel.colOnPrimary"
assert_contains "$notepad_widget" ": Appearance.ryokuEverywhere ? Appearance.ryoku.colOnPrimary"
assert_contains "$notepad_widget" "persistentSelection: true"
assert_contains "$notepad_widget" "TextInputContextMenu {"
assert_contains "$notepad_widget" "target: textArea"
assert_not_contains "$notepad_widget" "Appearance.inirEverywhere"

echo "PASS: sidebar requested widget and notepad context menu are wired"
