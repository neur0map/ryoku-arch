#!/bin/bash

# Static asserts for the SecPulse bar module. Mirrors the style of
# tests/sidebar-openvpn.sh. SecPulse is a focused OpenVPN-state
# indicator; see docs/superpowers/specs/2026-05-08-secpulse-ovpn-indicator-design.md.

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

assert_json_expr() {
  local path="$1"
  local jq_expr="$2"
  local message="$3"

  assert_file "$path"
  jq -e "$jq_expr" "$ROOT_DIR/$path" >/dev/null || fail "$message"
}

# 1. Module default lives in shell defaults so users get the toggle on a
#    fresh config and existing configs fall through to the runtime ?? true.
assert_json_expr  "shell/defaults/config.json" '.bar.modules.secPulse == true' \
  "shell defaults should set bar.modules.secPulse to true"

# 2. The OVPN service's bar-indicator gate reads the live module key,
#    not the deleted bar.secPulse.showOpenVpn schema.
assert_contains   "shell/services/RyokuOpenVpn.qml" \
  "Config.options?.bar?.modules?.secPulse ?? true"

echo "ok: bar-secpulse static asserts"
