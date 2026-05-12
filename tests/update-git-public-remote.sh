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

printf '%s\n' "new upstream content" >"$seed/README.md"
git -C "$seed" add README.md
git -C "$seed" commit -m "update readme" >/dev/null
git -C "$seed" push origin HEAD:main >/dev/null 2>&1

git -C "$checkout" remote set-url origin "$temp_dir/stale-or-private-origin.git"
git -C "$checkout" config http.https://github.com/.extraheader "AUTHORIZATION: basic stale-token"

output=$(
  HOME="$home_dir" \
  RYOKU_PATH="$checkout" \
  RYOKU_STATE_PATH="$temp_dir/state" \
  RYOKU_UPDATE_REMOTE_URL="$remote" \
  PATH="$bin_dir:$ROOT_DIR/bin:$PATH" \
  "$ROOT_DIR/bin/ryoku-update-git" 2>&1
) || fail "ryoku-update-git should recover from a stale origin by using RYOKU_UPDATE_REMOTE_URL: $output"

[[ $(git -C "$checkout" remote get-url origin) == "$remote" ]] || \
  fail "origin should be normalized to the configured update remote"

[[ -z $(git -C "$checkout" config --get-regexp 'extraheader' 2>/dev/null || true) ]] || \
  fail "stale repo-local GitHub auth headers should be removed"

[[ $(git -C "$checkout" rev-parse HEAD) == "$(git -C "$seed" rev-parse HEAD)" ]] || \
  fail "checkout should fast-forward to the configured update remote"

grep -qx 'new upstream content' "$checkout/README.md" || \
  fail "updated file should come from the configured update remote"

echo "PASS: ryoku-update-git normalizes stale origins"
