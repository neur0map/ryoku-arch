#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

# A non-Arch os-release must hard-stop the installer before any change, even
# in dry-run.
printf 'ID=fedora\nID_LIKE=rhel\nNAME=Fedora\n' >"$tmp_dir/os-release"
out="$tmp_dir/out.txt"

if HOME="$tmp_dir" RSI_OS_RELEASE="$tmp_dir/os-release" \
   bash "$ROOT_DIR/shell-install/install" --dry-run --yes >"$out" 2>&1; then
  fail "installer should have exited non-zero on a non-Arch system"
fi

grep -qi "unsupported distro 'fedora'" "$out" || fail "should name the unsupported distro and stop"
grep -qi "deploy complete" "$out" && fail "must not reach the deploy stage on an unsupported system"

[[ ! -e $tmp_dir/.local/share/ryoku ]] || fail "unsafe stop must not deploy anything"

printf 'PASS: tests/shell-install-safety-stop.sh\n'
