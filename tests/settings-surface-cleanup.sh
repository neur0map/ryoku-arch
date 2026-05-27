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
panels="shell/modules/drawers/Panels.qml"
content_window="shell/modules/drawers/ContentWindow.qml"
interactions="shell/modules/drawers/Interactions.qml"
bar_popouts="shell/modules/bar/popouts/Wrapper.qml"
settings_content="shell/noctalia/Modules/Panels/Settings/SettingsContent.qml"
settings_panel="shell/noctalia/Modules/Panels/Settings/SettingsPanel.qml"
settings_window="shell/noctalia/Modules/Panels/Settings/SettingsPanelWindow.qml"

for file in \
  "$launcher" \
  "$shell_entry" \
  "$shortcuts" \
  "$visibilities" \
  "$wrapper" \
  "$panels" \
  "$content_window" \
  "$interactions" \
  "$bar_popouts" \
  "$settings_content" \
  "$settings_panel" \
  "$settings_window" \
  shell/noctalia/ATTRIBUTION.md \
  shell/noctalia/LICENSE \
  shell/noctalia/Assets/settings-default.json \
  shell/noctalia/Assets/settings-search-index.json \
  shell/noctalia/Assets/ryoku-logo.svg \
  shell/noctalia/Modules/Panels/Settings/Tabs/About/CreditsSubTab.qml \
  shell/noctalia/Modules/Panels/Settings/Tabs/About/VersionSubTab.qml; do
  assert_file "$file"
done

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

assert_contains "$wrapper" 'import qs\.noctalia\.Modules\.Panels\.Settings' \
  "settings wrapper should import the Noctalia settings module"
assert_contains "$wrapper" 'SettingsContent \{' \
  "settings wrapper should render the vendored Noctalia settings content"
assert_contains "$wrapper" 'onCloseRequested: root\.visibilities\.settings = false' \
  "settings wrapper should close through drawer visibility state"
assert_contains "$wrapper" 'typeof initialize === "function"' \
  "settings wrapper should initialize the Noctalia content"
assert_contains "$wrapper" 'readonly property bool needsKeyboard: shouldBeActive \|\| offsetScale < 1' \
  "settings wrapper should request keyboard focus only while open or animating"
assert_contains "$wrapper" 'offsetScale' \
  "settings wrapper should preserve the shell drawer opening animation"
assert_contains "$wrapper" 'legacy/controlcenter/Wrapper\.qml\.orig' \
  "settings wrapper should document the archived inline settings UI"
assert_not_contains "$wrapper" 'component AboutPage|component AppearancePage|component ProfilesPage|component AppSettingsPage' \
  "settings wrapper should not keep the removed inline settings pages"
assert_not_contains "$wrapper" 'ControlCenter \{' \
  "settings wrapper should not render the old control-center backend"
assert_not_contains "$wrapper" 'ryoku-launch-wayle-settings|hyprctl clients -j|showLaunchSurface' \
  "settings wrapper should not contain external Wayle launch plumbing"

assert_contains "$settings_content" 'GeneralTab \{\}' \
  "Noctalia settings content should include General settings"
assert_contains "$settings_content" 'BarTab \{\}' \
  "Noctalia settings content should include Bar settings"
assert_contains "$settings_content" 'HyprlandTab \{\}' \
  "Noctalia settings content should include Hyprland settings"
assert_contains "$settings_content" 'WallpaperTab \{\}' \
  "Noctalia settings content should include Wallpaper settings"
assert_contains "$settings_content" 'AboutTab \{\}' \
  "Noctalia settings content should include About settings"
assert_contains "$settings_content" 'disabled": true // TODO: ryoku' \
  "settings content should mark unmapped Noctalia domains as disabled previews"
assert_contains "$settings_content" 'preview only, not available in ryoku yet' \
  "settings content should explain disabled preview-only tabs"
assert_contains "$settings_content" 'SettingsSearchService\.searchIndex' \
  "settings content should use the Noctalia settings search service"
assert_contains "$settings_content" 'signal closeRequested' \
  "settings content should expose a close signal for the wrapper"

assert_contains "shell/noctalia/Modules/Panels/Settings/Tabs/About/VersionSubTab.qml" 'text: "Ryoku"' \
  "Noctalia About version tab should carry Ryoku branding"
assert_contains "shell/noctalia/Modules/Panels/Settings/Tabs/About/VersionSubTab.qml" 'Assets/ryoku-logo\.svg' \
  "Noctalia About version tab should use the Ryoku logo"
assert_contains "shell/noctalia/Modules/Panels/Settings/Tabs/About/CreditsSubTab.qml" 'Settings UI adapted from Noctalia' \
  "Noctalia credits tab should preserve upstream attribution"
assert_contains "shell/noctalia/Modules/Panels/Settings/Tabs/About/CreditsSubTab.qml" 'noctalia-dev/noctalia-shell' \
  "Noctalia credits tab should link to the upstream project"

assert_contains "$panels" 'ControlCenter\.Wrapper' \
  "drawers should keep the settings wrapper"
assert_contains "$content_window" 'panel: panels\.settings' \
  "drawer background should keep the settings panel"
assert_contains "$content_window" '\|\| visibilities\.settings \|\|' \
  "settings should participate in the focus-grab outside-click dismissal path"
assert_not_contains "$content_window" 'showLaunchSurface' \
  "drawer background should not depend on an external launch placeholder"
assert_contains "$interactions" 'visibilities\.settings && !inPanelBounds\(panels\.settings' \
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
