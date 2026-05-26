#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_file() {
  local path="$1"

  [[ -f $ROOT_DIR/$path ]] || fail "missing required file: $path"
}

assert_absent() {
  local path="$1"

  [[ ! -e $ROOT_DIR/$path ]] || fail "removed Wayle surface still exists: $path"
}

assert_contains() {
  local file="$1"
  local needle="$2"
  local message="$3"

  grep -Fq -- "$needle" "$ROOT_DIR/$file" || fail "$message"
}

assert_not_contains() {
  local file="$1"
  local needle="$2"
  local message="$3"

  ! grep -Fq -- "$needle" "$ROOT_DIR/$file" || fail "$message"
}

assert_file "shell/modules/controlcenter/Wrapper.qml"
assert_file "shell/components/controls/Menu.qml"
assert_file "shell/components/controls/MenuItem.qml"
assert_file "shell/modules/drawers/ContentWindow.qml"
assert_file "shell/modules/drawers/Interactions.qml"
assert_file "shell/modules/Shortcuts.qml"
assert_file "shell/utils/Paths.qml"
assert_file "shell/services/Colours.qml"
assert_file "shell/modules/launcher/services/Schemes.qml"
assert_file "shell/modules/launcher/services/M3Variants.qml"
assert_file "shell/scripts/ryoku-shell"
assert_file "shell/scripts/ryoku-reload-hyprland"
assert_file "shell/scripts/ryoku-shell-profile"
assert_file "bin/ryoku-reload-hyprland"
assert_file "bin/ryoku-shell-profile"
assert_file "config/hypr/hyprland.conf"
assert_file "install/ryoku-base.packages"

for path in \
  bin/ryoku-launch-wayle-settings \
  bin/ryoku-theme-set-wayle \
  install/config/wayle-settings.sh \
  tests/wayle-settings-integration.sh \
  third_party/wayle; do
  assert_absent "$path"
done

assert_contains "shell/modules/controlcenter/Wrapper.qml" "component AboutPage" \
  "settings should render native QML About content"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "component AppearancePage" \
  "settings should render native QML Appearance content"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "component ProfilesPage" \
  "settings should mirror HyprMod's pinned Profiles page"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "component AppSettingsPage" \
  "settings should mirror HyprMod's pinned Settings page"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "title: \"HyprMod\"" \
  "settings sidebar header should use HyprMod's title"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "readonly property var pinnedPages: [8, 9]" \
  "settings sidebar should pin Profiles and Settings like HyprMod"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "readonly property int searchPageIndex: 10" \
  "settings search should remain a hidden stack page after pinned utilities"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "readonly property int pendingPageIndex: 11" \
  "pending changes should remain off-sidebar like HyprMod"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "property int currentPage: 1" \
  "settings should open on the first task page instead of a local About landing page"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "component SwitchPreferenceRow" \
  "settings should expose HyprMod-style switch preference rows"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "component AdwSwitch" \
  "settings should use HyprMod-style libadwaita switches"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "component SliderPreferenceRow" \
  "settings should expose compact scalar preference rows"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "component StepperButton" \
  "scalar settings should use HyprMod-style compact spin controls"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "component RowActionButton" \
  "changed settings should expose HyprMod-style row action buttons"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "property bool revealed" \
  "row action buttons should support HyprMod's hover-revealed reset strip"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "opacity: active && revealed ? 1 : 0" \
  "row action buttons should stay hidden until their row reveals them"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "HoverHandler {" \
  "preference rows should track hover for HyprMod-style reset affordances"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "revealed: sliderRow.hovered" \
  "numeric row reset buttons should reveal on row hover like HyprMod"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "tooltipText: \"Discard changes\"" \
  "row action buttons should carry HyprMod-style discard tooltips"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "dirtyValue" \
  "changed settings should track row dirty state for reset affordances"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "component ModePreferenceRow" \
  "choice settings should render as compact preference rows"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "component SchemePreferenceRow" \
  "settings should expose HyprMod-style scheme colour selection rows"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "SchemeSwatchButton { flavour: \"default\"" \
  "scheme colour controls should include the default Ryoku accent"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "component VariantPreferenceRow" \
  "settings should expose compact Material color variant controls"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "VariantPillButton { label: \"Rainbow\"; variant: \"rainbow\" }" \
  "variant controls should expose the full Ryoku scheme variant set"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "function beginEdit" \
  "numeric rows should support click-to-type editing"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "function cancelEdit" \
  "numeric rows should support canceling typed edits before commit"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "Keys.onEscapePressed: sliderRow.cancelEdit()" \
  "numeric row editors should use Escape to restore the pre-edit visible value"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "Keys.onUpPressed: sliderRow.commit(sliderRow.currentValue + sliderRow.stepSize)" \
  "numeric row editors should support keyboard spin-step increases"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "onWheel" \
  "numeric rows should support mouse-wheel stepping"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "property string targetKey" \
  "config rows should carry explicit keys when titles are duplicated across pages"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "propertyName: \"schemes\"; targetKey: \"launcher.useFuzzy.schemes\"" \
  "launcher scheme fuzzy matching should be exposed as a backed setting"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "component IslandPage" \
  "settings should replace the removed Dashboard settings section with Island controls"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "propertyName: \"dragThreshold\"; targetKey: \"dashboard.dragThreshold\"" \
  "island gesture threshold should be exposed as a backed setting"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "settingKey: \"paths.wallpaperDir\"" \
  "appearance should expose the backed wallpaper folder path"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "component WallpaperPreviewGrid" \
  "appearance should show wallpaper previews inside settings"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "readonly property string ryokuBridge" \
  "scheme controls should use the running shell runtime bridge, not a stale PATH command"
assert_contains "shell/utils/Paths.qml" "readonly property string ryokuBridge" \
  "shell scheme callers should share the running runtime bridge path"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "root.ryokuBridge, \"scheme\", \"preview\", \"--notify\"" \
  "scheme controls should preview through the Ryoku scheme bridge before saving"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "root.ryokuBridge, \"scheme\", \"set\", \"--notify\"" \
  "scheme controls should persist through the Ryoku scheme bridge on Save"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "command: [root.ryokuBridge, \"scheme\", \"get\", \"-nfvm\"]" \
  "scheme controls should read saved state from the runtime bridge"
assert_contains "shell/services/Colours.qml" "Paths.ryokuBridge, \"scheme\", \"set\", \"--notify\"" \
  "global theme mode switching should use the runtime bridge"
assert_contains "shell/modules/launcher/services/Schemes.qml" "Paths.ryokuBridge, \"scheme\", \"list\"" \
  "launcher scheme search should use the runtime bridge"
assert_contains "shell/modules/launcher/services/Schemes.qml" "Paths.ryokuBridge, \"scheme\", \"get\", \"-nfv\"" \
  "launcher scheme state should use the runtime bridge"
assert_contains "shell/modules/launcher/services/M3Variants.qml" "Paths.ryokuBridge, \"scheme\", \"set\", \"-v\"" \
  "launcher variant actions should use the runtime bridge"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "function refreshSchemeState" \
  "scheme controls should refresh current and saved state whenever settings opens"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "root.refreshSchemeState()" \
  "settings should avoid stale scheme state when reopened"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "onTriggered: root.refreshCurrentSchemeState()" \
  "scheme previews should hot-reload from the live scheme file without a shell restart"
assert_contains "shell/modules/controlcenter/Wrapper.qml" 'path: `${Paths.state}/scheme.json`' \
  "settings should watch the same live scheme file as the shell color service"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "onFileChanged: reload()" \
  "settings scheme chips should update when the live scheme file changes"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "id: schemePersist" \
  "scheme saves should use a tracked process so saved/current state refreshes when persistence completes"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "component SearchBox" \
  "settings should include a native sidebar search field"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "readonly property var searchIndex" \
  "settings should index shell settings for HyprMod-style global search"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "component SearchPage" \
  "settings search should render a HyprMod-style Search Results page"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "component SearchResultRow" \
  "settings search should render Adwaita-style result rows"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "function highlightSetting" \
  "settings search should flash-highlight the source row like HyprMod"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "root.navigateToSetting(entry.pageIndex, entry.key || \"\")" \
  "settings search results should navigate to and highlight their source option"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "currentIndex: root.contentPageIndex" \
  "settings content stack should switch into the Search Results page"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "root.searchQuery.length >= 2" \
  "settings search should use HyprMod's two-character activation threshold"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "ProfilesPage {}" \
  "settings stack should include the pinned Profiles page"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "AppSettingsPage {}" \
  "settings stack should include the pinned Settings page"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "SearchPage {}" \
  "settings stack should include the hidden Search Results page"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "PendingChangesPage {}" \
  "settings stack should include the hidden Pending Changes page"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "function focusSearch" \
  "settings should expose HyprMod-style keyboard search focus"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "function formatBreadcrumb" \
  "settings search rows should format breadcrumbs like HyprMod"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "replace(/\\s*>\\s*/g, \" \\u203a \")" \
  "settings search rows should use HyprMod's breadcrumb separator"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "placeholderText: \"Search options\\u2026\"" \
  "settings search placeholder should use HyprMod's ellipsis copy"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "text: \"Search options (Ctrl+F)\"" \
  "settings search tooltip should include HyprMod's shortcut hint"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "focus: root.shouldBeActive" \
  "settings wrapper should claim QML key focus while open"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "root.forceActiveFocus()" \
  "settings wrapper should restore key focus whenever the drawer opens"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "searchField.forceActiveFocus()" \
  "settings search field should receive focus when search opens"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "event.key === Qt.Key_F" \
  "settings should bind Ctrl+F to search like HyprMod"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "event.key === Qt.Key_S" \
  "settings should bind Ctrl+S to Save now like HyprMod"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "event.key === Qt.Key_Z" \
  "settings should bind Ctrl+Z and Ctrl+Shift+Z to pending-change history"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "function undoLastChange" \
  "settings should implement the advertised undo shortcut"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "function redoLastChange" \
  "settings should implement the advertised redo shortcut"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "property var changeHistory" \
  "settings should track recent changes for keyboard undo"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "fromValue" \
  "settings pending entries should keep pre-edit values for undo"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "toValue" \
  "settings pending entries should keep post-edit values for redo"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "root.dismissSearch()" \
  "settings Escape handling should dismiss search before closing"
assert_contains "shell/modules/drawers/Interactions.qml" "function closeSettingsIfOutside" \
  "settings should expose a shared outside-click close helper"
assert_contains "shell/modules/drawers/ContentWindow.qml" "visible: visibilities.settings" \
  "settings should install a dedicated outside-click catcher while open"
assert_contains "shell/modules/drawers/ContentWindow.qml" "interactions.closeSettingsIfOutside(event.x, event.y)" \
  "outside clicks should close the settings drawer from transparent space"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "component SidebarCategory" \
  "settings should use HyprMod-style sidebar category headers"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "component SidebarRow" \
  "settings should use HyprMod-style sidebar rows"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "component SidebarBadge" \
  "settings sidebar rows should show HyprMod-style pending badges"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "function pagePendingCount" \
  "settings sidebar badges should count pending changes per page"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "readonly property var navigationSections" \
  "settings sidebar should be grouped by task-oriented navigation sections"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "title: \"Display\"" \
  "settings sidebar should mirror HyprMod's Display category"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "title: \"Window Management\"" \
  "settings sidebar should mirror HyprMod's Window Management category"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "title: \"Startup\"" \
  "settings sidebar should mirror HyprMod's Startup category"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "component HeaderBar" \
  "settings should use toolbar header bars like HyprMod"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "property bool profileSaveButton" \
  "Profiles should use HyprMod's header-level save-current button"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "profileSaveButton: !root.searchActive && root.currentPage === 8" \
  "Profiles should show the save-current action in the page header"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "MenuItem {" \
  "settings header should expose a HyprMod-style menu"
assert_contains "shell/components/controls/MenuItem.qml" "property bool separatorBefore" \
  "shared menu items should support HyprMod-style menu sections"
assert_contains "shell/components/controls/MenuItem.qml" "property bool enabled" \
  "shared menu items should support HyprMod-style disabled action rows"
assert_contains "shell/components/controls/Menu.qml" "modelData.separatorBefore" \
  "shared menus should render HyprMod-style menu section separators"
assert_contains "shell/components/controls/Menu.qml" "item.modelData.enabled" \
  "shared menus should dim and block disabled HyprMod-style menu actions"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "separatorBefore: true" \
  "settings header menu should group HyprMod menu items into sections"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "text: \"Auto-save\"" \
  "settings header menu should expose HyprMod's Auto-save preference"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "text: \"Open HyprMod\"" \
  "settings menu should expose the advanced HyprMod app"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "text: \"Keyboard Shortcuts\"" \
  "settings header menu should expose HyprMod's keyboard shortcuts item"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "component ShortcutOverlay" \
  "settings keyboard shortcuts should open a HyprMod-style modal overlay"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "component ShortcutRow" \
  "settings keyboard shortcuts overlay should render action rows"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "Ctrl\", \"S" \
  "settings keyboard shortcuts overlay should document Ctrl+S"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "event.key === Qt.Key_F1" \
  "settings should bind F1 to the keyboard shortcuts overlay"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "text: \"Report a bug\"" \
  "settings header menu should expose HyprMod's bug report item"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "text: \"About Ryoku\"" \
  "settings About menu item should reference Ryoku's own about page"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "component PreferenceGroup" \
  "settings pages should use Adwaita-style preference groups"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "readonly property int contentMaxWidth: 800" \
  "settings content should be clamped to HyprMod's standard preference width"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "readonly property int hyprmodDefaultWidth: 900" \
  "settings shell should match HyprMod's default window width"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "readonly property int hyprmodDefaultHeight: 650" \
  "settings shell should match HyprMod's default window height"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "implicitWidth: Math.min(root.availableWidth * 0.92, root.hyprmodDefaultWidth)" \
  "settings shell should responsively cap width at HyprMod's default"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "implicitHeight: Math.min(root.availableHeight * 0.9, root.hyprmodDefaultHeight)" \
  "settings shell should responsively cap height at HyprMod's default"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "readonly property int hyprmodPageVerticalMargin: 24" \
  "settings pages should use HyprMod's standard vertical content margin"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "readonly property int hyprmodPageHorizontalMargin: 12" \
  "settings pages should use HyprMod's standard horizontal content margin"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "readonly property int hyprmodPageSpacing: 24" \
  "settings pages should use HyprMod's standard group spacing"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "contentHeight: pageBody.implicitHeight + root.hyprmodPageVerticalMargin * 2" \
  "settings pages should calculate scroll height from HyprMod margins"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "spacing: root.hyprmodPageSpacing" \
  "settings pages should space preference groups like HyprMod"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "component DirtyBanner" \
  "settings should include the HyprMod-style bottom status banner"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "Unsaved changes \\u2014 applied live, not saved to disk" \
  "settings dirty banner should use HyprMod's unsaved-changes message"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "component PendingChangesPage" \
  "settings should include a HyprMod-style Pending Changes page"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "component PendingChangeRow" \
  "settings should render pending changes as Adwaita-style rows"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "component ConfigDiffPreview" \
  "settings Pending Changes page should include HyprMod-style config diff preview"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "component DiffStatPill" \
  "settings diff preview should include HyprMod-style added and removed count pills"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "Comparison between the saved config and what the next save would write." \
  "settings diff preview should use HyprMod's config diff description"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "property var pendingEntries" \
  "settings should maintain a pending-change registry"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "root.openPendingChanges()" \
  "settings pending chip should navigate to Pending Changes"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "function discardAllPending" \
  "settings Pending Changes page should expose a discard-all action"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "function saveAllPending" \
  "settings dirty banner should expose HyprMod-style Save now behavior"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "component SaveSplitButton" \
  "settings dirty banner should use HyprMod's split Save now button"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "Save as new profile" \
  "settings split save button should expose HyprMod's profile save affordance"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "Save without updating profile" \
  "settings split save button should expose HyprMod's active-profile save affordance"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "component ProfileCard" \
  "settings Profiles page should render reusable profile cards"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "text: \"Save current as new profile\"" \
  "settings Profiles page should expose HyprMod's save-current profile tooltip"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "ryoku-shell-profile" \
  "settings Profiles page should use a real shell profile adapter"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "text: \"Delete profile\"" \
  "settings Profiles page should expose a working delete action instead of an inert menu"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "Qt.alpha(root.accent, 0.06)" \
  "active profile cards should use HyprMod's subtle accent tint"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "width: 3" \
  "active profile cards should use HyprMod's thin left accent bar"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "title: \"Config file path\"" \
  "settings app Settings page should expose HyprMod's config path row"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "component EntryPreferenceRow" \
  "settings app Settings page should use HyprMod-style editable entry rows"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "function applyText" \
  "editable entry rows should expose an apply action like Adw.EntryRow"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "Keys.onEscapePressed: entryRow.resetText()" \
  "editable entry rows should allow canceling text edits"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "settingKey: \"settings.configPath\"" \
  "settings app config path row should be searchable and highlightable"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "readOnly: entryRow.readOnly" \
  "settings app config path row should avoid pretending the backend path is editable"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "text: \"Browse\\u2026\"" \
  "settings app Settings page should expose HyprMod's icon-only browse tooltip"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "description: \"Automatically save changes after each modification.\"" \
  "settings app Settings page should expose HyprMod's auto-save behavior copy"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "autoSavePendingTimer" \
  "settings should support HyprMod-style debounced auto-save when enabled"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "beginShellConfigEditSession()" \
  "settings controls should suspend config autosave before live shell edits"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "setAutoSaveSuspended" \
  "settings controls should resume config autosave after pending shell edits are resolved"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "root.pageIndexForSetting(switchRow.title, switchRow.propertyName)" \
  "switch pending entries should be attributed to their source settings page"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "root.pageIndexForSetting(sliderRow.title, sliderRow.propertyName)" \
  "numeric pending entries should be attributed to their source settings page"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "targetKey: sliderRow.settingKey" \
  "numeric pending entries should navigate back to the exact source option"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "function abandonPendingSession" \
  "settings drawer close should abandon live pending edits instead of leaving autosave suspended"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "onShouldBeActiveChanged" \
  "settings drawer should clean up pending edit sessions when hidden"
assert_contains "shell/plugin/src/Ryoku/Config/rootconfig.hpp" "autoSaveSuspended" \
  "config backend should expose an autosave suspension hook for HyprMod-style pending edits"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "function saveScheme" \
  "settings scheme controls should persist previews from the Save now path"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "readonly property bool schemeDirty" \
  "settings should track unsaved scheme previews as a complete tuple"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "function isSchemePendingEntry" \
  "settings should identify scheme-related pending rows during discard"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "if (restoreSavedScheme)" \
  "discarding pending changes should restore the full saved scheme preview"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "if (root.schemeDirty)" \
  "closing settings should abandon unsaved scheme previews even without a row badge"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "accept: () =>" \
  "settings pending entries should accept the current value as the new saved baseline"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "#F25623" \
  "settings should use the Ryoku brand orange (docs/branding.md) for branded About accents"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "GlobalConfig.save();" \
  "settings controls should persist through the typed GlobalConfig layer"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "target.setProperty" \
  "settings controls should write through QObject config setters when available"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "RyokuAbout.helper, \"refresh-shell\"" \
  "Refresh Shell actions should use the runtime settings about adapter"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "ryoku-reload-hyprland" \
  "Reload Hyprland actions should use a Ryoku command adapter"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "ryoku-launch-hyprmod" \
  "settings should hand Hyprland configuration to HyprMod"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "Built for the sake of power and beauty." \
  "About should stay brand-led and compact"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "component ActionPreferenceRow" \
  "About actions should use the same HyprMod-style action rows as other pages"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "component NavigationPreferenceRow" \
  "settings should provide HyprMod-style navigation rows for in-surface shell edits"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "title: \"Shell edits\"" \
  "Hyprland page should include a shell edits section inside the HyprMod-style surface"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "key: \"hyprland.shell_edits\"" \
  "shell edits should be discoverable through settings search"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "visible: true" \
  "settings drawer should stay warm offscreen to avoid first-open delay"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "enabled: root.shouldBeActive || root.offsetScale < 1" \
  "settings drawer should only accept input while open or animating"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "readonly property bool needsKeyboard: root.shouldBeActive || root.offsetScale < 1" \
  "settings drawer should request keyboard focus only while open or animating"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "offsetScale" \
  "settings should preserve the top-frame drawer animation"
assert_contains "shell/modules/controlcenter/Wrapper.qml" "StackLayout" \
  "settings should use a resident native page stack"
assert_contains "shell/scripts/ryoku-shell" "ipc_call controlCenter toggle" \
  "ryoku-shell settings should open through the resident top-frame route"
assert_contains "shell/modules/drawers/ContentWindow.qml" "panel: panels.settings" \
  "drawer background should keep the native settings panel"
assert_contains "shell/modules/drawers/ContentWindow.qml" "|| visibilities.settings ||" \
  "settings should participate in the focus-grab outside-click dismissal path"
assert_contains "shell/modules/drawers/Interactions.qml" "visibilities.settings && !inPanelBounds(panels.settings" \
  "clicking outside the settings panel should dismiss the drawer"

assert_not_contains "shell/modules/controlcenter/Wrapper.qml" "ryoku-launch-wayle-settings" \
  "settings wrapper should not launch Wayle"
assert_not_contains "shell/modules/controlcenter/Wrapper.qml" "hyprctl clients -j" \
  "settings wrapper should not poll for external Wayle windows"
assert_not_contains "shell/modules/controlcenter/Wrapper.qml" "showLaunchSurface" \
  "settings wrapper should not keep an external-launch placeholder"
assert_not_contains "shell/modules/controlcenter/Wrapper.qml" "ControlCenter {" \
  "settings wrapper should not host the removed control-center backend"
assert_not_contains "shell/modules/controlcenter/Wrapper.qml" "component NavGroup" \
  "settings sidebar should not use grouped drawer-style navigation"
assert_not_contains "shell/modules/controlcenter/Wrapper.qml" "navGroups" \
  "settings sidebar should not keep grouped navigation data"
assert_not_contains "shell/modules/controlcenter/Wrapper.qml" "expand_more" \
  "settings sidebar should not show dropdown drawer affordances"
assert_not_contains "shell/modules/controlcenter/Wrapper.qml" "component SettingsGrid" \
  "settings should not keep the pre-HyprMod bento grid frontend"
assert_not_contains "shell/modules/controlcenter/Wrapper.qml" "StyledSlider" \
  "settings pages should not use oversized Material sliders"
assert_not_contains "shell/modules/controlcenter/Wrapper.qml" "StyledSwitch" \
  "settings pages should not use icon-heavy Material switches"
assert_not_contains "shell/modules/controlcenter/Wrapper.qml" "notify-send\", \"Ryoku Settings\"" \
  "settings keyboard shortcuts should not be a transient notification"
assert_not_contains "shell/modules/controlcenter/Wrapper.qml" "implicitHeight: parent.height - Tokens.padding.small" \
  "settings sidebar should not use a thin active rail"
assert_not_contains "shell/scripts/ryoku-shell" "ryoku-launch-wayle-settings" \
  "ryoku-shell settings should not spawn an external settings app"
assert_not_contains "shell/modules/Shortcuts.qml" "--prewarm" \
  "shell startup should not prewarm a removed external app"
assert_not_contains "config/hypr/hyprland.conf" "com.wayle.settings" \
  "Hyprland should not keep Wayle settings window rules"
assert_not_contains "install/ryoku-base.packages" "gtk4-layer-shell" \
  "base packages should not keep the Wayle layer-shell dependency"
assert_not_contains "install/ryoku-base.packages" "gtksourceview5" \
  "base packages should not keep the Wayle GtkSourceView dependency"

echo "PASS: tests/settings-controlcenter-redesign.sh"
