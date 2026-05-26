#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_file() {
  local path="$1"

  [[ -f $ROOT_DIR/$path ]] || fail "missing $path"
}

assert_executable() {
  local path="$1"

  [[ -x $ROOT_DIR/$path ]] || fail "missing executable $path"
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

assert_file shell/shell.qml
assert_file shell/CMakeLists.txt
assert_file shell/LICENSE
assert_file shell/plugin/src/Ryoku/CMakeLists.txt
assert_file shell/modules/Shortcuts.qml
assert_file shell/components/controls/MenuItem.qml
assert_file shell/components/controls/Menu.qml
assert_executable shell/scripts/ryoku-shell
assert_executable shell/scripts/ryoku
assert_executable shell/setup

assert_contains shell/CMakeLists.txt 'project\(ryoku-shell' \
  "shell CMake project should use Ryoku naming"
assert_contains shell/CMakeLists.txt 'INSTALL_QSCONFDIR "etc/xdg/quickshell/ryoku-shell"' \
  "shell CMake install path should use ryoku-shell"
assert_contains shell/utils/Paths.qml '/ryoku-shell`' \
  "shell user paths should use ryoku-shell"
assert_contains shell/utils/Paths.qml 'readonly property string ryokuBridge' \
  "shell scheme callers should share the runtime-local Ryoku bridge"
assert_contains shell/components/misc/CustomShortcut.qml 'appid: "ryoku"' \
  "global shortcuts should use Ryoku app id"
assert_contains shell/scripts/ryoku-shell 'RYOKU_COMPOSITOR.*hyprland|HYPRLAND_INSTANCE_SIGNATURE' \
  "launcher should support explicit Hyprland service handling"
assert_contains shell/scripts/ryoku-shell 'ipc_call controlCenter toggle' \
  "settings command should open the native top-frame settings drawer"
assert_contains shell/setup 'RYOKU_COMPOSITOR.*hyprland|HYPRLAND_INSTANCE_SIGNATURE' \
  "setup should support explicit Hyprland service handling"
assert_contains shell/setup "scripts/ryoku\" \"\\\$bin_dir/ryoku" \
  "setup should install the imported shell compatibility bridge"
assert_contains shell/modules/controlcenter/Wrapper.qml 'component AppearancePage' \
  "settings wrapper should provide a native Appearance page"
assert_contains shell/modules/controlcenter/Wrapper.qml 'component ProfilesPage' \
  "settings wrapper should provide HyprMod-style Profiles"
assert_contains shell/modules/controlcenter/Wrapper.qml 'component AppSettingsPage' \
  "settings wrapper should provide HyprMod-style app Settings"
assert_contains shell/modules/controlcenter/Wrapper.qml 'title: "HyprMod"' \
  "settings wrapper sidebar header should use HyprMod's title"
assert_contains shell/modules/controlcenter/Wrapper.qml 'readonly property var pinnedPages: \[8, 9\]' \
  "settings wrapper should pin Profiles and Settings like HyprMod"
assert_contains shell/modules/controlcenter/Wrapper.qml 'readonly property int searchPageIndex: 10' \
  "settings wrapper should keep search after pinned pages"
assert_contains shell/modules/controlcenter/Wrapper.qml 'readonly property int pendingPageIndex: 11' \
  "settings wrapper should keep pending changes off-sidebar"
assert_contains shell/modules/controlcenter/Wrapper.qml 'property int currentPage: 1' \
  "settings wrapper should open on the first task page"
assert_contains shell/modules/controlcenter/Wrapper.qml 'component SearchBox' \
  "settings wrapper should provide native settings search"
assert_contains shell/modules/controlcenter/Wrapper.qml 'component SearchPage' \
  "settings wrapper should provide a HyprMod-style Search Results page"
assert_contains shell/modules/controlcenter/Wrapper.qml 'component SearchResultRow' \
  "settings wrapper should provide Adwaita-style search result rows"
assert_contains shell/modules/controlcenter/Wrapper.qml 'function highlightSetting' \
  "settings wrapper should provide HyprMod-style source row highlighting"
assert_contains shell/modules/controlcenter/Wrapper.qml 'function formatBreadcrumb' \
  "settings wrapper should format search breadcrumbs like HyprMod"
assert_contains shell/modules/controlcenter/Wrapper.qml 'placeholderText: "Search options\\u2026"' \
  "settings wrapper search placeholder should use HyprMod's ellipsis copy"
assert_contains shell/modules/controlcenter/Wrapper.qml 'component SidebarCategory' \
  "settings wrapper should provide HyprMod-style sidebar categories"
assert_contains shell/modules/controlcenter/Wrapper.qml 'component SidebarRow' \
  "settings wrapper should provide HyprMod-style sidebar rows"
assert_contains shell/modules/controlcenter/Wrapper.qml 'component SidebarBadge' \
  "settings wrapper should provide HyprMod-style pending sidebar badges"
assert_contains shell/modules/controlcenter/Wrapper.qml 'title: "Display"' \
  "settings wrapper sidebar should mirror HyprMod's Display category"
assert_contains shell/modules/controlcenter/Wrapper.qml 'title: "Window Management"' \
  "settings wrapper sidebar should mirror HyprMod's Window Management category"
assert_contains shell/modules/controlcenter/Wrapper.qml 'title: "Startup"' \
  "settings wrapper sidebar should mirror HyprMod's Startup category"
assert_contains shell/modules/controlcenter/Wrapper.qml 'component PreferenceGroup' \
  "settings wrapper should provide Adwaita-style preference groups"
assert_contains shell/modules/controlcenter/Wrapper.qml 'component AdwSwitch' \
  "settings wrapper should provide HyprMod-style libadwaita switches"
assert_contains shell/modules/controlcenter/Wrapper.qml 'component StepperButton' \
  "settings wrapper should provide compact scalar controls"
assert_contains shell/modules/controlcenter/Wrapper.qml 'component RowActionButton' \
  "settings wrapper should provide row reset actions"
assert_contains shell/modules/controlcenter/Wrapper.qml 'property bool revealed' \
  "settings wrapper row reset actions should support HyprMod-style hover reveal"
assert_contains shell/modules/controlcenter/Wrapper.qml 'revealed: sliderRow\.hovered' \
  "settings wrapper numeric reset actions should reveal on row hover"
assert_contains shell/modules/controlcenter/Wrapper.qml 'tooltipText: "Discard changes"' \
  "settings wrapper should describe row reset actions like HyprMod"
assert_contains shell/modules/controlcenter/Wrapper.qml 'component SchemePreferenceRow' \
  "settings wrapper should provide scheme colour controls"
assert_contains shell/modules/controlcenter/Wrapper.qml 'component HeaderBar' \
  "settings wrapper should provide HyprMod-style toolbar headers"
assert_contains shell/modules/controlcenter/Wrapper.qml 'readonly property int hyprmodDefaultWidth: 900' \
  "settings wrapper should match HyprMod's default window width"
assert_contains shell/modules/controlcenter/Wrapper.qml 'readonly property int hyprmodDefaultHeight: 650' \
  "settings wrapper should match HyprMod's default window height"
assert_contains shell/modules/controlcenter/Wrapper.qml 'readonly property int hyprmodPageVerticalMargin: 24' \
  "settings wrapper should use HyprMod's standard vertical content margin"
assert_contains shell/modules/controlcenter/Wrapper.qml 'readonly property int hyprmodPageSpacing: 24' \
  "settings wrapper should use HyprMod's standard group spacing"
assert_contains shell/modules/controlcenter/Wrapper.qml 'focus: root\.shouldBeActive' \
  "settings wrapper should claim QML key focus while open"
assert_contains shell/modules/controlcenter/Wrapper.qml 'event\.key === Qt\.Key_F' \
  "settings wrapper should bind Ctrl+F to search like HyprMod"
assert_contains shell/modules/controlcenter/Wrapper.qml 'event\.key === Qt\.Key_S' \
  "settings wrapper should bind Ctrl+S to Save now like HyprMod"
assert_contains shell/modules/controlcenter/Wrapper.qml 'event\.key === Qt\.Key_Z' \
  "settings wrapper should bind Ctrl+Z/Ctrl+Shift+Z to pending-change history"
assert_contains shell/modules/controlcenter/Wrapper.qml 'function undoLastChange' \
  "settings wrapper should implement the advertised undo shortcut"
assert_contains shell/modules/controlcenter/Wrapper.qml 'MenuItem \{' \
  "settings wrapper should provide a HyprMod-style header menu"
assert_contains shell/components/controls/MenuItem.qml 'property bool separatorBefore' \
  "settings menu items should support HyprMod-style sections"
assert_contains shell/components/controls/MenuItem.qml 'property bool enabled' \
  "settings menu items should support HyprMod-style disabled action rows"
assert_contains shell/modules/controlcenter/Wrapper.qml 'separatorBefore: true' \
  "settings wrapper header menu should group HyprMod-style sections"
assert_contains shell/modules/controlcenter/Wrapper.qml 'text: "Auto-save"' \
  "settings wrapper header menu should expose HyprMod's Auto-save preference"
assert_contains shell/modules/controlcenter/Wrapper.qml 'text: "Migrate to Lua\\u2026"' \
  "settings wrapper header menu should include HyprMod's Lua migration action row"
assert_contains shell/modules/controlcenter/Wrapper.qml 'text: "Review deprecated syntax\\u2026"' \
  "settings wrapper header menu should include HyprMod's deprecated syntax action row"
assert_contains shell/modules/controlcenter/Wrapper.qml 'text: "Keyboard Shortcuts"' \
  "settings wrapper header menu should expose HyprMod's keyboard shortcuts item"
assert_contains shell/modules/controlcenter/Wrapper.qml 'component ShortcutOverlay' \
  "settings wrapper keyboard shortcuts should open a HyprMod-style modal overlay"
assert_contains shell/modules/controlcenter/Wrapper.qml 'event\.key === Qt\.Key_F1' \
  "settings wrapper should bind F1 to the keyboard shortcuts overlay"
assert_contains shell/modules/controlcenter/Wrapper.qml 'text: "About HyprMod"' \
  "settings wrapper header menu should use HyprMod's About label"
assert_contains shell/modules/controlcenter/Wrapper.qml 'SchemeSwatchButton \{ flavour: "default"' \
  "settings wrapper should expose the default Ryoku scheme accent"
assert_contains shell/modules/controlcenter/Wrapper.qml 'VariantPillButton \{ label: "Rainbow"; variant: "rainbow" \}' \
  "settings wrapper should expose the full Ryoku scheme variant set"
assert_contains shell/modules/controlcenter/Wrapper.qml 'function refreshSchemeState' \
  "settings wrapper should refresh scheme state when reopened"
assert_contains shell/modules/controlcenter/Wrapper.qml 'readonly property string ryokuBridge' \
  "settings wrapper should use the running shell runtime bridge for scheme edits"
assert_contains shell/modules/controlcenter/Wrapper.qml 'root\.ryokuBridge, "scheme", "preview", "--notify"' \
  "settings wrapper should preview scheme edits through the runtime bridge"
assert_contains shell/modules/controlcenter/Wrapper.qml 'command: \[root\.ryokuBridge, "scheme", "get", "-nfvm"\]' \
  "settings wrapper should read saved scheme fields from the runtime bridge"
assert_contains shell/services/Colours.qml 'Paths\.ryokuBridge, "scheme", "set", "--notify"' \
  "theme mode switching should use the runtime-local Ryoku bridge"
assert_contains shell/modules/launcher/services/Schemes.qml 'Paths\.ryokuBridge, "scheme", "list"' \
  "launcher scheme search should use the runtime-local Ryoku bridge"
assert_contains shell/modules/launcher/services/Schemes.qml 'Paths\.ryokuBridge, "scheme", "get", "-nfv"' \
  "launcher scheme state should use the runtime-local Ryoku bridge"
assert_contains shell/modules/launcher/services/M3Variants.qml 'Paths\.ryokuBridge, "scheme", "set", "-v"' \
  "launcher variant actions should use the runtime-local Ryoku bridge"
assert_contains shell/modules/controlcenter/Wrapper.qml 'onTriggered: root\.refreshCurrentSchemeState\(\)' \
  "settings wrapper should hot-reload scheme previews without restarting the shell"
assert_contains shell/modules/controlcenter/Wrapper.qml 'path: `\$\{Paths\.state\}/scheme\.json`' \
  "settings wrapper should watch the live scheme file for external hot reloads"
assert_contains shell/modules/controlcenter/Wrapper.qml 'onFileChanged: reload\(\)' \
  "settings wrapper should refresh scheme chips when the live scheme file changes"
assert_contains shell/modules/controlcenter/Wrapper.qml 'id: schemePersist' \
  "settings wrapper should refresh saved scheme state after persisting"
assert_contains shell/modules/controlcenter/Wrapper.qml 'Keys\.onEscapePressed: sliderRow\.cancelEdit\(\)' \
  "settings wrapper should let typed numeric edits be canceled before commit"
assert_contains shell/modules/controlcenter/Wrapper.qml 'component DirtyBanner' \
  "settings wrapper should provide the HyprMod-style bottom status banner"
assert_contains shell/modules/controlcenter/Wrapper.qml 'Unsaved changes \\u2014 applied live, not saved to disk' \
  "settings wrapper dirty banner should match HyprMod pending-copy"
assert_contains shell/modules/controlcenter/Wrapper.qml 'component PendingChangesPage' \
  "settings wrapper should provide a HyprMod-style Pending Changes page"
assert_contains shell/modules/controlcenter/Wrapper.qml 'component ConfigDiffPreview' \
  "settings wrapper should provide a HyprMod-style config diff preview"
assert_contains shell/modules/controlcenter/Wrapper.qml 'property var pendingEntries' \
  "settings wrapper should track changed rows for pending review"
assert_contains shell/modules/controlcenter/Wrapper.qml 'function saveAllPending' \
  "settings wrapper should accept pending values from the dirty banner"
assert_contains shell/modules/controlcenter/Wrapper.qml 'component SaveSplitButton' \
  "settings wrapper should use HyprMod's split Save now button"
assert_contains shell/modules/controlcenter/Wrapper.qml 'Save as new profile' \
  "settings wrapper should expose HyprMod's profile save affordance"
assert_contains shell/modules/controlcenter/Wrapper.qml 'Save without updating profile' \
  "settings wrapper should expose HyprMod's active-profile save affordance"
assert_contains shell/modules/controlcenter/Wrapper.qml 'component ProfileDnaPreview' \
  "settings wrapper should include HyprMod-style profile DNA previews"
assert_contains shell/modules/controlcenter/Wrapper.qml 'component ProfileCard' \
  "settings wrapper should render reusable profile cards"
assert_contains shell/modules/controlcenter/Wrapper.qml 'property bool profileSaveButton' \
  "settings wrapper should expose HyprMod's header save-current button"
assert_contains shell/modules/controlcenter/Wrapper.qml 'profileSaveButton: !root\.searchActive && root\.currentPage === 8' \
  "settings wrapper should show the Profiles save action in the header"
assert_contains shell/modules/controlcenter/Wrapper.qml 'text: "Save current as new profile"' \
  "settings wrapper should expose HyprMod's save-current profile tooltip"
assert_contains shell/modules/controlcenter/Wrapper.qml 'Qt\.alpha\(root\.accent, 0\.06\)' \
  "settings wrapper active profile cards should use a subtle accent tint"
assert_contains shell/modules/controlcenter/Wrapper.qml 'width: 3' \
  "settings wrapper active profile cards should use a thin left accent bar"
assert_contains shell/modules/controlcenter/Wrapper.qml 'title: "Config file path"' \
  "settings wrapper should expose HyprMod's config path row"
assert_contains shell/modules/controlcenter/Wrapper.qml 'component EntryPreferenceRow' \
  "settings wrapper should expose HyprMod-style editable entry rows"
assert_contains shell/modules/controlcenter/Wrapper.qml 'function applyText' \
  "settings wrapper editable entry rows should expose apply behavior"
assert_contains shell/modules/controlcenter/Wrapper.qml 'Keys\.onEscapePressed: entryRow\.resetText\(\)' \
  "settings wrapper editable entry rows should cancel text edits on Escape"
assert_contains shell/modules/controlcenter/Wrapper.qml 'settingKey: "settings\.configPath"' \
  "settings wrapper config path row should be searchable and highlightable"
assert_contains shell/modules/controlcenter/Wrapper.qml 'onApplied: root\.markSaved\(\)' \
  "settings wrapper config path row should expose an EntryRow-style apply path"
assert_contains shell/modules/controlcenter/Wrapper.qml 'text: "Browse\\u2026"' \
  "settings wrapper should expose HyprMod's browse tooltip"
assert_contains shell/modules/controlcenter/Wrapper.qml 'description: "Automatically save changes after each modification\."' \
  "settings wrapper should expose HyprMod's auto-save copy"
assert_contains shell/modules/controlcenter/Wrapper.qml 'component NavigationPreferenceRow' \
  "settings wrapper should provide HyprMod-style navigation rows for shell edits"
assert_contains shell/modules/controlcenter/Wrapper.qml 'title: "Shell edits"' \
  "settings wrapper Hyprland page should include shell edits"
assert_contains shell/modules/controlcenter/Wrapper.qml 'beginShellConfigEditSession\(\)' \
  "settings wrapper should preview shell config edits without immediate persistence"
assert_contains shell/modules/controlcenter/Wrapper.qml 'root\.pageIndexForSetting\(sliderRow\.title, sliderRow\.propertyName\)' \
  "settings wrapper should attribute pending numeric rows to their source page"
assert_contains shell/modules/controlcenter/Wrapper.qml 'targetKey: sliderRow\.settingKey' \
  "settings wrapper should navigate pending numeric rows back to their source option"
assert_contains shell/modules/controlcenter/Wrapper.qml 'function abandonPendingSession' \
  "settings wrapper should abandon live pending edits when the drawer is hidden"
assert_contains shell/modules/controlcenter/Wrapper.qml 'readonly property bool schemeDirty' \
  "settings wrapper should track unsaved scheme previews"
assert_contains shell/modules/controlcenter/Wrapper.qml 'function isSchemePendingEntry' \
  "settings wrapper should identify scheme pending rows for discard"
assert_contains shell/modules/controlcenter/Wrapper.qml 'if \(restoreSavedScheme\)' \
  "settings wrapper should restore saved scheme after discarding previews"
assert_contains shell/modules/drawers/Interactions.qml 'function closeSettingsIfOutside' \
  "drawer interactions should close settings from outside clicks"
assert_contains shell/modules/drawers/ContentWindow.qml 'interactions\.closeSettingsIfOutside\(event\.x, event\.y\)' \
  "settings outside-click catcher should be active in transparent space"
assert_contains shell/plugin/src/Ryoku/Config/rootconfig.hpp 'autoSaveSuspended' \
  "config backend should expose an autosave suspension hook for pending settings edits"
assert_contains shell/modules/controlcenter/Wrapper.qml 'GlobalConfig\.save\(\)' \
  "settings wrapper should persist controls through GlobalConfig"
assert_contains shell/modules/controlcenter/Wrapper.qml 'ryoku-launch-hyprmod' \
  "settings wrapper should hand advanced Hyprland configuration to HyprMod"
assert_contains shell/modules/Shortcuts.qml 'visibilities.settings = true' \
  "settings shortcuts should request the native settings drawer"
assert_contains shell/assets/systemd/ryoku-shell.service 'Environment=PATH=.*\.local/bin' \
  "service should expose user-installed Ryoku bridge commands"
assert_contains config/systemd/user/ryoku-shell.service 'Environment=PATH=.*\.local/bin' \
  "default service config should expose user-installed Ryoku bridge commands"
assert_contains shell/assets/systemd/ryoku-shell.service 'IOSchedulingPriority=2' \
  "runtime service template should prioritize shell startup I/O"
assert_contains config/systemd/user/ryoku-shell.service 'IOSchedulingPriority=2' \
  "default service config should prioritize shell startup I/O"
assert_contains shell/scripts/ryoku 'ryoku-wallpaper-apply' \
  "compatibility bridge should delegate wallpaper application to Ryoku commands"
assert_contains shell/scripts/ryoku 'ryoku-doctor' \
  "compatibility bridge should expose the global doctor command"
assert_contains install/ryoku-base.packages '^aubio$' \
  "base packages should include native shell audio analysis dependency"
assert_contains install/ryoku-base.packages '^gtk4$' \
  "base packages should keep GTK4 for native desktop integrations"
assert_not_contains install/ryoku-base.packages '^gtk4-layer-shell$' \
  "base packages should not keep the removed Wayle layer-shell dependency"
assert_not_contains install/ryoku-base.packages '^gtksourceview5$' \
  "base packages should not keep the removed Wayle GtkSourceView dependency"
assert_contains install/ryoku-base.packages '^ttf-cascadia-code-nerd$' \
  "base packages should include the shell mono Nerd Font"
assert_contains install/ryoku-aur.packages '^app2unit$' \
  "AUR packages should include the shell app2unit runtime helper"

command -v jq >/dev/null 2>&1 || fail "jq is required for the shell bridge test"
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

HOME="$tmp_dir/home" XDG_STATE_HOME="$tmp_dir/state" \
  "$ROOT_DIR/shell/scripts/ryoku" scheme list | jq -e '.ryoku.default.primary == "F25623"' >/dev/null || \
  fail "compatibility bridge should expose a shell-readable scheme list"

current_scheme=$(
  HOME="$tmp_dir/home" XDG_STATE_HOME="$tmp_dir/state" \
    "$ROOT_DIR/shell/scripts/ryoku" scheme get -nfv
)
[[ $current_scheme == $'ryoku\ndefault\ntonalspot' ]] || \
  fail "compatibility bridge should expose current scheme fields"

current_saved_scheme=$(
  HOME="$tmp_dir/home" XDG_STATE_HOME="$tmp_dir/state" \
    "$ROOT_DIR/shell/scripts/ryoku" scheme get -nfvm
)
[[ $current_saved_scheme == $'ryoku\ndefault\ntonalspot\ndark' ]] || \
  fail "compatibility bridge should expose saved scheme fields with mode"

HOME="$tmp_dir/home" XDG_STATE_HOME="$tmp_dir/state" \
  "$ROOT_DIR/shell/scripts/ryoku" scheme preview -f ocean -v rainbow -m light | \
  jq -e '.flavour == "ocean" and .variant == "rainbow" and .mode == "light"' >/dev/null || \
  fail "compatibility bridge should preview shell scheme changes without saving them"
preview_saved_scheme=$(
  HOME="$tmp_dir/home" XDG_STATE_HOME="$tmp_dir/state" \
    "$ROOT_DIR/shell/scripts/ryoku" scheme get -nfvm
)
[[ $preview_saved_scheme == $'ryoku\ndefault\ntonalspot\ndark' ]] || \
  fail "compatibility bridge scheme preview should not persist saved scheme fields"

tonal_payload=$(
  HOME="$tmp_dir/home" XDG_STATE_HOME="$tmp_dir/state" \
    "$ROOT_DIR/shell/scripts/ryoku" scheme preview -f ocean -v tonalspot -m dark | \
    jq -r '.colours.secondary + " " + .colours.tertiary'
)
fidelity_payload=$(
  HOME="$tmp_dir/home" XDG_STATE_HOME="$tmp_dir/state" \
    "$ROOT_DIR/shell/scripts/ryoku" scheme preview -f ocean -v fidelity -m dark | \
    jq -r '.colours.secondary + " " + .colours.tertiary'
)
content_payload=$(
  HOME="$tmp_dir/home" XDG_STATE_HOME="$tmp_dir/state" \
    "$ROOT_DIR/shell/scripts/ryoku" scheme preview -f ocean -v content -m dark | \
    jq -r '.colours.secondary + " " + .colours.tertiary'
)
[[ $fidelity_payload != "$tonal_payload" ]] || \
  fail "fidelity variant should produce a distinct live palette"
[[ $content_payload != "$tonal_payload" ]] || \
  fail "content variant should produce a distinct live palette"
[[ $content_payload != "$fidelity_payload" ]] || \
  fail "content and fidelity variants should not collapse to the same palette"

HOME="$tmp_dir/home" XDG_STATE_HOME="$tmp_dir/state" \
  "$ROOT_DIR/shell/scripts/ryoku" scheme set -v expressive
HOME="$tmp_dir/home" XDG_STATE_HOME="$tmp_dir/state" \
  "$ROOT_DIR/shell/scripts/ryoku" scheme get | jq -e '.variant == "expressive"' >/dev/null || \
  fail "compatibility bridge should persist shell variant changes"

HOME="$tmp_dir/home" XDG_STATE_HOME="$tmp_dir/state" \
  "$ROOT_DIR/shell/scripts/ryoku" wallpaper -p "$tmp_dir/wall.png" | jq -e '.variant == "expressive" and .colours.primary == "F56E0F" and .colours.surface == "171717"' >/dev/null || \
  fail "compatibility bridge should expose preview wallpaper colours from the current mode and variant"

mkdir -p "$tmp_dir/installed/bin"
cat >"$tmp_dir/installed/bin/ryoku-doctor" <<'SH'
#!/bin/bash
printf '%s' "$*" >"$RYOKU_DOCTOR_ARGS"
echo "global doctor selected"
SH
chmod 755 "$tmp_dir/installed/bin/ryoku-doctor"

doctor_args="$tmp_dir/doctor-args"
doctor_output=$(
  HOME="$tmp_dir/home" \
  XDG_STATE_HOME="$tmp_dir/state" \
  RYOKU_PATH="$tmp_dir/installed" \
  RYOKU_DOCTOR_ARGS="$doctor_args" \
    "$ROOT_DIR/shell/scripts/ryoku" doctor 2>&1
) || fail "compatibility bridge should run global ryoku doctor: $doctor_output"
[[ $doctor_output == "global doctor selected" ]] || \
  fail "compatibility bridge should run the installed global doctor"
[[ ! -s $doctor_args ]] || \
  fail "ryoku doctor should run the smart global doctor without forcing shell mode"

HOME="$tmp_dir/install-home" \
XDG_BIN_HOME="$tmp_dir/bin" \
XDG_CONFIG_HOME="$tmp_dir/config" \
XDG_DATA_HOME="$tmp_dir/data" \
XDG_STATE_HOME="$tmp_dir/state-install" \
RYOKU_SHELL_RUNTIME_DIR="$tmp_dir/runtime" \
RYOKU_SHELL_LIB_DIR="$tmp_dir/lib" \
RYOKU_SHELL_QML_DIR="$tmp_dir/qml" \
  "$ROOT_DIR/shell/setup" install --skip-build >/dev/null

[[ -s $tmp_dir/install-home/.face ]] || \
  fail "setup should install a default face image for first-run shell startup"
[[ -f $tmp_dir/state-install/ryoku-shell/scheme.json ]] || \
  fail "setup should initialize shell scheme state"
[[ -f $tmp_dir/state-install/ryoku-shell/wallpaper/path.txt ]] || \
  fail "setup should initialize shell wallpaper state"
[[ $(<"$tmp_dir/runtime/.ryoku-source-path") == "$ROOT_DIR" ]] || \
  fail "setup should stamp the source repo path into the runtime"

HOME="$tmp_dir/runtime-home" \
XDG_BIN_HOME="$tmp_dir/runtime-bin" \
XDG_CONFIG_HOME="$tmp_dir/runtime-config" \
XDG_DATA_HOME="$tmp_dir/runtime-data" \
XDG_STATE_HOME="$tmp_dir/runtime-state" \
RYOKU_SHELL_RUNTIME_DIR="$tmp_dir/runtime-from-runtime" \
RYOKU_SHELL_LIB_DIR="$tmp_dir/runtime-lib" \
RYOKU_SHELL_QML_DIR="$tmp_dir/runtime-qml" \
  "$tmp_dir/runtime/setup" install --skip-build >/dev/null

[[ $(<"$tmp_dir/runtime-from-runtime/.ryoku-source-path") == "$ROOT_DIR" ]] || \
  fail "runtime setup should preserve the original source repo path"

upstream_pattern='cae''lestia|Cae''lestia|CAELE''STIA|cae''lestia-dots|sora''mane'
# Exclude LICENSE (legal text) and the About settings pane's credits
# section (intentional attribution to the upstream shell heritage, same
# rationale as the repo-root CREDITS.md exemption in rebirth-docs-ready).
if rg -n "$upstream_pattern" "$ROOT_DIR/shell" \
    --glob '!LICENSE' \
    --glob '!AboutPane.qml' \
    --glob '!RyokuAbout.qml' >/tmp/ryoku-shell-seed-names.$$; then
  cat /tmp/ryoku-shell-seed-names.$$
  rm -f /tmp/ryoku-shell-seed-names.$$
  fail "shell runtime should not expose upstream product naming outside license/credits"
fi
rm -f /tmp/ryoku-shell-seed-names.$$

echo "PASS: rebirth Ryoku shell seed is imported and product-named"
