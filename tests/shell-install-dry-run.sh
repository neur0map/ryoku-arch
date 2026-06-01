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

# Dry run must detect the distro, print a plan, and change nothing in HOME.
HOME="$tmp_dir" bash "$ROOT_DIR/shell-install/install" --dry-run --yes >"$out" 2>&1 \
  || fail "dry-run install exited non-zero"

grep -q "family" "$out" || fail "dry-run should report a detected distro family"
grep -q "dry run: nothing was changed" "$out" || fail "dry-run should announce it changed nothing"
grep -q "will NOT touch" "$out" || fail "dry-run plan should list what is never touched"

[[ ! -e $tmp_dir/.local/share/ryoku ]] || fail "dry-run must not deploy the payload"
[[ ! -e $tmp_dir/.local/state/ryoku-shell/manifest.tsv ]] || fail "dry-run must not write a manifest"
[[ ! -e $tmp_dir/.config/quickshell/ryoku-shell ]] || fail "dry-run must not deploy the shell"

printf 'PASS: tests/shell-install-dry-run.sh\n'
