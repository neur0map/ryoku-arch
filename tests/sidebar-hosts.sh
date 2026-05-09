#!/bin/bash

# Static asserts for the Hosts sidebar tab. Mirrors the style of
# tests/sidebar-openvpn.sh and tests/sidebar-tailscale.sh. Spec:
# docs/superpowers/specs/2026-05-08-hosts-sidebar-tab-design.md.

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_file() {
  local path="$1"
  [[ -f $ROOT_DIR/$path ]] || fail "$path should exist"
}

assert_executable() {
  local path="$1"
  assert_file "$path"
  [[ -x $ROOT_DIR/$path ]] || fail "$path should be executable"
}

assert_contains() {
  local path="$1"
  local needle="$2"
  assert_file "$path"
  grep -qF "$needle" "$ROOT_DIR/$path" || fail "$path should contain: $needle"
}

assert_matches() {
  local path="$1"
  local re="$2"
  assert_file "$path"
  grep -qE "$re" "$ROOT_DIR/$path" || fail "$path should match regex: $re"
}

assert_json_expr() {
  local path="$1"
  local jq_expr="$2"
  local message="$3"

  assert_file "$path"
  jq -e "$jq_expr" "$ROOT_DIR/$path" >/dev/null || fail "$message"
}

# 1. Helper script: pkexec writer with add/remove subcommands and the
#    canonical state-file location.
assert_executable "bin/ryoku-hosts-edit"
assert_contains   "bin/ryoku-hosts-edit" "pkexec install -m 644"
assert_contains   "bin/ryoku-hosts-edit" '# >>> ryoku-hosts (managed) >>>'
assert_contains   "bin/ryoku-hosts-edit" '# <<< ryoku-hosts (managed) <<<'
assert_contains   "bin/ryoku-hosts-edit" '${XDG_STATE_HOME:-$HOME/.local/state}/ryoku/hosts'
assert_matches    "bin/ryoku-hosts-edit" '^[[:space:]]*case [^)]+ in$'
assert_contains   "bin/ryoku-hosts-edit" "ok-noop"
assert_contains   "bin/ryoku-hosts-edit" "is_v4"
assert_contains   "bin/ryoku-hosts-edit" "is_v6"
assert_contains   "bin/ryoku-hosts-edit" "is_domain"


# 2. Service singleton + qmldir registration. Service exposes add/remove
#    action methods, parses the managed block, and watches both
#    /etc/hosts and the helper's last-op.json status manifest.
assert_file       "shell/services/RyokuHosts.qml"
assert_contains   "shell/services/qmldir" "singleton RyokuHosts 1.0 RyokuHosts.qml"
assert_contains   "shell/services/RyokuHosts.qml" "function add"
assert_contains   "shell/services/RyokuHosts.qml" "function remove"
assert_contains   "shell/services/RyokuHosts.qml" 'Quickshell.execDetached(["ryoku-hosts-edit"'
assert_matches    "shell/services/RyokuHosts.qml" "ryoku-hosts.*managed"
assert_contains   "shell/services/RyokuHosts.qml" "/etc/hosts"
assert_matches    "shell/services/RyokuHosts.qml" 'property bool tabOpen'

echo "ok: sidebar-hosts static asserts"
