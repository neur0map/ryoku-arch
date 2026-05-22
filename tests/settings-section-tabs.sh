#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
CONTENT_PAGE="$ROOT_DIR/shell/modules/common/widgets/ContentPage.qml"
SETTINGS_CARD="$ROOT_DIR/shell/modules/common/widgets/SettingsCardSection.qml"
SEARCH_REGISTRY="$ROOT_DIR/shell/modules/common/widgets/SettingsSearchRegistry.qml"
TOOLBAR_TAB_BUTTON="$ROOT_DIR/shell/modules/common/widgets/ToolbarTabButton.qml"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_file_contains() {
  local path="$1"
  local pattern="$2"
  local message="$3"

  grep -Eq "$pattern" "$path" || fail "$message"
}

assert_file_not_contains() {
  local path="$1"
  local pattern="$2"
  local message="$3"

  if grep -Eq "$pattern" "$path"; then
    fail "$message"
  fi
}

assert_file_contains "$CONTENT_PAGE" 'property var sectionTabSections: \[\]' \
  "ContentPage should own the registered settings section tabs"
assert_file_contains "$CONTENT_PAGE" 'property var sectionTabVisibleSections: \[\]' \
  "ContentPage should track visible section tabs without overwriting page visibility"
assert_file_contains "$CONTENT_PAGE" 'function registerSectionTab\(section\)' \
  "ContentPage should register direct SettingsCardSection children"
assert_file_contains "$CONTENT_PAGE" 'function activateSectionTab\(section\)' \
  "ContentPage should expose search activation for a section tab"
assert_file_contains "$CONTENT_PAGE" 'root\.currentSectionTab < 0' \
  "ContentPage should clamp startup tab state so one section is visibly selected"
assert_file_contains "$CONTENT_PAGE" 'previousSelectedSection' \
  "ContentPage should preserve the selected section when earlier conditional tabs hide"
assert_file_contains "$CONTENT_PAGE" 'function isDirectSectionTabChild\(item\)' \
  "ContentPage should avoid tabbing nested SettingsCardSection delegates"
assert_file_contains "$CONTENT_PAGE" 'function sectionTabChildOrder\(item\)' \
  "ContentPage should preserve the original visual order of settings sections"
assert_file_contains "$CONTENT_PAGE" 'sections\.sort\(function\(a, b\)' \
  "ContentPage should sort registered tabs by their layout order"
assert_file_contains "$CONTENT_PAGE" 'ToolbarTabBar[[:space:]]*\{' \
  "ContentPage should render a shared settings section tab strip"
assert_file_contains "$CONTENT_PAGE" 'tabButtonList: root\.sectionTabButtons' \
  "Settings section tabs should be driven by the registered section model"
assert_file_contains "$CONTENT_PAGE" 'wheelNavigationEnabled: false' \
  "Settings section tabs should allow page wheel scrolling instead of changing tabs"
assert_file_contains "$CONTENT_PAGE" 'visible: root\.sectionTabButtons\.length > 1' \
  "ContentPage should not show a one-tab tab strip"

assert_file_contains "$SETTINGS_CARD" 'property bool sectionTabsManaged: false' \
  "SettingsCardSection should know when ContentPage manages it as a tab panel"
assert_file_contains "$SETTINGS_CARD" 'property bool sectionTabsSelected: true' \
  "SettingsCardSection should expose selected state without using drawer expansion"
assert_file_contains "$SETTINGS_CARD" 'implicitHeight: root\.sectionTabsManaged && !root\.sectionTabsSelected \? 0 : card\.implicitHeight' \
  "SettingsCardSection should hide inactive tab panels without overwriting page-authored visible bindings"
assert_file_contains "$SETTINGS_CARD" 'Layout\.preferredHeight: root\.implicitHeight' \
  "SettingsCardSection should force layouts to collapse inactive tab panels"
assert_file_contains "$SETTINGS_CARD" 'Layout\.maximumHeight: root\.implicitHeight' \
  "SettingsCardSection should prevent inactive tab panels from reserving stale height"
assert_file_contains "$SETTINGS_CARD" 'readonly property bool sectionTabsRenderActive: !root\.sectionTabsManaged \|\| root\.sectionTabsSelected' \
  "SettingsCardSection should keep inactive tab panels visually dormant"
assert_file_contains "$SETTINGS_CARD" 'root\.collapsible && !root\.sectionTabsManaged' \
  "Tabbed SettingsCardSection headers should not keep drawer toggle affordances"
assert_file_contains "$SETTINGS_CARD" 'sectionTabsPage\.registerSectionTab\(root\)' \
  "SettingsCardSection should register itself with the surrounding ContentPage"
assert_file_contains "$SETTINGS_CARD" 'if \(!root\.sectionTabsManaged && SettingsSearchRegistry\.registerCollapsibleSection\)' \
  "Tabbed SettingsCardSections should not participate in drawer collapse search logic"
assert_file_contains "$SETTINGS_CARD" 'function activateFromSettingsSearch\(\)' \
  "SettingsCardSection should switch tabs before focusing search results"
assert_file_contains "$SETTINGS_CARD" 'sectionTabsPage\.activateSectionTab\(root\)' \
  "Search should activate the tab containing the matched setting"
assert_file_contains "$SEARCH_REGISTRY" 'activateAncestorsFromSettingsSearch\(control\)' \
  "Settings search should activate tab ancestors before focusing controls"
assert_file_contains "$SEARCH_REGISTRY" 'if \(!targetSection\)' \
  "Settings search should not collapse unrelated drawer sections when the target is a tab panel"
assert_file_contains "$TOOLBAR_TAB_BUTTON" 'visible: !root\.showLabel && root\.text\.length > 0' \
  "Icon-only compact section tabs should show a tooltip with the hidden tab label"

direct_section_count="$(rg -n '^\s*SettingsCardSection\s*\{' "$ROOT_DIR/shell/modules/settings" -g '*.qml' | wc -l)"
(( direct_section_count >= 100 )) || fail "Expected shared section-tab behavior to cover existing settings pages"

assert_file_not_contains "$ROOT_DIR/shell/modules/settings/QuickConfig.qml" 'SettingsCardSection[[:space:]]*\{' \
  "Quick should remain a hand-built true-tab page, not revert to drawer-backed sections"
