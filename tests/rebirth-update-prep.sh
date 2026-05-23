#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

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

assert_contains "$ROOT_DIR/bin/ryoku-update-git" 'hyprctl reload' \
  "updater should reload Hyprland config when the user is already on Hyprland"
assert_contains "$ROOT_DIR/bin/ryoku-update-git" 'niri msg action load-config-file' \
  "updater should keep the existing compositor reload fallback before rebirth lands"
assert_not_contains "$ROOT_DIR/install/config/shell.sh" 'service enable niri|niri\.service\.wants' \
  "shell updater should not force-wire the shell to the old compositor service"
assert_contains "$ROOT_DIR/bin/ryoku-doctor" 'RYOKU_SHELL_RUNTIME_DIR' \
  "doctor should prefer the active runtime shell doctor when source and runtime drift"
assert_contains "$ROOT_DIR/bin/ryoku-doctor" 'shell\)' \
  "doctor should expose an explicit shell diagnostics mode"

echo "PASS: unstable-dev updater is prepared for the rebirth transition"
