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

compact="shell/modules/sidebarRight/CompactSidebarRightContent.qml"
sliders="shell/modules/sidebarRight/QuickSliders.qml"
classic="shell/modules/sidebarRight/quickToggles/ClassicQuickPanel.qml"

for prop in \
  "compactTightHeight" \
  "compactNarrowWidth" \
  "compactPanelPadding" \
  "compactContentPadding" \
  "compactRailWidth" \
  "compactRailMargin" \
  "compactNavItemHeight" \
  "compactNavBgHeight" \
  "compactNavSpacing" \
  "compactActionItemHeight" \
  "compactActionBgHeight" \
  "compactSectionSpacing" \
  "compactGridSpacing"; do
  assert_contains "$compact" "readonly property"
  assert_contains "$compact" "$prop"
done

assert_contains "$compact" "Layout.preferredWidth: root.compactRailWidth"
assert_contains "$compact" "readonly property int navItemH: root.compactNavItemHeight"
assert_contains "$compact" "readonly property int navBgH: root.compactNavBgHeight"
assert_contains "$compact" "readonly property int navSpacing: root.compactNavSpacing"
assert_contains "$compact" "implicitHeight: root.compactNavItemHeight"
assert_contains "$compact" "implicitHeight: root.compactActionItemHeight"
assert_contains "$compact" "height: root.compactActionBgHeight"
assert_contains "$compact" "root.compactSectionSpacing"
assert_contains "$compact" "compactItemSlotWidth:"
assert_contains "$compact" "compactSpacing:"
assert_contains "$compact" "controlsRoot.controlsAreaPadding"
assert_contains "$compact" "controlsRoot.controlsInlineGap"
assert_contains "$compact" "AngelPartialBorder { targetRadius: ccSurface.radius; visible: false }"
assert_contains "$sliders" "visible: !root.compactSurface && Appearance.angelEverywhere"
assert_contains "$classic" "property int compactItemSlotWidth: 48"
assert_contains "$classic" "property int compactSpacing: 8"
assert_contains "$classic" "root.compactMode ? root.compactItemSlotWidth : 52"
assert_contains "$classic" "root.compactMode ? root.compactSpacing : 12"

assert_not_contains "$compact" "Layout.preferredWidth: 56"
assert_not_contains "$compact" "readonly property int navItemH: 46"
assert_not_contains "$compact" "readonly property int navBgH: 38"
assert_not_contains "$compact" "readonly property int navSpacing: 4"

echo "PASS: compact sidebar spacing"
