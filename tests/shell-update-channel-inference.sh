#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
SHELL_UPDATES_QML="$ROOT_DIR/shell/services/ShellUpdates.qml"
OVERLAY_QML="$ROOT_DIR/shell/modules/shellUpdate/ShellUpdateOverlay.qml"
CONFIG_QML="$ROOT_DIR/shell/modules/common/Config.qml"
IPC_REGISTRY="$ROOT_DIR/shell/scripts/lib/ipc-registry.sh"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

[[ -f $SHELL_UPDATES_QML ]] || fail "missing ShellUpdates.qml"
[[ -f $OVERLAY_QML ]] || fail "missing ShellUpdateOverlay.qml"
[[ -f $CONFIG_QML ]] || fail "missing Config.qml"
[[ -f $IPC_REGISTRY ]] || fail "missing IPC registry"

rg -q 'property string currentBranch: ""' "$SHELL_UPDATES_QML" || \
  fail "ShellUpdates should not default the actual branch to main before git reports it"

rg -q 'readonly property string explicitConfiguredChannel' "$SHELL_UPDATES_QML" || \
  fail "ShellUpdates should distinguish explicit config from inferred current branch"

rg -q 'currentBranch === "unstable-dev" \? "unstable-dev"' "$SHELL_UPDATES_QML" || \
  fail "Missing shellUpdates.channel should infer unstable-dev from the checked-out branch"

! rg -q 'currentBranchChannel\.length > 0 \? currentBranchChannel : "main"' "$SHELL_UPDATES_QML" || \
  fail "ShellUpdates should not show Stable before config or branch detection completes"

rg -q 'readonly property bool channelKnown: configuredChannel\.length > 0' "$SHELL_UPDATES_QML" || \
  fail "ShellUpdates should expose whether the update channel is known"

rg -q 'property string channel: ""' "$CONFIG_QML" || \
  fail "Config should declare shellUpdates.channel so channel changes are reactive"

rg -q 'interval: 0  // no delay' "$SHELL_UPDATES_QML" || \
  fail "ShellUpdates should detect branch immediately instead of showing a false stable default"

rg -q '_fetchAfterCurrentBranch = true' "$SHELL_UPDATES_QML" || \
  fail "Update checks should read the current branch before fetching a default channel"

rg -q 'if \(!repoPathLoaded\)' "$SHELL_UPDATES_QML" || \
  fail "Update checks should wait for repo path discovery before running git commands"

rg -q 'function setChannel\(channel\)' "$SHELL_UPDATES_QML" || \
  fail "ShellUpdates should expose a channel setter for settings and IPC"

rg -q '\[shellUpdate\]="[^"]*setChannel' "$IPC_REGISTRY" || \
  fail "shellUpdate IPC should expose setChannel for standalone settings"

rg -q 'currentBranchProc\.running = true' "$SHELL_UPDATES_QML" || \
  fail "Update checks should run currentBranchProc before fetching"

rg -q 'implicitHeight: ShellUpdates\.requiresChannelSwitch \? 30 : 36' "$OVERLAY_QML" || \
  fail "Channel switch button should be slimmer than the normal update button"

rg -q 'Translation\.tr\("Switch"\)' "$OVERLAY_QML" || \
  fail "Channel switch button should use a compact label"

echo "PASS: shell update channel infers current branch and uses compact switch button"
