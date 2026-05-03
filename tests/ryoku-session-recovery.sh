#!/bin/bash

set -euo pipefail
cd "$(dirname "$0")/.."

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

pass() {
  echo "OK: $1"
}

assert_file() {
  local path="$1"

  [[ -f $path ]] || fail "$path should exist"
}

assert_executable() {
  local path="$1"

  assert_file "$path"
  [[ -x $path ]] || fail "$path should be executable"
}

assert_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"

  grep -Eq -- "$pattern" "$file" || fail "$message"
}

assert_not_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"

  if grep -Eq -- "$pattern" "$file"; then
    fail "$message"
  fi
}

assert_executable bin/ryoku-session-recover
assert_executable bin/ryoku-shell-cleanup-orphans
assert_executable default/systemd/system-sleep/ryoku-session-recover

bash -n bin/ryoku-session-recover || fail "ryoku-session-recover has a syntax error"
bash -n bin/ryoku-shell-cleanup-orphans || fail "ryoku-shell-cleanup-orphans has a syntax error"
bash -n default/systemd/system-sleep/ryoku-session-recover \
  || fail "system sleep recovery hook has a syntax error"

assert_contains bin/ryoku-session-recover 'niri msg action power-on-monitors' \
  "session recovery should force Niri monitors back on after resume"
assert_contains bin/ryoku-session-recover 'niri\.\*\.sock' \
  "session recovery should discover the Niri socket when NIRI_SOCKET is absent"
assert_contains bin/ryoku-session-recover 'ryoku-shell-cleanup-orphans --quiet' \
  "session recovery should clean stale shell helpers"
assert_contains bin/ryoku-session-recover 'ryoku-restart-ui --quiet' \
  "session recovery should hard-refresh the Ryoku UI"
assert_contains bin/ryoku-session-recover 'systemctl --user import-environment' \
  "session recovery should refresh the user systemd environment"
assert_contains bin/ryoku-session-recover 'dbus-update-activation-environment --systemd --all' \
  "session recovery should refresh dbus activation environment"
assert_not_contains bin/ryoku-session-recover 'hyprctl|hypridle|waybar|mako|swayosd' \
  "session recovery should not target old Hyprland-era services"

assert_contains bin/ryoku-shell-cleanup-orphans 'inir cleanup-orphans' \
  "shell cleanup should keep upstream Quickshell runtime cleanup"
assert_contains bin/ryoku-shell-cleanup-orphans 'terminate_exact swayidle' \
  "shell cleanup should stop stale swayidle instances"
assert_contains bin/ryoku-shell-cleanup-orphans 'keyboard_lock_state_daemon' \
  "shell cleanup should stop stale keyboard indicator daemons"
assert_contains bin/ryoku-shell-cleanup-orphans 'nmcli monitor' \
  "shell cleanup should stop stale network monitor subscribers"
assert_contains bin/ryoku-shell-cleanup-orphans 'switchwall' \
  "shell cleanup should stop stale wallpaper color workers"
assert_contains bin/ryoku-shell-cleanup-orphans 'awww-daemon' \
  "shell cleanup should stop stale shell wallpaper daemons"
assert_contains bin/ryoku-shell-cleanup-orphans 'Wallpaper switcher' \
  "shell cleanup should stop stale wallpaper notification actions"
assert_not_contains bin/ryoku-shell-cleanup-orphans 'gnome-keyring-daemon|firefox|chromium|kitty|alacritty|ghostty|steam|discord|signal|obsidian' \
  "shell cleanup should not target user apps or keyring"

assert_contains default/systemd/system-sleep/ryoku-session-recover '/run/user/\*' \
  "system sleep hook should discover active user sessions"
assert_contains default/systemd/system-sleep/ryoku-session-recover 'systemctl --user show-environment' \
  "system sleep hook should read each user manager environment"
assert_contains default/systemd/system-sleep/ryoku-session-recover 'RYOKU_PATH=' \
  "system sleep hook should use RYOKU_PATH when available"
assert_contains default/systemd/system-sleep/ryoku-session-recover 'DBUS_SESSION_BUS_ADDRESS=' \
  "system sleep hook should connect to the user bus"
assert_contains default/systemd/system-sleep/ryoku-session-recover '--quiet --resume' \
  "system sleep hook should trigger quiet resume recovery"
assert_not_contains default/systemd/system-sleep/ryoku-session-recover 'prowl/' \
  "system sleep hook should not hardcode a development machine path"

assert_contains install/config/all.sh 'config/session-recover\.sh' \
  "fresh installs should install the Ryoku session recovery hook"
assert_contains install/config/session-recover.sh 'default/systemd/system-sleep/ryoku-session-recover' \
  "session recovery installer should install the system sleep hook"
if (( $(grep -c 'ryoku-shell-branding\.sh' install/config/inir.sh) < 2 )); then
  fail "iNiR setup should re-apply Ryoku branding after service enable rewrites the unit"
fi
assert_contains config/systemd/user/inir.service 'ryoku-shell-cleanup-orphans --quiet' \
  "Ryoku shell service should use Ryoku cleanup for stale shell helpers"
assert_contains install/config/ryoku-shell-branding.sh 'lock\.secure' \
  "Ryoku shell branding should harden iNiR lock against insecure session-lock activation"
assert_contains install/config/ryoku-shell-branding.sh 'Lock session did not become secure' \
  "Ryoku shell branding should force a secure fallback when iNiR lock is only visually locked"

pass "Ryoku session recovery contract"
