#!/bin/bash

set -euo pipefail

fail() {
  echo "cursor-theme-session: FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"

  if ! grep -Eq "$pattern" "$file"; then
    fail "$message"
  fi
}

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

test_home="$tmp_dir/home"
fake_bin="$tmp_dir/bin"
command_log="$tmp_dir/commands.log"

mkdir -p \
  "$test_home/.local/share/icons/Bibata-Modern-Classic/cursors" \
  "$fake_bin"

for cmd in gsettings systemctl dbus-update-activation-environment hyprctl; do
  cat >"$fake_bin/$cmd" <<'EOF'
#!/bin/bash
printf '%s\n' "$0 $*" >>"$RYOKU_TEST_COMMAND_LOG"
EOF
  chmod 0755 "$fake_bin/$cmd"
done

HOME="$test_home" \
XDG_DATA_HOME="$test_home/.local/share" \
RYOKU_PATH="$PWD" \
RYOKU_STATE_PATH="$test_home/.local/state/ryoku" \
RYOKU_TEST_COMMAND_LOG="$command_log" \
PATH="$PWD/bin:$fake_bin:/usr/bin:/bin" \
  bash bin/ryoku-cursor-set Bibata-Modern-Classic 24

state_file="$test_home/.local/state/ryoku/toggles/cursor.conf"
modern_default="$test_home/.local/share/icons/default/index.theme"
legacy_default="$test_home/.icons/default/index.theme"

assert_contains "$state_file" '^XCURSOR_THEME=Bibata-Modern-Classic$' \
  "cursor setter should persist the selected Xcursor theme"
assert_contains "$state_file" '^XCURSOR_SIZE=24$' \
  "cursor setter should persist the selected Xcursor size"
assert_contains "$modern_default" '^Inherits=Bibata-Modern-Classic$' \
  "cursor setter should write the XDG default cursor theme for Xwayland apps"
assert_contains "$legacy_default" '^Inherits=Bibata-Modern-Classic$' \
  "cursor setter should write the legacy Xcursor default theme fallback"
assert_contains "$command_log" 'gsettings set org\.gnome\.desktop\.interface cursor-theme Bibata-Modern-Classic' \
  "cursor setter should keep GNOME cursor preferences in sync"
assert_contains "$command_log" 'hyprctl setcursor Bibata-Modern-Classic 24' \
  "cursor setter should apply the Hyprland cursor live"
assert_contains "$command_log" 'systemctl --user import-environment XCURSOR_THEME XCURSOR_SIZE HYPRCURSOR_THEME HYPRCURSOR_SIZE' \
  "cursor setter should import cursor environment into user services"
assert_contains "$command_log" 'dbus-update-activation-environment --systemd XCURSOR_THEME XCURSOR_SIZE HYPRCURSOR_THEME HYPRCURSOR_SIZE' \
  "cursor setter should import cursor environment into DBus activation"

hypr_conf="$test_home/.config/hypr/hyprland.conf"
mkdir -p "$(dirname -- "$hypr_conf")"
cat >"$hypr_conf" <<'EOF'
source = ~/.config/hypr/colors.conf
env = XCURSOR_SIZE,24
env = HYPRCURSOR_SIZE,24
env = QT_QPA_PLATFORM,wayland
EOF

HOME="$test_home" \
XDG_CONFIG_HOME="$test_home/.config" \
XDG_DATA_HOME="$test_home/.local/share" \
RYOKU_PATH="$PWD" \
RYOKU_STATE_PATH="$test_home/.local/state/ryoku" \
RYOKU_TEST_COMMAND_LOG="$command_log" \
PATH="$PWD/bin:$fake_bin:/usr/bin:/bin" \
  bash migrations/1779493501.sh >/dev/null

assert_contains "$hypr_conf" '^env = XCURSOR_THEME,Bibata-Modern-Classic$' \
  "cursor migration should add the Ryoku Xcursor theme to existing Hyprland configs"
assert_contains "$hypr_conf" '^env = HYPRCURSOR_THEME,Bibata-Modern-Classic$' \
  "cursor migration should add the Ryoku Hyprcursor theme to existing Hyprland configs"
assert_contains migrations/1779493501.sh 'ryoku-cursor-set' \
  "cursor migration should reuse the shared cursor setter"

# Lua mode: when the box ships native Lua (hyprland.lua present), the setter must
# upsert the cursor env via hl.env(...) into hyprland.lua, not the hyprlang config.
hypr_lua="$test_home/.config/hypr/hyprland.lua"
cat >"$hypr_lua" <<'EOF'
hl.env("GDK_SCALE", "1")
require("custom")
EOF

HOME="$test_home" \
XDG_CONFIG_HOME="$test_home/.config" \
XDG_DATA_HOME="$test_home/.local/share" \
RYOKU_PATH="$PWD" \
RYOKU_STATE_PATH="$test_home/.local/state/ryoku" \
RYOKU_TEST_COMMAND_LOG="$command_log" \
PATH="$PWD/bin:$fake_bin:/usr/bin:/bin" \
  bash bin/ryoku-cursor-set Bibata-Modern-Classic 24

assert_contains "$hypr_lua" '^hl\.env\("XCURSOR_THEME", "Bibata-Modern-Classic"\)$' \
  "cursor setter should persist the Xcursor theme via hl.env in the Lua config"
assert_contains "$hypr_lua" '^hl\.env\("HYPRCURSOR_THEME", "Bibata-Modern-Classic"\)$' \
  "cursor setter should persist the Hyprcursor theme via hl.env in the Lua config"

echo "cursor-theme-session: ok"
