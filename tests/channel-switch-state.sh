#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

write_stub() {
  local path="$1"
  local body="$2"

  printf '%s\n' '#!/bin/bash' >"$path"
  printf '%s\n' "$body" >>"$path"
  chmod +x "$path"
}

assert_channel() {
  local state_file="$1"
  local expected="$2"

  [[ -f $state_file ]] || fail "missing channel state: $state_file"
  [[ $(<"$state_file") == "$expected" ]] || fail "expected channel $expected, got $(<"$state_file")"
}

temp_dir="$(mktemp -d)"
trap 'rm -rf "$temp_dir"' EXIT

fake_ryoku="$temp_dir/ryoku"
state_dir="$temp_dir/state"
config_dir="$temp_dir/config"
bin_dir="$fake_ryoku/bin"

mkdir -p "$bin_dir" "$state_dir" "$config_dir/ryoku-shell"
printf '%s\n' "main" >"$state_dir/channel"
printf '%s\n' '{"shellUpdates":{"channel":"main"}}' >"$config_dir/ryoku-shell/config.json"

write_stub "$bin_dir/ryoku-refresh-pacman" 'exit 1'
write_stub "$bin_dir/ryoku-update-branch" 'printf "%s\n" "unexpected update branch" >&2; exit 1'

if RYOKU_PATH="$fake_ryoku" RYOKU_STATE_PATH="$state_dir" RYOKU_SHELL_CONFIG_DIR= XDG_CONFIG_HOME="$config_dir" \
  "$ROOT_DIR/bin/ryoku-channel-set" unstable-dev >/dev/null 2>&1; then
  fail "channel set should fail when pacman refresh is cancelled"
fi

assert_channel "$state_dir/channel" "main"

write_stub "$bin_dir/ryoku-snapshot" 'exit 0'
write_stub "$bin_dir/ryoku-update-git" 'exit 0'
write_stub "$bin_dir/ryoku-update-perform" 'exit 1'
write_stub "$bin_dir/git" 'exit 0'

if RYOKU_PATH="$fake_ryoku" RYOKU_STATE_PATH="$state_dir" RYOKU_SHELL_CONFIG_DIR= XDG_CONFIG_HOME="$config_dir" \
  "$ROOT_DIR/bin/ryoku-update-branch" unstable-dev >/dev/null 2>&1; then
  fail "update branch should fail when update perform fails"
fi

assert_channel "$state_dir/channel" "main"
rg -q '"channel":"main"' "$config_dir/ryoku-shell/config.json" || \
  fail "shell config channel should remain main after failed switch"

write_stub "$bin_dir/ryoku-update-perform" 'exit 0'

RYOKU_PATH="$fake_ryoku" RYOKU_STATE_PATH="$state_dir" RYOKU_SHELL_CONFIG_DIR= XDG_CONFIG_HOME="$config_dir" \
  "$ROOT_DIR/bin/ryoku-update-branch" unstable-dev >/dev/null

assert_channel "$state_dir/channel" "unstable-dev"
rg -q '"channel": "unstable-dev"' "$config_dir/ryoku-shell/config.json" || \
  fail "shell config channel should update after successful switch"

echo "PASS: channel switch state is committed only after success"
