#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

write_channel_config() {
  local channel=$1

  mkdir -p "$home_dir/.config/ryoku-shell"
  printf '{"shellUpdates":{"channel":"%s"}}\n' "$channel" >"$home_dir/.config/ryoku-shell/config.json"
}

temp_dir=$(mktemp -d)
trap 'rm -rf "$temp_dir"' EXIT

remote="$temp_dir/remote.git"
seed="$temp_dir/seed"
checkout="$temp_dir/checkout"
home_dir="$temp_dir/home"
state_dir="$temp_dir/state"
bin_dir="$temp_dir/bin"

mkdir -p "$home_dir" "$state_dir" "$bin_dir"
printf '#!/bin/bash\nexit 0\n' >"$bin_dir/ryoku-update-time"
chmod +x "$bin_dir/ryoku-update-time"

git init --bare "$remote" >/dev/null

git clone "$remote" "$seed" >/dev/null 2>&1
git -C "$seed" config user.email test@example.invalid
git -C "$seed" config user.name "Ryoku Test"
printf '%s\n' "stable base" >"$seed/README.md"
git -C "$seed" add README.md
git -C "$seed" commit -m "stable base" >/dev/null
git -C "$seed" push origin HEAD:main >/dev/null 2>&1

git -C "$seed" checkout -b unstable-dev >/dev/null 2>&1
printf '%s\n' "dev-only feature" >"$seed/dev-widget.txt"
git -C "$seed" add dev-widget.txt
git -C "$seed" commit -m "dev widget work" >/dev/null
git -C "$seed" push origin HEAD:unstable-dev >/dev/null 2>&1

git clone "$remote" "$checkout" >/dev/null 2>&1
git -C "$checkout" checkout main >/dev/null 2>&1

write_channel_config unstable-dev

output=$(
  HOME="$home_dir" \
  RYOKU_SHELL_CONFIG_DIR="$home_dir/.config/ryoku-shell" \
  RYOKU_PATH="$checkout" \
  RYOKU_STATE_PATH="$state_dir" \
  RYOKU_UPDATE_REMOTE_URL="$remote" \
  PATH="$bin_dir:$ROOT_DIR/bin:$PATH" \
  "$ROOT_DIR/bin/ryoku-update-git" 2>&1
) || fail "ryoku-update-git should follow the configured unstable-dev channel: $output"

[[ $(git -C "$checkout" branch --show-current) == "unstable-dev" ]] || \
  fail "checkout should switch to unstable-dev when shellUpdates.channel selects it"

grep -qx 'dev-only feature' "$checkout/dev-widget.txt" || \
  fail "dev channel update should bring files from origin/unstable-dev"

write_channel_config main

output=$(
  HOME="$home_dir" \
  RYOKU_SHELL_CONFIG_DIR="$home_dir/.config/ryoku-shell" \
  RYOKU_PATH="$checkout" \
  RYOKU_STATE_PATH="$state_dir" \
  RYOKU_UPDATE_REMOTE_URL="$remote" \
  PATH="$bin_dir:$ROOT_DIR/bin:$PATH" \
  "$ROOT_DIR/bin/ryoku-update-git" 2>&1
) || fail "ryoku-update-git should switch back to the configured main channel: $output"

[[ $(git -C "$checkout" branch --show-current) == "main" ]] || \
  fail "checkout should switch back to main when shellUpdates.channel selects it"

[[ ! -e $checkout/dev-widget.txt ]] || \
  fail "switching back to main should remove dev-only tracked files from the checkout"

grep -qx 'stable base' "$checkout/README.md" || \
  fail "stable channel update should restore files from origin/main"

echo "PASS: ryoku-update-git follows configured update channel"
