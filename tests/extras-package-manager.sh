#!/bin/bash

# Extras install/uninstall: the Settings -> Extras bundle manager. Covers the
# ryoku-extras-install CLI contract (per-item detection, report, repo/AUR routing,
# uninstall) and that the shell wires per-item state and install/uninstall the way
# the Plugins tab does.

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
CLI="$ROOT_DIR/bin/ryoku-extras-install"
SERVICE="$ROOT_DIR/shell/services/RyokuExtras.qml"
TAB="$ROOT_DIR/shell/settingsgui/Modules/Panels/Settings/Tabs/Extras/ExtrasTab.qml"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}
has() { rg -q -e "$2" -- "$1" || fail "$3"; }

# --- CLI: exists, parses, exposes the full contract ---
[[ -f $CLI ]] || fail "missing ryoku-extras-install"
bash -n "$CLI" || fail "ryoku-extras-install has a syntax error"
has "$CLI" 'status\)' "CLI exposes a status subcommand"
has "$CLI" 'uninstall\)' "CLI exposes an uninstall subcommand"
has "$CLI" '\-\-report' "CLI supports --report for per-item results"
has "$CLI" 'ryoku-pkg-add' "CLI installs repo packages via ryoku-pkg-add"
has "$CLI" 'ryoku-pkg-aur-add' "CLI routes AUR packages to ryoku-pkg-aur-add"
has "$CLI" 'ryoku-pkg-remove' "CLI uninstalls packages via ryoku-pkg-remove"
has "$CLI" 'pacman -Si' "CLI detects repo vs AUR with pacman -Si"
has "$CLI" 'write_report' "CLI writes a per-item report"

# --- CLI: deterministic report statuses (no sudo; uses an already-present pkg) ---
if command -v jq >/dev/null 2>&1 && command -v ryoku-pkg-present >/dev/null 2>&1 &&
  [[ -d ${RYOKU_EXTRAS_DIR:-$HOME/.local/share/ryoku-extras} ]]; then
  rep="$(mktemp)"
  bash "$CLI" item package jq --report "$rep" >/dev/null 2>&1 || true
  jq -e '.items[0] | (.name == "jq") and (.status == "present")' "$rep" >/dev/null ||
    fail "report should mark an already-present package as present"
  bash "$CLI" item plugin wallhaven --report "$rep" >/dev/null 2>&1 || true
  jq -e '.items[0].status == "deferred"' "$rep" >/dev/null ||
    fail "plugin items should be deferred in the report"
  bash "$CLI" uninstall item package not-a-real-pkg --report "$rep" >/dev/null 2>&1 || true
  jq -e '.items[0].status == "absent"' "$rep" >/dev/null ||
    fail "uninstalling a missing package should report absent"
  rm -f "$rep"
fi

# --- Service: terminal handoff + report watcher + per-item state + (un)install ---
[[ -f $SERVICE ]] || fail "missing RyokuExtras.qml"
has "$SERVICE" 'ryoku-launch-floating-terminal-with-presentation' "installs run in a terminal so sudo/yay can prompt"
has "$SERVICE" 'reportPath' "service defines the install-report path"
has "$SERVICE" 'watchChanges: true' "service watches the install report"
has "$SERVICE" 'property var installing' "service tracks per-item in-flight state"
has "$SERVICE" 'property var results' "service tracks per-item results"
has "$SERVICE" 'function installBundle' "service exposes installBundle"
has "$SERVICE" 'function uninstallBundle' "service exposes uninstallBundle"

# --- Tab: per-item state, loader, failure, install + uninstall (like Plugins) ---
[[ -f $TAB ]] || fail "missing ExtrasTab.qml"
has "$TAB" 'RyokuExtras.installing' "tab reflects installing state"
has "$TAB" 'RyokuExtras.results' "tab reflects per-item results"
has "$TAB" 'NBusyIndicator' "tab shows a loader while running"
has "$TAB" 'installState' "tab computes per-item install state"
has "$TAB" 'Install all' "tab has an Install all action"
has "$TAB" 'Uninstall all' "tab has an Uninstall all action"
has "$TAB" 'uninstallItem' "tab can uninstall single items"

echo "PASS: extras install/uninstall (CLI contract + terminal/report wiring + per-item UX)"
