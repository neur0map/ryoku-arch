#!/bin/bash
# Guards against the "feature wired but its tool is not shipped" class (the
# gnome-calendar / Super+G gap): every external program the shell gates a
# feature on via ProgramCheckerService must map to a package that the ISO
# actually ships (install/ryoku-base.packages or ryoku-aur.packages), or be
# explicitly allow-listed as intentionally bring-your-own / optional.
#
# Adding a program to ProgramCheckerService.programsToCheck therefore forces a
# decision here: map it to a shipped package, or allow-list it. A new gated
# program with no shipped package is a silent no-op on fresh installs and fails
# this gate.

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
PCS="$ROOT_DIR/shell/settingsgui/Services/System/ProgramCheckerService.qml"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

[[ -f $PCS ]] || fail "shell/settingsgui/Services/System/ProgramCheckerService.qml is missing"

# Program (binary probed via `command -v`) -> the package that provides it.
declare -A PKG=(
  [bluetoothctl]=bluez-utils
  [nmcli]=networkmanager
  [wlsunset]=wlsunset
  [gnome-calendar]=gnome-calendar
  [wtype]=wtype
  [python3]=python
)

# Programs intentionally NOT shipped (handled gracefully when absent).
declare -A ALLOW=()

pkgs="$(grep -hvE '^[[:space:]]*#|^[[:space:]]*$' \
  "$ROOT_DIR/install/ryoku-base.packages" "$ROOT_DIR/install/ryoku-aur.packages" 2>/dev/null)"
[[ -n $pkgs ]] || fail "could not read the package lists"

# Programs ProgramCheckerService gates features on.
progs="$(grep -oE 'command -v [a-z][a-z0-9_.-]+' "$PCS" | sed 's/command -v //' | sort -u)"
[[ -n $progs ]] || fail "could not extract any 'command -v' probes from ProgramCheckerService"

checked=0
while IFS= read -r p; do
  [[ -z $p ]] && continue
  [[ -n ${ALLOW[$p]:-} ]] && continue
  pkg="${PKG[$p]:-}"
  [[ -n $pkg ]] || fail "ProgramCheckerService gates a feature on '$p' but it is unmapped here. Add it to PKG (program->package) and ship the package, or to ALLOW if it is intentionally bring-your-own/optional."
  grep -qxF "$pkg" <<<"$pkgs" \
    || fail "feature gated on '$p' but its package '$pkg' ships nowhere (install/ryoku-base.packages or ryoku-aur.packages). On a fresh install the feature is a silent no-op (the gnome-calendar/Super+G class). Ship '$pkg' or allow-list '$p'."
  checked=$((checked + 1))
done <<<"$progs"

(( checked > 0 )) || fail "no programs were checked - extraction likely broke"
echo "PASS: shell-tool-availability ($checked gated programs, all shipped)"
