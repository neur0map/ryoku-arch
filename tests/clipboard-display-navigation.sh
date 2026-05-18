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

string_utils="shell/modules/common/functions/StringUtils.qml"
clipboard_panel="shell/modules/clipboard/ClipboardPanel.qml"
clipboard_item="shell/modules/clipboard/ClipboardItem.qml"

assert_contains "$string_utils" "function stripHtmlTags"
assert_contains "$string_utils" ".replace(/<[^>]*>/g, \"\")"
assert_contains "$string_utils" ".replace(/&nbsp;/gi, \" \")"
assert_contains "$string_utils" "function sanitizeDisplayText"
assert_contains "$string_utils" ".replace(/[\\u200B\\u200C\\u200D\\uFEFF\\u00AD]/g, \"\")"
assert_contains "$string_utils" ".replace(/\\u00A0/g, \" \")"

assert_contains "$clipboard_panel" "property int matchCount: 0"
assert_contains "$clipboard_panel" "property bool navigateMode: false"
assert_contains "$clipboard_panel" "property double _lastPanelCopyTime: 0"
assert_contains "$clipboard_panel" "StringUtils.stripHtmlTags(cleaned)"
assert_contains "$clipboard_panel" "StringUtils.sanitizeDisplayText(cleaned)"
assert_contains "$clipboard_panel" "filteredClipboardModel.append({ \"rawEntry\": entry, \"isMatch\": hit })"
assert_contains "$clipboard_panel" "filteredClipboardModel.append({ \"rawEntry\": entry, \"isMatch\": true })"
assert_contains "$clipboard_panel" "matchCount = matches"
assert_contains "$clipboard_panel" "function jumpToNextMatch()"
assert_contains "$clipboard_panel" "function jumpToPrevMatch()"
assert_contains "$clipboard_panel" "event.key === Qt.Key_Tab && root.navigateMode"
assert_contains "$clipboard_panel" "event.key === Qt.Key_Backtab && root.navigateMode"
assert_contains "$clipboard_panel" "root.navigateMode = !root.navigateMode"
assert_contains "$clipboard_panel" "root.matchCount + \" \" + Translation.tr(\"matches\")"
assert_contains "$clipboard_panel" "Date.now() - root._lastPanelCopyTime > 5000"
assert_contains "$clipboard_panel" "required property bool isMatch"
assert_contains "$clipboard_panel" "isSearchMatch: isMatch"
assert_contains "$clipboard_panel" "root.copyEntry(rawEntry)"
assert_not_contains "$clipboard_panel" "Cliphist.copy(rawEntry)"
assert_not_contains "$clipboard_panel" "Appearance.i""nirEverywhere"

assert_contains "$clipboard_item" "property bool isSearchMatch: true"
assert_contains "$clipboard_item" "opacity: root.isSearchMatch ? 1.0 : 0.35"

echo "PASS: clipboard display navigation upstream fixes are wired"
