#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_file() {
  local path="$1"

  [[ -f $ROOT_DIR/$path ]] || fail "$path should exist"
}

assert_executable() {
  local path="$1"

  assert_file "$path"
  [[ -x $ROOT_DIR/$path ]] || fail "$path should be executable"
}

assert_contains() {
  local path="$1"
  local pattern="$2"
  local message="$3"

  grep -Eq -- "$pattern" "$ROOT_DIR/$path" || fail "$message"
}

assert_listener_script() {
  assert_executable "bin/ryoku-resume-listener"
  assert_contains "bin/ryoku-resume-listener" 'gdbus monitor' \
    "Listener should use gdbus monitor to read the system bus"
  assert_contains "bin/ryoku-resume-listener" '--system' \
    "Listener should subscribe on the system bus"
  assert_contains "bin/ryoku-resume-listener" '--dest org\.freedesktop\.login1' \
    "Listener should target the systemd-logind destination"
  assert_contains "bin/ryoku-resume-listener" 'PrepareForSleep' \
    "Listener should match the PrepareForSleep signal name"
  assert_contains "bin/ryoku-resume-listener" '\(false,\)' \
    "Listener should match the falsey (resume) argument shape"
  assert_contains "bin/ryoku-resume-listener" 'ryoku-session-recover --quiet --resume' \
    "Listener should invoke ryoku-session-recover with --quiet and --resume"
}

assert_listener_script

echo "PASS: ryoku resume listener"
