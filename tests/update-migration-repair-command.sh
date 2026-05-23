#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT_DIR/bin/ryoku-update-repair-migrations"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_contains() {
  local path="$1"
  local pattern="$2"
  local message="$3"

  grep -Eq "$pattern" "$path" || fail "$message"
}

assert_not_contains() {
  local path="$1"
  local pattern="$2"
  local message="$3"

  if grep -Eq "$pattern" "$path"; then
    fail "$message"
  fi
}

[[ -x $SCRIPT ]] || fail "repair command should exist and be executable"

# shellcheck disable=SC2016
assert_contains "$SCRIPT" 'git -C "\$ryoku_path" fetch origin' \
  "repair command should fetch the latest fixed channel"
# shellcheck disable=SC2016
assert_contains "$SCRIPT" 'git -C "\$ryoku_path" pull --ff-only origin "\$channel"' \
  "repair command should fast-forward the installed checkout"
assert_contains "$SCRIPT" 'install/preflight/migrations\.sh' \
  "repair command should baseline current migration files"
assert_contains "$SCRIPT" 'ryoku-migrate" --repair-baseline' \
  "repair command should use safe migrator baseline repair"
assert_contains "$SCRIPT" 'independence-cutover\.started' \
  "repair command should clear stale cutover in-progress state"
assert_contains "$SCRIPT" 'install/config/shell\.sh' \
  "repair command should resync the shell runtime"
assert_contains "$SCRIPT" 'restart ryoku-shell\.service|start ryoku-shell\.service' \
  "repair command should restart the user shell"
assert_not_contains "$SCRIPT" 'reset --hard' \
  "repair command should not destroy local checkout edits by default"

echo "PASS: update migration repair command"
