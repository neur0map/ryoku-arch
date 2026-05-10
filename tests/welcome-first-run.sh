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

assert_contains shell/services/FirstRunExperience.qml 'Quickshell\.execDetached\(\["/usr/bin/qs", "-p", root\.welcomeQmlPath\]\)' \
  "first-run launcher should open welcome.qml"
assert_not_contains shell/services/FirstRunExperience.qml 'root\.disableNextTime\(\)' \
  "first-run launcher should not mark onboarding complete before welcome.qml renders"

assert_contains shell/welcome.qml 'firstRunFilePath' \
  "welcome.qml should know the first-run marker path"
assert_contains shell/welcome.qml 'firstRunFileContent' \
  "welcome.qml should know the first-run marker content"
assert_contains shell/welcome.qml 'mkdir -p "\$\{parentDir\}"' \
  "welcome.qml should create the marker parent directory when onboarding is finished"
assert_contains shell/welcome.qml 'echo "\$\{root\.firstRunFileContent\}" > "\$\{root\.firstRunFilePath\}"' \
  "welcome.qml should write the first-run marker only when onboarding is finished"

echo "PASS: welcome first-run marker contract"
