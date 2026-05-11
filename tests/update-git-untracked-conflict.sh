#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

temp_dir=$(mktemp -d)
trap 'rm -rf "$temp_dir"' EXIT

remote="$temp_dir/remote.git"
seed="$temp_dir/seed"
checkout="$temp_dir/checkout"
home_dir="$temp_dir/home"
bin_dir="$temp_dir/bin"

mkdir -p "$home_dir" "$bin_dir"
printf '#!/bin/sh\nexit 0\n' >"$bin_dir/ryoku-update-time"
chmod +x "$bin_dir/ryoku-update-time"
git init --bare "$remote" >/dev/null

git clone "$remote" "$seed" >/dev/null 2>&1
git -C "$seed" config user.email test@example.invalid
git -C "$seed" config user.name "Ryoku Test"
printf '%s\n' "base" >"$seed/README.md"
git -C "$seed" add README.md
git -C "$seed" commit -m "base" >/dev/null
git -C "$seed" push origin HEAD:main >/dev/null 2>&1

git clone "$remote" "$checkout" >/dev/null 2>&1
git -C "$checkout" checkout main >/dev/null 2>&1

mkdir -p "$checkout/tests" "$seed/tests"
printf '%s\n' "local generated file" >"$checkout/tests/installer-keymap.sh"

printf '%s\n' "tracked upstream test" >"$seed/tests/installer-keymap.sh"
git -C "$seed" add tests/installer-keymap.sh
git -C "$seed" commit -m "track installer keymap test" >/dev/null
git -C "$seed" push origin HEAD:main >/dev/null 2>&1

output=$(
  HOME="$home_dir" \
  RYOKU_PATH="$checkout" \
  RYOKU_STATE_PATH="$temp_dir/state" \
  PATH="$bin_dir:$ROOT_DIR/bin:$PATH" \
  "$ROOT_DIR/bin/ryoku-update-git" 2>&1
) || fail "ryoku-update-git should recover when an untracked file conflicts with an upstream tracked file: $output"

[[ $(git -C "$checkout" rev-parse HEAD) == "$(git -C "$seed" rev-parse HEAD)" ]] || \
  fail "ryoku-update-git should leave checkout at upstream HEAD"

[[ -f "$checkout/tests/installer-keymap.sh" ]] || \
  fail "tracked upstream file should exist after update"

grep -qx 'tracked upstream test' "$checkout/tests/installer-keymap.sh" || \
  fail "tracked upstream file should win the checkout path after update"

git -C "$checkout" stash list | grep -q 'ryoku-update autostash' || \
  fail "conflicting untracked local file should remain recoverable in git stash"

git -C "$checkout" status --short | grep -Eq 'tests/installer-keymap\.sh' && \
  fail "checkout should not leave conflicting installer-keymap path dirty after update"

echo "PASS: update git untracked conflict recovery"
