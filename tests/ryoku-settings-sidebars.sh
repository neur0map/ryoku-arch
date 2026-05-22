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

settings_path="shell/ryokuSettings.qml"

assert_contains "$settings_path" 'title: "Sidebars"'
assert_contains "$settings_path" '{ label: "Left sidebar", description: "AI, translator, wallpaper, tools, and widget tabs.", listPath: "enabledPanels", id: "iiSidebarLeft" }'
assert_contains "$settings_path" '{ label: "Right sidebar", description: "Quick controls, calendar, notes, system tools, and monitoring widgets.", listPath: "enabledPanels", id: "iiSidebarRight" }'

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
  assert_contains "$settings_path" "path: \"$setting\""
done

assert_contains "$settings_path" 'Config.setNestedValue("policies.ai", newValue)'
assert_contains "$settings_path" 'Config.setNestedValue("policies.weeb", newValue)'

right_toggle_count=$(grep -cF 'app.setRightSidebarWidgetEnabled("' "$ROOT_DIR/$settings_path")
(( right_toggle_count == 11 )) || fail "official Settings should expose 11 right sidebar widget toggles"

for widget in calendar events todo notepad calculator sysmon timer openvpn hosts netmon firewall; do
  assert_contains "$settings_path" "app.setRightSidebarWidgetEnabled(\"$widget\", !checked)"
done

assert_contains "$settings_path" 'Config.setNestedValue("sidebar.right.enabledWidgets", widgets)'
assert_contains "$settings_path" '{ label: "Sidebars", desc: "Left tabs, right widgets, panel loading", page: "Panels & Modules", subTab: 0 }'

echo "PASS: official settings sidebars are exposed"
