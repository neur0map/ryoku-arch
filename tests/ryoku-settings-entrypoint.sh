#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail() { echo "FAIL: $1" >&2; exit 1; }
[[ -f shell/settings.qml ]] || fail "kept iNiR-derived settings.qml must exist"
[[ ! -f shell/ryokuSettings.qml ]] || fail "deleted Ryoku settings remake should not exist"
[[ ! -f shell/modules/settings/SettingsOverlay.qml ]] || fail "deleted SettingsOverlay remake should not exist"
grep -q 'title: "illogical-impulse Settings"' shell/settings.qml \
  || fail "kept settings app should be the iNiR-derived settings.qml"
grep -q 'settingsUi\.easyMode' shell/settings.qml \
  || fail "kept settings app should retain easy mode"
grep -q 'StandardKey\.Find' shell/settings.qml \
  || fail "kept settings app should retain Ctrl+F search"
echo "PASS: kept settings app entrypoint"
