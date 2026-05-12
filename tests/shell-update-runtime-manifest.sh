#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
SETUP="$ROOT_DIR/shell/setup"
SHELL_UPDATES_QML="$ROOT_DIR/shell/services/ShellUpdates.qml"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

[[ -f $SETUP ]] || fail "missing shell/setup"
[[ -f $SHELL_UPDATES_QML ]] || fail "missing ShellUpdates.qml"

rg -q 'sync_launcher_from_repo' "$SETUP" || \
  fail "setup should install or refresh the ryoku-shell launcher"

! rg -q 'cp -f "\$\{REPO_ROOT\}/scripts/ryoku-shell" "\$launcher_target"' "$SETUP" || \
  fail "setup should not use direct launcher cp that fails when source and destination are the same file"

rg -q 'realpath -se "\$launcher_src"' "$SETUP" || \
  fail "launcher sync should compare real paths before copying"

rg -q 'generate_manifest "\$II_SOURCE" "\$\{II_TARGET\}/\.ryoku-manifest"' "$SETUP" || \
  fail "setup update should regenerate the manifest path used by the shell"

! rg -q '\.ryoku-shell-manifest' "$SETUP" || \
  fail "setup update should not write a stale alternate shell manifest"

rg -q "manifest_v2='false'" "$SHELL_UPDATES_QML" || \
  fail "shell local-mod detection should detect v2 manifests"

rg -q '\[\[ \\"\$manifest_v2\\" != \\"true\\" && -d \\"\$repo/\.git\\" \]\]' "$SHELL_UPDATES_QML" || \
  fail "v2 manifest entries without checksums should not be compared against moving repo HEAD"

echo "PASS: shell update runtime manifest stays authoritative"
