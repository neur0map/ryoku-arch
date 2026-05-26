#!/bin/bash
set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

export RYOKU_PATH="$ROOT_DIR"
export RYOKU_CONFIG_PATH="$tmp_dir/config"
export RYOKU_SHELL_PROFILES_DIR="$tmp_dir/profiles"
export RYOKU_SHELL_RUNTIME_DIR="$tmp_dir/runtime"
export XDG_STATE_HOME="$tmp_dir/state"
export PATH="$ROOT_DIR/bin:$PATH"

mkdir -p "$RYOKU_CONFIG_PATH" "$XDG_STATE_HOME/ryoku-shell"
printf '{"bar":{"persistent":true}}\n' >"$RYOKU_CONFIG_PATH/shell.json"
printf '{"appearance":{"rounding":{"normal":17}}}\n' >"$RYOKU_CONFIG_PATH/shell-tokens.json"
printf 'ryoku\n' >"$XDG_STATE_HOME/ryoku-shell/scheme.name"
printf 'forest\n' >"$XDG_STATE_HOME/ryoku-shell/scheme.flavour"
printf 'vibrant\n' >"$XDG_STATE_HOME/ryoku-shell/scheme.variant"
printf 'dark\n' >"$XDG_STATE_HOME/ryoku-shell/scheme.mode"

profile_id=$("$ROOT_DIR/bin/ryoku-shell-profile" save "Test Profile")
[[ $profile_id == "test-profile" ]] || fail "profile id should be slugified"
[[ -f $RYOKU_SHELL_PROFILES_DIR/test-profile/shell.json ]] || fail "profile should copy shell config"
[[ -f $RYOKU_SHELL_PROFILES_DIR/test-profile/shell-tokens.json ]] || fail "profile should copy shell tokens"
[[ $(<"$RYOKU_SHELL_PROFILES_DIR/test-profile/scheme/flavour") == "forest" ]] || fail "profile should copy scheme flavour"

list_json=$("$ROOT_DIR/bin/ryoku-shell-profile" list --json)
[[ $list_json == *'"id":"test-profile"'* ]] || fail "profile list should include saved profile"
[[ $list_json == *'"active":true'* ]] || fail "profile list should mark matching shell config active"

printf '{"bar":{"persistent":false}}\n' >"$RYOKU_CONFIG_PATH/shell.json"
printf 'ocean\n' >"$XDG_STATE_HOME/ryoku-shell/scheme.flavour"

"$ROOT_DIR/bin/ryoku-shell-profile" apply test-profile
[[ $(<"$RYOKU_CONFIG_PATH/shell.json") == '{"bar":{"persistent":true}}' ]] || fail "profile apply should restore shell config"
[[ $(<"$XDG_STATE_HOME/ryoku-shell/scheme.flavour") == "forest" ]] || fail "profile apply should restore scheme state"

"$ROOT_DIR/bin/ryoku-shell-profile" delete test-profile
[[ ! -e $RYOKU_SHELL_PROFILES_DIR/test-profile ]] || fail "profile delete should remove saved profile"

echo "PASS: ryoku shell profiles"
