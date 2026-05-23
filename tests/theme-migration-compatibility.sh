#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
MIGRATION="$ROOT_DIR/migrations/1752725616.sh"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

home_ryoku="$tmp/home-ryoku"
ryoku_path="$tmp/ryoku"
mkdir -p "$home_ryoku" "$ryoku_path/themes/rose-pine"

HOME="$home_ryoku" RYOKU_PATH="$ryoku_path" bash "$MIGRATION" >/dev/null

[[ -d $home_ryoku/.config/ryoku/themes ]] || \
  fail "migration should create the Ryoku user theme directory"
[[ -L $home_ryoku/.config/ryoku/themes/rose-pine ]] || \
  fail "migration should create the rose-pine theme symlink"
[[ $(readlink "$home_ryoku/.config/ryoku/themes/rose-pine") == "$ryoku_path/themes/rose-pine" ]] || \
  fail "migration should prefer the active Ryoku checkout theme"

home_omarchy="$tmp/home-omarchy"
missing_ryoku="$tmp/missing-ryoku"
mkdir -p "$home_omarchy/.local/share/omarchy/themes/rose-pine" "$missing_ryoku"

HOME="$home_omarchy" RYOKU_PATH="$missing_ryoku" bash "$MIGRATION" >/dev/null

[[ -L $home_omarchy/.config/ryoku/themes/rose-pine ]] || \
  fail "migration should preserve compatibility with old Omarchy theme trees"
[[ $(readlink "$home_omarchy/.config/ryoku/themes/rose-pine") == "$home_omarchy/.local/share/omarchy/themes/rose-pine" ]] || \
  fail "migration should fall back to the old Omarchy theme path when needed"

echo "PASS: old theme migration keeps compatible Ryoku and Omarchy themes"
