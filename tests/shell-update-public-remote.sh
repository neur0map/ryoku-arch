#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
SHELL_UPDATES_QML="$ROOT_DIR/shell/services/ShellUpdates.qml"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

[[ -f $SHELL_UPDATES_QML ]] || fail "missing ShellUpdates.qml"

rg -q 'https://github\.com/neur0map/ryoku-arch\.git' "$SHELL_UPDATES_QML" || \
  fail "Shell update checks should normalize to the public Ryoku remote"

rg -q 'GIT_TERMINAL_PROMPT: "0"' "$SHELL_UPDATES_QML" || \
  fail "Shell update git commands should disable terminal credential prompts"

rg -q 'GIT_ASKPASS: "/bin/true"' "$SHELL_UPDATES_QML" || \
  fail "Shell update git commands should disable GUI askpass credential prompts"

rg -q 'remote set-url origin' "$SHELL_UPDATES_QML" || \
  fail "Shell update checks should replace stale/private origins"

rg -q 'remote add origin' "$SHELL_UPDATES_QML" || \
  fail "Shell update checks should recover if origin is missing"

rg -q 'normalizeRemoteProc\.running = true' "$SHELL_UPDATES_QML" || \
  fail "Manual and automatic checks should normalize origin before fetching"

rg -q '\+refs/heads/main:refs/remotes/origin/main' "$SHELL_UPDATES_QML" || \
  fail "Shell update checks should explicitly fetch origin/main, even from feature-branch ISO builds"

! rg -q 'origin/" \+ root\.currentBranch' "$SHELL_UPDATES_QML" || \
  fail "Shell update checks should not track stale feature-branch remote refs"

! rg -q '\$\{git_cmd\[@\]\}' "$SHELL_UPDATES_QML" || \
  fail "Shell update checker should not embed Bash arrays in QML template strings"

echo "PASS: Shell update checker uses public remote without prompts"
