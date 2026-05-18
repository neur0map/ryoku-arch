#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_file() {
  local path="$1"

  [[ -f $path ]] || fail "missing file: $path"
}

assert_absent() {
  local path="$1"

  [[ ! -e $path ]] || fail "unexpected file exists: $path"
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

assert_matches() {
  local path="$1"
  local pattern="$2"

  rg -q "$pattern" "$path" || fail "$path should match: $pattern"
}

assert_not_matches() {
  local path="$1"
  local pattern="$2"
  local message="$3"

  ! rg -q "$pattern" "$path" || fail "$message"
}

global_states="shell/GlobalStates.qml"
sidebar_left="shell/modules/sidebarLeft/SidebarLeft.qml"
sidebar_content="shell/modules/sidebarLeft/SidebarLeftContent.qml"
ai_chat="shell/modules/sidebarLeft/AiChat.qml"
api_indicator="shell/modules/sidebarLeft/ApiInputBoxIndicator.qml"
launcher="shell/scripts/ryoku-shell"

assert_file "$global_states"
assert_file "$sidebar_left"
assert_file "$sidebar_content"
assert_file "$ai_chat"
assert_file "$api_indicator"
assert_file "$launcher"
assert_absent "shell/aiChat.qml"

assert_contains "$global_states" "property bool sidebarLeftExpanded: false"
assert_contains "$global_states" "property bool aiChatDetached: false"

assert_contains "$sidebar_left" "pluginViewActive || GlobalStates.sidebarLeftExpanded"
assert_contains "$sidebar_left" "GlobalStates.sidebarLeftExpanded = false"
assert_contains "$sidebar_left" "active: GlobalStates.aiChatDetached"
assert_contains "$sidebar_left" "FloatingWindow {"
assert_contains "$sidebar_left" "title: \"Ryoku AI Chat\""
assert_contains "$sidebar_left" "GlobalStates.aiChatDetached = false"
assert_contains "$sidebar_left" "function detach(): void"
assert_contains "$sidebar_left" "function attach(): void"
assert_contains "$sidebar_left" "GlobalStates.aiChatDetached = true"
assert_contains "$sidebar_left" "AiChat {"

assert_contains "$sidebar_content" "event.key === Qt.Key_O"
assert_contains "$sidebar_content" "GlobalStates.sidebarLeftExpanded = !GlobalStates.sidebarLeftExpanded"
assert_contains "$sidebar_content" "event.key === Qt.Key_P"
assert_contains "$sidebar_content" "GlobalStates.aiChatDetached = true"
assert_contains "$sidebar_content" "GlobalStates.sidebarLeftOpen = false"
assert_contains "$sidebar_content" "GlobalStates.sidebarLeftExpanded = false"
assert_not_contains "$sidebar_content" "Quickshell.execDetached"

assert_contains "$ai_chat" "Ctrl+O to expand the sidebar"
assert_contains "$ai_chat" "Ctrl+P to detach sidebar into a window"
assert_contains "$ai_chat" "Ask %1 anything..."
assert_contains "$ai_chat" "Select a model to start chatting"
assert_contains "$ai_chat" "messageInputField.text = root.commandPrefix + \"model \""
assert_contains "$ai_chat" "messageInputField.text = root.commandPrefix + \"tool \""
assert_contains "$ai_chat" "GlobalStates.settingsOverlayRequestedPage = 7"
assert_contains "$ai_chat" "GlobalStates.settingsOverlayOpen = true"
assert_contains "$api_indicator" "property var clickAction"
assert_contains "$api_indicator" "readonly property bool interactive"
assert_contains "$api_indicator" "expand_more"
assert_contains "$api_indicator" "Qt.PointingHandCursor"

assert_contains "$launcher" "ryoku-shell sidebarLeft detach"
assert_contains "$launcher" "sidebar-left) printf '%s\\n' \"sidebarLeft\""
assert_not_matches "$launcher" "aiChat\\.qml" "ryoku-shell should not launch a root AI chat file"

touched_files=(
  "$global_states"
  "$sidebar_left"
  "$sidebar_content"
  "$ai_chat"
  "$api_indicator"
  "$launcher"
)

legacy_brand="i""NiR"
legacy_brand_alt="I""nir"
legacy_cmd="i""nir"
legacy_upper="I""NIR"
legacy_pattern="$legacy_brand|$legacy_brand_alt|$legacy_upper|scripts/$legacy_cmd|Appearance\\.$legacy_cmd""Everywhere|\\b$legacy_cmd\\b|/$legacy_cmd"

for path in "${touched_files[@]}"; do
  assert_not_matches "$path" "$legacy_pattern" "$path should use Ryoku naming only"
done

echo "PASS: sidebar AI expand and detach UX are wired"
