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

assert_less_than() {
  local actual="$1"
  local limit="$2"
  local message="$3"

  (( actual < limit )) || fail "$message"
}

control="shell/modules/controlcenter/ControlCenter.qml"
title="shell/modules/controlcenter/WindowTitle.qml"
nav="shell/modules/controlcenter/NavRail.qml"
panes="shell/modules/controlcenter/Panes.qml"
appearance="shell/modules/controlcenter/appearance/AppearancePane.qml"

assert_contains "$control" "implicitWidth: Math.min(screen.width * 0.46, 980)" \
  "settings window should use the new compact workbench width"
assert_contains "$control" "implicitHeight: Math.min(screen.height * 0.46, 640)" \
  "settings window should use the new compact workbench height"
assert_not_contains "$control" "1220" \
  "settings window should not keep the previous wide default"
assert_not_contains "$control" "820" \
  "settings window should not keep the previous tall default"

assert_contains "$title" "implicitHeight: 44" \
  "floating settings titlebar should be compact"
assert_not_contains "$title" "implicitHeight: 58" \
  "floating settings titlebar should not keep the oversized header"

assert_contains "$nav" "implicitWidth: 168" \
  "left settings sidebar should be narrower"
assert_contains "$nav" "implicitHeight: 36" \
  "left settings entries should be dense"
assert_not_contains "$nav" "implicitWidth: 224" \
  "left settings sidebar should not keep the bulky width"
assert_not_contains "$nav" "implicitHeight: Math.max(44" \
  "left settings entries should not keep tall list rows"

assert_contains "$panes" "component PaneToolbar: StyledRect" \
  "pane chrome should use a compact toolbar"
assert_contains "$panes" "implicitHeight: 36" \
  "pane toolbar should be short"
assert_not_contains "$panes" "id: titleColumn" \
  "pane chrome should not keep the old two-line title block"
assert_not_contains "$panes" "root.activeEntry.description" \
  "pane chrome should not spend a full line on descriptions"

assert_contains "$appearance" "component AppearanceBoard: StyledRect" \
  "appearance should use a new compact board layout"
assert_contains "$appearance" "component ToneDock: AppearanceDock" \
  "appearance should group theme choices in a dock"
assert_contains "$appearance" "component TuningDock: AppearanceDock" \
  "appearance should group ranges in a compact dock"
assert_contains "$appearance" "component WallpaperDock: AppearanceDock" \
  "appearance should make wallpaper picking a compact dock"
assert_not_contains "$appearance" "PickerBoard {" \
  "appearance should not keep the previous vertical picker board"
assert_not_contains "$appearance" "PickerSection {" \
  "appearance should not keep the previous section stack"
assert_not_contains "$appearance" "Layout.preferredHeight: 360" \
  "appearance wallpaper picker should not keep the tall thumbnail block"

fill_count="$(grep -Fc "CompactToggle {" "$ROOT_DIR/$appearance" || true)"
assert_less_than "$fill_count" 20 \
  "appearance should not keep a long page of repeated full-row toggles"

assert_contains "$appearance" "Colours.setMode" \
  "appearance rework should preserve light and dark backend behavior"
assert_contains "$appearance" "Wallpapers.setWallpaper(entry.path)" \
  "appearance rework should preserve random wallpaper backend"
assert_contains "$appearance" "Quickshell.execDetached([\"ryoku\", \"scheme\", \"set\", \"-v\", variant])" \
  "appearance rework should preserve variant backend"
assert_contains "$appearance" "GlobalConfig.background.desktopClock.position = root.desktopClockPosition" \
  "appearance rework should preserve desktop clock backend"

echo "PASS: tests/settings-compact-workbench-rework.sh"
