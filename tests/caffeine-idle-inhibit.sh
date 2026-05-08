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

idle_service="shell/services/Idle.qml"

[[ -f $idle_service ]] || fail "$idle_service missing"

assert_contains "$idle_service" 'hypridle\.service' \
  "caffeine should manage the active hypridle daemon"
assert_contains "$idle_service" 'systemd-inhibit' \
  "caffeine on should hold a systemd idle inhibitor"
assert_contains "$idle_service" '"--what=idle"' \
  "caffeine should inhibit system idle without blocking explicit sleep"
assert_contains "$idle_service" 'pkill", "-f", "\^/usr/bin/systemd-inhibit --what=idle --who=Ryoku' \
  "caffeine should clean stale Ryoku idle inhibitor processes across shell restarts"
assert_contains "$idle_service" 'running: root\.inhibit && root\._idleInhibitorAllowed' \
  "the inhibitor process should only start after stale inhibitors are cleaned"
assert_contains "$idle_service" 'systemctl", "--user", "start", "hypridle\.service"' \
  "the idle service should keep hypridle available for lock hooks"
assert_not_contains "$idle_service" 'systemctl", "--user", "stop", "hypridle\.service"' \
  "caffeine should not stop hypridle because that removes lock-session hooks"
assert_not_contains "$idle_service" 'Component\.onDestruction:[[:space:]]*_stopIdleDaemon\(\)' \
  "shell shutdown should not leave the external hypridle service stopped"

echo "OK: caffeine idle inhibit contract"
