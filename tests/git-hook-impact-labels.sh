#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
COMMIT_MSG_HOOK="$ROOT_DIR/.githooks/commit-msg"
PRE_COMMIT_HOOK="$ROOT_DIR/.githooks/pre-commit"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"

  grep -Eq -- "$pattern" "$file" || fail "$message"
}

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

printf '%s\n' '[global] Repair browser defaults' >"$tmp_dir/valid-global"
"$COMMIT_MSG_HOOK" "$tmp_dir/valid-global"

printf '%s\n' 'Repair browser defaults' >"$tmp_dir/missing-label"
if "$COMMIT_MSG_HOOK" "$tmp_dir/missing-label" >/dev/null 2>&1; then
  fail "commit-msg should reject unlabeled commit subjects"
fi

assert_contains "$COMMIT_MSG_HOOK" '\[global\]' \
  "commit-msg should document the global impact label"
assert_contains "$COMMIT_MSG_HOOK" '\[system\]' \
  "commit-msg should document the system impact label"
assert_contains "$PRE_COMMIT_HOOK" 'global_default_change' \
  "pre-commit should detect default config changes"
assert_contains "$PRE_COMMIT_HOOK" 'RYOKU_ALLOW_NO_MIGRATION' \
  "pre-commit should require an explicit bypass for fresh-install-only config changes"
assert_contains "$ROOT_DIR/docs/maintenance.md" '\[global\]' \
  "maintenance docs should define the global label"

bash -n "$COMMIT_MSG_HOOK" "$PRE_COMMIT_HOOK" "$0"

echo "PASS: git hooks enforce impact labels"
