#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_contains() {
  local path="$1"
  local needle="$2"

  grep -qF "$needle" "$ROOT_DIR/$path" || fail "$path should contain: $needle"
}

assert_contains "shell/modules/lock/LockSurface.qml" "id: topBatteryRow"
assert_contains "shell/modules/lock/LockSurface.qml" "readonly property int batteryLevel: Math.round((UPower.displayDevice?.percentage ?? 0) * 100)"
assert_contains "shell/modules/lock/LockSurface.qml" "text: topBatteryRow.batteryLevel + \"%\""
assert_contains "shell/modules/lock/LockSurface.qml" "topBatteryRow.batteryLevel <= 15 && !topBatteryRow.isCharging"

assert_contains "shell/services/ResourceUsage.qml" "cpu_priority=0"
assert_contains "shell/services/ResourceUsage.qml" "coretemp|k10temp|zenpower|cpu_thermal|fam15h_power|via_cputemp) priority_level=3"
assert_contains "shell/services/ResourceUsage.qml" "acpitz|pch_*) priority_level=1"
assert_contains "shell/services/ResourceUsage.qml" "if (( priority_level > cpu_priority )); then"
assert_contains "shell/services/ResourceUsage.qml" 'if [[ -z "$cpu_path" || -z "$gpu_path" ]]; then'

echo "PASS: lock battery status and resource sensor priority"
