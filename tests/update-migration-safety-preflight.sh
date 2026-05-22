#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
PERFORM="$ROOT_DIR/bin/ryoku-update-perform"

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

assert_order() {
  local file="$1"
  local first_pattern="$2"
  local second_pattern="$3"
  local message="$4"
  local first_line second_line

  first_line=$(grep -nE "$first_pattern" "$file" | head -n1 | cut -d: -f1)
  second_line=$(grep -nE "$second_pattern" "$file" | head -n1 | cut -d: -f1)

  [[ -n $first_line && -n $second_line ]] || fail "$message"
  (( first_line < second_line )) || fail "$message"
}

assert_contains "$PERFORM" 'update_migration_safety_stage\(\)' \
  "update performer should define a migration safety preflight stage"
assert_contains "$PERFORM" 'ryoku-migrate --repair-baseline' \
  "migration safety preflight should repair missing migration baselines without running migrations"
assert_contains "$PERFORM" '"Migration safety"' \
  "migration safety preflight should be visible as the first update stage"
assert_order "$PERFORM" '"Migration safety"' '"Arch signing keys"' \
  "migration safety preflight should run before package/key stages"
assert_order "$PERFORM" 'ryoku_update_run_stage 1 .*"Migration safety"' 'ryoku_update_run_stage 2 .*"Arch signing keys"' \
  "migration safety preflight should be the first executed update stage"
assert_order "$PERFORM" 'ryoku-migrate --repair-baseline' 'ryoku_update_run_stage 7 .*"Migrations"' \
  "baseline repair should happen before normal migrations can run"

echo "PASS: update runs migration safety preflight first"
