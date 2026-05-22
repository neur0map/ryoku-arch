#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail() { echo "FAIL: $1" >&2; exit 1; }
launcher="shell/scripts/ryoku-shell"
settings_qml="shell/settings.qml"
shell_entry="shell/shell.qml"
[[ -f "$settings_qml" ]] || fail "kept iNiR-derived settings.qml should exist"
[[ ! -f shell/ryokuSettings.qml ]] || fail "attempted Ryoku settings remake should be deleted"
[[ ! -f shell/modules/settings/SettingsOverlay.qml ]] || fail "attempted SettingsOverlay remake should be deleted"
! grep -q '^SettingsOverlay ' shell/modules/settings/qmldir \
  || fail "SettingsOverlay should not be exported"
# shellcheck disable=SC2016
grep -q 'open_detached_qml_window "$config_dir" "settings.qml"' "$launcher" \
  || fail "settings commands should launch kept settings.qml"
grep -q 'settings-window|ryoku-settings-window' "$launcher" \
  || fail "ryoku-settings-window compatibility alias should remain"
grep -q 'Quickshell.execDetached.*settings-window' "$shell_entry" \
  || fail "settings IPC should launch kept settings window"
! grep -q 'component: SettingsOverlay' "$shell_entry" \
  || fail "shell should not load deleted SettingsOverlay"
grep -q 'property bool overlayMode: false' shell/modules/common/Config.qml \
  || fail "overlay remake config should default disabled"
echo "PASS: kept settings app wiring"
