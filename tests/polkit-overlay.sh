#!/bin/bash

set -euo pipefail
cd "$(dirname "$0")/.."

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"

  grep -Eq "$pattern" "$file" || fail "$message"
}

assert_not_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"

  if grep -Eq "$pattern" "$file"; then
    fail "$message"
  fi
}

polkit_agents='polkit-gnome-authentication-agent-1|polkit-mate-authentication-agent-1|polkit-kde-authentication-agent-1|lxqt-policykit-agent|lxpolkit'

assert_contains "shell/modules/polkit/Polkit.qml" \
  "WlrLayershell\\.keyboardFocus: WlrKeyboardFocus\\.Exclusive" \
  "Ryoku polkit prompt must request exclusive keyboard focus"

assert_contains "shell/modules/settings/SettingsOverlay.qml" \
  "property bool polkitActive: PolkitService\\.active" \
  "Settings overlay must track active Ryoku polkit prompts"

assert_contains "shell/modules/settings/SettingsOverlay.qml" \
  "visible: root\\.settingsOpen && !root\\.polkitActive" \
  "Settings overlay must yield visibility while polkit is active"

assert_contains "shell/modules/settings/SettingsOverlay.qml" \
  "grab\\.active = root\\.settingsOpen && !root\\.polkitActive" \
  "Settings overlay focus grab must yield while polkit is active"

assert_not_contains "config/niri/config.d/50-startup.kdl" \
  "spawn-at-startup \"/usr/lib/($polkit_agents)" \
  "Ryoku Niri config must not spawn an external polkit agent"

assert_not_contains "shell/defaults/niri/config.d/50-startup.kdl" \
  "spawn-at-startup \"/usr/lib/($polkit_agents)" \
  "Shell Niri defaults must not spawn an external polkit agent"

echo "PASS: tests/polkit-overlay.sh"
