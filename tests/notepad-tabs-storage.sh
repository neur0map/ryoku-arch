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

assert_block_not_contains() {
  local block="$1"
  local needle="$2"
  local description="$3"

  [[ $block != *"$needle"* ]] || fail "$description should not contain: $needle"
}

assert_block_contains() {
  local block="$1"
  local needle="$2"
  local description="$3"

  [[ $block == *"$needle"* ]] || fail "$description should contain: $needle"
}

assert_no_legacy_tokens() {
  local path="$1"
  local pattern

  pattern="$(printf '%s' 'i''NiR')|$(printf '%s' 'A''ppearance\.i''nir')|$(printf '%s' 'snow''arch')|$(printf '%s' 'Dank''Material''Shell')|$(printf '%s' 'for i''i')|$(printf '%s' 'current''Tab')|$(printf '%s' 'add''Tab')|$(printf '%s' 'remove''Tab')|$(printf '%s' 'set''Tab''Title')"

  ! rg -n "$pattern" "$path" >/dev/null \
    || fail "$path should not contain legacy upstream tokens"
}

service="shell/services/Notepad.qml"
widget="shell/modules/sidebarRight/notepad/NotepadWidget.qml"
self="tests/notepad-tabs-storage.sh"
tabs_loaded_block="$(sed -n '/id: tabsFileView/,/onLoadFailed:/p' "$service")"
activate_tab_block="$(sed -n '/function activateTab(index)/,/^    }/p' "$service")"

# shellcheck disable=SC2016
assert_contains "$service" 'readonly property string tabsFilePath: `${Directories.stateUserPath}/notepad-tabs.json`'
assert_contains "$service" "readonly property string legacyFilePath: Directories.notepadPath"
assert_contains "$service" "property int activeTab: 0"
assert_contains "$service" "property var tabs: [{ title: \"Note 1\", text: \"\" }]"
assert_contains "$service" "readonly property string text: (tabs[activeTab]?.text) ?? \"\""
assert_contains "$service" "function setTextValue(newText)"
assert_contains "$service" "function createTab(title = \"\")"
assert_contains "$service" "function deleteTab(index)"
assert_contains "$service" "function renameTab(index, title)"
assert_contains "$service" "function activateTab(index)"
assert_contains "$service" "JSON.stringify({ activeTab: activeTab, tabs: tabs })"
assert_contains "$service" "root.activeTab = root._clampTabIndex(data.activeTab ?? 0, root.tabs.length)"
assert_contains "$service" "legacyFileView.reload()"
assert_contains "$service" "root.tabs = [{ title: \"Note 1\", text: content || \"\" }]"
assert_contains "$service" "root._saveTabs()"
assert_contains "$service" "property string _pendingSaveText: \"\""
assert_contains "$service" "id: ensureTabsDirectoryProc"
assert_contains "$service" "command: [\"/usr/bin/mkdir\", \"-p\", root.tabsFilePath.substring(0, root.tabsFilePath.lastIndexOf('/'))]"
assert_contains "$service" "tabsFileView.setText(root._pendingSaveText)"
assert_not_contains "$service" "Process.exec"

assert_contains "$widget" "readonly property int tabCount: Notepad.tabs.length"
assert_contains "$widget" "function saveCurrentText()"
assert_contains "$widget" "function commitTabRename(index, title)"
assert_contains "$widget" "Repeater {"
assert_contains "$widget" "model: Notepad.tabs"
assert_contains "$widget" "readonly property bool active: index === Notepad.activeTab"
assert_contains "$widget" "root.saveCurrentText()"
assert_contains "$widget" "Notepad.activateTab(tabPill.index)"
assert_contains "$widget" "Notepad.createTab()"
assert_contains "$widget" "Notepad.deleteTab(tabPill.index)"
assert_contains "$widget" "Notepad.renameTab(index, title)"
assert_contains "$widget" "TextInputContextMenu {"
assert_contains "$widget" "target: textArea"

assert_not_contains "$service" "property string filePath: Directories.notepadPath"
assert_not_contains "$service" "notepadFileView"
assert_block_not_contains "$tabs_loaded_block" "legacyFileView.reload()" "canonical tabs load path"
assert_block_contains "$tabs_loaded_block" "root._resetTabs()" "invalid canonical tabs fallback"
assert_block_contains "$activate_tab_block" "activeTab = index" "active tab persistence path"
assert_block_contains "$activate_tab_block" "root._saveTabs()" "active tab persistence path"

for path in "$service" "$widget" "$self"; do
  assert_no_legacy_tokens "$path"
done

echo "PASS: notepad tabs storage and UI wiring are Ryoku-named"
