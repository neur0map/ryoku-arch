#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

# rsi_read_manifest must emit normal packages but never one inside an
# `# @os-only` ... `# @end` region.
# shellcheck disable=SC1091
source "$ROOT_DIR/shell-install/lib/packages.sh"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
cat >"$tmp" <<'PKG'
hyprland
# @os-only
sddm
plymouth
# @end
quickshell
PKG

out="$(rsi_read_manifest "$tmp")"
grep -qx hyprland <<<"$out" || fail "reader dropped a normal package before the region"
grep -qx quickshell <<<"$out" || fail "reader dropped a package after @end"
grep -qx sddm <<<"$out" && fail "reader leaked an @os-only package"
grep -qx plymouth <<<"$out" && fail "reader leaked an @os-only package"

printf 'PASS: tests/manifest-reader-skips-os-only.sh\n'
