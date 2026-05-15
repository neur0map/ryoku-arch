#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

if [[ ! -x /usr/bin/ufw ]]; then
  echo "skip: /usr/bin/ufw is not installed"
  exit 0
fi

mkdir -p "$TMP_DIR/bin" "$TMP_DIR/state"
cat >"$TMP_DIR/bin/pkexec" <<'PKEXEC'
#!/bin/bash
exit "${RYOKU_FAKE_PKEXEC_RC:-42}"
PKEXEC
chmod +x "$TMP_DIR/bin/pkexec"

PATH="$TMP_DIR/bin:$PATH" \
XDG_STATE_HOME="$TMP_DIR/state" \
RYOKU_FAKE_PKEXEC_RC=42 \
  "$ROOT_DIR/bin/ryoku-firewall" reload >/dev/null 2>&1 && fail "reload should fail"
rc=$?
(( rc == 42 )) || fail "reload should preserve pkexec rc 42, got $rc"
jq -e '.op == "reload" and .status == "error" and .error == "ufw failed (rc=42)"' \
  "$TMP_DIR/state/ryoku/firewall/last-op.json" >/dev/null || fail "reload failure should record rc 42"

PATH="$TMP_DIR/bin:$PATH" \
XDG_STATE_HOME="$TMP_DIR/state" \
RYOKU_FAKE_PKEXEC_RC=0 \
  "$ROOT_DIR/bin/ryoku-firewall" reload >/dev/null 2>&1 || fail "reload should succeed"
jq -e '.op == "reload" and .status == "ok" and .error == ""' \
  "$TMP_DIR/state/ryoku/firewall/last-op.json" >/dev/null || fail "reload success should record ok"

PATH="$TMP_DIR/bin:$PATH" \
XDG_STATE_HOME="$TMP_DIR/state" \
RYOKU_FAKE_PKEXEC_RC=42 \
  "$ROOT_DIR/bin/ryoku-firewall" restore-defaults >/dev/null 2>&1 && fail "restore-defaults should fail"
rc=$?
(( rc == 42 )) || fail "restore-defaults should preserve pkexec rc 42, got $rc"
jq -e '.op == "restore-defaults" and .status == "error" and .error == "restore defaults failed (rc=42)"' \
  "$TMP_DIR/state/ryoku/firewall/last-op.json" >/dev/null || fail "restore-defaults failure should record rc 42"

echo "ok: firewall helper rc handling"
