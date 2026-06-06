#!/bin/bash

set -euo pipefail

# Regression: switching workspaces from a bar on a secondary/third monitor must
# act on THAT monitor, not the focused one. The bar displays per-monitor state
# (perMonitorWorkspaces defaults true) but historically dispatched a plain
# `workspace N` / `workspace r±1`, which Hyprland applies to the *focused*
# monitor -- so clicking/scrolling the bar on an extended display switched the
# primary display instead. The fix routes bar workspace actions through
# Hypr.dispatchOnMonitor(), which focuses the bar's monitor first, atomically:
# a single `hyprctl --batch` under Lua config mode (preserves order) and ordered
# IPC dispatches under legacy Hyprland.

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

HYPR="shell/services/Hypr.qml"
WS="shell/modules/bar/components/workspaces/Workspaces.qml"
BAR="shell/modules/bar/Bar.qml"
BARCONFIG="shell/plugin/src/Ryoku/Config/barconfig.hpp"

fail() { echo "FAIL: $1" >&2; exit 1; }

for f in "$HYPR" "$WS" "$BAR" "$BARCONFIG"; do
  [[ -f $f ]] || fail "missing $f"
done

# 0. Per-monitor display stays the default; the targeting fix assumes it.
grep -q 'perMonitorWorkspaces, true' "$BARCONFIG" || \
  fail "perMonitorWorkspaces should default to true so each bar reflects its own monitor"

# 1. Hypr service exposes a monitor-targeted dispatch that focuses the monitor first.
grep -q 'function dispatchOnMonitor' "$HYPR" || \
  fail "$HYPR must define dispatchOnMonitor(monitor, request)"
grep -q 'focusmonitor ${monitor.name}' "$HYPR" || \
  fail "dispatchOnMonitor must focus the target monitor before dispatching"
grep -q '"hyprctl", "--batch"' "$HYPR" || \
  fail "dispatchOnMonitor must batch focus+action into one hyprctl call under Lua mode (ordering)"
grep -q 'case "focusmonitor"' "$HYPR" || \
  fail "toLuaDispatch must map focusmonitor to hl.dsp.focus({ monitor = ... })"

# 2. Click targets the bar's monitor and compares the per-monitor active workspace.
grep -q 'Hypr.dispatchOnMonitor(mon' "$WS" || \
  fail "$WS click must route through Hypr.dispatchOnMonitor(mon, ...)"
grep -q 'root.activeWsId !== ws' "$WS" || \
  fail "$WS click must compare the per-monitor active workspace (root.activeWsId), not the global one"
if grep -qE 'Hypr\.dispatch\(`workspace ' "$WS"; then
  fail "$WS click must not dispatch a plain global 'workspace N' (it hits the focused monitor)"
fi

# 3. Scroll targets the bar's monitor.
grep -q 'Hypr.dispatchOnMonitor(targetMon' "$BAR" || \
  fail "$BAR workspace scroll must route through Hypr.dispatchOnMonitor(targetMon, ...)"
if grep -qE 'Hypr\.dispatch\(`workspace r' "$BAR"; then
  fail "$BAR workspace scroll must not dispatch a plain global 'workspace r±1'"
fi

echo "PASS: bar workspace switching targets its own monitor"
