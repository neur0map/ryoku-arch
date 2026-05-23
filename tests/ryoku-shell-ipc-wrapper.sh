#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
SCRIPT="$ROOT_DIR/shell/scripts/ryoku-shell"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_contains() {
  local pattern="$1"
  local message="$2"

  grep -Eq "$pattern" "$SCRIPT" || fail "$message"
}

assert_literal() {
  local text="$1"
  local message="$2"

  grep -Fq "$text" "$SCRIPT" || fail "$message"
}

[[ -f $SCRIPT ]] || fail "ryoku-shell launcher missing"
[[ -x $SCRIPT ]] || fail "ryoku-shell launcher should be executable"
bash -n "$SCRIPT" || fail "ryoku-shell launcher has a syntax error"

assert_contains 'ipc_call drawers toggle launcher' \
  "launcher command should route through the drawers IPC target"
assert_contains 'ipc_call drawers toggle session' \
  "session command should route through the drawers IPC target"
assert_contains 'ipc_call drawers toggle dashboard' \
  "dashboard command should route through the drawers IPC target"
assert_contains 'ipc_call controlCenter toggle' \
  "settings command should toggle the control center"
! grep -Eq 'keybinds[|)]|ipc_call keybinds' "$SCRIPT" || \
  fail "ryoku-shell should not expose the removed keybind legend command"
assert_contains 'ipc call lock lock' \
  "lock command should route through the lock IPC target"
assert_contains 'lock_qylock_direct' \
  "lock command should fall back to qylock when shell IPC is unavailable"
assert_contains 'ipc_call picker openFreeze' \
  "screenshot command should route through the picker IPC target"
# shellcheck disable=SC2016
assert_literal '"$qs_bin" -p "$runtime_dir" ipc call "$@"' \
  "generic IPC wrapper should call qs against the rebirth runtime path"

! rg -q '\\.local/share/omarchy|ryoku_legacy_path|shell/scripts/lib/ipc-registry' "$SCRIPT" || \
  fail "ryoku-shell launcher should not fall back to old shell checkouts or generated registries"

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

runtime_dir="$tmp_dir/runtime"
mkdir -p "$runtime_dir" "$tmp_dir/xhome"
touch "$runtime_dir/shell.qml"

cat >"$tmp_dir/qs" <<'SH'
#!/bin/bash
if [[ ${RYOKU_TEST_QS_FAIL_LOCK:-0} == "1" && ${5:-} == "lock" && ${6:-} == "lock" ]]; then
  exit 1
fi

{
  printf '<%s>' "$@"
  printf '\n'
} >>"$RYOKU_TEST_CAPTURE"
SH
chmod +x "$tmp_dir/qs"

mkdir -p "$tmp_dir/xhome/.local/share/quickshell-lockscreen"
cat >"$tmp_dir/xhome/.local/share/quickshell-lockscreen/lock.sh" <<'SH'
#!/bin/bash
{
  printf '<qylock><%s><%s><%s>\n' \
    "${QS_CONFIG_NAME-unset}" \
    "${QS_CONFIG_PATH-unset}" \
    "${QS_MANIFEST-unset}"
} >>"$RYOKU_TEST_CAPTURE"
SH
chmod +x "$tmp_dir/xhome/.local/share/quickshell-lockscreen/lock.sh"

run_launcher() {
  RYOKU_TEST_CAPTURE="$tmp_dir/capture" \
  HOME="$tmp_dir/xhome" \
  PATH="/usr/bin" \
  RYOKU_QS_BIN="$tmp_dir/qs" \
  RYOKU_SHELL_RUNTIME_DIR="$runtime_dir" \
    "$SCRIPT" "$@"
}

run_launcher settings
run_launcher launcher
run_launcher session
run_launcher screenshot
run_launcher lock
run_launcher ipc controlCenter close

expected="$tmp_dir/expected"
{
  printf '<-p><%s><ipc><call><controlCenter><toggle>\n' "$runtime_dir"
  printf '<-p><%s><ipc><call><drawers><toggle><launcher>\n' "$runtime_dir"
  printf '<-p><%s><ipc><call><drawers><toggle><session>\n' "$runtime_dir"
  printf '<-p><%s><ipc><call><picker><openFreeze>\n' "$runtime_dir"
  printf '<-p><%s><ipc><call><lock><lock>\n' "$runtime_dir"
  printf '<-p><%s><ipc><call><controlCenter><close>\n' "$runtime_dir"
} >"$expected"

cmp -s "$expected" "$tmp_dir/capture" || {
  diff -u "$expected" "$tmp_dir/capture" >&2 || true
  fail "ryoku-shell IPC command mapping changed unexpectedly"
}

: >"$tmp_dir/capture"
RYOKU_TEST_QS_FAIL_LOCK=1 run_launcher lock
printf '<qylock><unset><unset><unset>\n' >"$expected"

cmp -s "$expected" "$tmp_dir/capture" || {
  diff -u "$expected" "$tmp_dir/capture" >&2 || true
  fail "ryoku-shell lock should fall back to qylock when IPC is unavailable"
}

echo "PASS: ryoku-shell IPC wrapper targets the rebirth shell"
