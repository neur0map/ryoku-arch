#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_file() {
  local path="$1"
  [[ -f $ROOT_DIR/$path ]] || fail "$path should exist"
}

assert_contains() {
  local path="$1"
  local needle="$2"

  assert_file "$path"
  grep -qF "$needle" "$ROOT_DIR/$path" || fail "$path should contain: $needle"
}

settings_path="shell/modules/waffle/settings/pages/WModulesPage.qml"
search_path="shell/modules/waffle/settings/WSettingsContent.qml"

assert_contains "$settings_path" 'title: Translation.tr("Sidebars")'

assert_contains "$settings_path" 'root.setPanelEnabled("iiSidebarLeft", checked)'
assert_contains "$settings_path" 'root.setPanelEnabled("iiSidebarRight", checked)'

for setting in \
  "sidebar.widgets.enable" \
  "sidebar.translator.enable" \
  "sidebar.wallhaven.enable" \
  "sidebar.animeSchedule.enable" \
  "sidebar.reddit.enable" \
  "sidebar.tools.enable" \
  "sidebar.software.enable" \
  "sidebar.ytmusic.enable"
do
  assert_contains "$settings_path" "Config.setNestedValue(\"$setting\", checked)"
done

assert_contains "$settings_path" 'Config.setNestedValue("policies.ai", newValue)'
assert_contains "$settings_path" 'Config.setNestedValue("policies.weeb", newValue)'

right_toggle_count=$(grep -cF 'root.setRightSidebarWidgetEnabled("' "$ROOT_DIR/$settings_path")
(( right_toggle_count == 11 )) || fail "new Settings should expose 11 right sidebar widget toggles"

for widget in calendar events todo notepad calculator sysmon timer openvpn hosts netmon firewall; do
  assert_contains "$settings_path" "root.setRightSidebarWidgetEnabled(\"$widget\", checked)"
done

assert_contains "$settings_path" 'Config.setNestedValue("sidebar.right.enabledWidgets", widgets)'
assert_contains "$search_path" 'pageName: "Modules", section: "Sidebars", label: "Left Sidebar"'
assert_contains "$search_path" 'pageName: "Modules", section: "Sidebars", label: "Right Sidebar"'

echo "PASS: waffle settings sidebars are exposed"
