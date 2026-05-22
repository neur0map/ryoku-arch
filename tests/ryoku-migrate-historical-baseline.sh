#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

temp_dir=$(mktemp -d)
trap 'rm -rf "$temp_dir"' EXIT

write_migration() {
  local path="$1"
  local marker="$2"
  local exit_code="${3:-0}"

  cat >"$path" <<MIGRATION
#!/bin/bash
echo ran >"$marker"
exit $exit_code
MIGRATION
}

assert_missing_history_is_baselined() {
  local home_dir="$temp_dir/missing-history-home"
  local ryoku_dir="$temp_dir/missing-history-ryoku"
  local state_dir="$home_dir/.local/state/ryoku"
  local old_ran="$temp_dir/old-ran"
  local cutover_ran="$temp_dir/cutover-ran"

  mkdir -p "$home_dir" "$ryoku_dir/migrations" "$state_dir/migrations"
  touch "$state_dir/migrations/1751134560.sh"

  write_migration "$ryoku_dir/migrations/1752643269.sh" "$old_ran" 33
  write_migration "$ryoku_dir/migrations/1776979278.sh" "$cutover_ran"

  HOME="$home_dir" \
    RYOKU_PATH="$ryoku_dir" \
    RYOKU_STATE_PATH="$state_dir" \
    /bin/bash "$ROOT_DIR/bin/ryoku-migrate" >/dev/null

  [[ ! -e $old_ran ]] \
    || fail "historical Omarchy-era migrations should not execute when no legacy state exists"
  [[ -f $state_dir/migrations/1752643269.sh ]] \
    || fail "historical migration should be marked as baseline"
  [[ ! -e $cutover_ran ]] \
    || fail "cutover migrations should not replay when Ryoku migration history is missing"
  [[ -f $state_dir/migrations/1776979278.sh ]] \
    || fail "cutover migration should be marked as part of the current baseline"
}

assert_repair_baseline_does_not_run_pending_migrations() {
  local home_dir="$temp_dir/repair-mode-home"
  local ryoku_dir="$temp_dir/repair-mode-ryoku"
  local state_dir="$home_dir/.local/state/ryoku"
  local pending_ran="$temp_dir/pending-ran"

  mkdir -p "$home_dir" "$ryoku_dir/migrations" "$state_dir/migrations"
  touch "$state_dir/migrations/1776912972.sh"

  write_migration "$ryoku_dir/migrations/1776912972.sh" "$temp_dir/already-applied-ran"
  write_migration "$ryoku_dir/migrations/1779999999.sh" "$pending_ran"

  HOME="$home_dir" \
    RYOKU_PATH="$ryoku_dir" \
    RYOKU_STATE_PATH="$state_dir" \
    /bin/bash "$ROOT_DIR/bin/ryoku-migrate" --repair-baseline >/dev/null

  [[ ! -e $pending_ran ]] \
    || fail "repair baseline mode should not execute pending migrations"
  [[ ! -f $state_dir/migrations/1779999999.sh ]] \
    || fail "repair baseline mode should not mark normal pending Ryoku migrations"
}

assert_missing_history_is_baselined
assert_repair_baseline_does_not_run_pending_migrations

echo "PASS: ryoku-migrate baselines missing migration history"
