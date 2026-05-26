#!/bin/bash
set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_file() {
  local path="$1"
  [[ -f $ROOT_DIR/$path ]] || fail "missing required file: $path"
}

assert_absent() {
  local path="$1"
  [[ ! -e $ROOT_DIR/$path ]] || fail "removed settings surface still exists: $path"
}

assert_contains() {
  local path="$1"
  local pattern="$2"
  local message="$3"

  grep -Eq -- "$pattern" "$ROOT_DIR/$path" || fail "$message"
}

assert_not_contains() {
  local path="$1"
  local pattern="$2"
  local message="$3"

  if grep -Eq -- "$pattern" "$ROOT_DIR/$path"; then
    fail "$message"
  fi
}

launcher="shell/scripts/ryoku-shell"
shell_entry="shell/shell.qml"
shortcuts="shell/modules/Shortcuts.qml"
visibilities="shell/components/DrawerVisibilities.qml"
wrapper="shell/modules/controlcenter/Wrapper.qml"
paths="shell/utils/Paths.qml"
colours="shell/services/Colours.qml"
schemes="shell/modules/launcher/services/Schemes.qml"
variants="shell/modules/launcher/services/M3Variants.qml"
menu="shell/components/controls/Menu.qml"
menu_item="shell/components/controls/MenuItem.qml"
panels="shell/modules/drawers/Panels.qml"
content_window="shell/modules/drawers/ContentWindow.qml"
interactions="shell/modules/drawers/Interactions.qml"
bar_popouts="shell/modules/bar/popouts/Wrapper.qml"

assert_file "$launcher"
assert_file "$shell_entry"
assert_file "$shortcuts"
assert_file "$visibilities"
assert_file "$wrapper"
assert_file "$paths"
assert_file "$colours"
assert_file "$schemes"
assert_file "$variants"
assert_file "$menu"
assert_file "$menu_item"
assert_file "$panels"
assert_file "$content_window"
assert_file "$interactions"
assert_file "$bar_popouts"
assert_file "shell/scripts/ryoku-reload-hyprland"
assert_file "shell/scripts/ryoku-shell-profile"
assert_file "bin/ryoku-reload-hyprland"
assert_file "bin/ryoku-shell-profile"

for path in \
  shell/ryokuSettings.qml \
  shell/settings.qml \
  shell/waffleSettings.qml \
  shell/modules/controlcenter/ControlCenter.qml \
  shell/modules/controlcenter/NavRail.qml \
  shell/modules/controlcenter/PaneRegistry.qml \
  shell/modules/controlcenter/Panes.qml \
  shell/modules/controlcenter/WindowFactory.qml \
  shell/modules/controlcenter/WindowTitle.qml \
  shell/modules/controlcenter/about \
  shell/modules/controlcenter/appearance \
  shell/modules/controlcenter/audio \
  shell/modules/controlcenter/bluetooth \
  shell/modules/controlcenter/dashboard \
  shell/modules/controlcenter/launcher \
  shell/modules/controlcenter/network \
  shell/modules/controlcenter/notifications \
  shell/modules/controlcenter/state \
  shell/modules/controlcenter/taskbar \
  shell/modules/settings \
  shell/modules/waffle/settings \
  bin/ryoku-launch-wayle-settings \
  bin/ryoku-theme-set-wayle \
  install/config/wayle-settings.sh \
  third_party/wayle; do
  assert_absent "$path"
done

assert_contains "$shell_entry" 'Drawers \{\}' \
  "settings should be hosted by the resident drawers shell"
assert_contains "$launcher" 'ipc_call controlCenter toggle' \
  "ryoku-shell settings should route through the resident top-frame settings wrapper"
assert_contains "$shortcuts" 'target: "controlCenter"' \
  "primary settings IPC target should remain compatible with existing shell routes"
assert_contains "$shortcuts" 'visibilities\.settings = true' \
  "settings IPC open should request the settings drawer"
assert_contains "$visibilities" 'property bool settings' \
  "settings should be tracked by drawer visibility state"
assert_contains "$wrapper" 'component AboutPage' \
  "settings wrapper should render native About content"
assert_contains "$wrapper" 'component AppearancePage' \
  "settings wrapper should render native Appearance content"
assert_contains "$wrapper" 'component ProfilesPage' \
  "settings wrapper should mirror HyprMod's pinned Profiles page"
assert_contains "$wrapper" 'component AppSettingsPage' \
  "settings wrapper should mirror HyprMod's pinned Settings page"
assert_contains "$wrapper" 'title: "Ryoku"' \
  "settings wrapper sidebar header should carry the Ryoku brand, not the HyprMod placeholder"
assert_contains "$wrapper" 'readonly property var pinnedPages: \[8, 9\]' \
  "settings sidebar should pin Profiles and Settings like HyprMod"
assert_contains "$wrapper" 'readonly property int searchPageIndex: 11' \
  "settings search should remain hidden after pinned utilities"
assert_contains "$wrapper" 'readonly property int pendingPageIndex: 12' \
  "pending changes should remain off-sidebar like HyprMod"
assert_contains "$wrapper" 'property int currentPage: 1' \
  "settings wrapper should open on the first task page"
assert_contains "$wrapper" 'component SearchBox' \
  "settings wrapper should include native sidebar search"
assert_contains "$wrapper" 'readonly property var searchIndex' \
  "settings wrapper should index settings for global search"
assert_contains "$wrapper" 'component SearchPage' \
  "settings wrapper should render a HyprMod-style Search Results page"
assert_contains "$wrapper" 'component SearchResultRow' \
  "settings wrapper should render Adwaita-style search result rows"
assert_contains "$wrapper" 'function highlightSetting' \
  "settings wrapper should flash-highlight source rows after search navigation"
assert_contains "$wrapper" 'root\.navigateToSetting\(entry\.pageIndex, entry\.key \|\| ""\)' \
  "settings wrapper search results should navigate to and highlight source options"
assert_contains "$wrapper" 'currentIndex: root\.contentPageIndex' \
  "settings wrapper content stack should switch into search results"
assert_contains "$wrapper" 'root\.searchQuery\.length >= 2' \
  "settings wrapper search should use HyprMod's two-character threshold"
assert_contains "$wrapper" 'ProfilesPage \{\}' \
  "settings wrapper stack should include the pinned Profiles page"
assert_contains "$wrapper" 'AppSettingsPage \{\}' \
  "settings wrapper stack should include the pinned Settings page"
assert_contains "$wrapper" 'SearchPage \{\}' \
  "settings wrapper stack should include the hidden Search Results page"
assert_contains "$wrapper" 'PendingChangesPage \{\}' \
  "settings wrapper stack should include the hidden Pending Changes page"
assert_contains "$wrapper" 'component SidebarCategory' \
  "settings wrapper should include HyprMod-style sidebar categories"
assert_contains "$wrapper" 'component SidebarRow' \
  "settings wrapper should include HyprMod-style sidebar rows"
assert_contains "$wrapper" 'component SidebarBadge' \
  "settings wrapper sidebar rows should include HyprMod-style pending badges"
assert_contains "$wrapper" 'function pagePendingCount' \
  "settings wrapper sidebar badges should count pending changes per page"
assert_contains "$wrapper" 'readonly property var navigationSections' \
  "settings wrapper should organize navigation into task sections"
assert_contains "$wrapper" 'title: "Display"' \
  "settings wrapper sidebar should mirror HyprMod's Display category"
assert_contains "$wrapper" 'title: "Window Management"' \
  "settings wrapper sidebar should mirror HyprMod's Window Management category"
assert_contains "$wrapper" 'title: "Startup"' \
  "settings wrapper sidebar should mirror HyprMod's Startup category"
assert_contains "$wrapper" 'component HeaderBar' \
  "settings wrapper should use toolbar header bars"
assert_contains "$wrapper" 'property bool profileSaveButton' \
  "settings wrapper Profiles page should expose a header save-current button"
assert_contains "$wrapper" 'profileSaveButton: !root\.searchActive && root\.currentPage === 8' \
  "settings wrapper Profiles page should show the save-current action in the header"
assert_contains "$wrapper" 'MenuItem \{' \
  "settings wrapper should expose a HyprMod-style header menu"
assert_contains "$menu_item" 'property bool separatorBefore' \
  "shared menu items should support HyprMod-style sections"
assert_contains "$menu_item" 'property bool enabled' \
  "shared menu items should support HyprMod-style disabled action rows"
assert_contains "$menu" 'modelData\.separatorBefore' \
  "shared menus should render HyprMod-style menu section separators"
assert_contains "$menu" 'item\.modelData\.enabled' \
  "shared menus should dim and block disabled HyprMod-style menu actions"
assert_contains "$wrapper" 'separatorBefore: true' \
  "settings wrapper header menu should group HyprMod-style sections"
assert_contains "$wrapper" 'text: "Auto-save"' \
  "settings wrapper header menu should expose HyprMod's Auto-save preference"
assert_not_contains "$wrapper" 'text: "Migrate to Lua\\u2026"' \
  "settings wrapper should not ship the inert HyprMod Lua-migration placeholder"
assert_contains "$wrapper" 'text: "Open HyprMod"' \
  "settings wrapper header menu should expose HyprMod"
assert_contains "$wrapper" 'text: "Keyboard Shortcuts"' \
  "settings wrapper header menu should expose HyprMod's keyboard shortcuts item"
assert_contains "$wrapper" 'component ShortcutOverlay' \
  "settings wrapper keyboard shortcuts should open a HyprMod-style modal overlay"
assert_contains "$wrapper" 'component ShortcutRow' \
  "settings wrapper keyboard shortcuts overlay should render action rows"
assert_contains "$wrapper" 'Ctrl", "S' \
  "settings wrapper keyboard shortcuts overlay should document Ctrl+S"
assert_contains "$wrapper" 'event\.key === Qt\.Key_F1' \
  "settings wrapper should bind F1 to the keyboard shortcuts overlay"
assert_contains "$wrapper" 'text: "Report a bug"' \
  "settings wrapper header menu should expose HyprMod's bug report item"
assert_contains "$wrapper" 'text: "About Ryoku"' \
  "settings wrapper About menu item should reference Ryoku's own about page"
assert_contains "$wrapper" 'component PreferenceGroup' \
  "settings wrapper should use Adwaita-style preference groups"
assert_contains "$wrapper" 'component SwitchPreferenceRow' \
  "settings wrapper should expose switch preference rows"
assert_contains "$wrapper" 'component AdwSwitch' \
  "settings wrapper should expose HyprMod-style libadwaita switches"
assert_contains "$wrapper" 'component SliderPreferenceRow' \
  "settings wrapper should expose compact scalar preference rows"
assert_contains "$wrapper" 'component StepperButton' \
  "settings wrapper scalar controls should use compact spin affordances"
assert_contains "$wrapper" 'component RowActionButton' \
  "settings wrapper should expose HyprMod-style row action buttons"
assert_contains "$wrapper" 'property bool revealed' \
  "settings wrapper row action buttons should support HyprMod's hover-revealed reset strip"
assert_contains "$wrapper" 'opacity: active && revealed \? 1 : 0' \
  "settings wrapper row action buttons should stay hidden until row hover"
assert_contains "$wrapper" 'HoverHandler \{' \
  "settings wrapper rows should track hover for HyprMod-style reset affordances"
assert_contains "$wrapper" 'revealed: sliderRow\.hovered' \
  "settings wrapper numeric row reset buttons should reveal on row hover"
assert_contains "$wrapper" 'tooltipText: "Discard changes"' \
  "settings wrapper row action buttons should carry HyprMod-style discard tooltips"
assert_contains "$wrapper" 'dirtyValue' \
  "settings wrapper should track changed rows for reset affordances"
assert_contains "$wrapper" 'component ModePreferenceRow' \
  "settings wrapper choice controls should render inside preference rows"
assert_contains "$wrapper" 'component SchemePreferenceRow' \
  "settings wrapper should expose scheme color selection rows"
assert_contains "$wrapper" 'SchemeSwatchButton \{ flavour: "default"' \
  "settings wrapper scheme controls should include the default Ryoku accent"
assert_contains "$wrapper" 'component VariantPreferenceRow' \
  "settings wrapper should expose Material color variant controls"
assert_contains "$wrapper" 'VariantPillButton \{ label: "Rainbow"; variant: "rainbow" \}' \
  "settings wrapper variant controls should expose the full Ryoku variant set"
assert_contains "$wrapper" 'function beginEdit' \
  "numeric rows should support click-to-type editing"
assert_contains "$wrapper" 'function cancelEdit' \
  "numeric rows should support canceling typed edits"
assert_contains "$wrapper" 'Keys\.onEscapePressed: sliderRow\.cancelEdit\(\)' \
  "numeric row editors should cancel on Escape"
assert_contains "$wrapper" 'Keys\.onUpPressed: sliderRow\.commit\(sliderRow\.currentValue \+ sliderRow\.stepSize\)' \
  "numeric row editors should spin-step upward from the keyboard"
assert_contains "$wrapper" 'onWheel' \
  "numeric rows should support mouse-wheel stepping"
assert_contains "$wrapper" 'property string targetKey' \
  "settings rows should carry explicit config keys where labels repeat"
assert_contains "$wrapper" 'propertyName: "schemes"; targetKey: "launcher.useFuzzy.schemes"' \
  "settings wrapper should expose launcher scheme fuzzy matching"
assert_contains "$wrapper" 'component IslandPage' \
  "settings wrapper should replace the removed Dashboard section with Island controls"
assert_contains "$wrapper" 'propertyName: "dragThreshold"; targetKey: "dashboard.dragThreshold"' \
  "settings wrapper should expose the island gesture threshold"
assert_contains "$wrapper" 'settingKey: "paths\.wallpaperDir"' \
  "settings wrapper Appearance page should expose the wallpaper folder path"
assert_contains "$wrapper" 'component WallpaperPreviewGrid' \
  "settings wrapper Appearance page should render wallpaper previews"
assert_contains "$wrapper" 'readonly property string ryokuBridge' \
  "scheme controls should use the running shell runtime bridge"
assert_contains "$paths" 'readonly property string ryokuBridge' \
  "scheme callers should share the runtime bridge path"
assert_contains "$wrapper" 'root\.ryokuBridge, "scheme", "preview", "--notify"' \
  "scheme controls should preview through the Ryoku scheme bridge before saving"
assert_contains "$wrapper" 'root\.ryokuBridge, "scheme", "set", "--notify"' \
  "scheme controls should persist through the Ryoku scheme bridge on Save"
assert_contains "$wrapper" 'command: \[root\.ryokuBridge, "scheme", "get", "-nfvm"\]' \
  "scheme controls should read saved state from the runtime bridge"
assert_contains "$colours" 'Paths\.ryokuBridge, "scheme", "set", "--notify"' \
  "global theme mode switching should use the runtime bridge"
assert_contains "$schemes" 'Paths\.ryokuBridge, "scheme", "list"' \
  "launcher scheme search should use the runtime bridge"
assert_contains "$schemes" 'Paths\.ryokuBridge, "scheme", "get", "-nfv"' \
  "launcher scheme state should use the runtime bridge"
assert_contains "$variants" 'Paths\.ryokuBridge, "scheme", "set", "-v"' \
  "launcher variant actions should use the runtime bridge"
assert_contains "$wrapper" 'function refreshSchemeState' \
  "scheme controls should refresh current and saved state whenever settings opens"
assert_contains "$wrapper" 'root\.refreshSchemeState\(\)' \
  "settings should avoid stale scheme state when reopened"
assert_contains "$wrapper" 'onTriggered: root\.refreshCurrentSchemeState\(\)' \
  "scheme previews should hot-reload from the live scheme file without a shell restart"
assert_contains "$wrapper" 'path: `\$\{Paths\.state\}/scheme\.json`' \
  "settings should watch the same live scheme file as the shell color service"
assert_contains "$wrapper" 'onFileChanged: reload\(\)' \
  "settings scheme chips should update when the live scheme file changes"
assert_contains "$wrapper" 'id: schemePersist' \
  "scheme saves should refresh state when the persistence process exits"
assert_contains "$wrapper" 'readonly property int contentMaxWidth: 800' \
  "settings wrapper should clamp content to HyprMod's preference width"
assert_contains "$wrapper" 'readonly property int hyprmodDefaultWidth: 900' \
  "settings wrapper should match HyprMod's default window width"
assert_contains "$wrapper" 'readonly property int hyprmodDefaultHeight: 650' \
  "settings wrapper should match HyprMod's default window height"
assert_contains "$wrapper" 'implicitWidth: Math\.min\(root\.availableWidth \* 0\.92, root\.hyprmodDefaultWidth\)' \
  "settings wrapper should responsively cap width at HyprMod's default"
assert_contains "$wrapper" 'implicitHeight: Math\.min\(root\.availableHeight \* 0\.9, root\.hyprmodDefaultHeight\)' \
  "settings wrapper should responsively cap height at HyprMod's default"
assert_contains "$wrapper" 'readonly property int hyprmodPageVerticalMargin: 24' \
  "settings wrapper should use HyprMod's standard vertical content margin"
assert_contains "$wrapper" 'readonly property int hyprmodPageHorizontalMargin: 12' \
  "settings wrapper should use HyprMod's standard horizontal content margin"
assert_contains "$wrapper" 'readonly property int hyprmodPageSpacing: 24' \
  "settings wrapper should use HyprMod's standard group spacing"
assert_contains "$wrapper" 'contentHeight: pageBody\.implicitHeight \+ root\.hyprmodPageVerticalMargin \* 2' \
  "settings wrapper should calculate scroll height from HyprMod margins"
assert_contains "$wrapper" 'spacing: root\.hyprmodPageSpacing' \
  "settings wrapper should space preference groups like HyprMod"
assert_contains "$wrapper" 'function focusSearch' \
  "settings wrapper should expose HyprMod-style keyboard search focus"
assert_contains "$wrapper" 'function formatBreadcrumb' \
  "settings wrapper search rows should format breadcrumbs like HyprMod"
assert_contains "$wrapper" 'replace\(/\\s\*>\\s\*/g, " \\u203a "\)' \
  "settings wrapper search rows should use HyprMod's breadcrumb separator"
assert_contains "$wrapper" 'placeholderText: "Search options\\u2026"' \
  "settings wrapper search placeholder should use HyprMod's ellipsis copy"
assert_contains "$wrapper" 'text: "Search options \(Ctrl\+F\)"' \
  "settings wrapper search tooltip should include HyprMod's shortcut hint"
assert_contains "$wrapper" 'focus: root\.shouldBeActive' \
  "settings wrapper should claim QML key focus while open"
assert_contains "$wrapper" 'root\.forceActiveFocus\(\)' \
  "settings wrapper should restore key focus whenever the drawer opens"
assert_contains "$wrapper" 'searchField\.forceActiveFocus\(\)' \
  "settings wrapper search field should receive focus when search opens"
assert_contains "$wrapper" 'event\.key === Qt\.Key_F' \
  "settings wrapper should bind Ctrl+F to search like HyprMod"
assert_contains "$wrapper" 'event\.key === Qt\.Key_S' \
  "settings wrapper should bind Ctrl+S to Save now like HyprMod"
assert_contains "$wrapper" 'event\.key === Qt\.Key_Z' \
  "settings wrapper should bind Ctrl+Z/Ctrl+Shift+Z to pending-change history"
assert_contains "$wrapper" 'function undoLastChange' \
  "settings wrapper should implement the advertised undo shortcut"
assert_contains "$wrapper" 'function redoLastChange' \
  "settings wrapper should implement the advertised redo shortcut"
assert_contains "$wrapper" 'property var changeHistory' \
  "settings wrapper should track recent changes for keyboard undo"
assert_contains "$wrapper" 'fromValue' \
  "settings wrapper pending entries should keep pre-edit values for undo"
assert_contains "$wrapper" 'toValue' \
  "settings wrapper pending entries should keep post-edit values for redo"
assert_contains "$wrapper" 'root\.dismissSearch\(\)' \
  "settings wrapper Escape handling should dismiss search before closing"
assert_contains "$interactions" 'function closeSettingsIfOutside' \
  "drawer interactions should expose a shared settings outside-click close helper"
assert_contains "$content_window" 'visible: visibilities\.settings' \
  "settings should install a dedicated outside-click catcher while open"
assert_contains "$content_window" 'interactions\.closeSettingsIfOutside\(event\.x, event\.y\)' \
  "outside clicks should close the settings drawer from transparent space"
assert_contains "$wrapper" 'component DirtyBanner' \
  "settings wrapper should include the HyprMod-style bottom status banner"
assert_contains "$wrapper" 'Unsaved changes \\u2014 applied live, not saved to disk' \
  "settings wrapper dirty banner should use HyprMod's unsaved-changes message"
assert_contains "$wrapper" 'component PendingChangesPage' \
  "settings wrapper should include a HyprMod-style Pending Changes page"
assert_contains "$wrapper" 'component PendingChangeRow' \
  "settings wrapper should render pending changes as Adwaita-style rows"
assert_contains "$wrapper" 'component ConfigDiffPreview' \
  "settings wrapper Pending Changes page should include a HyprMod-style config diff preview"
assert_contains "$wrapper" 'component DiffStatPill' \
  "settings wrapper diff preview should include HyprMod-style added and removed count pills"
assert_contains "$wrapper" 'Comparison between the saved config and what the next save would write\.' \
  "settings wrapper diff preview should use HyprMod's config diff description"
assert_contains "$wrapper" 'property var pendingEntries' \
  "settings wrapper should maintain a pending-change registry"
assert_contains "$wrapper" 'root\.openPendingChanges\(\)' \
  "settings wrapper pending chip should navigate to Pending Changes"
assert_contains "$wrapper" 'function discardAllPending' \
  "settings wrapper Pending Changes page should expose a discard-all action"
assert_contains "$wrapper" 'function saveAllPending' \
  "settings wrapper dirty banner should expose HyprMod-style Save now behavior"
assert_contains "$wrapper" 'component SaveSplitButton' \
  "settings wrapper dirty banner should use HyprMod's split Save now button"
assert_contains "$wrapper" 'Save as new profile' \
  "settings wrapper split save button should expose HyprMod's profile save affordance"
assert_contains "$wrapper" 'Save without updating profile' \
  "settings wrapper split save button should expose HyprMod's active-profile save affordance"
assert_contains "$wrapper" 'component ProfileCard' \
  "settings wrapper Profiles page should render reusable profile cards"
assert_contains "$wrapper" 'text: "Save current as new profile"' \
  "settings wrapper Profiles page should expose HyprMod's save-current tooltip"
assert_contains "$wrapper" 'ryoku-shell-profile' \
  "settings wrapper Profiles page should use a real shell profile adapter"
assert_contains "$wrapper" 'text: "Delete profile"' \
  "settings wrapper Profiles page should replace the inert three-dot menu with a working delete action"
assert_contains "$wrapper" 'Qt\.alpha\(root\.accent, 0\.06\)' \
  "settings wrapper active profile cards should use HyprMod's subtle accent tint"
assert_contains "$wrapper" 'width: 3' \
  "settings wrapper active profile cards should use HyprMod's left accent bar"
assert_contains "$wrapper" 'title: "Config file path"' \
  "settings wrapper Settings page should expose HyprMod's config path row"
assert_contains "$wrapper" 'component EntryPreferenceRow' \
  "settings wrapper Settings page should use HyprMod-style editable entry rows"
assert_contains "$wrapper" 'function applyText' \
  "settings wrapper editable entry rows should expose an apply action"
assert_contains "$wrapper" 'Keys\.onEscapePressed: entryRow\.resetText\(\)' \
  "settings wrapper editable entry rows should cancel text edits on Escape"
assert_contains "$wrapper" 'settingKey: "settings\.configPath"' \
  "settings wrapper config path row should be searchable and highlightable"
assert_contains "$wrapper" 'readOnly: entryRow\.readOnly' \
  "settings wrapper config path row should avoid pretending the backend path is editable"
assert_contains "$wrapper" 'text: "Browse\\u2026"' \
  "settings wrapper Settings page should expose HyprMod's browse tooltip"
assert_contains "$wrapper" 'description: "Automatically save changes after each modification\."' \
  "settings wrapper Settings page should expose HyprMod's auto-save copy"
assert_contains "$wrapper" 'component NavigationPreferenceRow' \
  "settings wrapper should provide HyprMod-style navigation rows for shell edits"
assert_contains "$wrapper" 'title: "Shell edits"' \
  "settings wrapper Hyprland page should include an in-surface shell edits section"
assert_contains "$wrapper" 'key: "hyprland\.shell_edits"' \
  "settings wrapper shell edits should be searchable"
assert_contains "$wrapper" 'autoSavePendingTimer' \
  "settings wrapper should support HyprMod-style debounced auto-save when enabled"
assert_contains "$wrapper" 'beginShellConfigEditSession\(\)' \
  "settings wrapper should suspend config autosave before live shell edits"
assert_contains "$wrapper" 'setAutoSaveSuspended' \
  "settings wrapper should resume config autosave after pending shell edits are resolved"
assert_contains "$wrapper" 'root\.pageIndexForSetting\(switchRow\.title, switchRow\.propertyName\)' \
  "settings wrapper should attribute switch pending entries to their source page"
assert_contains "$wrapper" 'root\.pageIndexForSetting\(sliderRow\.title, sliderRow\.propertyName\)' \
  "settings wrapper should attribute numeric pending entries to their source page"
assert_contains "$wrapper" 'targetKey: sliderRow\.settingKey' \
  "settings wrapper pending numeric rows should navigate back to the exact source option"
assert_contains "$wrapper" 'function abandonPendingSession' \
  "settings wrapper should abandon live pending edits when the drawer is hidden"
assert_contains "$wrapper" 'onShouldBeActiveChanged' \
  "settings wrapper should clean up pending edit sessions when hidden"
assert_contains "shell/plugin/src/Ryoku/Config/rootconfig.hpp" 'autoSaveSuspended' \
  "config backend should expose an autosave suspension hook for pending settings edits"
assert_contains "$wrapper" 'function saveScheme' \
  "settings wrapper scheme controls should persist previews from the Save now path"
assert_contains "$wrapper" 'readonly property bool schemeDirty' \
  "settings wrapper should track unsaved scheme previews as a complete tuple"
assert_contains "$wrapper" 'function isSchemePendingEntry' \
  "settings wrapper should identify scheme-related pending rows during discard"
assert_contains "$wrapper" 'if \(restoreSavedScheme\)' \
  "settings wrapper should restore the full saved scheme after discarding previews"
assert_contains "$wrapper" 'if \(root\.schemeDirty\)' \
  "settings wrapper close should abandon unsaved scheme previews"
assert_contains "$wrapper" 'accept: \(\) =>' \
  "settings wrapper pending entries should accept current values as saved baselines"
assert_contains "$wrapper" '#F25623' \
  "settings wrapper should use the Ryoku brand orange (docs/branding.md) for branded About accents"
assert_contains "$wrapper" 'GlobalConfig\.save\(\)' \
  "settings wrapper should persist changes through GlobalConfig"
assert_contains "$wrapper" 'RyokuAbout\.helper, "refresh-shell"' \
  "settings wrapper should restart through the runtime settings about adapter"
assert_contains "$wrapper" 'ryoku-reload-hyprland' \
  "settings wrapper should reload Hyprland through a Ryoku command adapter"
assert_contains "$wrapper" 'visible: true' \
  "settings wrapper should stay resident for immediate opens"
assert_contains "$wrapper" 'offsetScale' \
  "settings wrapper should preserve the shell drawer opening animation"
assert_contains "$wrapper" 'ryoku-launch-hyprmod' \
  "settings wrapper should delegate advanced Hyprland configuration to HyprMod"
assert_not_contains "$wrapper" 'ControlCenter \{' \
  "settings wrapper should not render the old control-center backend"
assert_not_contains "$wrapper" 'component NavGroup|navGroups|expand_more' \
  "settings wrapper should not contain grouped drawer-style sidebar navigation"
assert_not_contains "$wrapper" 'component SettingsGrid' \
  "settings wrapper should not keep the pre-HyprMod bento grid frontend"
assert_not_contains "$wrapper" 'StyledSlider' \
  "settings wrapper should not use oversized Material sliders"
assert_not_contains "$wrapper" 'StyledSwitch' \
  "settings wrapper should not use icon-heavy Material switches"
assert_not_contains "$wrapper" 'notify-send", "Ryoku Settings"' \
  "settings wrapper keyboard shortcuts should not be a transient notification"
assert_not_contains "$wrapper" 'implicitHeight: parent\.height - Tokens\.padding\.small' \
  "settings wrapper should not use a thin active sidebar rail"
assert_not_contains "$wrapper" 'ryoku-launch-wayle-settings|hyprctl clients -j|showLaunchSurface' \
  "settings wrapper should not contain external Wayle launch plumbing"
assert_not_contains "$wrapper" '\bbar\.enabled|launcher\.itemScale|notifs\.expireTimeout|background\.clockEnabled|background\.visualiserEnabled' \
  "settings search should not advertise shell options without backed rows"
assert_contains "$panels" 'ControlCenter\.Wrapper' \
  "drawers should keep the settings wrapper"
assert_contains "$content_window" 'panel: panels\.settings' \
  "drawer background should keep the settings panel"
assert_contains "$content_window" '\|\| visibilities\.settings \|\|' \
  "settings should participate in the focus-grab outside-click dismissal path"
assert_not_contains "$content_window" 'showLaunchSurface' \
  "drawer background should not depend on an external launch placeholder"
assert_contains "shell/modules/drawers/Interactions.qml" 'visibilities\.settings && !inPanelBounds\(panels\.settings' \
  "clicking outside the settings panel should dismiss the drawer"
assert_contains "$bar_popouts" 'visibilities\.settings = true' \
  "bar popout settings actions should route through the top-frame settings wrapper"
assert_not_contains "$bar_popouts" 'ryoku-launch-wayle-settings' \
  "bar popout settings actions should not bypass the resident top-frame wrapper"
assert_not_contains "$bar_popouts" 'ControlCenter \{' \
  "bar popouts should not render the old control-center backend"

assert_not_contains "$launcher" 'settings-window|ryoku-settings-window|legacy-settings-window|waffle-settings-window|ryoku-launch-wayle-settings' \
  "ryoku-shell should not expose detached or external settings commands"
assert_not_contains "$launcher" 'open_detached_qml_window[^\n]*(ryokuSettings|settings|waffleSettings)\.qml' \
  "ryoku-shell should not launch removed settings QML entrypoints"
assert_not_contains "$launcher" 'RYOKU_SETTINGS_MODE|settings_launch_mode|open_settings_surface' \
  "detached settings launch-mode code should be removed"

echo "PASS: settings surface cleanup"
