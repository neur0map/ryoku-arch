#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_file() {
  local path="$1"
  [[ -f "$path" ]] || fail "missing required file: $path"
}

assert_absent() {
  local path="$1"
  [[ ! -e "$path" ]] || fail "removed settings surface still exists: $path"
}

assert_not_contains() {
  local path="$1"
  local pattern="$2"
  local message="$3"
  if grep -Eq "$pattern" "$path"; then
    fail "$message"
  fi
}

launcher="shell/scripts/ryoku-shell"
overlay="shell/modules/settings/SettingsOverlay.qml"
shell_entry="shell/shell.qml"
config_schema="shell/modules/common/Config.qml"
defaults="shell/defaults/config.json"
quick_settings="shell/modules/settings/QuickConfig.qml"

assert_file "$launcher"
assert_file "$overlay"
assert_file "$shell_entry"
assert_file "$config_schema"
assert_file "$defaults"
assert_file "$quick_settings"

for path in shell/ryokuSettings.qml shell/settings.qml shell/waffleSettings.qml; do
  assert_absent "$path"
done
assert_absent "shell/modules/waffle/settings"

grep -q 'target: "settings"' "$shell_entry" \
  || fail "primary settings IPC target should remain resident in shell.qml"
grep -q 'component: SettingsOverlay' "$shell_entry" \
  || fail "shell.qml should keep the resident SettingsOverlay loader"
grep -q 'GlobalStates.settingsOverlayOpen = true' "$shell_entry" \
  || fail "settings IPC open should show the resident overlay"

assert_not_contains "$launcher" 'settings-window|ryoku-settings-window|legacy-settings-window|waffle-settings-window' \
  "ryoku-shell should not expose detached settings-window commands"
assert_not_contains "$launcher" 'open_detached_qml_window[^\n]*(ryokuSettings|settings|waffleSettings)\.qml' \
  "ryoku-shell should not launch removed settings QML entrypoints"
assert_not_contains "$launcher" 'RYOKU_SETTINGS_MODE|settings_launch_mode|open_settings_surface' \
  "detached settings launch-mode code should be removed"

assert_not_contains "$overlay" 'settings-window|Config file|shellConfigPath|overlayMode' \
  "retained SettingsOverlay should not link to removed window/config-file surfaces"
assert_not_contains "$quick_settings" 'Open config|shellConfigPath|Config: %1' \
  "retained Quick settings page should not expose shell config-file controls"
assert_not_contains "$config_schema" 'overlayMode|launchMode' \
  "settings config schema should not keep removed window/overlay mode selectors"
assert_not_contains "$defaults" '"overlayMode"|"launchMode"' \
  "default config should not keep removed window/overlay mode keys"

echo "PASS: settings surface cleanup"
