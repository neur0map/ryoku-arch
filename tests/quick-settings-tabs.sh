#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
QUICK_CONFIG="$ROOT_DIR/shell/modules/settings/QuickConfig.qml"
TOOLBAR_TAB_BAR="$ROOT_DIR/shell/modules/common/widgets/ToolbarTabBar.qml"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_contains() {
  local pattern="$1"
  local message="$2"

  grep -Eq "$pattern" "$QUICK_CONFIG" || fail "$message"
}

assert_file_contains() {
  local path="$1"
  local pattern="$2"
  local message="$3"

  grep -Eq "$pattern" "$path" || fail "$message"
}

assert_count() {
  local pattern="$1"
  local expected="$2"
  local message="$3"
  local count

  count="$(grep -Ec "$pattern" "$QUICK_CONFIG" || true)"
  (( count == expected )) || fail "$message (expected $expected, got $count)"
}

assert_contains 'id: quickPage' \
  "Quick page should expose a stable id for tab state"
assert_contains 'property int currentQuickTab: 0' \
  "Quick page should track the selected quick sub-tab"
assert_contains 'ToolbarTabBar[[:space:]]*\{' \
  "Quick page should render top-level sub-tabs"
assert_contains 'tabButtonList: quickPage\.quickTabs' \
  "Quick tab bar should be driven by the shared tab model"
assert_contains 'onCurrentIndexChanged: quickPage\.currentQuickTab = currentIndex' \
  "Quick tab changes should update the visible content"
assert_contains 'wheelNavigationEnabled: false' \
  "Quick tabs should let page scrolling pass through instead of changing tabs"
assert_contains 'initialIndex: quickPage\.currentQuickTab' \
  "Quick tabs should mark the first tab selected on initial render"
assert_file_contains "$TOOLBAR_TAB_BAR" 'property int initialIndex: 0' \
  "Toolbar tab bar should expose a stable initial selected index"
assert_file_contains "$TOOLBAR_TAB_BAR" 'setCurrentIndex\(root\.initialIndex\)' \
  "Toolbar tab bar should apply the initial selected index after creation"
assert_file_contains "$TOOLBAR_TAB_BAR" 'property bool wheelNavigationEnabled: true' \
  "Toolbar tab bar should expose an opt-out for wheel navigation"
assert_file_contains "$TOOLBAR_TAB_BAR" 'enabled: root\.wheelNavigationEnabled' \
  "Toolbar tab bar wheel handler should honor the opt-out"
assert_file_contains "$ROOT_DIR/shell/modules/common/widgets/SettingsSearchRegistry.qml" 'activateFromSettingsSearch' \
  "Settings search should activate tab panels before scrolling to hidden controls"

for label in "Wallpaper & Colors" "Bar & screen" "Game Mode" "Quick Actions"; do
  assert_contains "Translation\\.tr\\(\"$label\"\\)" \
    "Quick tab label '$label' should still exist"
done

if grep -Eq 'SettingsCardSection[[:space:]]*\{' "$QUICK_CONFIG"; then
  fail "Quick page should not use drawer-backed SettingsCardSection components"
fi

if grep -Eq '(^|[[:space:]])collapsible:' "$QUICK_CONFIG"; then
  fail "Quick page should not keep collapsible drawer flags"
fi

if grep -Eq '(^|[[:space:]])expanded:' "$QUICK_CONFIG"; then
  fail "Quick page should not keep expanded/collapsed drawer state"
fi

assert_count 'QuickTabPanel[[:space:]]*\{' 4 \
  "Quick page should render four true tab panels"
assert_count 'quickTabIndex: [0-3]' 4 \
  "Each quick section should be tied to one top sub-tab"
assert_contains 'visible: quickPage\.currentQuickTab === quickTabIndex' \
  "Quick tab panels should show only the selected tab content"
assert_count 'function activateFromSettingsSearch\(\)' 1 \
  "Quick tab panels should expose one search activation hook"
assert_contains 'color: SettingsMaterialPreset\.cardColor' \
  "Quick tab panel should inherit the active settings style card color"
assert_contains 'border\.color: SettingsMaterialPreset\.cardBorderColor' \
  "Quick tab panel should inherit the active settings style border color"
assert_contains 'topLeftRadius: panelRoot\.radius' \
  "Quick tab panel header wash should preserve the rounded top-left corner"
assert_contains 'topRightRadius: panelRoot\.radius' \
  "Quick tab panel header wash should preserve the rounded top-right corner"
assert_contains 'color: SettingsMaterialPreset\.iconExpandedColor' \
  "Quick tab panel icons should inherit the active settings style accent color"
assert_contains 'color: SettingsMaterialPreset\.titleExpandedColor' \
  "Quick tab panel title should inherit the active settings style text color"

quick_panel_source="$(sed -n '/component QuickTabPanel:/,/ToolbarTabBar[[:space:]]*{/p' "$QUICK_CONFIG")"
if grep -Eq 'Appearance\.(ryokuEverywhere|auroraEverywhere|angelEverywhere)|Appearance\.(ryoku|aurora|angel)\.' <<<"$quick_panel_source"; then
  fail "Quick tab panel shell should not hard-code Ryoku/Aurora/Angel style colors"
fi

for preserved_label in \
  "Derive theme colors from backdrop" \
  "Bar position" \
  "Screen round corner" \
  "Auto-detect fullscreen" \
  "Disable Discover overlay" \
  "Reload shell" \
  "Shortcuts" \
  "Confirm before closing windows"; do
  assert_contains "Translation\\.tr\\(\"$preserved_label\"\\)" \
    "Existing Quick feature '$preserved_label' should be preserved"
done
