#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DASHBOARD="$ROOT_DIR/lib/update-dashboard.sh"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

grep -Fq 'RYOKU_UPDATE_DOCTOR_COMMAND' "$DASHBOARD" || \
  fail "update dashboard should honor the path-safe doctor command from bootstrap/update"
grep -Fq '$RYOKU_PATH/bin/ryoku-doctor' "$DASHBOARD" || \
  fail "update dashboard should fall back to the installed checkout doctor"

echo "PASS: update dashboard uses path-safe doctor command"
