#!/bin/bash

# Verifies the Lua linter used by the pre-commit hook: a clean file passes, a
# file with a real diagnostic fails, and diagnostics are filtered to the
# requested files so a dirty sibling never blocks an unrelated target.
#
# Skipped (pass) when lua-language-server is not installed, since the linter
# degrades to a no-op there.

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

BIN="bin/ryoku-dev-lint-lua"

fail() { echo "FAIL: $1" >&2; exit 1; }

if ! command -v lua-language-server >/dev/null 2>&1; then
  echo "skip: lua-language-server not installed"
  exit 0
fi

[[ -x $BIN ]] || fail "$BIN is missing or not executable"

work="$(mktemp -d "$ROOT_DIR/tests/.lualint.XXXXXX")"
trap 'rm -rf "$work"' EXIT
rel="${work#"$ROOT_DIR"/}"

printf 'local x = 1\nreturn x\n' >"$work/good.lua"
printf 'local y = 1\nreturn y + undefined_glob_zzz\n' >"$work/bad.lua"

# 1. A clean file passes.
"$BIN" --files "$rel/good.lua" || fail "clean Lua file should pass"

# 2. A file with an undefined global fails.
if "$BIN" --files "$rel/bad.lua" >/dev/null 2>&1; then
  fail "Lua file with an undefined global should fail"
fi

# 3. Requesting only the clean file passes even though a dirty sibling exists in
#    the same workspace directory (diagnostics are filtered to the target set).
"$BIN" --files "$rel/good.lua" || fail "clean target should pass despite dirty sibling"

# 4. A non-Lua argument is a no-op (nothing to lint).
"$BIN" --files README.md || fail "non-Lua argument should be a no-op pass"

echo "ryoku-dev-lint-lua: ok"
