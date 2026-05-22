#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SHELL_SCRIPT="$ROOT_DIR/shell/scripts/ryoku-shell"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_contains() {
  local pattern="$1"
  local message="$2"

  rg -n -- "$pattern" "$SHELL_SCRIPT" >/dev/null || fail "$message"
}

assert_not_contains() {
  local pattern="$1"
  local message="$2"

  if rg -n -- "$pattern" "$SHELL_SCRIPT" >/dev/null; then
    fail "$message"
  fi
}

assert_contains "v2:\\\$abi_cache_key" \
  "ABI cache key should be versioned so old patch-compatible cache entries do not hide new checks"
assert_contains "\"\\\$runtime_qt\"\\) ;;" \
  "Quickshell ABI guard should reject Qt patch-version mismatches, not only minor-version mismatches"
assert_not_contains 'build_minor=.*buildtime_qt' \
  "ABI guard should not collapse build-time Qt to a minor version"
assert_not_contains 'runtime_minor=.*runtime_qt' \
  "ABI guard should not collapse runtime Qt to a minor version"

printf 'PASS: tests/ryoku-shell-abi-check.sh\n'
