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

  grep -Eq "$pattern" "$ROOT_DIR/$path" || fail "$message"
}

assert_contains "install/config/shell.sh" "restore_user_shell_config" \
  "shell updater should merge the active user config around shell setup install"
assert_contains "install/config/shell.sh" "backup_config_file" \
  "shell updater should back up the active user config before shell setup install"

printf 'PASS: shell updater preserves config across shell restore\n'
