#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

[[ -d $ROOT_DIR/shell-vroomies/quickshell ]] || \
  fail "missing Vroomies quickshell runtime"
[[ -f $ROOT_DIR/shell-vroomies/quickshell/shell.qml ]] || \
  fail "missing Vroomies shell.qml"
[[ -f $ROOT_DIR/shell-vroomies/UPSTREAM.md ]] || \
  fail "missing Vroomies upstream attribution"
[[ -x $ROOT_DIR/bin/ryoku-vroomies-shell ]] || \
  fail "missing executable ryoku-vroomies-shell wrapper"
[[ -f $ROOT_DIR/config/hypr/hyprland.conf ]] || \
  fail "missing Hyprland entry config"

if find "$ROOT_DIR/shell-vroomies/quickshell" \( -path '*/.git/*' -o -path '*/.idea/*' -o -path '*/__pycache__/*' -o -name '*.pyc' \) | grep -q .; then
  fail "Vroomies shell should not vendor repo metadata, IDE files, or Python bytecode caches"
fi
[[ ! -e $ROOT_DIR/shell-vroomies/quickshell/components/state/gif-index ]] || \
  fail "Vroomies runtime state should not be versioned"

home_prefix="/h""ome/"
if rg -n "${home_prefix}max|~/.config/quickshell|fish|AETHER|dnf|xbps-install" "$ROOT_DIR/shell-vroomies/quickshell" >/tmp/vroomies-hardcoded-paths.$$; then
  cat /tmp/vroomies-hardcoded-paths.$$
  rm -f /tmp/vroomies-hardcoded-paths.$$
  fail "Vroomies runtime should not keep upstream machine paths or installer assumptions"
fi
rm -f /tmp/vroomies-hardcoded-paths.$$

! rg -n 'settingsState|components/Settings/Settings.qml' "$ROOT_DIR/shell-vroomies/quickshell/shell.qml" || \
  fail "Vroomies shell should not load the missing upstream Settings component"
rg -q 'RYOKU_VROOMIES_SHELL_DIR' "$ROOT_DIR/shell-vroomies/quickshell" || \
  fail "Vroomies QML should resolve assets through the selected Ryoku runtime directory"
! rg -n 'exclusionMode: ExclusionMode\.Exclusive' "$ROOT_DIR/shell-vroomies/quickshell" || \
  fail "Vroomies QML should use Quickshell 0.2-compatible exclusion modes"
rg -q 'required property var modelData' "$ROOT_DIR/shell-vroomies/quickshell/components/Bar/Sway.qml" || \
  fail "Vroomies top bar should bind each screen from Variants without startup warnings"

grep -Fq 'Source: https://github.com/maxchennn/vroomies' "$ROOT_DIR/shell-vroomies/UPSTREAM.md" || \
  fail "Vroomies upstream attribution should name the source repository"
grep -Fq 'License: MIT' "$ROOT_DIR/shell-vroomies/UPSTREAM.md" || \
  fail "Vroomies upstream attribution should preserve license metadata"

grep -Fq 'qs_config_name="ryoku-vroomies-shell"' "$ROOT_DIR/bin/ryoku-vroomies-shell" || \
  fail "wrapper should select the Vroomies Quickshell config name"
grep -Fq 'RYOKU_VROOMIES_SHELL_DIR' "$ROOT_DIR/bin/ryoku-vroomies-shell" || \
  fail "wrapper should export the Vroomies runtime directory"
grep -Fq "exec \"\$qs_bin\" -d \"\${qs_args[@]}\"" "$ROOT_DIR/bin/ryoku-vroomies-shell" || \
  fail "wrapper should support daemonized live restarts"
grep -Fq 'components/Launcher/Sway.qml' "$ROOT_DIR/bin/ryoku-vroomies-shell" || \
  fail "wrapper should expose the Vroomies launcher as a command"
grep -Fq "exec \"\$qs_bin\" \"\${qs_args[@]}\" ipc \"\$@\"" "$ROOT_DIR/bin/ryoku-vroomies-shell" || \
  fail "wrapper should route IPC to the selected Vroomies shell"

rg -q "exec-once = sh -lc '\\\$HOME/.local/bin/ryoku-vroomies-shell'" "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should start Vroomies without relying on PATH"
rg -q 'env = QS_CONFIG_NAME,ryoku-vroomies-shell' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland config should route shell IPC to the Vroomies instance"
rg -q "[$]menu = sh -lc '\\\$HOME/.local/bin/ryoku-vroomies-shell ipc call vroomies launcher" "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland launcher bind should use the Vroomies shell"
rg -q "[$]systemPanel = sh -lc '\\\$HOME/.local/bin/ryoku-vroomies-shell ipc call vroomies dashboard'" "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland system-panel bind should use the Vroomies dashboard"
rg -q "[$]shellRestart = sh -lc '\\\$HOME/.local/bin/ryoku-vroomies-shell restart'" "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland restart bind should restart the Vroomies shell"
rg -q "[$]clipboard = sh -lc 'cliphist list \\| fuzzel --dmenu" "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "Hyprland clipboard bind should keep clipboard history without the old shell IPC"
! rg -q 'ryoku-rebirth-shell ipc' "$ROOT_DIR/config/hypr/hyprland.conf" || \
  fail "active Hyprland config should not depend on rebirth shell IPC"

echo "PASS: Vroomies shell runtime is self-contained and Hyprland-wired"
