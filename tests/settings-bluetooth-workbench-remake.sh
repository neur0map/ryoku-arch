#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local needle="$2"
  local message="$3"

  grep -Fq "$needle" "$ROOT_DIR/$file" || fail "$message"
}

assert_not_contains() {
  local file="$1"
  local needle="$2"
  local message="$3"

  ! grep -Fq "$needle" "$ROOT_DIR/$file" || fail "$message"
}

pane="shell/modules/controlcenter/bluetooth/BtPane.qml"
settings="shell/modules/controlcenter/bluetooth/Settings.qml"

assert_not_contains "$pane" "SplitPaneWithDetails" \
  "Bluetooth settings should not keep the old split-pane frontend"
assert_contains "$pane" "component BluetoothWorkbench: StyledRect" \
  "Bluetooth pane should wrap devices and adapter controls in one compact workbench"
assert_contains "$pane" "component BluetoothDock: StyledRect" \
  "Bluetooth pane should use compact docks"
assert_contains "$pane" "Layout.maximumHeight: implicitHeight" \
  "Bluetooth docks should not stretch empty states to the tallest grid cell"
assert_contains "$pane" "component EmptyDevicePrompt: StyledRect" \
  "Bluetooth pane should fill the no-device state with compact scan controls"
assert_contains "$pane" "implicitHeight: promptLayout.implicitHeight + Tokens.padding.small * 2" \
  "Bluetooth empty state should use compact prompt padding"
assert_contains "$pane" "columns: page.width > 620 ? 5 : 1" \
  "Bluetooth pane should keep a compact multi-column workbench"
assert_contains "$pane" "Layout.columnSpan: page.width > 620 ? 5 : 1" \
  "Bluetooth workbench should stack full-width docks instead of leaving a blank side column"
assert_contains "$pane" "implicitWidth: Math.max(118, actionContent.implicitWidth + Tokens.padding.small * 2)" \
  "Bluetooth empty-state actions should size to their labels instead of stretching across the pane"
assert_contains "$pane" "Bluetooth.devices.values.length === 0" \
  "Bluetooth pane should explicitly handle the empty device state"
assert_not_contains "$pane" "Layout.preferredHeight: 420" \
  "Bluetooth adapter settings should not force a tall clipped right pane"
assert_contains "$pane" "DeviceList {" \
  "Bluetooth pane should preserve the device list"
assert_contains "$pane" "Details {" \
  "Bluetooth pane should preserve selected-device details"
assert_contains "$pane" "Settings {" \
  "Bluetooth pane should preserve adapter settings"

assert_not_contains "$settings" "SettingsHeader" \
  "Bluetooth adapter settings should not render the old big settings header"
assert_not_contains "$settings" "Bluetooth Settings" \
  "Bluetooth adapter settings should not show the old generic header text"
assert_not_contains "$settings" "Layout.topMargin: Tokens.spacing.large" \
  "Bluetooth settings should not keep large stacked section gaps"
assert_not_contains "$settings" "implicitHeight: adapterStatus.implicitHeight + Tokens.padding.large * 2" \
  "Bluetooth settings should not keep the tall adapter status card"
assert_contains "$settings" "component AdapterDock: StyledRect" \
  "Bluetooth settings should group controls in compact adapter docks"
assert_contains "$settings" "GridLayout {" \
  "Bluetooth settings should arrange adapter docks as a compact grid"
assert_contains "$settings" "columns: width > 620 ? 2 : 1" \
  "Bluetooth settings should use two columns in the compact workbench when width allows"
assert_contains "$settings" "component TogglePill: StyledRect" \
  "Bluetooth settings should expose compact toggle pills"
assert_contains "$settings" "component AdapterChip: StyledRect" \
  "Bluetooth settings should replace the adapter drawer with compact adapter chips"
assert_contains "$settings" "adapter.enabled = checked" \
  "Bluetooth settings should preserve powered backend behavior"
assert_contains "$settings" "adapter.discoverable = checked" \
  "Bluetooth settings should preserve discoverable backend behavior"
assert_contains "$settings" "adapter.pairable = checked" \
  "Bluetooth settings should preserve pairable backend behavior"
assert_contains "$pane" "Bluetooth.defaultAdapter.discovering = true" \
  "Bluetooth empty state should preserve scan backend behavior"
assert_contains "$settings" "root.session.bt.currentAdapter = chip.modelData" \
  "Bluetooth settings should preserve adapter selection behavior"
assert_contains "$settings" "root.session.bt.currentAdapter.discoverableTimeout = value" \
  "Bluetooth settings should preserve discoverable timeout behavior"

echo "PASS: tests/settings-bluetooth-workbench-remake.sh"
