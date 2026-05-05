#!/bin/bash
# Static validation for the Settings -> Login screen page and its
# privileged helpers. Pure shell assertions; does not run quickshell,
# does not start SDDM, does not call any helper.

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_file() {
  [[ -f $ROOT_DIR/$1 ]] || fail "missing file: $1"
}

assert_executable() {
  [[ -x $ROOT_DIR/$1 ]] || fail "not executable: $1"
}

assert_grep() {
  local pattern="$1" file="$2"
  grep -qE "$pattern" "$ROOT_DIR/$file" || fail "$file: missing pattern /$pattern/"
}

assert_no_grep() {
  local pattern="$1" file="$2"
  if grep -qE "$pattern" "$ROOT_DIR/$file"; then
    fail "$file: should not contain pattern /$pattern/"
  fi
}

assert_png() {
  local path="$1"
  assert_file "$path"
  file -b "$ROOT_DIR/$path" | grep -q "PNG image data" \
    || fail "$path: not a PNG"
}

# ---------------------------------------------------------------------
# Assertions (filled in as tasks land code).
# ---------------------------------------------------------------------

echo "PASS: tests/login-screen-config.sh ($0)"
