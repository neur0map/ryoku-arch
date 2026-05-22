#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

temp_dir=$(mktemp -d)
trap 'rm -rf "$temp_dir"' EXIT

home_dir="$temp_dir/home"
ryoku_dir="$temp_dir/ryoku"
state_dir="$home_dir/.local/state/ryoku"
old_ran="$temp_dir/old-ran"
new_ran="$temp_dir/new-ran"

mkdir -p "$home_dir" "$ryoku_dir/migrations"

cat >"$ryoku_dir/migrations/1752643269.sh" <<MIGRATION
#!/bin/bash
echo old >"$old_ran"
exit 33
MIGRATION

cat >"$ryoku_dir/migrations/1776912972.sh" <<MIGRATION
#!/bin/bash
echo new >"$new_ran"
MIGRATION

HOME="$home_dir" \
  RYOKU_PATH="$ryoku_dir" \
  RYOKU_STATE_PATH="$state_dir" \
  /bin/bash "$ROOT_DIR/bin/ryoku-migrate" >/dev/null

[[ ! -e $old_ran ]] \
  || fail "historical Omarchy-era migrations should not execute when no legacy state exists"
[[ -f $state_dir/migrations/1752643269.sh ]] \
  || fail "historical migration should be marked as baseline"
[[ -e $new_ran ]] \
  || fail "Ryoku-era migrations should still run"
[[ -f $state_dir/migrations/1776912972.sh ]] \
  || fail "Ryoku-era migration should be recorded after running"

echo "PASS: ryoku-migrate seeds historical baseline migrations"
