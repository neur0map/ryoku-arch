#!/bin/bash
set -euo pipefail

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

require_rg() {
  local pattern=$1
  local path=$2
  rg -q -- "$pattern" "$path" || fail "missing pattern in $path: $pattern"
}

reject_rg() {
  local pattern=$1
  local path=$2
  if rg -q -- "$pattern" "$path"; then
    rg -n -- "$pattern" "$path" >&2
    fail "unexpected pattern in $path: $pattern"
  fi
}

file=shell/modules/settings/DesktopWidgetsConfig.qml
[[ -f $file ]] || fail "missing $file"

require_rg 'component WidgetStateControls: ColumnLayout' "$file"
require_rg 'title: Translation\.tr\("Placement"\)' "$file"
require_rg 'Layout\.fillWidth: true' "$file"

state_count=$(rg -c 'WidgetStateControls \{' "$file")
(( state_count >= 7 )) || fail "expected built-in and custom widget state rows to use WidgetStateControls"

reject_rg 'Layout\.preferredWidth: Math\.min\(500, Math\.max\(420' "$file"
reject_rg 'Layout\.minimumWidth: Math\.min\(420' "$file"
reject_rg 'Layout\.fillWidth: wsr\.trailing' "$file"
reject_rg 'enableTooltip:' "$file"
reject_rg 'Show the desktop clock widget' "$file"

echo "desktop widget tuning layout ok"
