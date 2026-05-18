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

idle_service="shell/services/Idle.qml"
caffeine_cmd="bin/ryoku-cmd-caffeine"

[[ -f $idle_service ]] || fail "$idle_service missing"
[[ -f $caffeine_cmd ]] || fail "$caffeine_cmd missing"

assert_contains "$idle_service" 'hypridle\.service' \
  "caffeine should manage the active hypridle daemon"
assert_contains "$idle_service" 'ryoku-cmd-caffeine' \
  "the UI should route caffeine through the shared helper"
assert_not_contains "$idle_service" 'systemd-inhibit' \
  "the UI should not own the long-lived inhibitor process"
assert_not_contains "$idle_service" '_idleInhibitorAllowed|id: _idleInhibitor|running: root\.inhibit' \
  "caffeine should not be tied to the Quickshell process lifetime"
assert_contains "$idle_service" 'systemctl", "--user", "start", "hypridle\.service"' \
  "the idle service should keep hypridle available for lock hooks"
assert_not_contains "$idle_service" 'systemctl", "--user", "stop", "hypridle\.service"' \
  "caffeine should not stop hypridle because that removes lock-session hooks"
assert_not_contains "$idle_service" 'Component\.onDestruction:[[:space:]]*_stopIdleDaemon\(\)' \
  "shell shutdown should not leave the external hypridle service stopped"
assert_not_contains "$idle_service" 'Component\.onDestruction:[^}]*ryoku-cmd-caffeine[^}]*stop' \
  "shell shutdown should not turn off a persisted caffeine request"

assert_contains "$caffeine_cmd" '--what=idle' \
  "caffeine helper should inhibit system idle"
assert_not_contains "$caffeine_cmd" '--what=idle:sleep' \
  "caffeine helper should not block explicit sleep requests"
assert_contains "$caffeine_cmd" 'ryoku-caffeine-inhibit' \
  "caffeine helper status should track the same inhibitor it starts"
assert_contains "$caffeine_cmd" 'legacy_inhibit_pattern=' \
  "caffeine helper should clean the old QML-owned inhibitor during migration"
assert_contains "$caffeine_cmd" 'flock -x' \
  "caffeine helper should serialize start/stop so shell startup cannot spawn duplicate inhibitors"
assert_contains "$caffeine_cmd" '9>&-' \
  "caffeine helper should not leak the serialization lock into the background inhibitor"

echo "OK: caffeine idle inhibit contract"
