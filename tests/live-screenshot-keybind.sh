#!/bin/bash

set -euo pipefail

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

require_command() {
  local command_name="$1"

  command -v "$command_name" >/dev/null 2>&1 || fail "$command_name is required"
}

has_area_picker() {
  hyprctl layers -j |
    jq -e '.. | objects | select((.namespace? // "") == "ryoku-area-picker")' >/dev/null
}

cleanup() {
  systemctl --user restart ryoku-shell.service >/dev/null 2>&1 || true
}

require_command hyprctl
require_command jq
require_command qs
require_command systemctl
require_command ydotool

trap cleanup EXIT

systemctl --user restart ryoku-shell.service >/dev/null
sleep 1

if has_area_picker; then
  fail "area picker should not be open before the keybind test"
fi

expected_bind="arg: sh -lc 'exec \"$HOME/.local/share/ryoku/bin/ryoku-cmd-screenshot\" choose'"

hyprctl binds | grep -Fq "$expected_bind" ||
  fail "Hyprland should bind Super+S to the installed screenshot helper"

qs -p "${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/ryoku-shell" ipc show |
  grep -Fq 'function openFreeze(): void' ||
  fail "Ryoku shell picker IPC should expose openFreeze"

ydotool key -d 80 125:1 31:1 31:0 125:0 >/dev/null 2>&1

for _ in {1..20}; do
  if has_area_picker; then
    echo "PASS: Super+S opens the Ryoku screenshot area picker"
    exit 0
  fi
  sleep 0.1
done

fail "Super+S did not open the Ryoku screenshot area picker"
