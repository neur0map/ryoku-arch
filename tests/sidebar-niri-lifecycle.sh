#!/bin/bash

set -euo pipefail
cd "$(dirname "$0")/.."

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local text="$2"
  local message="$3"

  rg -nF -- "$text" "$file" >/dev/null || fail "$message"
}

right_shell="shell/modules/sidebarRight/SidebarRight.qml"
right_content="shell/modules/sidebarRight/SidebarRightContent.qml"
left_shell="shell/modules/sidebarLeft/SidebarLeft.qml"

assert_contains "$right_shell" 'active: GlobalStates.sidebarRightOpen' \
  "right sidebar content should load immediately when opened"
assert_contains "$right_shell" '|| ((Config?.options?.sidebar?.keepRightSidebarLoaded ?? true) && !CompositorService.isNiri)' \
  "right sidebar should not preload closed content on Niri"
assert_contains "$right_shell" 'target: "sidebarRight"' \
  "right sidebar IPC target should stay available"
assert_contains "$right_shell" 'function open(): void' \
  "right sidebar IPC open action should stay available"
assert_contains "$right_shell" 'function close(): void' \
  "right sidebar IPC close action should stay available"
assert_contains "$right_content" 'layer.enabled: GlobalStates.sidebarRightOpen && !gameModeMinimal' \
  "right sidebar opacity mask should only run while visible"
assert_contains "$left_shell" 'visible: true' \
  "left sidebar layer-shell surface should stay mapped"
assert_contains "$left_shell" 'item: GlobalStates.sidebarLeftOpen ? _fullMask : _emptyMask' \
  "left sidebar should close via mask instead of unmapping"
assert_contains "$left_shell" 'active: CompositorService.isHyprland && GlobalStates.sidebarLeftOpen' \
  "left sidebar focus grab should follow open state"

echo "PASS: sidebar Niri lifecycle checks"
