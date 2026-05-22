#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
SERVICES_QML="$ROOT_DIR/shell/modules/settings/ServicesConfig.qml"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

[[ -f $SERVICES_QML ]] || fail "missing ServicesConfig.qml"

rg -q 'function checkShellUpdates' "$SERVICES_QML" || \
  fail "Services page should route manual update checks through a helper"

rg -q 'ShellUpdates\.check\(\)' "$SERVICES_QML" || \
  fail "Services check button should refresh the resident shell update state"

rg -q 'onClicked: checkShellUpdates\(\)' "$SERVICES_QML" || \
  fail "Services Check Now button should use the shared update check helper"

echo "PASS: Services page update check reaches the resident shell"
