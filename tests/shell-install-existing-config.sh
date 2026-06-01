#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

# Pre-existing config that the installer would back up. This must NOT abort
# the run after the safety checks (regression: the conflict report used a
# `(( found == 0 )) && rsi_ok` that returned non-zero under set -e when a
# conflict existed, exiting the whole installer before the consent prompt).
mkdir -p "$tmp_dir/.config/hypr"
printf 'monitor=,preferred,auto,1\n' >"$tmp_dir/.config/hypr/hyprland.conf"

out="$tmp_dir/out.txt"
HOME="$tmp_dir" bash "$ROOT_DIR/shell-install/install" --dry-run --yes >"$out" 2>&1 \
  || fail "dry-run must not exit non-zero when an existing config is present"

grep -q "will be backed up" "$out" || fail "the existing config should be reported as a conflict to back up"
grep -q "deploy complete" "$out" || fail "the run must continue past the conflict report to the deploy preview"

printf 'PASS: tests/shell-install-existing-config.sh\n'
