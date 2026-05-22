#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
SHELL_UPDATES_QML="$ROOT_DIR/shell/services/ShellUpdates.qml"
OVERLAY_QML="$ROOT_DIR/shell/modules/shellUpdate/ShellUpdateOverlay.qml"
SERVICES_QML="$ROOT_DIR/shell/modules/settings/ServicesConfig.qml"
ABOUT_QML="$ROOT_DIR/shell/modules/settings/About.qml"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

[[ -f $SHELL_UPDATES_QML ]] || fail "missing ShellUpdates.qml"
[[ -f $OVERLAY_QML ]] || fail "missing ShellUpdateOverlay.qml"
[[ -f $SERVICES_QML ]] || fail "missing ServicesConfig.qml"
[[ -f $ABOUT_QML ]] || fail "missing About.qml"

rg -q 'function performUpdate\(confirmChannelSwitch\)' "$SHELL_UPDATES_QML" || \
  fail "ShellUpdates.performUpdate should require an explicit channel-switch confirmation argument"

rg -q 'requiresChannelSwitch && !confirmedChannelSwitch' "$SHELL_UPDATES_QML" || \
  fail "ShellUpdates.performUpdate should refuse unconfirmed branch switches"

rg -q 'mark_update_cancelled' "$SHELL_UPDATES_QML" || \
  fail "Shell update terminal command should mark cancelled terminal flows"

rg -q 'trap mark_update_cancelled EXIT INT TERM HUP' "$SHELL_UPDATES_QML" || \
  fail "Shell update terminal command should trap terminal exit/cancel signals"

rg -q 'Update cancelled or failed' "$SHELL_UPDATES_QML" || \
  fail "Shell update progress poller should report cancelled terminal flows immediately"

rg -q 'confirmingChannelSwitch' "$OVERLAY_QML" || \
  fail "Shell update overlay should keep a local channel-switch confirmation state"

rg -q 'ShellUpdates\.performUpdate\(true\)' "$OVERLAY_QML" || \
  fail "Shell update overlay should only pass confirmation after the explicit confirmation step"

rg -q 'Translation\.tr\("Confirm"\)' "$OVERLAY_QML" || \
  fail "Shell update overlay should use a compact confirmation label"

rg -q 'ShellUpdates\.requiresChannelSwitch \? ShellUpdates\.openOverlay\(\) : ShellUpdates\.performUpdate\(false\)' "$SERVICES_QML" || \
  fail "Services page should open details instead of directly launching an unconfirmed channel switch"

rg -q 'function openShellUpdateDetails' "$ABOUT_QML" || \
  fail "About page should keep a shared helper for opening update details"

rg -q 'onClicked: checkShellUpdates\(\)' "$ABOUT_QML" || \
  fail "About page check button should use the shared update check helper"

rg -q 'openShellUpdateDetails\(\)' "$ABOUT_QML" || \
  fail "About page should open details instead of directly launching an unconfirmed channel switch"

echo "PASS: shell update channel switch requires confirmation"
