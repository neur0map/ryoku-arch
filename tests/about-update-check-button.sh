#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
ABOUT_QML="$ROOT_DIR/shell/modules/settings/About.qml"
WAFFLE_ABOUT_QML="$ROOT_DIR/shell/modules/waffle/settings/pages/WAboutPage.qml"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

[[ -f $ABOUT_QML ]] || fail "missing settings About.qml"
[[ -f $WAFFLE_ABOUT_QML ]] || fail "missing waffle settings WAboutPage.qml"

rg -q 'Check updates|Check for updates' "$ABOUT_QML" || \
  fail "About Ryoku card should expose a manual update check button"

rg -q 'ShellUpdates\.check\(\)' "$ABOUT_QML" || \
  fail "About update button should trigger the existing update checker"

rg -q 'shellUpdate.*check|shellUpdate", "check"' "$ABOUT_QML" || \
  fail "About update button should tell the main shell to check when settings runs separately"

rg -q 'ShellUpdates\.openOverlay\(\)' "$ABOUT_QML" || \
  fail "About update button should open the existing update overlay when possible"

rg -q 'ShellUpdates\.localVersion' "$ABOUT_QML" || \
  fail "About version badge should use the canonical local version"

! rg -q '0\.1\.0-pre-alpha' "$ABOUT_QML" || \
  fail "About version badge should not hardcode stale pre-alpha text"

rg -q 'shellUpdate.*open|shellUpdate", "open"' "$ABOUT_QML" || \
  fail "About update button should use shellUpdate IPC when settings runs separately"

rg -q 'visible: ShellUpdates\.hasUpdate' "$ABOUT_QML" || \
  fail "About update-available button should only appear after an update is detected"

! rg -q 'Check updates.*Update available|Update available.*Check updates' "$ABOUT_QML" || \
  fail "About manual check button should not turn into an update-available button"

rg -q 'Check updates|Check for updates' "$WAFFLE_ABOUT_QML" || \
  fail "Waffle About Ryoku card should expose a manual update check button"

rg -q 'ShellUpdates\.check\(\)' "$WAFFLE_ABOUT_QML" || \
  fail "Waffle About update button should trigger the existing update checker"

rg -q 'shellUpdate.*check|shellUpdate", "check"' "$WAFFLE_ABOUT_QML" || \
  fail "Waffle About update button should tell the main shell to check when settings runs separately"

rg -q 'ShellUpdates\.openOverlay\(\)' "$WAFFLE_ABOUT_QML" || \
  fail "Waffle About update button should open the existing update overlay when possible"

rg -q 'shellUpdate.*open|shellUpdate", "open"' "$WAFFLE_ABOUT_QML" || \
  fail "Waffle About update button should use shellUpdate IPC when settings runs separately"

rg -q 'visible: ShellUpdates\.hasUpdate' "$WAFFLE_ABOUT_QML" || \
  fail "Waffle About update-available button should only appear after an update is detected"

echo "PASS: About page exposes shell update check"
