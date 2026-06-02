#!/bin/bash
# Guards shell IPC <-> keybind parity: every `ryoku-shell ipc <t> <f>` bind must
# dispatch to a real handler in the committed IPC surface manifest. Runs in
# manifest mode (RYOKU_AUDIT_FORCE_MANIFEST) so it is deterministic in CI where
# no shell is running.

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
AUDIT="$ROOT_DIR/bin/ryoku-dev-audit-shell-binds"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

[[ -f $AUDIT ]] || fail "bin/ryoku-dev-audit-shell-binds should exist"
[[ -x $AUDIT ]] || fail "bin/ryoku-dev-audit-shell-binds should be executable"
[[ -f $ROOT_DIR/shell/ipc-surface.txt ]] || fail "shell/ipc-surface.txt manifest should be committed (run: ryoku-dev-audit-shell-binds --refresh)"

# 1. The real repo must pass: no shipped keybind dispatches to a missing handler,
#    and the committed manifest must cover every bound invocation.
if ! RYOKU_AUDIT_FORCE_MANIFEST=1 RYOKU_PATH="$ROOT_DIR" "$AUDIT" --check >/dev/null 2>&1; then
  RYOKU_AUDIT_FORCE_MANIFEST=1 RYOKU_PATH="$ROOT_DIR" "$AUDIT" --check || true
  fail "shipped keybinds reference a missing IPC handler (or the manifest is stale; run --refresh)"
fi

# 2. The gate must actually DETECT a dangling bind (behavior, not just current state).
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/shell" "$tmp/config/hypr"
printf 'target foo\n  function bar(): void\n' >"$tmp/shell/ipc-surface.txt"
printf "bind = SUPER, X, exec, ryoku-shell ipc foo bar\n" >"$tmp/config/hypr/ok.conf"
if ! RYOKU_AUDIT_FORCE_MANIFEST=1 RYOKU_PATH="$tmp" "$AUDIT" --check >/dev/null 2>&1; then
  fail "gate false-positived on a valid bind (foo bar exists in the manifest)"
fi
printf "bind = SUPER, Y, exec, ryoku-shell ipc foo nope\n" >"$tmp/config/hypr/bad.conf"
if RYOKU_AUDIT_FORCE_MANIFEST=1 RYOKU_PATH="$tmp" "$AUDIT" --check >/dev/null 2>&1; then
  fail "gate did NOT detect a dangling bind (foo nope is not in the manifest)"
fi

echo "PASS: shell-bind-parity"
