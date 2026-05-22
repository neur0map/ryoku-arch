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

assert_contains() {
  local path="$1"
  local pattern="$2"
  local message="$3"

  grep -Eq "$pattern" "$ROOT_DIR/$path" || fail "$message"
}

assert_not_contains() {
  local path="$1"
  local pattern="$2"
  local message="$3"

  if grep -Eq "$pattern" "$ROOT_DIR/$path"; then
    fail "$message"
  fi
}

assert_file install/ryoku-base.packages
assert_file install/login/sddm.sh
assert_file bin/ryoku-sddm-autologin
assert_file install/config/shell.sh
assert_file shell/scripts/ryoku-shell
assert_file shell/setup

assert_contains install/ryoku-base.packages '^hyprland$' \
  "base packages should install Hyprland"
assert_contains install/ryoku-base.packages '^xdg-desktop-portal-hyprland$' \
  "base packages should install the Hyprland portal"
assert_not_contains install/ryoku-base.packages '^niri$' \
  "base packages should not install Niri on rebirth"
assert_not_contains install/ryoku-base.packages '^xdg-desktop-portal-gnome$' \
  "base packages should not install the GNOME portal on rebirth"

assert_contains install/login/sddm.sh 'hyprland\.desktop|Hyprland\.desktop|hyprland-uwsm\.desktop' \
  "SDDM setup should verify a Hyprland session file"
assert_not_contains install/login/sddm.sh 'niri\.desktop|niri session' \
  "SDDM setup should not require Niri"

assert_contains bin/ryoku-sddm-autologin 'hyprland\.desktop|Hyprland\.desktop|hyprland-uwsm\.desktop' \
  "SDDM autologin should choose a Hyprland session"
assert_not_contains bin/ryoku-sddm-autologin 'Session=niri\.desktop|straight in Niri' \
  "SDDM autologin should not default to Niri"

assert_not_contains install/config/shell.sh 'service enable niri|niri\.service\.wants' \
  "shell install should not wire ryoku-shell to Niri"
assert_contains shell/scripts/ryoku-shell 'RYOKU_COMPOSITOR.*hyprland|HYPRLAND_INSTANCE_SIGNATURE' \
  "shell service detection should support an explicit Hyprland path"
assert_contains shell/setup 'RYOKU_COMPOSITOR.*hyprland|HYPRLAND_INSTANCE_SIGNATURE' \
  "setup service wiring should support an explicit Hyprland path"

echo "PASS: rebirth install defaults are Hyprland-first"
