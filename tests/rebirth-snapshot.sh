#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
SNAPSHOT="$ROOT_DIR/bin/ryoku-rebirth-snapshot"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_file() {
  local path="$1"

  [[ -f $path ]] || fail "missing file: $path"
}

assert_contains() {
  local needle="$1"
  local path="$2"

  grep -Fq "$needle" "$path" || fail "missing '$needle' in $path"
}

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

export HOME="$tmp_dir/home"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_STATE_HOME="$HOME/.local/state"

mkdir -p \
  "$XDG_CONFIG_HOME/niri" \
  "$XDG_CONFIG_HOME/hypr" \
  "$XDG_CONFIG_HOME/systemd/user/niri.service.wants" \
  "$XDG_CONFIG_HOME/quickshell/ryoku-shell" \
  "$XDG_CONFIG_HOME/ryoku-shell" \
  "$XDG_STATE_HOME"

printf 'niri config\n' > "$XDG_CONFIG_HOME/niri/config.kdl"
printf 'hypridle config\n' > "$XDG_CONFIG_HOME/hypr/hypridle.conf"
printf 'hyprlock config\n' > "$XDG_CONFIG_HOME/hypr/hyprlock.conf"
printf 'service\n' > "$XDG_CONFIG_HOME/systemd/user/ryoku-shell.service"
printf 'wants link\n' > "$XDG_CONFIG_HOME/systemd/user/niri.service.wants/ryoku-shell.service"
printf 'shell\n' > "$XDG_CONFIG_HOME/quickshell/ryoku-shell/shell.qml"
printf '{}\n' > "$XDG_CONFIG_HOME/ryoku-shell/config.json"

set +e
dry_output=$("$SNAPSHOT" --dry-run 2>&1)
dry_status=$?
set -e

(( dry_status == 0 )) || fail "dry run should succeed: $dry_output"
grep -Fq "$XDG_STATE_HOME/ryoku/rebirth-snapshots" <<<"$dry_output" || \
  fail "dry run should print planned snapshot root"
[[ ! -d $XDG_STATE_HOME/ryoku/rebirth-snapshots ]] || \
  fail "dry run should not create snapshot directories"

output=$("$SNAPSHOT")
snapshot_dir=$(sed -n 's/^Snapshot: //p' <<<"$output" | tail -1)

[[ -n $snapshot_dir ]] || fail "snapshot command should print the snapshot path"
[[ -d $snapshot_dir ]] || fail "snapshot directory should exist"

manifest="$snapshot_dir/manifest.txt"
assert_file "$manifest"
assert_file "$snapshot_dir/config/niri/config.kdl"
assert_file "$snapshot_dir/config/hypr/hypridle.conf"
assert_file "$snapshot_dir/config/hypr/hyprlock.conf"
assert_file "$snapshot_dir/config/systemd/user/ryoku-shell.service"
assert_file "$snapshot_dir/config/systemd/user/niri.service.wants/ryoku-shell.service"
assert_file "$snapshot_dir/config/quickshell/ryoku-shell/shell.qml"
assert_file "$snapshot_dir/config/ryoku-shell/config.json"

assert_contains "branch=rebirth" "$manifest"
assert_contains "timestamp=" "$manifest"
assert_contains "home=$HOME" "$manifest"
assert_contains "xdg_config_home=$XDG_CONFIG_HOME" "$manifest"
assert_contains "xdg_state_home=$XDG_STATE_HOME" "$manifest"
assert_contains "copied=config/niri/config.kdl" "$manifest"
assert_contains "copied=config/hypr/hypridle.conf" "$manifest"
assert_contains "copied=config/hypr/hyprlock.conf" "$manifest"
assert_contains "copied=config/systemd/user/ryoku-shell.service" "$manifest"
assert_contains "copied=config/systemd/user/niri.service.wants/ryoku-shell.service" "$manifest"
assert_contains "copied=config/quickshell/ryoku-shell/shell.qml" "$manifest"
assert_contains "copied=config/ryoku-shell/config.json" "$manifest"

echo "PASS: rebirth snapshot archives live shell and compositor state"
