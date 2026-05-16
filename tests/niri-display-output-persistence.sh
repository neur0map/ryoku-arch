#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_file() {
  local path="$1"

  [[ -f $path ]] || fail "$path should exist"
}

assert_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"

  grep -Eq "$pattern" "$file" || fail "$message"
}

assert_not_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"

  if grep -Eq "$pattern" "$file"; then
    fail "$message"
  fi
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

assert_include_layout() {
  local root_config="$1"

  assert_contains "$root_config" 'include "config\.d/15-outputs\.kdl"' \
    "$root_config should include generated display output settings"
  assert_order "$root_config" 'include "config\.d/10-input-and-cursor\.kdl"' \
    'include "config\.d/15-outputs\.kdl"' \
    "$root_config should load display outputs after input settings"
  assert_order "$root_config" 'include "config\.d/15-outputs\.kdl"' \
    'include "config\.d/20-layout-and-overview\.kdl"' \
    "$root_config should load display outputs before layout settings"
  assert_order "$root_config" 'include "config\.d/15-outputs\.kdl"' \
    'include "config\.d/90-user-extra\.kdl"' \
    "$root_config should let 90-user-extra override generated output settings"
}

assert_include_layout "$ROOT_DIR/config/niri/config.kdl"
assert_include_layout "$ROOT_DIR/shell/defaults/niri/config.kdl"
assert_file "$ROOT_DIR/config/niri/config.d/15-outputs.kdl"
assert_file "$ROOT_DIR/shell/defaults/niri/config.d/15-outputs.kdl"
assert_contains "$ROOT_DIR/config/niri/config.d/15-outputs.kdl" \
  'This file starts empty because every machine has different displays' \
  "core output file should not ship a hardcoded display mode"
assert_contains "$ROOT_DIR/shell/defaults/niri/config.d/15-outputs.kdl" \
  'This file starts empty because every machine has different displays' \
  "shell output file should not ship a hardcoded display mode"

if grep -RE '^[[:space:]]*(//[[:space:]]*)?mode "[0-9]+x[0-9]+@[0-9]' \
  "$ROOT_DIR/config/niri" "$ROOT_DIR/shell/defaults/niri"; then
  fail "shipped Niri defaults should not contain hardcoded display refresh modes"
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

runtime_config="$tmp_dir/config"
mkdir -p "$runtime_config"
cp -a "$ROOT_DIR/shell/defaults/niri" "$runtime_config/niri"

XDG_CONFIG_HOME="$runtime_config" \
  python3 "$ROOT_DIR/shell/scripts/niri-config.py" persist-output DP-1 mode=2560x1440@165.000 \
  >"$tmp_dir/persist.json"

python3 - "$tmp_dir/persist.json" "$runtime_config/niri/config.d/15-outputs.kdl" <<'PY'
import json
import sys
from pathlib import Path

data = json.loads(Path(sys.argv[1]).read_text())
expected_file = Path(sys.argv[2])

if data.get("success") is not True:
    raise SystemExit("persist-output should report success")
if Path(data.get("file", "")) != expected_file:
    raise SystemExit("persist-output should write config.d/15-outputs.kdl")
PY

assert_contains "$runtime_config/niri/config.d/15-outputs.kdl" 'output "DP-1"' \
  "persist-output should create an output block in 15-outputs.kdl"
assert_contains "$runtime_config/niri/config.d/15-outputs.kdl" 'mode "2560x1440@165\.000"' \
  "persist-output should preserve the selected high refresh mode"
assert_not_contains "$runtime_config/niri/config.kdl" 'output "DP-1"' \
  "persist-output should not fall back to writing output blocks into config.kdl"

XDG_CONFIG_HOME="$runtime_config" \
  python3 "$ROOT_DIR/shell/scripts/niri-config.py" persist-output DP-1 mode=2560x1440@240.000 \
  >"$tmp_dir/persist-update.json"

assert_contains "$runtime_config/niri/config.d/15-outputs.kdl" 'mode "2560x1440@240\.000"' \
  "persist-output should update an existing active output block"
dp1_count=$(grep -c '^[[:space:]]*output "DP-1"' "$runtime_config/niri/config.d/15-outputs.kdl" || true)
(( dp1_count == 1 )) || fail "persist-output should not duplicate active output blocks"

XDG_CONFIG_HOME="$runtime_config" \
  python3 "$ROOT_DIR/shell/scripts/niri-config.py" detect-customizations \
  >"$tmp_dir/customizations.json"

python3 - "$tmp_dir/customizations.json" <<'PY'
import json
import sys
from pathlib import Path

data = json.loads(Path(sys.argv[1]).read_text())
summary = data.get("summary", {})
files = data.get("files", [])

if data.get("customized"):
    raise SystemExit("generated display output settings should not be actionable customizations")
if summary.get("actionable") != 0:
    raise SystemExit("generated display output settings should not increment actionable count")
if summary.get("expected_generated") != 1:
    raise SystemExit("generated display output settings should be informational")
if not any(file.get("path") == "config.d/15-outputs.kdl" and file.get("kind") == "expected-generated" for file in files):
    raise SystemExit("15-outputs.kdl should be classified as expected-generated")
PY

migration="$(grep -l "Preserve Niri display output settings" "$ROOT_DIR"/migrations/*.sh | sort -n | tail -n1)"
[[ -n $migration ]] || fail "top-level display output migration should exist"

migration_home="$tmp_dir/top-level-home"
mkdir -p "$migration_home/.config/niri/config.d"
cat >"$migration_home/.config/niri/config.kdl" <<'KDL'
prefer-no-csd
include "config.d/10-input-and-cursor.kdl"
include "config.d/20-layout-and-overview.kdl"

output "DP-2" {
    mode "3840x2160@240.000"
    scale 1
}

include "config.d/90-user-extra.kdl"
KDL

HOME="$migration_home" RYOKU_PATH="$ROOT_DIR" bash "$migration" >/dev/null
HOME="$migration_home" RYOKU_PATH="$ROOT_DIR" bash "$migration" >/dev/null

assert_contains "$migration_home/.config/niri/config.d/15-outputs.kdl" 'output "DP-2"' \
  "top-level migration should move root output blocks into 15-outputs.kdl"
assert_contains "$migration_home/.config/niri/config.d/15-outputs.kdl" 'mode "3840x2160@240\.000"' \
  "top-level migration should preserve high refresh mode"
assert_not_contains "$migration_home/.config/niri/config.kdl" 'output "DP-2"' \
  "top-level migration should remove output blocks from root config"
assert_include_layout "$migration_home/.config/niri/config.kdl"

include_count=$(grep -c 'include "config.d/15-outputs.kdl"' "$migration_home/.config/niri/config.kdl" || true)
(( include_count == 1 )) || fail "top-level migration should be idempotent for include lines"
output_count=$(grep -c 'output "DP-2"' "$migration_home/.config/niri/config.d/15-outputs.kdl" || true)
(( output_count == 1 )) || fail "top-level migration should not duplicate moved output blocks"

shell_migration="$ROOT_DIR/shell/sdata/migrations/024-display-output-persistence.sh"
assert_file "$shell_migration"

shell_home="$tmp_dir/shell-home"
mkdir -p "$shell_home/.config/niri/config.d"
cat >"$shell_home/.config/niri/config.kdl" <<'KDL'
prefer-no-csd
include "config.d/10-input-and-cursor.kdl"
include "config.d/20-layout-and-overview.kdl"

output "HDMI-A-1" {
    mode "2560x1440@165.000"
    variable-refresh-rate
}

include "config.d/90-user-extra.kdl"
KDL

(
  export HOME="$shell_home"
  export XDG_CONFIG_HOME="$shell_home/.config"
  export REPO_ROOT="$ROOT_DIR/shell"
  # shellcheck source=shell/sdata/migrations/024-display-output-persistence.sh
  source "$shell_migration"
  migration_check || fail "shell migration should be needed before apply"
  migration_apply
  if migration_check; then
    fail "shell migration should be clean after apply"
  fi
)

assert_contains "$shell_home/.config/niri/config.d/15-outputs.kdl" 'output "HDMI-A-1"' \
  "shell migration should move root output blocks into 15-outputs.kdl"
assert_contains "$shell_home/.config/niri/config.d/15-outputs.kdl" 'mode "2560x1440@165\.000"' \
  "shell migration should preserve high refresh mode"
assert_not_contains "$shell_home/.config/niri/config.kdl" 'output "HDMI-A-1"' \
  "shell migration should remove output blocks from shell root config"
assert_include_layout "$shell_home/.config/niri/config.kdl"

printf 'PASS: tests/niri-display-output-persistence.sh\n'
