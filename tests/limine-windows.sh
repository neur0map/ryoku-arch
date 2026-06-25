#!/usr/bin/env bash
# Fixture test for ryoku-windows-entry: the idempotent, marker-fenced editing of
# limine.conf and the emitted chainload entry. The disk scan is short-circuited
# with RYOKU_WINDOWS_GUID, so this runs hermetically with no real partitions.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
tool="$here/../system/boot/limine/ryoku-windows-entry"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }

conf="$tmp/limine.conf"
cat >"$conf" <<'EOF'
timeout: 3
default_entry: 1

/Ryoku Linux
    protocol: efi
    path: boot():/EFI/Linux/ryoku.efi
EOF

# --- emit -----------------------------------------------------------------
out="$("$tool" emit AAAA-BBBB)"
grep -qF 'path: uuid(AAAA-BBBB):/EFI/Microsoft/Boot/bootmgfw.efi' <<<"$out" \
  || fail "emit did not produce a uuid()-addressed Windows path"
grep -qxF '/Windows' <<<"$out" || fail "emit missing the /Windows title"
grep -qF 'protocol: efi_chainload' <<<"$out" || fail "emit missing the chainload protocol"

# --- sync adds a managed block and keeps existing entries -----------------
RYOKU_WINDOWS_GUID="1111-2222" "$tool" sync "$conf" >/dev/null
grep -qF '/Ryoku Linux' "$conf" || fail "sync clobbered the existing kernel entry"
grep -qF 'path: uuid(1111-2222):/EFI/Microsoft/Boot/bootmgfw.efi' "$conf" \
  || fail "sync did not write the Windows entry"
[[ "$(grep -c '^/Windows$' "$conf")" == 1 ]] || fail "expected exactly one /Windows entry"
grep -qE '^# >>> ryoku-windows-entry' "$conf" || fail "missing managed begin fence"

# --- idempotent: a second run with the same GUID does not duplicate --------
RYOKU_WINDOWS_GUID="1111-2222" "$tool" sync "$conf" >/dev/null
[[ "$(grep -c '^/Windows$' "$conf")" == 1 ]] || fail "sync duplicated the Windows entry"

# --- update: a new GUID replaces the old one in place ---------------------
RYOKU_WINDOWS_GUID="3333-4444" "$tool" sync "$conf" >/dev/null
grep -qF 'uuid(3333-4444)' "$conf" || fail "sync did not update to the new GUID"
grep -qF 'uuid(1111-2222)' "$conf" && fail "sync left the stale GUID behind"
[[ "$(grep -c '^/Windows$' "$conf")" == 1 ]] || fail "update left more than one Windows entry"

# --- no Windows detected: an existing managed block is left untouched ------
cp "$conf" "$tmp/before.conf"
RYOKU_WINDOWS_GUID="" "$tool" sync "$conf" >/dev/null
diff -q "$tmp/before.conf" "$conf" >/dev/null || fail "sync changed conf when no Windows detected"

# --- no Windows detected on a clean conf: nothing is added ----------------
cat >"$tmp/clean.conf" <<'EOF'
timeout: 3
/Ryoku Linux
    protocol: efi
    path: boot():/EFI/Linux/ryoku.efi
EOF
RYOKU_WINDOWS_GUID="" "$tool" sync "$tmp/clean.conf" >/dev/null
grep -qF '/Windows' "$tmp/clean.conf" && fail "sync added a Windows entry when none detected"

echo "limine-windows: all checks passed"
