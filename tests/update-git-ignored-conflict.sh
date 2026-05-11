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
state_dir="$temp_dir/state"
bin_dir="$temp_dir/bin"
conflict_path="bin/ryoku-netmon-collect"

mkdir -p "$home_dir" "$state_dir" "$bin_dir"
printf '#!/bin/bash\nexit 0\n' >"$bin_dir/ryoku-update-time"
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

printf '%s\n' "$conflict_path" >>"$checkout/.git/info/exclude"
mkdir -p "$checkout/bin"
printf '%s\n' "local ignored helper" >"$checkout/$conflict_path"

mkdir -p "$seed/bin"
printf '%s\n' "tracked upstream helper" >"$seed/$conflict_path"
git -C "$seed" add "$conflict_path"
git -C "$seed" commit -m "track netmon helper" >/dev/null
git -C "$seed" push origin HEAD:main >/dev/null 2>&1

output=$(
  HOME="$home_dir" \
  RYOKU_PATH="$checkout" \
  RYOKU_STATE_PATH="$state_dir" \
  RYOKU_UPDATE_REMOTE_URL="$remote" \
  PATH="$bin_dir:$ROOT_DIR/bin:$PATH" \
  "$ROOT_DIR/bin/ryoku-update-git" 2>&1
) || fail "ryoku-update-git should move ignored files that block a tracked update: $output"

[[ $(git -C "$checkout" rev-parse HEAD) == "$(git -C "$seed" rev-parse HEAD)" ]] || \
  fail "checkout should fast-forward to upstream HEAD"

grep -qx 'tracked upstream helper' "$checkout/$conflict_path" || \
  fail "tracked upstream helper should replace the checkout path"

backup_file="$(find "$state_dir/update-backups" -path "*/$conflict_path" -type f -print -quit 2>/dev/null || true)"
[[ -n $backup_file ]] || fail "ignored local helper should be preserved in update-backups"
grep -qx 'local ignored helper' "$backup_file" || \
  fail "backup should contain the ignored local helper"

echo "PASS: update git ignored conflict recovery"
