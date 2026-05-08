#!/bin/bash

# Static asserts for the Tailscale + Trayscale integration. Mirrors the
# style of tests/sidebar-openvpn.sh and tests/bar-secpulse.sh. Spec:
# docs/superpowers/specs/2026-05-08-tailscale-trayscale-integration-design.md.

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

# 1. Service singleton + qmldir registration.
assert_file       "shell/services/RyokuTailscale.qml"
assert_contains   "shell/services/qmldir" "singleton RyokuTailscale 1.0 RyokuTailscale.qml"
assert_contains   "shell/services/RyokuTailscale.qml" "tailscale status --json"
assert_contains   "shell/services/RyokuTailscale.qml" "BackendState"
assert_contains   "shell/services/RyokuTailscale.qml" "Self?.HostName"
assert_contains   "shell/services/RyokuTailscale.qml" "function openTrayscale"
assert_matches    "shell/services/RyokuTailscale.qml" 'property bool tabOpen'

# 1b. AUR package list ships trayscale so fresh installs have the GUI
#     the openTrayscale() action launches.
assert_matches    "install/ryoku-aur.packages" '^trayscale$'

echo "ok: sidebar-tailscale static asserts"
