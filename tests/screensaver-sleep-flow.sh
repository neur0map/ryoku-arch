#!/bin/bash

set -euo pipefail
cd "$(dirname "$0")/.."

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

pass() {
  echo "OK: screensaver sleep flow"
}

assert_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"

  grep -Eq "$pattern" "$file" || fail "$message"
}

assert_order() {
  local file="$1"
  local first_pattern="$2"
  local second_pattern="$3"
  local message="$4"
  local first_line
  local second_line

  first_line="$(grep -nE "$first_pattern" "$file" | head -n1 | cut -d: -f1)"
  second_line="$(grep -nE "$second_pattern" "$file" | head -n1 | cut -d: -f1)"

  [[ -n $first_line ]] || fail "$message: missing first pattern"
  [[ -n $second_line ]] || fail "$message: missing second pattern"
  (( first_line < second_line )) || fail "$message"
}

assert_contains bin/ryoku-launch-screensaver 'ryoku-cmd-screensaver' \
  "screensaver launcher should run the TTE screensaver command"
assert_contains bin/ryoku-launch-screensaver '\$RYOKU_PATH/bin/ryoku-cmd-screensaver' \
  "screensaver launcher should pass an absolute command path to terminal children"
assert_contains bin/ryoku-launch-screensaver '\$\{1:-\} != "force"' \
  "screensaver launcher should handle no-argument idle launches under set -u"
assert_contains bin/ryoku-cmd-screensaver 'tte -i "\$RYOKU_CONFIG_PATH/branding/screensaver\.txt"' \
  "screensaver command should render the configured ASCII branding with TTE"

assert_contains config/hypr/hypridle.conf 'ryoku-launch-screensaver' \
  "idle config should launch the preserved ASCII screensaver before monitor-off"
assert_contains config/hypr/hypridle.conf 'pkill -f org\.ryoku\.screensaver' \
  "idle resume should close stale screensaver windows"
assert_order config/hypr/hypridle.conf 'ryoku-launch-screensaver' 'power-off-monitors' \
  "screensaver should start before monitors are powered off"

assert_contains shell/modules/common/functions/Session.qml 'ryoku-launch-screensaver.*force' \
  "manual hibernate should show the ASCII screensaver before sleeping"
assert_order shell/modules/common/functions/Session.qml '_launchScreensaver\(true\)' '_hibernateTimer\.restart\(\)' \
  "manual hibernate should start screensaver before scheduling hibernate"
assert_contains shell/modules/common/functions/Session.qml '_hibernateLockTimer' \
  "manual hibernate should still lock before entering hibernation"

bash -n bin/ryoku-launch-screensaver bin/ryoku-cmd-screensaver tests/screensaver-sleep-flow.sh

pass
