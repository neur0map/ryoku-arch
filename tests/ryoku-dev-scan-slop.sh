#!/bin/bash

# Verifies the AI-slop comment scanner: full-line comments matching the phrase
# list are flagged across languages, code and string literals are left alone,
# the diff parser only inspects added lines, and the allowlist exempts vendored
# trees. This test file is itself allowlisted in the scanner so its fixtures do
# not trip the pre-commit hook.

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

BIN="bin/ryoku-dev-scan-slop"

fail() { echo "FAIL: $1" >&2; exit 1; }

[[ -x $BIN ]] || fail "$BIN is missing or not executable"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# 1. A slop comment is flagged.
printf '#!/bin/bash\n# As you can see, this is slop\necho hi\n' >"$work/slop.sh"
if "$BIN" --files "$work/slop.sh" >/dev/null 2>&1; then
  fail "a slop comment should be flagged"
fi

# 2. An ordinary comment passes.
printf '#!/bin/bash\n# Restart the service after applying config\necho hi\n' >"$work/clean.sh"
"$BIN" --files "$work/clean.sh" || fail "an ordinary comment should pass"

# 3. A slop phrase inside code or a string literal is not flagged (comment-scoped).
printf '#!/bin/bash\nmsg="as you can see this lives in a string"\n' >"$work/str.sh"
"$BIN" --files "$work/str.sh" || fail "a slop phrase in code should not flag"

# 4. Detection works for Lua (-- comments) and Markdown (prose).
printf -- '-- note that this is Lua slop\nlocal x = 1\n' >"$work/s.lua"
if "$BIN" --files "$work/s.lua" >/dev/null 2>&1; then
  fail "a Lua slop comment should be flagged"
fi
printf 'As you can see, this prose is slop.\n' >"$work/s.md"
if "$BIN" --files "$work/s.md" >/dev/null 2>&1; then
  fail "Markdown slop should be flagged"
fi

# 5. Diff mode flags an added comment but ignores added code.
added_comment=$'diff --git a/foo.sh b/foo.sh\n--- a/foo.sh\n+++ b/foo.sh\n@@ -0,0 +1,2 @@\n+# hope this helps\n+echo ok\n'
if printf '%s' "$added_comment" | "$BIN" --stdin >/dev/null 2>&1; then
  fail "an added slop comment in a diff should be flagged"
fi
added_code=$'diff --git a/foo.sh b/foo.sh\n--- a/foo.sh\n+++ b/foo.sh\n@@ -0,0 +1,1 @@\n+echo "as you can see this is code"\n'
printf '%s' "$added_code" | "$BIN" --stdin || fail "an added code line should not flag"

# 6. The allowlist exempts vendored trees (shell/).
exempt=$'diff --git a/shell/x.sh b/shell/x.sh\n--- a/shell/x.sh\n+++ b/shell/x.sh\n@@ -0,0 +1,1 @@\n+# as you can see this is exempt\n'
printf '%s' "$exempt" | "$BIN" --stdin || fail "shell/ should be allowlisted"

echo "ryoku-dev-scan-slop: ok"
