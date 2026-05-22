#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
ABOUT_QML="$ROOT_DIR/shell/modules/settings/About.qml"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

[[ -f $ABOUT_QML ]] || fail "missing settings About.qml"

rg -q 'Check updates|Check for updates' "$ABOUT_QML" || \
  fail "About Ryoku card should expose a manual update check button"

rg -q 'ShellUpdates\.check\(\)' "$ABOUT_QML" || \
  fail "About update button should trigger the existing update checker"

rg -q 'ShellUpdates\.openOverlay\(\)' "$ABOUT_QML" || \
  fail "About update button should open the existing update overlay when possible"

rg -q 'ShellUpdates\.localVersion' "$ABOUT_QML" || \
  fail "About version badge should use the canonical local version"

rg -q 'setShellUpdateChannel' "$ABOUT_QML" || \
  fail "About page should expose the shell update channel selector"

rg -q 'unstable-dev' "$ABOUT_QML" || \
  fail "About page should let users select the unstable-dev channel"

rg -q 'ShellUpdates\.configuredChannel' "$ABOUT_QML" || \
  fail "About page should show the configured update channel"

rg -q 'Current branch' "$ABOUT_QML" || \
  fail "About page should show the current checked-out branch separately from the selected channel"

rg -q 'Selected channel' "$ABOUT_QML" || \
  fail "About page should label the selected update channel as a target, not the active branch"

rg -q 'ShellUpdates\.requiresChannelSwitch && ShellUpdates\.selfUpdateSupported' "$ABOUT_QML" || \
  fail "About page should expose an explicit channel-switch action when the selected channel differs"

rg -q 'ShellUpdates\.channelKnown' "$ABOUT_QML" || \
  fail "About page should hide channel controls until the real channel is known"

rg -q 'Detecting channel' "$ABOUT_QML" || \
  fail "About page should show a pending channel state instead of a false stable default"

rg -q 'Translation\.tr\("Switch channel"\)' "$ABOUT_QML" || \
  fail "About page should show a switch-channel button for pending channel changes"

rg -q 'onClicked: openShellUpdateDetails\(\)' "$ABOUT_QML" || \
  fail "About channel-switch action should open the existing confirmation details"

rg -q 'ShellUpdates\.setChannel\(channel\)' "$ABOUT_QML" \
  || fail "About channel selector should update the local shell update service"

rg -q 'setShellUpdateChannel\(newValue\)' "$ABOUT_QML" \
  || fail "About channel selector should notify the shell update service after changing channel"

! rg -q '0\.1\.0-pre-alpha' "$ABOUT_QML" || \
  fail "About version badge should not hardcode stale pre-alpha text"

rg -q 'visible: ShellUpdates\.canApplyUpdate' "$ABOUT_QML" || \
  fail "About update-available button should appear when an update or channel switch can be applied"

! rg -q 'Check updates.*Update available|Update available.*Check updates' "$ABOUT_QML" || \
  fail "About manual check button should not turn into an update-available button"

! rg -q 'Layout\.preferredHeight: 320' "$ABOUT_QML" || \
  fail "About top row should not use a fixed height that clips the channel selector"

rg -q 'id: aboutTopRow' "$ABOUT_QML" || \
  fail "About top row should expose an id for content-driven sizing"

rg -q 'ryokuHeroColumn\.implicitHeight \+ 40' "$ABOUT_QML" || \
  fail "About Ryoku hero card height should account for its full contents"

rg -q 'systemInfoColumn\.implicitHeight \+ 40' "$ABOUT_QML" || \
  fail "About system info card height should account for its full contents"

echo "PASS: About page exposes shell update check"
