#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
LAUNCHER="$ROOT_DIR/shell/scripts/ryoku-shell"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

[[ -f $LAUNCHER ]] || fail "missing shell launcher"
bash -n "$LAUNCHER" || fail "ryoku-shell launcher has a syntax error"

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

runtime_dir="$tmp_dir/runtime"
mkdir -p "$runtime_dir" "$tmp_dir/home"
touch "$runtime_dir/shell.qml"

cat >"$tmp_dir/qs" <<'SH'
#!/bin/bash
{
  printf 'args='
  printf '<%s>' "$@"
  printf '\n'
  printf 'RYOKU_SHELL_LIB_DIR=%s\n' "${RYOKU_SHELL_LIB_DIR:-}"
  printf 'QML_IMPORT_PATH=%s\n' "${QML_IMPORT_PATH:-}"
  printf 'QML2_IMPORT_PATH=%s\n' "${QML2_IMPORT_PATH:-}"
  printf 'QT_QPA_PLATFORM=%s\n' "${QT_QPA_PLATFORM:-}"
  printf 'QS_CONFIG_NAME_SET=%s\n' "${QS_CONFIG_NAME+yes}"
  printf 'QS_CONFIG_PATH_SET=%s\n' "${QS_CONFIG_PATH+yes}"
  printf 'QS_MANIFEST_SET=%s\n' "${QS_MANIFEST+yes}"
} >"$RYOKU_TEST_CAPTURE"
SH
chmod +x "$tmp_dir/qs"

RYOKU_TEST_CAPTURE="$tmp_dir/capture" \
HOME="$tmp_dir/home" \
PATH="/usr/bin" \
RYOKU_QS_BIN="$tmp_dir/qs" \
RYOKU_SHELL_RUNTIME_DIR="$runtime_dir" \
RYOKU_SHELL_LIB_DIR="$tmp_dir/lib" \
RYOKU_SHELL_QML_DIR="$tmp_dir/qml" \
QML_IMPORT_PATH="/existing/qml" \
QML2_IMPORT_PATH="/existing/qml2" \
QT_QPA_PLATFORM="" \
  "$LAUNCHER" run --session --debug

grep -Fxq "args=<-p><$runtime_dir><--debug>" "$tmp_dir/capture" || \
  fail "launcher should start qs against the explicit runtime path"
grep -Fxq "RYOKU_SHELL_LIB_DIR=$tmp_dir/lib" "$tmp_dir/capture" || \
  fail "launcher should export the shell library path"
grep -Fxq "QML_IMPORT_PATH=$tmp_dir/qml:/existing/qml" "$tmp_dir/capture" || \
  fail "launcher should prepend the shell QML import path"
grep -Fxq "QML2_IMPORT_PATH=$tmp_dir/qml:/existing/qml2" "$tmp_dir/capture" || \
  fail "launcher should prepend the legacy QML import path"
grep -Fxq "QT_QPA_PLATFORM=wayland;xcb" "$tmp_dir/capture" || \
  fail "launcher should default to Wayland with xcb fallback"
grep -Fxq "QS_CONFIG_NAME_SET=" "$tmp_dir/capture" || \
  fail "launcher should clear inherited qs config names"
grep -Fxq "QS_CONFIG_PATH_SET=" "$tmp_dir/capture" || \
  fail "launcher should clear inherited qs config paths"
grep -Fxq "QS_MANIFEST_SET=" "$tmp_dir/capture" || \
  fail "launcher should clear inherited qs manifests"

echo "PASS: ryoku-shell launch environment is scoped to the rebirth runtime"
