#!/bin/bash

# Static asserts for the Network Monitor sidebar tab. Mirrors the style
# of tests/sidebar-openvpn.sh, tests/sidebar-tailscale.sh, and
# tests/sidebar-hosts.sh. Spec:
# docs/superpowers/specs/2026-05-08-network-monitor-tab-design.md.

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

# 1. Helper script: emits one JSON blob with addrs/routes/links/nmcli/wifi/dns.
assert_executable "bin/ryoku-netmon-collect"
assert_contains   "bin/ryoku-netmon-collect" "ip -j addr show"
assert_contains   "bin/ryoku-netmon-collect" "ip -j route show default"
assert_contains   "bin/ryoku-netmon-collect" "ip -j -s link show"
assert_contains   "bin/ryoku-netmon-collect" "nmcli"
assert_contains   "bin/ryoku-netmon-collect" "resolvectl"
assert_contains   "bin/ryoku-netmon-collect" "addrs"
assert_contains   "bin/ryoku-netmon-collect" "wifi"

echo "ok: sidebar-netmon static asserts"
