#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
OVERLAY_QML="$ROOT_DIR/shell/modules/shellUpdate/ShellUpdateOverlay.qml"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

[[ -f $OVERLAY_QML ]] || fail "missing ShellUpdateOverlay.qml"

rg -q 'property bool changelogExpanded: false' "$OVERLAY_QML" || \
  fail "Shell update overlay should keep changelog collapsed by default"

rg -q 'changelogExpanded = false' "$OVERLAY_QML" || \
  fail "Shell update overlay should reset changelog expansion between opens"

rg -q 'onClicked: root\.changelogExpanded = !root\.changelogExpanded' "$OVERLAY_QML" || \
  fail "Shell update overlay should let users open and close the changelog"

rg -q 'visible: root\.changelogExpanded' "$OVERLAY_QML" || \
  fail "Shell update overlay should hide the changelog body until expanded"

! rg -q 'visible: root\.hasUpdate && changelogText\.text\.length > 0' "$OVERLAY_QML" || \
  fail "Shell update overlay should not render the changelog body just because an update exists"

echo "PASS: shell update changelog is collapsed by default"
