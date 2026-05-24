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

assert_update_result() {
  local output=$1
  local path=$2
  local channel=$3

  grep -Fq 'Ryoku update result:' <<<"$output" || \
    fail "update should print a post-update provenance summary"
  grep -Fq "Path: $path" <<<"$output" || \
    fail "update provenance should show the installed checkout path"
  grep -Fq "Channel: $channel" <<<"$output" || \
    fail "update provenance should show the selected channel"
  grep -Fq "Expected doctor: $path/bin/ryoku-doctor" <<<"$output" || \
    fail "update provenance should show the expected installed doctor path"
  grep -Fq 'Active doctor:' <<<"$output" || \
    fail "update provenance should show which doctor command PATH resolves"
  grep -Fq 'Runtime bridge:' <<<"$output" || \
    fail "update provenance should show the local runtime-env bridge state"
  [[ -r $state_dir/last-update ]] || \
    fail "update should persist last-update provenance for doctor/status"
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

printf '%s\n' "unstable-dev" >"$state_dir/channel"
rm -rf "$home_dir/.config/ryoku-shell"

output=$(
  HOME="$home_dir" \
  RYOKU_SHELL_CONFIG_DIR="$home_dir/.config/ryoku-shell" \
  RYOKU_PATH="$checkout" \
  RYOKU_STATE_PATH="$state_dir" \
  RYOKU_UPDATE_REMOTE_URL="$remote" \
  PATH="$bin_dir:$ROOT_DIR/bin:$PATH" \
  "$ROOT_DIR/bin/ryoku-update-git" 2>&1
) || fail "ryoku-update-git should follow the persisted unstable-dev channel state: $output"
assert_update_result "$output" "$checkout" "unstable-dev"

[[ $(git -C "$checkout" branch --show-current) == "unstable-dev" ]] || \
  fail "checkout should switch to unstable-dev when state channel selects it"

grep -qx 'dev-only feature' "$checkout/dev-widget.txt" || \
  fail "state channel update should bring files from origin/unstable-dev"

printf '%s\n' "main" >"$state_dir/channel"

output=$(
  HOME="$home_dir" \
  RYOKU_SHELL_CONFIG_DIR="$home_dir/.config/ryoku-shell" \
  RYOKU_PATH="$checkout" \
  RYOKU_STATE_PATH="$state_dir" \
  RYOKU_UPDATE_REMOTE_URL="$remote" \
  PATH="$bin_dir:$ROOT_DIR/bin:$PATH" \
  "$ROOT_DIR/bin/ryoku-update-git" 2>&1
) || fail "ryoku-update-git should switch back to main from persisted channel state: $output"

[[ $(git -C "$checkout" branch --show-current) == "main" ]] || \
  fail "checkout should switch back to main when state channel selects it"

[[ ! -e $checkout/dev-widget.txt ]] || \
  fail "state channel main update should remove dev-only tracked files"

rm -f "$state_dir/channel"
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

diverged_remote="$temp_dir/diverged-remote.git"
diverged_seed="$temp_dir/diverged-seed"
diverged_checkout="$temp_dir/diverged-checkout"
diverged_state="$temp_dir/diverged-state"

mkdir -p "$diverged_state"
git init --bare "$diverged_remote" >/dev/null
git clone "$diverged_remote" "$diverged_seed" >/dev/null 2>&1
git -C "$diverged_seed" config user.email test@example.invalid
git -C "$diverged_seed" config user.name "Ryoku Test"
printf '%s\n' "common base" >"$diverged_seed/README.md"
git -C "$diverged_seed" add README.md
git -C "$diverged_seed" commit -m "common base" >/dev/null
git -C "$diverged_seed" push origin HEAD:main >/dev/null 2>&1
git -C "$diverged_seed" checkout -b unstable-dev >/dev/null 2>&1
printf '%s\n' "dev branch content" >"$diverged_seed/dev-only.txt"
git -C "$diverged_seed" add dev-only.txt
git -C "$diverged_seed" commit -m "dev branch content" >/dev/null
git -C "$diverged_seed" push origin HEAD:unstable-dev >/dev/null 2>&1
git -C "$diverged_seed" checkout main >/dev/null 2>&1
printf '%s\n' "main branch content" >"$diverged_seed/main-only.txt"
git -C "$diverged_seed" add main-only.txt
git -C "$diverged_seed" commit -m "main branch content" >/dev/null
git -C "$diverged_seed" push origin HEAD:main >/dev/null 2>&1

git clone "$diverged_remote" "$diverged_checkout" >/dev/null 2>&1
git -C "$diverged_checkout" checkout main >/dev/null 2>&1
git -C "$diverged_checkout" branch unstable-dev origin/main
git -C "$diverged_checkout" branch --set-upstream-to origin/unstable-dev unstable-dev >/dev/null
printf '%s\n' "unstable-dev" >"$diverged_state/channel"

output=$(
  HOME="$home_dir" \
  RYOKU_SHELL_CONFIG_DIR="$home_dir/.config/ryoku-shell" \
  RYOKU_PATH="$diverged_checkout" \
  RYOKU_STATE_PATH="$diverged_state" \
  RYOKU_UPDATE_REMOTE_URL="$diverged_remote" \
  PATH="$bin_dir:$ROOT_DIR/bin:$PATH" \
  "$ROOT_DIR/bin/ryoku-update-git" 2>&1
) || fail "ryoku-update-git should realign a stale official unstable-dev branch: $output"

[[ $(git -C "$diverged_checkout" branch --show-current) == "unstable-dev" ]] || \
  fail "checkout should stay on the selected unstable-dev channel after realignment"

[[ $(git -C "$diverged_checkout" rev-parse HEAD) == "$(git -C "$diverged_seed" rev-parse unstable-dev)" ]] || \
  fail "stale unstable-dev branch should be realigned to origin/unstable-dev"

grep -qx 'dev branch content' "$diverged_checkout/dev-only.txt" || \
  fail "realigned unstable-dev checkout should contain dev branch content"

[[ ! -e $diverged_checkout/main-only.txt ]] || \
  fail "realigned unstable-dev checkout should not keep main-only tracked content"

rewritten_remote="$temp_dir/rewritten-remote.git"
rewritten_seed="$temp_dir/rewritten-seed"
rewritten_checkout="$temp_dir/rewritten-checkout"
rewritten_state="$temp_dir/rewritten-state"

mkdir -p "$rewritten_state"
git init --bare "$rewritten_remote" >/dev/null
git clone "$rewritten_remote" "$rewritten_seed" >/dev/null 2>&1
git -C "$rewritten_seed" config user.email test@example.invalid
git -C "$rewritten_seed" config user.name "Ryoku Test"
printf '%s\n' "base" >"$rewritten_seed/README.md"
git -C "$rewritten_seed" add README.md
git -C "$rewritten_seed" commit -m "base" >/dev/null
base_commit="$(git -C "$rewritten_seed" rev-parse HEAD)"
printf '%s\n' "old official content" >"$rewritten_seed/old-official.txt"
git -C "$rewritten_seed" add old-official.txt
git -C "$rewritten_seed" commit -m "old official branch tip" >/dev/null
git -C "$rewritten_seed" push origin HEAD:main >/dev/null 2>&1

git clone "$rewritten_remote" "$rewritten_checkout" >/dev/null 2>&1
git -C "$rewritten_checkout" checkout main >/dev/null 2>&1
printf '%s\n' "old official refresh" >"$rewritten_seed/old-official-refresh.txt"
git -C "$rewritten_seed" add old-official-refresh.txt
git -C "$rewritten_seed" commit -m "old official refresh" >/dev/null
git -C "$rewritten_seed" push origin HEAD:main >/dev/null 2>&1
git -C "$rewritten_checkout" fetch origin "+refs/heads/main:refs/remotes/origin/main" >/dev/null 2>&1
git -C "$rewritten_checkout" branch unstable-dev origin/main
git -C "$rewritten_checkout" branch --set-upstream-to origin/unstable-dev unstable-dev >/dev/null 2>&1 || true

git -C "$rewritten_seed" reset --hard "$base_commit" >/dev/null
printf '%s\n' "rewritten main content" >"$rewritten_seed/main-rewritten.txt"
git -C "$rewritten_seed" add main-rewritten.txt
git -C "$rewritten_seed" commit -m "rewritten main branch" >/dev/null
git -C "$rewritten_seed" push --force origin HEAD:main >/dev/null 2>&1
git -C "$rewritten_seed" reset --hard "$base_commit" >/dev/null
git -C "$rewritten_seed" checkout -B unstable-dev >/dev/null 2>&1
printf '%s\n' "rewritten dev content" >"$rewritten_seed/dev-rewritten.txt"
git -C "$rewritten_seed" add dev-rewritten.txt
git -C "$rewritten_seed" commit -m "rewritten dev branch" >/dev/null
git -C "$rewritten_seed" push --force origin HEAD:unstable-dev >/dev/null 2>&1

git -C "$rewritten_checkout" switch -q unstable-dev
printf '%s\n' "unstable-dev" >"$rewritten_state/channel"

output=$(
  HOME="$home_dir" \
  RYOKU_SHELL_CONFIG_DIR="$home_dir/.config/ryoku-shell" \
  RYOKU_PATH="$rewritten_checkout" \
  RYOKU_STATE_PATH="$rewritten_state" \
  RYOKU_UPDATE_REMOTE_URL="$rewritten_remote" \
  PATH="$bin_dir:$ROOT_DIR/bin:$PATH" \
  "$ROOT_DIR/bin/ryoku-update-git" 2>&1
) || fail "ryoku-update-git should realign an old official branch tip after remote history moves: $output"

[[ $(git -C "$rewritten_checkout" branch --show-current) == "unstable-dev" ]] || \
  fail "rewritten checkout should stay on unstable-dev"

[[ $(git -C "$rewritten_checkout" rev-parse HEAD) == "$(git -C "$rewritten_seed" rev-parse unstable-dev)" ]] || \
  fail "old official branch tip should be realigned to rewritten origin/unstable-dev"

grep -qx 'rewritten dev content' "$rewritten_checkout/dev-rewritten.txt" || \
  fail "rewritten realignment should install the new unstable-dev content"

[[ ! -e $rewritten_checkout/old-official.txt ]] || \
  fail "rewritten realignment should remove old official tracked files"

echo "PASS: ryoku-update-git follows configured update channel"
