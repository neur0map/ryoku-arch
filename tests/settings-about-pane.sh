#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local needle="$2"

  grep -qF -- "$needle" "$ROOT_DIR/$file" || fail "$file should contain: $needle"
}

assert_json_expr() {
  local json_file="$1"
  local jq_expr="$2"
  local message="$3"

  jq -e "$jq_expr" "$json_file" >/dev/null || fail "$message"
}

helper="$ROOT_DIR/shell/scripts/ryoku-settings-about"
[[ -x $helper ]] || fail "ryoku-settings-about helper should be executable"

assert_contains "shell/modules/controlcenter/PaneRegistry.qml" 'readonly property string id: "about"'
assert_contains "shell/modules/controlcenter/PaneRegistry.qml" 'readonly property string group: "about"'
assert_contains "shell/modules/controlcenter/Panes.qml" 'import "about"'
assert_contains "shell/modules/controlcenter/NavRail.qml" 'group: "about"'
assert_contains "shell/modules/controlcenter/about/AboutPane.qml" 'https://github.com/basecamp/omarchy'
assert_contains "shell/modules/controlcenter/about/AboutPane.qml" 'https://github.com/caelestia-dots/shell'
assert_contains "shell/modules/controlcenter/about/AboutPane.qml" 'https://github.com/BlueManCZ/hyprmod'
assert_contains "shell/modules/controlcenter/about/AboutPane.qml" 'https://github.com/Darkkal44/qylock'
assert_contains "shell/modules/controlcenter/about/AboutPane.qml" 'RyokuAbout.startUpdate'
assert_contains "shell/modules/controlcenter/about/AboutPane.qml" 'Update Ryoku'
assert_contains "shell/scripts/ryoku-settings-about" 'update-current-run'
assert_contains "shell/setup" '.ryoku-source-path'

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

repo="$tmp_dir/repo"
git init "$repo" >/dev/null
git -C "$repo" config user.email test@example.invalid
git -C "$repo" config user.name "Ryoku Test"
printf '0.1.0-test\n' >"$repo/VERSION"
git -C "$repo" add VERSION
git -C "$repo" commit -m "initial" >/dev/null
git -C "$repo" switch -q -c rebirth

status_json="$tmp_dir/status.json"
RYOKU_PATH="$repo" \
RYOKU_STATE_PATH="$tmp_dir/state" \
XDG_CONFIG_HOME="$tmp_dir/config" \
  "$helper" status >"$status_json"

assert_json_expr "$status_json" '.ok == true and (.version | startswith("0.1.0-test"))' \
  "status output should include Ryoku version"
assert_json_expr "$status_json" '.currentBranch == "rebirth" and .updateBranch == "rebirth"' \
  "status output should report the checkout branch as the update branch"
assert_json_expr "$status_json" '.configuredChannel == "main"' \
  "status output should default to main channel"
assert_json_expr "$status_json" '([.channels[].id] | index("main") and index("unstable-dev") and (index("rebirth") | not))' \
  "channel options should remain limited to main and unstable-dev"

echo "PASS: settings about pane"
