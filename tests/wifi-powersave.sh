#!/usr/bin/env bash
# Fixture test for ryoku-wifi-powersave: Game Mode's privileged WiFi helper. Stubs
# iw on PATH and points the sysfs scan and state file at a tmp dir, so no real
# radio is touched and no root is needed. Verifies device discovery, that `off`
# saves each device's prior power-save and disables it, that `on` restores the
# saved state (defaulting to enabled when none was saved), and that `status`
# reports the live state.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
helper="$here/../system/hardware/network/ryoku-wifi-powersave"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

bin="$tmp/bin"; mkdir -p "$bin"
iwps="$tmp/iwps"; mkdir -p "$iwps"      # per-device live power-save (on/off)
echo on >"$iwps/wlan0"
echo on >"$iwps/wlan1"

# Fake sysfs with two WiFi devices.
net="$tmp/net"
mkdir -p "$net/wlan0/wireless" "$net/wlan1/wireless" "$net/eth0"

# iw stub: get prints "Power save: <state>"; set writes the new state.
cat >"$bin/iw" <<EOF
#!/usr/bin/env bash
dev="\$2"
case "\$3" in
  get) echo "Power save: \$(cat "$iwps/\$dev" 2>/dev/null || echo on)" ;;
  set) echo "\$5" >"$iwps/\$dev" ;;
esac
exit 0
EOF
chmod +x "$bin/iw"

export PATH="$bin:$PATH"
export RYOKU_NET_SYSFS="$net"
export RYOKU_WIFI_PS_STATE="$tmp/prev"
state="$RYOKU_WIFI_PS_STATE"

fail() { echo "FAIL: $1" >&2; exit 1; }

# --- status reports both WiFi devices, not eth0 -----------------------------
out="$("$helper" status)"
grep -qx "wlan0 on" <<<"$out" || fail "status missing wlan0"
grep -qx "wlan1 on" <<<"$out" || fail "status missing wlan1"
grep -q "eth0" <<<"$out" && fail "status listed a non-WiFi device"

# --- off: saves prior state and disables power-save on every device ---------
"$helper" off
[[ $(cat "$iwps/wlan0") == off ]] || fail "off did not disable wlan0 power-save"
[[ $(cat "$iwps/wlan1") == off ]] || fail "off did not disable wlan1 power-save"
[[ -f $state ]] || fail "off did not save prior state"
grep -qx "wlan0 on" "$state" || fail "saved state missing wlan0=on"
grep -qx "wlan1 on" "$state" || fail "saved state missing wlan1=on"

# --- on: restores the saved state and clears the save file ------------------
"$helper" on
[[ $(cat "$iwps/wlan0") == on ]] || fail "on did not restore wlan0"
[[ $(cat "$iwps/wlan1") == on ]] || fail "on did not restore wlan1"
[[ -f $state ]] && fail "on did not clear the save file"

# --- non-destructive: a device that was already off is restored to off ------
echo off >"$iwps/wlan1"           # wlan1 power-save was already off
"$helper" off
[[ $(cat "$iwps/wlan1") == off ]] || fail "off changed an already-off device's target"
"$helper" on
[[ $(cat "$iwps/wlan1") == off ]] || fail "on wrongly enabled a device that was off before"
[[ $(cat "$iwps/wlan0") == on ]]  || fail "on did not restore wlan0 to its prior on"

# --- on with no saved state defaults to enabling power-save -----------------
rm -f "$state"
echo off >"$iwps/wlan0"
"$helper" on
[[ $(cat "$iwps/wlan0") == on ]] || fail "on without saved state did not default to enabled"

echo "wifi-powersave: all checks passed"
