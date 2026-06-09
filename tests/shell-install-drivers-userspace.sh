#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
out="$tmp_dir/out.txt"

# Default standalone: drivers are planned, boot config OFF (packages only).
HOME="$tmp_dir" bash "$ROOT_DIR/shell-install/install" --dry-run --yes >"$out" 2>&1 \
  || fail "dry-run install exited non-zero"
grep -qi 'driver' "$out" || fail "plan should mention installing drivers"
grep -q 'RYOKU_BOOT_CONFIG=0' "$out" || fail "default standalone must plan drivers with boot config OFF"
[[ ! -e $tmp_dir/.local/share/ryoku ]] || fail "dry-run must not deploy anything"

# Opt-in: full boot-config parity.
HOME="$tmp_dir" bash "$ROOT_DIR/shell-install/install" --dry-run --yes --with-boot-config >"$out" 2>&1 \
  || fail "opt-in dry-run exited non-zero"
grep -q 'RYOKU_BOOT_CONFIG=1' "$out" || fail "--with-boot-config must enable boot config"

printf 'PASS: tests/shell-install-drivers-userspace.sh\n'
