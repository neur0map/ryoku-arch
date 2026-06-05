#!/bin/bash

set -euo pipefail
cd "$(dirname "$0")/.."

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_contains() {
  local path="$1"
  local needle="$2"
  local message="$3"

  grep -Fq -- "$needle" "$path" || fail "$message"
}

assert_not_contains() {
  local path="$1"
  local needle="$2"
  local message="$3"

  ! grep -Fq -- "$needle" "$path" || fail "$message"
}

island="shell/modules/island/Content.qml"
wrapper="shell/modules/island/Wrapper.qml"
panels="shell/modules/drawers/Panels.qml"
content_window="shell/modules/drawers/ContentWindow.qml"
helper="bin/ryoku-cmd-color-picker"

[[ -f $island ]] || fail "missing island content"
[[ -f $wrapper ]] || fail "missing island wrapper"
[[ -f $helper ]] || fail "missing Ryoku color picker helper"
[[ -x $helper ]] || fail "Ryoku color picker helper should be executable"

bash -n "$helper" || fail "Ryoku color picker helper should be valid bash"

assert_contains "$helper" 'hyprpicker -a' \
  "color picker helper should use hyprpicker autocopy mode"
assert_contains "$helper" '--repeat' \
  "color picker helper should support repeated picks from the island"
assert_contains "$helper" 'while true' \
  "color picker helper should keep picking until the user cancels repeat mode"
assert_contains install/ryoku-base.packages 'hyprpicker' \
  "fresh installs should include hyprpicker for the island color picker"

assert_contains "$island" 'import qs.dashboard.modules.widgets.dashboard as DashboardContent' \
  "island content should import the Ryoku dashboard widget surface"
assert_contains "$island" 'DashboardContent.DashboardView' \
  "island content should load the Ryoku dashboard view"
assert_contains "$island" 'property string mode: "dashboard"' \
  "island content should default to the Ryoku dashboard mode"
assert_contains "$island" 'mode === "record"' \
  "island content should dynamically switch into record mode"
assert_contains "$island" '["ryoku-cmd-google-lens"]' \
  "island Lens action should launch the Ryoku Google Lens helper"
assert_contains "$island" '["ryoku-cmd-color-picker", "--repeat"]' \
  "island color action should launch the repeatable Ryoku color picker helper"
assert_contains "$island" 'UtilityCards.Record' \
  "record quick action should open the existing recorder UI inside the island"
assert_contains "$island" 'Utilities.RecordingDeleteModal' \
  "record mode should preserve recording deletion confirmation inside the island"
assert_contains "$wrapper" 'Loader {' \
  "island wrapper should host the copied island through a Loader like settings"
assert_contains "$wrapper" 'active: root.shouldBeActive || root.visible' \
  "island wrapper should lazy-load content using the settings wrapper contract"

assert_contains "$wrapper" 'required property BarPopouts.Wrapper popouts' \
  "island wrapper should receive the existing popout wrapper for reused utility controls"
assert_contains "$wrapper" 'readonly property PersistentProperties props' \
  "island wrapper should own persistent utility-card state"
assert_contains "$wrapper" 'property matrix4x4 deformMatrix' \
  "island wrapper should receive the blob deform matrix for utility modals"
assert_contains "$panels" 'popouts: root.popouts' \
  "drawer panels should pass popouts into the island"
assert_contains "$content_window" 'island.deformMatrix: islandBg.rawDeformMatrix' \
  "drawer content should pass the island blob deform matrix into the island"

echo "PASS: dynamic island hosts the Ryoku dashboard surface"
