#!/bin/bash

# Static asserts for the SecPulse bar module. Mirrors the style of
# tests/sidebar-openvpn.sh. SecPulse is the combined OpenVPN + Tailscale
# bar indicator. See:
#   docs/superpowers/specs/2026-05-08-secpulse-ovpn-indicator-design.md
#   docs/superpowers/specs/2026-05-08-tailscale-trayscale-integration-design.md

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


# 3. The widget exists and binds to the existing RyokuOpenVpn surface.
assert_file       "shell/modules/bar/SecPulseIndicator.qml"
assert_contains   "shell/modules/bar/SecPulseIndicator.qml" "RyokuOpenVpn.activeProfile"
assert_contains   "shell/modules/bar/SecPulseIndicator.qml" "RyokuOpenVpn.transitioning"
assert_contains   "shell/modules/bar/SecPulseIndicator.qml" "GlobalStates.sidebarRightOpen = true"
assert_contains   "shell/modules/bar/SecPulseIndicator.qml" "vpn_key"
assert_contains   "shell/modules/bar/SecPulseIndicator.qml" "vpn_key_off"

# 4. BarContent instantiates SecPulseIndicator and gates it on the module key.
assert_contains   "shell/modules/bar/BarContent.qml" "SecPulseIndicator {"
assert_contains   "shell/modules/bar/BarContent.qml" "bar?.modules?.secPulse"

# 5. BarConfig exposes a SettingsSwitch bound to the new module key.
assert_contains   "shell/modules/settings/BarConfig.qml" "bar.modules.secPulse"
assert_contains   "shell/modules/settings/BarConfig.qml" 'Translation.tr("SecPulse")'


# 6. SecPulseIndicator now reads RyokuTailscale state and the tooltip
#    surfaces both OpenVPN and Tailscale status lines.
assert_contains   "shell/modules/bar/SecPulseIndicator.qml" "RyokuTailscale.connected"
assert_contains   "shell/modules/bar/SecPulseIndicator.qml" "RyokuTailscale.transitioning"
assert_contains   "shell/modules/bar/SecPulseIndicator.qml" "OpenVPN:"
assert_contains   "shell/modules/bar/SecPulseIndicator.qml" "Tailscale:"
assert_contains   "shell/modules/bar/SecPulseIndicator.qml" 'root._ovpnLine() + "\n" + root._tsLine()'

echo "ok: bar-secpulse static asserts"
