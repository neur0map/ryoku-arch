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

  [[ ! -e $ROOT_DIR/$path ]] || fail "removed settings surface still exists: $path"
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

wrapper="shell/modules/controlcenter/Wrapper.qml"
settings_content="shell/noctalia/Modules/Panels/Settings/SettingsContent.qml"
settings_panel="shell/noctalia/Modules/Panels/Settings/SettingsPanel.qml"
settings_window="shell/noctalia/Modules/Panels/Settings/SettingsPanelWindow.qml"
about_tab="shell/noctalia/Modules/Panels/Settings/Tabs/About/AboutTab.qml"
version_tab="shell/noctalia/Modules/Panels/Settings/Tabs/About/VersionSubTab.qml"
credits_tab="shell/noctalia/Modules/Panels/Settings/Tabs/About/CreditsSubTab.qml"
basics_tab="shell/noctalia/Modules/Panels/Settings/Tabs/General/BasicsSubTab.qml"
keybinds_tab="shell/noctalia/Modules/Panels/Settings/Tabs/General/KeybindsSubTab.qml"

for file in \
  "$wrapper" \
  "$settings_content" \
  "$settings_panel" \
  "$settings_window" \
  "$about_tab" \
  "$version_tab" \
  "$credits_tab" \
  "$basics_tab" \
  "$keybinds_tab" \
  legacy/controlcenter/Wrapper.qml.orig \
  shell/components/controls/Menu.qml \
  shell/components/controls/MenuItem.qml \
  shell/modules/drawers/ContentWindow.qml \
  shell/modules/drawers/Interactions.qml \
  shell/modules/Shortcuts.qml \
  shell/scripts/ryoku-shell \
  bin/ryoku-keybinds; do
  assert_file "$file"
done

for path in \
  shell/ryokuSettings.qml \
  shell/settings.qml \
  shell/waffleSettings.qml \
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
  tests/wayle-settings-integration.sh \
  third_party/wayle; do
  assert_absent "$path"
done

assert_contains "$wrapper" "import qs.noctalia.Modules.Panels.Settings" \
  "settings wrapper should import the vendored Noctalia settings panel"
assert_contains "$wrapper" "legacy/controlcenter/Wrapper.qml.orig" \
  "settings wrapper should document the archived inline settings surface"
assert_contains "$wrapper" "SettingsContent {" \
  "settings wrapper should host the Noctalia SettingsContent island"
assert_contains "$wrapper" "onCloseRequested: root.visibilities.settings = false" \
  "Noctalia settings close requests should close the resident drawer"
assert_contains "$wrapper" "if (typeof initialize === \"function\")" \
  "settings wrapper should initialize Noctalia content after loading"
assert_contains "$wrapper" "readonly property bool needsKeyboard: shouldBeActive || offsetScale < 1" \
  "settings wrapper should preserve the drawer keyboard contract"
assert_contains "$wrapper" "anchors.topMargin: (-implicitHeight - 5) * offsetScale" \
  "settings wrapper should preserve the top-frame popup animation"
assert_contains "$wrapper" "implicitWidth: 900" \
  "settings wrapper should use a stable Noctalia panel width"
assert_contains "$wrapper" "implicitHeight: Math.min(950, availableHeight)" \
  "settings wrapper should cap Noctalia panel height to the screen"

assert_not_contains "$wrapper" "component AboutPage" \
  "settings wrapper should not keep the removed inline About page"
assert_not_contains "$wrapper" "component AppearancePage" \
  "settings wrapper should not keep the removed inline Appearance page"
assert_not_contains "$wrapper" "component ProfilesPage" \
  "settings wrapper should not keep the removed inline Profiles page"
assert_not_contains "$wrapper" "component AppSettingsPage" \
  "settings wrapper should not keep the removed inline Settings page"

assert_contains "$settings_content" "import qs.noctalia.Modules.Panels.Settings.Tabs.About" \
  "Noctalia settings content should expose the About tab"
assert_contains "$settings_content" "GeneralTab {}" \
  "Noctalia settings content should expose the General tab"
assert_contains "$settings_content" "HyprlandTab {}" \
  "Noctalia settings content should expose the Hyprland tab"
assert_contains "$settings_content" "WallpaperTab {}" \
  "Noctalia settings content should expose the Wallpaper tab"
assert_contains "$settings_content" "AboutTab {}" \
  "Noctalia settings content should expose the Ryoku About tab"
assert_contains "$settings_content" "disabled\": true // TODO: ryoku has no dock component yet" \
  "unmapped Noctalia settings tabs should be marked as disabled previews"
assert_contains "$settings_content" "disabled tabs render as a greyed, non-interactive preview" \
  "disabled Noctalia tabs should be visually marked as previews"
assert_contains "$settings_content" "TooltipService.show(tabItem" \
  "disabled Noctalia tabs should explain preview-only state"

assert_contains "$about_tab" "VersionSubTab {}" \
  "About should include Ryoku version details"
assert_contains "$about_tab" "CreditsSubTab {}" \
  "About should include Noctalia attribution"
assert_contains "$version_tab" "source: \"../../../../../Assets/ryoku-logo.svg\"" \
  "About should use the Ryoku logo"
assert_contains "$version_tab" "text: \"Ryoku\"" \
  "About should present the Ryoku product name"
assert_contains "$version_tab" "RYOKU: removed Noctalia telemetry" \
  "About should remove Noctalia telemetry controls"
assert_contains "$credits_tab" "Settings UI adapted from Noctalia" \
  "credits should attribute the vendored settings UI"
assert_contains "$credits_tab" "https://github.com/noctalia-dev/noctalia-shell" \
  "credits should link back to upstream Noctalia"

assert_contains "$basics_tab" "GlobalConfig.appearance.font.family.sans" \
  "General basics should wire font settings through GlobalConfig"
assert_contains "$basics_tab" "GlobalConfig.save();" \
  "General basics should persist through the typed Ryoku config layer"
assert_contains "$keybinds_tab" "ryoku-keybinds" \
  "General keybinds should mutate keybinds through the Ryoku command boundary"
assert_contains "$keybinds_tab" "Reload Hyprland" \
  "General keybinds should expose a Hyprland reload action"

assert_contains "shell/scripts/ryoku-shell" "ipc_call controlCenter toggle" \
  "ryoku-shell settings should open through the resident top-frame route"
assert_contains "shell/modules/drawers/ContentWindow.qml" "panel: panels.settings" \
  "drawer background should keep the settings panel"
assert_contains "shell/modules/drawers/Interactions.qml" "visibilities.settings && !inPanelBounds(panels.settings" \
  "clicking outside settings should dismiss the drawer"

echo "PASS: tests/settings-controlcenter-redesign.sh"
