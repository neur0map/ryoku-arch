#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
CHECKER="$ROOT_DIR/bin/ryoku-dev-shellcheck-changed"
HOOK="$ROOT_DIR/.githooks/pre-push"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_file() {
  local path="$1"

  [[ -f $path ]] || fail "$path should exist"
}

assert_executable() {
  local path="$1"

  assert_file "$path"
  [[ -x $path ]] || fail "$path should be executable"
}

assert_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"

  grep -Eq "$pattern" "$file" || fail "$message"
}

assert_not_selected() {
  local selected="$1"
  local pattern="$2"
  local message="$3"

  if grep -Eq "$pattern" "$selected"; then
    fail "$message"
  fi
}

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

assert_executable "$CHECKER"
assert_executable "$HOOK"
assert_contains "$HOOK" 'ryoku-dev-shellcheck-changed"?[[:space:]]+--push-stdin' \
  "pre-push should run the CI-equivalent ShellCheck helper"
assert_contains "$CHECKER" 'shellcheck -x -s bash --severity=warning' \
  "local ShellCheck helper should match the GitHub Actions severity and shell mode"
assert_contains "$ROOT_DIR/docs/maintenance.md" 'bin/ryoku-dev-shellcheck-changed' \
  "maintenance docs should document the local ShellCheck command"

"$CHECKER" --print-files --files \
  bin/ryoku-dev-install-hooks \
  .githooks/pre-push \
  install/ryoku-base.packages \
  shell/scripts/emoji/emoji-data.sh \
  .github/workflows/shellcheck.yml \
  >"$tmp_dir/selected.txt"

assert_contains "$tmp_dir/selected.txt" '^bin/ryoku-dev-install-hooks$' \
  "helper should include executable bin scripts"
assert_contains "$tmp_dir/selected.txt" '^\.githooks/pre-push$' \
  "helper should include shebang git hooks"
assert_not_selected "$tmp_dir/selected.txt" '^install/ryoku-base\.packages$' \
  "helper should not lint install package-list data"
assert_not_selected "$tmp_dir/selected.txt" '^shell/scripts/emoji/emoji-data\.sh$' \
  "helper should preserve the CI emoji data exclusion"
assert_not_selected "$tmp_dir/selected.txt" '^\.github/workflows/shellcheck\.yml$' \
  "helper should not lint non-shell workflow yaml"

printf 'PASS: tests/shellcheck-pre-push-hook.sh\n'
