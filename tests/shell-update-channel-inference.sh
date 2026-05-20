#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
SHELL_UPDATES_QML="$ROOT_DIR/shell/services/ShellUpdates.qml"
OVERLAY_QML="$ROOT_DIR/shell/modules/shellUpdate/ShellUpdateOverlay.qml"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

[[ -f $SHELL_UPDATES_QML ]] || fail "missing ShellUpdates.qml"
[[ -f $OVERLAY_QML ]] || fail "missing ShellUpdateOverlay.qml"

rg -q 'property string currentBranch: ""' "$SHELL_UPDATES_QML" || \
  fail "ShellUpdates should not default the actual branch to main before git reports it"

rg -q 'readonly property string explicitConfiguredChannel' "$SHELL_UPDATES_QML" || \
  fail "ShellUpdates should distinguish explicit config from inferred current branch"

rg -q 'currentBranch === "unstable-dev" \? "unstable-dev"' "$SHELL_UPDATES_QML" || \
  fail "Missing shellUpdates.channel should infer unstable-dev from the checked-out branch"

rg -q '_fetchAfterCurrentBranch = true' "$SHELL_UPDATES_QML" || \
  fail "Update checks should read the current branch before fetching a default channel"

rg -q 'currentBranchProc\.running = true' "$SHELL_UPDATES_QML" || \
  fail "Update checks should run currentBranchProc before fetching"

rg -q 'implicitHeight: ShellUpdates\.requiresChannelSwitch \? 30 : 36' "$OVERLAY_QML" || \
  fail "Channel switch button should be slimmer than the normal update button"

rg -q 'Translation\.tr\("Switch"\)' "$OVERLAY_QML" || \
  fail "Channel switch button should use a compact label"

echo "PASS: shell update channel infers current branch and uses compact switch button"
