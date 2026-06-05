#!/bin/bash

set -euo pipefail
cd "$(dirname "$0")/.."

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"

  [[ -f $file ]] || fail "missing file: $file"
  if ! grep -Eq "$pattern" "$file"; then
    fail "$message"
  fi
}

assert_not_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"

  [[ -f $file ]] || fail "missing file: $file"
  if grep -Eq "$pattern" "$file"; then
    fail "$message"
  fi
}

assert_contains shell/components/DrawerVisibilities.qml 'property bool obsidian' \
  "drawer visibility state should include an Obsidian notes panel"
assert_contains shell/components/DrawerVisibilities.qml 'obsidian = false' \
  "transient drawer clearing should hide the Obsidian panel"
assert_contains shell/modules/drawers/Panels.qml 'import qs\.modules\.obsidian as Obsidian' \
  "drawer panels should import the Obsidian module"
assert_contains shell/modules/drawers/Panels.qml 'readonly property alias obsidian: obsidian' \
  "drawer panels should expose the Obsidian panel for frame regions"
assert_contains shell/modules/drawers/Panels.qml 'Obsidian\.Wrapper \{' \
  "drawer panels should instantiate the Obsidian wrapper"
assert_contains shell/modules/drawers/Panels.qml 'anchors\.bottom: parent\.bottom' \
  "Obsidian drawer should attach to the clock/date corner"
assert_contains shell/modules/drawers/Panels.qml 'anchors\.left: parent\.left' \
  "Obsidian drawer should attach to the taskbar-side corner"
assert_contains shell/modules/obsidian/Wrapper.qml 'anchors\.bottomMargin: \(-implicitHeight - 5\) \* offsetScale' \
  "Obsidian wrapper should slide in from the clock/date edge"
assert_contains shell/modules/drawers/ContentWindow.qml 'id: obsidianBg' \
  "content window should give Obsidian the native frame blob wrapper"
assert_contains shell/modules/drawers/ContentWindow.qml 'obsidian\.transform: Matrix4x4' \
  "Obsidian panel should receive the frame deformation transform"
assert_contains shell/modules/drawers/ContentWindow.qml 'visibilities\.obsidian' \
  "Obsidian drawer should participate in focus and fullscreen clearing"
assert_contains shell/modules/drawers/Regions.qml 'panel: root\.panels\.obsidian' \
  "input regions should subtract the Obsidian panel surface"
assert_contains shell/modules/drawers/Interactions.qml 'property bool obsidianShortcutActive' \
  "drawer interactions should track Obsidian hover ownership"
assert_contains shell/modules/bar/Bar.qml 'function isClockHover\(y: real\)' \
  "bar should expose a clock/date hover helper for the Obsidian drawer"
assert_contains shell/modules/bar/BarWrapper.qml 'function isClockHover\(y: real\)' \
  "bar wrapper should expose clock/date hover detection to drawer interactions"
assert_contains shell/modules/drawers/Interactions.qml 'function inObsidianPanel' \
  "drawer interactions should separate Obsidian activation from the full open panel"
assert_contains shell/modules/drawers/Interactions.qml 'bar\.isClockHover\(y\)' \
  "Obsidian closed-state hover activation should target the taskbar clock/date entry"
assert_contains shell/modules/drawers/Interactions.qml 'const showObsidian = !visibilities\.settings && inObsidianPanel\(panels\.obsidian, x, y\)' \
  "taskbar-corner hover should use the constrained Obsidian activation helper"
assert_contains shell/modules/drawers/Interactions.qml '!showObsidian' \
  "bar popouts should not steal the Obsidian taskbar hover target"
assert_contains shell/modules/Shortcuts.qml '"obsidian"' \
  "IPC drawer toggles should treat Obsidian as a fullscreen-sensitive drawer"
assert_contains shell/services/ObsidianNotes.qml 'ryoku-obsidian-notes' \
  "Obsidian notes service should use the Ryoku command boundary"
assert_contains shell/setup 'ryoku-obsidian-notes' \
  "shell runtime setup should install the Obsidian helper used by the popup"
assert_contains shell/services/ObsidianNotes.qml 'GlobalConfig\.paths\.obsidianVaultDir' \
  "Obsidian notes service should read the configured vault path"
assert_contains shell/services/ObsidianNotes.qml 'GlobalConfig\.paths\.obsidianDailyDir' \
  "Obsidian notes service should read the configured daily notes folder"
assert_contains shell/services/ObsidianNotes.qml 'GlobalConfig\.paths\.obsidianInboxFile' \
  "Obsidian notes service should read the configured quick-note inbox"
assert_contains shell/services/ObsidianNotes.qml 'GlobalConfig\.paths\.obsidianVaultName' \
  "Obsidian notes service should read the configured Obsidian vault name"
assert_contains shell/services/ObsidianNotes.qml 'function _noteArgs' \
  "Obsidian notes service should separate note path args from open-only args"
assert_contains shell/services/ObsidianNotes.qml 'function _openArgs' \
  "Obsidian notes service should isolate Obsidian URI args"
assert_contains shell/services/ObsidianNotes.qml 'vaultName !== "Ryoku Notes"' \
  "Obsidian notes service should ignore the old default vault name that can trigger Obsidian verification errors"
assert_contains shell/services/ObsidianNotes.qml 'property bool notesExpanded' \
  "Obsidian notes service should track whether the note editor is expanded"
assert_contains shell/services/ObsidianNotes.qml 'readonly property int draftRetentionMs: 5 \* 60 \* 1000' \
  "Obsidian notes service should retain unsaved sidebar drafts for five minutes"
assert_contains shell/services/ObsidianNotes.qml 'property string draftText' \
  "Obsidian notes service should own draft text outside the transient editor component"
assert_contains shell/services/ObsidianNotes.qml 'property var recentNotes' \
  "Obsidian notes service should keep recent notes saved through the widget"
assert_contains shell/services/ObsidianNotes.qml 'property string currentEntryId' \
  "Obsidian notes service should track the selected editable widget note id"
assert_contains shell/services/ObsidianNotes.qml 'property string savedText' \
  "Obsidian notes service should distinguish saved text from dirty edits"
assert_contains shell/services/ObsidianNotes.qml 'readonly property bool hasUnsavedDraft' \
  "Obsidian notes service should expose a dirty draft state"
assert_contains shell/services/ObsidianNotes.qml 'draftText !== savedText' \
  "dirty state should only show when the loaded note differs from the saved body"
assert_contains shell/services/ObsidianNotes.qml 'function rememberDraft\(content: string\)' \
  "Obsidian notes service should let the editor persist draft text while typing"
assert_contains shell/services/ObsidianNotes.qml 'function selectRecentNote\(note: var\)' \
  "Obsidian notes service should let the recent-note view reopen a saved note for editing"
assert_contains shell/services/ObsidianNotes.qml 'function startNewNote\(\)' \
  "Obsidian notes service should still let users intentionally start a new widget note"
assert_contains shell/services/ObsidianNotes.qml 'function _upsertRecentNote' \
  "Obsidian notes service should refresh the last-three saved widget notes"
assert_contains shell/services/ObsidianNotes.qml 'recentNotes = notes\.slice\(0, 3\)' \
  "Obsidian notes service should keep only the last three widget notes"
assert_contains shell/services/ObsidianNotes.qml 'function pruneExpiredDrafts' \
  "Obsidian notes service should expire stale draft notes"
assert_contains shell/services/ObsidianNotes.qml 'id: draftExpiryTimer' \
  "Obsidian notes service should run a draft retention timer"
assert_contains shell/services/ObsidianNotes.qml 'function selectDate\(date: var\)' \
  "clicking a calendar date should select a note date through the service"
assert_contains shell/services/ObsidianNotes.qml 'notesExpanded = true' \
  "selecting a calendar date or notes button should expand the note editor"
assert_contains shell/services/ObsidianNotes.qml 'function saveNote\(content: string\)' \
  "service should save markdown note content through the command boundary"
assert_contains shell/services/ObsidianNotes.qml 'function openSelectedNote' \
  "service should open the selected Obsidian note"
assert_contains shell/modules/obsidian/Wrapper.qml 'readonly property int expandedHeight' \
  "Obsidian wrapper should support an expanded notes height"
assert_contains shell/modules/obsidian/Wrapper.qml 'readonly property int maxPanelHeight' \
  "Obsidian wrapper should clamp itself to each monitor's available height"
assert_contains shell/modules/obsidian/Wrapper.qml 'screen\.height -' \
  "Obsidian wrapper height should be derived from monitor height"
assert_not_contains shell/modules/obsidian/Wrapper.qml 'Math\.max\(610' \
  "Obsidian wrapper should not force a tall minimum that clips on shorter monitors"
assert_contains shell/modules/obsidian/Wrapper.qml 'readonly property int panelHeight: expandedHeight' \
  "Obsidian wrapper should keep the notes editor open instead of collapsing to calendar-only"
assert_contains shell/modules/obsidian/Wrapper.qml 'ObsidianNotes\.notesExpanded = true' \
  "Obsidian wrapper should open directly into the calendar and notes view"
assert_not_contains shell/modules/obsidian/Wrapper.qml 'notesExpanded = false' \
  "Obsidian wrapper should not collapse the note editor on open"
assert_contains shell/modules/obsidian/Wrapper.qml 'readonly property bool shouldBeActive: visibilities\.obsidian' \
  "Obsidian wrapper visibility should be driven by the drawer state"
assert_contains shell/modules/obsidian/Content.qml 'MonthGrid \{' \
  "Obsidian popup should use a QML MonthGrid calendar"
assert_contains shell/modules/obsidian/Content.qml 'readonly property int calendarGridHeight' \
  "Obsidian popup should shrink the calendar grid on shorter monitors"
assert_contains shell/modules/obsidian/Content.qml 'implicitHeight: root\.calendarGridHeight' \
  "Obsidian MonthGrid should use the responsive calendar grid height"
assert_contains shell/modules/obsidian/Content.qml 'DayOfWeekRow \{' \
  "Obsidian popup should include weekday labels"
assert_not_contains shell/modules/obsidian/Content.qml 'text: qsTr\("Notes"\)' \
  "Obsidian popup should replace the old Notes button with the recent-note view"
assert_contains shell/modules/obsidian/Content.qml 'model: ObsidianNotes\.recentNotes' \
  "Obsidian popup should show notes saved through the widget"
assert_contains shell/modules/obsidian/Content.qml 'ObsidianNotes\.selectRecentNote\(modelData\)' \
  "recent note chips should reload a saved widget note for editing"
assert_contains shell/modules/obsidian/Content.qml 'ObsidianNotes\.startNewNote\(\)' \
  "recent note view should expose an intentional new-note action"
assert_contains shell/modules/obsidian/Content.qml 'TextArea \{' \
  "Obsidian popup should include a markdown note editor"
assert_contains shell/modules/obsidian/Content.qml 'placeholderText: qsTr\("Markdown note"\)' \
  "note editor should invite markdown entry"
assert_contains shell/modules/obsidian/Content.qml 'text: ObsidianNotes\.draftText' \
  "note editor should restore the retained draft when reopened"
assert_contains shell/modules/obsidian/Content.qml 'ObsidianNotes\.rememberDraft\(noteEditor\.text\)' \
  "note editor should persist changes outside the transient component"
assert_contains shell/modules/obsidian/Content.qml 'Quickshell\.clipboardText = noteEditor\.text' \
  "note editor should copy content like a codeblock copy button"
assert_contains shell/modules/obsidian/Content.qml 'ObsidianNotes\.selectDate\(dayItem\.model\.date\)' \
  "calendar date clicks should open the quick note for that date"
assert_contains shell/modules/obsidian/Content.qml 'ObsidianNotes\.saveNote\(noteEditor\.text\)' \
  "save button should send markdown content to the service"
assert_contains shell/modules/obsidian/Content.qml 'type: ObsidianNotes\.hasUnsavedDraft \? IconButton\.Filled : IconButton\.Tonal' \
  "save button should switch to the Ryoku primary color when text is unsaved"
assert_not_contains shell/modules/obsidian/Content.qml 'toggle: true' \
  "notes section should stay open instead of behaving as a collapsible toggle"
assert_contains shell/modules/obsidian/Content.qml 'Layout\.fillHeight: true' \
  "note editor should absorb remaining popup height instead of overflowing"
assert_not_contains shell/modules/obsidian/Content.qml 'Math\.max\(220' \
  "note editor should not force a fixed 220px minimum that clips the popup"
assert_contains shell/modules/obsidian/Content.qml 'StyledScrollBar\.vertical' \
  "expanded note editor should be scrollable"
assert_contains shell/plugin/src/Ryoku/Config/userpaths.hpp 'obsidianVaultDir' \
  "typed config should expose the default Obsidian vault directory"
assert_contains shell/plugin/src/Ryoku/Config/userpaths.hpp 'obsidianVaultDir, QString\(\)' \
  "typed config should leave the Obsidian vault path empty so the helper can discover the registered vault"
assert_contains shell/plugin/src/Ryoku/Config/userpaths.hpp 'obsidianDailyDir' \
  "typed config should expose the default daily notes folder"
assert_contains shell/plugin/src/Ryoku/Config/userpaths.hpp 'obsidianInboxFile' \
  "typed config should expose the default quick-note inbox"
assert_contains shell/plugin/src/Ryoku/Config/userpaths.hpp 'obsidianVaultName' \
  "typed config should expose the Obsidian vault name"
assert_contains shell/plugin/src/Ryoku/Config/userpaths.hpp 'obsidianVaultName, QString\(\)' \
  "typed config should not default to an unverified Obsidian vault name"
assert_contains shell/settingsgui/Modules/Panels/Settings/Tabs/General/BasicsSubTab.qml 'id: obsidianVaultPicker' \
  "settings should expose a folder picker for the Obsidian vault"
assert_contains shell/settingsgui/Modules/Panels/Settings/Tabs/General/BasicsSubTab.qml 'selectionMode: "folders"' \
  "Obsidian vault picker should select folders"
assert_contains shell/settingsgui/Modules/Panels/Settings/Tabs/General/BasicsSubTab.qml 'label: "Obsidian notes"' \
  "settings should include an Obsidian notes section"
assert_contains shell/settingsgui/Modules/Panels/Settings/Tabs/General/BasicsSubTab.qml 'GlobalConfig\.paths\.obsidianVaultDir = text\.trim\(\)' \
  "settings should persist the configured Obsidian vault folder"
assert_contains shell/settingsgui/Modules/Panels/Settings/Tabs/General/BasicsSubTab.qml 'GlobalConfig\.paths\.obsidianDailyDir = text\.trim\(\)' \
  "settings should persist the configured daily notes folder"
assert_contains shell/settingsgui/Modules/Panels/Settings/Tabs/General/BasicsSubTab.qml 'GlobalConfig\.paths\.obsidianInboxFile = text\.trim\(\)' \
  "settings should persist the configured quick-note inbox file"
assert_contains shell/settingsgui/Modules/Panels/Settings/Tabs/General/BasicsSubTab.qml 'GlobalConfig\.paths\.obsidianVaultName = text\.trim\(\)' \
  "settings should persist the optional Obsidian vault name"
assert_contains shell/settingsgui/Modules/Panels/Settings/Tabs/General/BasicsSubTab.qml 'GlobalConfig\.save\(\)' \
  "settings should save Obsidian path changes through GlobalConfig"

echo "PASS: obsidian frame popup"
