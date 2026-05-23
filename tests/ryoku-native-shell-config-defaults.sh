#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_json_expr() {
  local path="$1"
  local jq_expr="$2"
  local message="$3"

  jq -e "$jq_expr" "$path" >/dev/null || fail "$message"
}

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

test_home="$tmp_dir/home"
config_dir="$test_home/.config/ryoku"
config_file="$config_dir/shell.json"

mkdir -p "$config_dir" "$tmp_dir/shell" "$tmp_dir/runtime"
cat >"$config_file" <<'JSON'
{
  "bar": {
    "status": {
      "showNetwork": false
    }
  },
  "dashboard": {
    "showPerformance": true
  }
}
JSON

assert_json_expr "$ROOT_DIR/default/ryoku-shell/shell.json" \
  '.appearance.spacing.scale and .background.visualiser.enabled == true and .dashboard.showWeather == true' \
  "Ryoku native shell defaults should carry local shell settings"

HOME="$test_home" \
XDG_CONFIG_HOME="$test_home/.config" \
RYOKU_CONFIG_PATH="$config_dir" \
RYOKU_PATH="$ROOT_DIR" \
RYOKU_SHELL_PATH="$tmp_dir/shell" \
RYOKU_SHELL_RUNTIME_PATH="$tmp_dir/runtime" \
PATH="$ROOT_DIR/bin:$PATH" \
  bash "$ROOT_DIR/install/config/ryoku-shell-branding.sh" >/dev/null

assert_json_expr "$config_file" \
  '.bar.status.showNetwork == false and .dashboard.showPerformance == true' \
  "Native shell defaults should preserve explicit local user settings"

assert_json_expr "$config_file" \
  '.appearance.font.family.sans == "DejaVu Sans" and .background.visualiser.enabled == true and .services.showLyrics == true' \
  "Native shell defaults should add missing Ryoku-owned settings"

echo "PASS: ryoku native shell config defaults"
