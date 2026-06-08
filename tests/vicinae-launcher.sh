#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_file() {
  [[ -f $ROOT_DIR/$1 ]] || fail "$1 should exist"
}

assert_contains() {
  grep -Eq -- "$2" "$ROOT_DIR/$1" || fail "$3"
}

assert_not_contains() {
  if grep -Eq -- "$2" "$ROOT_DIR/$1"; then
    fail "$3"
  fi
}

# Package: shipped as a default AUR install so it also lands in the offline ISO
# mirror (build-iso.sh feeds install/ryoku-aur.packages through makepkg).
grep -qxF vicinae-bin "$ROOT_DIR/install/ryoku-aur.packages" || \
  fail "install/ryoku-aur.packages should include vicinae-bin"

# vicinae-server hard-needs libqt6keychain.so.1, which vicinae-bin does not pull
# itself, so the keychain backend must ship in the base manifest.
grep -qxF qtkeychain-qt6 "$ROOT_DIR/install/ryoku-base.packages" || \
  fail "install/ryoku-base.packages should include qtkeychain-qt6 (vicinae runtime dep)"

# systemd user unit, started from the Hyprland session like ryoku-shell.service
# (no [Install]; graphical-session.target is not reliably active in Ryoku).
assert_file "config/systemd/user/vicinae.service"
assert_contains "config/systemd/user/vicinae.service" 'Description=' \
  "vicinae unit should have a Description"
assert_contains "config/systemd/user/vicinae.service" 'ExecStart=.*vicinae server' \
  "vicinae unit should start the vicinae server"
assert_contains "config/systemd/user/vicinae.service" 'Restart=on-failure' \
  "vicinae unit should restart on failure"
assert_not_contains "config/systemd/user/vicinae.service" '^\[Install\]' \
  "vicinae unit should have no [Install] section; Hyprland starts it via exec-once"
assert_not_contains "config/systemd/user/vicinae.service" '^WantedBy=' \
  "vicinae unit should not be enabled against a systemd target"

# Hyprland wiring: launcher keybind, server autostart, layer-shell integration.
assert_contains "config/hypr/hyprland.lua" "var_menu = .*ryoku-launch-app'" \
  "Hyprland \$menu should dispatch through ryoku-launch-app"
assert_contains "config/hypr/hyprland.lua" 'hl\.bind\("SUPER \+ Space", hl\.dsp\.exec_cmd\(var_menu\)\)' \
  "SUPER+Space should open the launcher"
assert_contains "config/hypr/hyprland.lua" 'hl\.exec_cmd\(.*ryoku-launch-app apply' \
  "Hyprland should reconcile the launcher backend at login via ryoku-launch-app apply"
assert_contains "config/hypr/hyprland.lua" 'namespace = "\^\(vicinae\)\$"' \
  "Hyprland should target the Vicinae layer surface (0.55+ match:namespace syntax)"
assert_contains "config/hypr/hyprland.lua" 'blur = true' \
  "Hyprland should blur the Vicinae layer surface"
assert_contains "config/hypr/hyprland.lua" 'focus_on_activate = true' \
  "Hyprland should let the launcher take activation focus"

# Default config, seeded into ~/.config by install/config/config.sh.
assert_file "config/vicinae/settings.json"
assert_contains "config/vicinae/settings.json" '"name": "ryoku"' \
  "settings.json should select the Ryoku theme"
assert_contains "config/vicinae/settings.json" '"keyboard_interactivity": "on_demand"' \
  "settings.json should avoid exclusive keyboard interactivity under Hyprland"

# matugen renders the launcher theme so it tracks the active wallpaper palette.
assert_contains "shell/dashboard/assets/matugen/config.toml" '\[templates.vicinae\]' \
  "matugen config should template the Vicinae theme"
assert_contains "shell/dashboard/assets/matugen/config.toml" 'vicinae/themes/ryoku.toml' \
  "matugen should output the Ryoku theme into the official Vicinae theme dir"
assert_file "shell/dashboard/assets/matugen/vicinae.toml"
assert_contains "shell/dashboard/assets/matugen/vicinae.toml" '\[colors.core\]' \
  "Vicinae theme template should define core colors"
assert_not_contains "shell/dashboard/assets/matugen/vicinae.toml" '\{\{mode\}\}' \
  "Vicinae theme template must not use {{mode}}; matugen does not expand it"

# Migration converges existing installs onto the new launcher.
assert_file "migrations/1780374622.sh"
assert_contains "migrations/1780374622.sh" 'ryoku-launch-app' \
  "Migration should repoint \$menu to the ryoku-launch-app dispatcher"
assert_contains "migrations/1780374622.sh" 'vicinae-bin' \
  "Migration should install the launcher package"
assert_contains "migrations/1780374622.sh" 'vicinae\.service' \
  "Migration should deploy the launcher unit"

# Runtime launcher dispatcher: $menu and the autostart both route through this so
# the Settings toggle switches backends without rewriting the Hyprland config.
assert_file "bin/ryoku-launch-app"
[[ -x $ROOT_DIR/bin/ryoku-launch-app ]] || fail "bin/ryoku-launch-app should be executable"
assert_contains "bin/ryoku-launch-app" 'launcher.useVicinae' \
  "ryoku-launch-app should read the launcher.useVicinae setting from shell.json"
assert_contains "bin/ryoku-launch-app" 'vicinae toggle' \
  "ryoku-launch-app should open Vicinae when selected"
assert_contains "bin/ryoku-launch-app" 'ryoku-shell launcher' \
  "ryoku-launch-app should fall back to the built-in quickshell launcher"
assert_contains "bin/ryoku-launch-app" 'systemctl --user (start|stop) vicinae.service' \
  "ryoku-launch-app apply should start/stop the Vicinae server"

# Settings toggle: typed config key (default on) in Ryoku.Config + the settings-gui
# Launcher > General settings page bound to it (the active settings UI).
assert_contains "shell/plugin/src/Ryoku/Config/launcherconfig.hpp" 'CONFIG_PROPERTY\(bool, useVicinae, true\)' \
  "launcherconfig.hpp should declare launcher.useVicinae defaulting to true"
launcher_subtab="shell/settingsgui/Modules/Panels/Settings/Tabs/Launcher/GeneralSubTab.qml"
assert_contains "$launcher_subtab" 'label: qsTr\("Use Vicinae launcher"\)' \
  "settings-gui Launcher settings should add a 'Use Vicinae launcher' toggle"
assert_contains "$launcher_subtab" 'GlobalConfig.launcher.useVicinae = checked' \
  "the toggle should write GlobalConfig.launcher.useVicinae"
assert_contains "$launcher_subtab" 'ryoku-launch-app.*apply' \
  "the toggle should run ryoku-launch-app apply to reconcile the server"

echo "PASS: vicinae launcher defaults"
