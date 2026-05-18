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
feature_branch="codex/iso-offline-release-manifests"

mkdir -p "$home_dir" "$bin_dir"
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
git -C "$seed" push origin HEAD:"$feature_branch" >/dev/null 2>&1

git clone "$remote" "$checkout" >/dev/null 2>&1
git -C "$checkout" checkout -b "$feature_branch" "origin/$feature_branch" >/dev/null 2>&1
git -C "$checkout" config user.email test@example.invalid
git -C "$checkout" config user.name "Ryoku Test"
printf '%s\n' "local feature work" >"$checkout/feature.txt"
git -C "$checkout" add feature.txt
git -C "$checkout" commit -m "local feature work" >/dev/null

printf '%s\n' "new release content" >"$seed/README.md"
git -C "$seed" add README.md
git -C "$seed" commit -m "release update" >/dev/null
git -C "$seed" push origin HEAD:main >/dev/null 2>&1

output=$(
  HOME="$home_dir" \
  RYOKU_PATH="$checkout" \
  RYOKU_STATE_PATH="$temp_dir/state" \
  RYOKU_UPDATE_REMOTE_URL="$remote" \
  PATH="$bin_dir:$ROOT_DIR/bin:$PATH" \
  "$ROOT_DIR/bin/ryoku-update-git" 2>&1
) || fail "ryoku-update-git should update from main even when the checkout is on a stale feature branch: $output"

[[ $(git -C "$checkout" rev-parse HEAD) == "$(git -C "$seed" rev-parse HEAD)" ]] || \
  fail "checkout should fast-forward to origin/main, not the stale feature branch"

[[ $(git -C "$checkout" branch --show-current) == "main" ]] || \
  fail "checkout should switch to the release branch before fast-forwarding"

grep -qx 'new release content' "$checkout/README.md" || \
  fail "updated file should come from origin/main"

echo "PASS: ryoku-update-git follows release branch"
