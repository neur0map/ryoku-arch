#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

mkdir -p "$tmp_dir/.local/share/ryoku/config/demo"
mkdir -p "$tmp_dir/.local/share/ryoku/default"
mkdir -p "$tmp_dir/.config/demo"

printf 'shipped setting\n' >"$tmp_dir/.local/share/ryoku/config/demo/settings.conf"
printf 'new shipped setting\n' >"$tmp_dir/.local/share/ryoku/config/demo/new.conf"
printf 'shipped bashrc\n' >"$tmp_dir/.local/share/ryoku/default/bashrc"

printf 'user setting\n' >"$tmp_dir/.config/demo/settings.conf"
printf 'user bashrc\n' >"$tmp_dir/.bashrc"

HOME="$tmp_dir" RYOKU_PATH="$tmp_dir/.local/share/ryoku" bash "$ROOT_DIR/install/config/config.sh"

[[ $(<"$tmp_dir/.config/demo/settings.conf") == "user setting" ]] \
  || fail "config install should not overwrite existing user config files"

[[ $(<"$tmp_dir/.config/demo/new.conf") == "new shipped setting" ]] \
  || fail "config install should still copy newly shipped default config files"

[[ $(<"$tmp_dir/.bashrc") == "user bashrc" ]] \
  || fail "config install should not overwrite an existing .bashrc"

printf 'PASS: tests/config-update-preserves-user-files.sh\n'
