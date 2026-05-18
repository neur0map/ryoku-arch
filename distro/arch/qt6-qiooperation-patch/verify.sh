#!/bin/bash
# Verify the qt6-qiooperation-patch is in place and active.
# Exits 0 on success, non-zero with a diagnostic on failure.

set -euo pipefail

readonly FIX_LIB="$HOME/.local/lib/qt6-fix/libQt6Core.so.6.11.0"
readonly DROPIN="$HOME/.config/systemd/user/ryoku-shell.service.d/qt6-qiooperation-patch.conf"
readonly NOP5_HEX="0f1f440000"
readonly OFFSETS=(0x32bf7a 0x32bfaa)

ok()   { printf '\033[32m✓\033[0m %s\n' "$*"; }
fail() { printf '\033[31m✗\033[0m %s\n' "$*" >&2; exit 1; }

[[ -f $FIX_LIB ]]   || fail "patched lib missing at $FIX_LIB; run apply.sh"
[[ -f $DROPIN ]]    || fail "systemd drop-in missing at $DROPIN; run apply.sh"

ok "patched lib exists"
ok "systemd drop-in exists"

# Check both call sites are NOPs
for off in "${OFFSETS[@]}"; do
    cur=$(python3 -c "import sys; f=open('$FIX_LIB','rb'); f.seek($off); sys.stdout.write(f.read(5).hex())")
    if [[ $cur == "$NOP5_HEX" ]]; then
        ok "byte-patch in place at $off"
    else
        fail "byte-patch missing at $off (got $cur, expected $NOP5_HEX)"
    fi
done

# Confirm running shell loaded our copy
pid=$(pgrep -f "/usr/bin/qs " | head -1 || true)
if [[ -z $pid ]]; then
    fail "no running qs process; start ryoku-shell.service first"
fi

mapped=$(awk '/libQt6Core/ {print $NF; exit}' /proc/"$pid"/maps 2>/dev/null || true)
if [[ $mapped == "$FIX_LIB" ]]; then
    ok "PID $pid has the patched libQt6Core mapped"
else
    fail "PID $pid is using $mapped (not $FIX_LIB)"
fi

# Confirm env wiring
if grep -q "LD_LIBRARY_PATH=$HOME/.local/lib/qt6-fix" /proc/"$pid"/environ 2>/dev/null; then
    ok "LD_LIBRARY_PATH points at the fix directory"
else
    fail "LD_LIBRARY_PATH not set on running process"
fi

printf '\nAll checks passed.\n'
