#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
AUTOMATED_SCRIPT="$ROOT_DIR/iso/configs/airootfs/root/.automated_script.sh"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

[[ -f $AUTOMATED_SCRIPT ]] || fail "missing ISO automated script"

if ! grep -Eq 'env -i RYOKU_CHROOT_INSTALL=1[[:space:]]*\\' "$AUTOMATED_SCRIPT"; then
  fail "ISO chroot should still mark the install as a Ryoku chroot install"
fi

if grep -Eq '^[[:space:]]*RYOKU_ONLINE_INSTALL=1[[:space:]]*\\' "$AUTOMATED_SCRIPT"; then
  fail "ISO chroot must not force online install mode; offline mirror installs should not need DNS"
fi

echo "PASS: ISO chroot install stays offline-first"
