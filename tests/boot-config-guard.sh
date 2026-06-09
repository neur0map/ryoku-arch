#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

# shellcheck disable=SC1091
source "$ROOT_DIR/install/helpers/boot-config.sh"

RYOKU_BOOT_CONFIG=1 ryoku_boot_config_enabled || fail "should be enabled when RYOKU_BOOT_CONFIG=1"
if RYOKU_BOOT_CONFIG=0 ryoku_boot_config_enabled; then
  fail "should be disabled when RYOKU_BOOT_CONFIG=0"
fi
unset RYOKU_BOOT_CONFIG
ryoku_boot_config_enabled || fail "should default to enabled (OS/ISO behavior unchanged)"

printf 'PASS: tests/boot-config-guard.sh\n'
