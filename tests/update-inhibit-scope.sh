#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
UPDATE="$ROOT_DIR/bin/ryoku-update"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

[[ -f $UPDATE ]] || fail "missing ryoku-update"

grep -Eq -- '--what=sleep:idle[[:space:]]*\\?$' "$UPDATE" || \
  fail "ryoku-update should request only user-allowed sleep/idle inhibitors"

! rg -q 'shutdown|handle-lid-switch|handle-suspend-key|handle-hibernate-key' "$UPDATE" || \
  fail "ryoku-update should not request privileged shutdown or handle-* inhibitors"

echo "PASS: ryoku-update uses user-allowed inhibit scopes"
