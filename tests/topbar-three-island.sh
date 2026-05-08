#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_file() {
  local path="$1"
  [[ -f $ROOT_DIR/$path ]] || fail "$path should exist"
}

assert_executable() {
  local path="$1"
  assert_file "$path"
  [[ -x $ROOT_DIR/$path ]] || fail "$path should be executable"
}

assert_contains() {
  local path="$1"
  local needle="$2"
  local file="$ROOT_DIR/$path"
  [[ -f $file ]] || fail "$path should exist"
  grep -qF "$needle" "$file" || fail "$path should contain: $needle"
}

assert_not_contains() {
  local path="$1"
  local needle="$2"
  local file="$ROOT_DIR/$path"
  [[ -f $file ]] || fail "$path should exist"
  ! grep -qF "$needle" "$file" || fail "$path should not contain: $needle"
}

assert_contains_regex() {
  local path="$1"
  local pattern="$2"
  local file="$ROOT_DIR/$path"
  [[ -f $file ]] || fail "$path should exist"
  grep -qE "$pattern" "$file" || fail "$path should match regex: $pattern"
}

assert_count() {
  local path="$1"
  local needle="$2"
  local expected="$3"
  local file="$ROOT_DIR/$path"
  local actual
  actual=$(grep -cF "$needle" "$file" || true)
  [[ $actual -eq $expected ]] || fail "$path: expected $expected occurrences of '$needle', got $actual"
}

# 1. New files exist under shell/modules/bar/threeIsland/
assert_file "shell/modules/bar/threeIsland/RyokuThreeIslandContent.qml"
assert_file "shell/modules/bar/threeIsland/RyokuTopFrame.qml"
assert_file "shell/modules/bar/threeIsland/RyokuLeftIsland.qml"
assert_file "shell/modules/bar/threeIsland/RyokuCenterIsland.qml"
assert_file "shell/modules/bar/threeIsland/RyokuRightIsland.qml"
assert_file "shell/modules/bar/threeIsland/RyokuClock.qml"
assert_file "shell/modules/bar/threeIsland/RyokuDateLabel.qml"
assert_file "shell/modules/bar/threeIsland/SecPulseIndicator.qml"

# 2. Singleton service exists and is registered
assert_file "shell/services/RyokuSecPulse.qml"
assert_contains "shell/services/qmldir" "singleton RyokuSecPulse 1.0 RyokuSecPulse.qml"

# 2b. Tailscale CLI is in the base package list (SecPulse polls it).
# The default click target opens the web admin console, not the Trayscale GUI.
assert_contains "install/ryoku-base.packages" "tailscale"
assert_not_contains "install/ryoku-aur.packages" "trayscale"
assert_contains "shell/modules/common/Config.qml" "xdg-open https://login.tailscale.com/admin/machines"

# 3. Config.qml declares the new keys with documented defaults
assert_contains "shell/modules/common/Config.qml" "property bool kanjiClock: true"
assert_contains "shell/modules/common/Config.qml" "property bool secPulse: true"
assert_contains "shell/modules/common/Config.qml" "property bool dateLabel: true"
assert_contains "shell/modules/common/Config.qml" "property bool weatherIcon: true"
assert_contains "shell/modules/common/Config.qml" "property JsonObject kanjiClock"
assert_contains "shell/modules/common/Config.qml" "property JsonObject secPulse"
assert_contains "shell/modules/common/Config.qml" "property bool showDate: true"
assert_contains "shell/modules/common/Config.qml" "property bool useKanjiDigits: false"
assert_contains "shell/modules/common/Config.qml" "property bool showVpn: true"
assert_contains "shell/modules/common/Config.qml" "property bool showPublicIp: false"
assert_contains "shell/modules/common/Config.qml" "property bool showListening: false"

# 4. Bar.qml: Loader wraps BarContent, switches on cornerStyle === 4
assert_contains "shell/modules/bar/Bar.qml" "import qs.modules.bar.threeIsland"
assert_contains "shell/modules/bar/Bar.qml" "RyokuThreeIslandContent"
assert_contains_regex "shell/modules/bar/Bar.qml" "cornerStyle.*===.*4"
# 5. Bar.qml: roundDecorators activates on cornerStyle === 0 || cornerStyle === 4
assert_contains_regex "shell/modules/bar/Bar.qml" "cornerStyle.*===.*0.*\|\|.*cornerStyle.*===.*4|cornerStyle.*===.*4.*\|\|.*cornerStyle.*===.*0"

# 6. BarContent.qml is unchanged compared to HEAD (no edits)
if git -C "$ROOT_DIR" rev-parse HEAD >/dev/null 2>&1; then
  if ! git -C "$ROOT_DIR" diff --quiet HEAD -- shell/modules/bar/BarContent.qml; then
    fail "shell/modules/bar/BarContent.qml must not be modified"
  fi
fi

# 7. Settings UI: each picker has exactly one value: 4 entry
assert_count "shell/modules/settings/BarConfig.qml" "value: 4" 1
assert_count "shell/modules/settings/QuickConfig.qml" "value: 4" 1
assert_count "shell/welcome.qml" "value: 4" 1
assert_contains "shell/modules/settings/BarConfig.qml" "Three-Island"
assert_contains "shell/modules/settings/QuickConfig.qml" "Three-Island"
assert_contains "shell/welcome.qml" "Three-Island"

# 8. BarConfig.qml: Modules toggles for kanjiClock and secPulse
assert_contains "shell/modules/settings/BarConfig.qml" "bar.modules.kanjiClock"
assert_contains "shell/modules/settings/BarConfig.qml" "bar.modules.secPulse"

# 8b. SecPulse listening hover explains the TCP listener count.
assert_contains "shell/services/RyokuSecPulse.qml" "parseListeningSockets"
assert_contains "shell/services/RyokuSecPulse.qml" "ss -lntpeH"
assert_contains "shell/modules/bar/threeIsland/SecPulseIndicator.qml" "StyledPopup"
assert_contains "shell/modules/bar/threeIsland/SecPulseIndicator.qml" "RyokuSecPulse.listeningPorts"
assert_contains "shell/modules/bar/threeIsland/SecPulseIndicator.qml" "maxListeningRows"
assert_contains "shell/modules/bar/threeIsland/SecPulseIndicator.qml" "listeningPopupWidth"
assert_contains "shell/modules/bar/threeIsland/SecPulseIndicator.qml" "horizontalPadding: 28"
assert_contains "shell/modules/bar/threeIsland/SecPulseIndicator.qml" "verticalPadding: 22"
assert_contains "shell/modules/bar/threeIsland/SecPulseIndicator.qml" "anchors.centerIn: parent"
assert_contains "shell/modules/bar/threeIsland/SecPulseIndicator.qml" "colPopupText"
assert_contains "shell/modules/bar/threeIsland/SecPulseIndicator.qml" "colPopupSecondaryText"
assert_contains "shell/modules/bar/threeIsland/SecPulseIndicator.qml" "colBackground:"
assert_contains "shell/modules/bar/threeIsland/SecPulseIndicator.qml" "text: modelData.purpose"
assert_contains "shell/modules/bar/threeIsland/SecPulseIndicator.qml" "text: modelData.endpoint + \" · \" + modelData.processLabel"
assert_not_contains "shell/modules/bar/threeIsland/SecPulseIndicator.qml" "settings_ethernet"
assert_contains "shell/modules/bar/StyledPopup.qml" "property color colBackground"
assert_contains "shell/modules/bar/StyledPopup.qml" "color: root.colBackground"

# 8c. The right notch frame follows the visible right island width. A hidden
# duplicate sizer can drift from the anchored visible row and leave content
# outside the island shape.
assert_contains "shell/modules/bar/threeIsland/RyokuThreeIslandContent.qml" "readonly property int islandFramePadding: 16"
assert_contains "shell/modules/bar/threeIsland/RyokuThreeIslandContent.qml" "readonly property int rightContentWidth: rightIsland.implicitWidth"
assert_contains "shell/modules/bar/threeIsland/RyokuThreeIslandContent.qml" "property int rightNotchWidth: GlobalStates.toolsModeOpen ? 0 : Math.max(140, root.rightContentWidth + root.islandFramePadding)"
assert_contains "shell/modules/bar/threeIsland/RyokuThreeIslandContent.qml" "id: rightIsland"
assert_not_contains "shell/modules/bar/threeIsland/RyokuThreeIslandContent.qml" "rightSizer.implicitWidth + 16"

# 8d. Right island uses compact spacing so transient status pills do not push
# neighboring icons apart.
assert_contains "shell/modules/bar/threeIsland/RyokuRightIsland.qml" "readonly property int compactSpacing: 6"
assert_contains "shell/modules/bar/threeIsland/RyokuRightIsland.qml" "readonly property int horizontalPadding: 8"
assert_contains "shell/modules/bar/threeIsland/RyokuRightIsland.qml" "implicitWidth: rowLayout.width + (root.horizontalPadding * 2)"
assert_contains "shell/modules/bar/threeIsland/RyokuRightIsland.qml" "spacing: root.compactSpacing"
assert_contains "shell/modules/bar/threeIsland/RyokuRightIsland.qml" "anchors.right: parent.right"
assert_contains "shell/modules/bar/threeIsland/RyokuRightIsland.qml" "anchors.verticalCenter: parent.verticalCenter"
assert_contains "shell/modules/bar/threeIsland/RyokuRightIsland.qml" "anchors.rightMargin: root.horizontalPadding"
assert_contains "shell/modules/bar/threeIsland/RyokuRightIsland.qml" "height: parent.height"
assert_contains "shell/modules/bar/threeIsland/RyokuRightIsland.qml" "width: implicitWidth"
assert_contains "shell/modules/bar/threeIsland/RyokuRightIsland.qml" "compact: true"
assert_contains "shell/modules/bar/ShellUpdateIndicator.qml" "property bool compact: false"
assert_contains "shell/modules/bar/ShellUpdateIndicator.qml" "readonly property int horizontalPadding: root.compact ? 6 : 8"
assert_contains "shell/modules/bar/ShellUpdateIndicator.qml" "readonly property int contentSpacing: root.compact ? 4 : 5"
assert_contains "shell/modules/bar/ShellUpdateIndicator.qml" "width: contentRow.implicitWidth + (root.horizontalPadding * 2)"
assert_contains "shell/modules/bar/ShellUpdateIndicator.qml" "spacing: root.contentSpacing"

# 8e. Ryoku update hover follows StyledPopup rich-tooltip layout rules.
assert_contains "shell/modules/bar/ShellUpdateIndicator.qml" "readonly property int updatePopupWidth: 380"
assert_contains "shell/modules/bar/ShellUpdateIndicator.qml" "readonly property int popupRowSpacing: 8"
assert_contains "shell/modules/bar/ShellUpdateIndicator.qml" "readonly property color popupTextColor"
assert_contains "shell/modules/bar/ShellUpdateIndicator.qml" "readonly property color popupSubtextColor"
assert_contains "shell/modules/bar/ShellUpdateIndicator.qml" "horizontalPadding: 16"
assert_contains "shell/modules/bar/ShellUpdateIndicator.qml" "verticalPadding: 12"
assert_contains "shell/modules/bar/ShellUpdateIndicator.qml" "id: updatePopupContent"
assert_contains "shell/modules/bar/ShellUpdateIndicator.qml" "anchors.centerIn: parent"
assert_contains "shell/modules/bar/ShellUpdateIndicator.qml" "implicitWidth: root.updatePopupWidth"
assert_contains "shell/modules/bar/ShellUpdateIndicator.qml" "anchors.left: parent.left"
assert_contains "shell/modules/bar/ShellUpdateIndicator.qml" "anchors.right: parent.right"
assert_contains "shell/modules/bar/ShellUpdateIndicator.qml" "anchors.verticalCenter: parent.verticalCenter"
assert_contains "shell/modules/bar/ShellUpdateIndicator.qml" "spacing: root.popupRowSpacing"
assert_contains "shell/modules/bar/ShellUpdateIndicator.qml" "color: root.popupTextColor"
assert_contains "shell/modules/bar/ShellUpdateIndicator.qml" "color: root.popupSubtextColor"
assert_not_contains "shell/modules/bar/ShellUpdateIndicator.qml" "implicitWidth: 260"
assert_not_contains "shell/modules/bar/ShellUpdateIndicator.qml" "color: Appearance.colors.colOnSurfaceVariant"

# 9. RyokuSecPulse: gated subprocess starts (no unconditional process.start in onCompleted)
sec_pulse="$ROOT_DIR/shell/services/RyokuSecPulse.qml"
if [[ -f $sec_pulse ]]; then
  # If onCompleted exists, it must not call .start() / .startDetached() / running = true unconditionally.
  # We check that any .running = true / .start() inside onCompleted is wrapped in a Config.options check.
  if grep -A4 'Component.onCompleted' "$sec_pulse" | grep -E '^\s*(running\s*=\s*true|\.start\(\)|\.startDetached\()' \
     | grep -v 'Config.options' >/dev/null; then
    fail "shell/services/RyokuSecPulse.qml: subprocess starts in onCompleted must be Config.options-gated"
  fi
fi

# 10. Migration script exists and references SHELL_PATH + runtime-payload-dirs.txt
migration_files=$(find "$ROOT_DIR/migrations" -name "*.sh" -newer "$ROOT_DIR/migrations/1778100000.sh" 2>/dev/null || true)
found_migration=0
for m in $migration_files; do
  if grep -qE 'three.?island|threeIsland|RyokuSecPulse' "$m" \
     && grep -qE 'RYOKU_SHELL_PATH|SHELL_PATH=' "$m" \
     && grep -q 'runtime-payload-dirs.txt' "$m"; then
    found_migration=1
    break
  fi
done
[[ $found_migration -eq 1 ]] || fail "migrations/<timestamp>.sh referencing three-island + SHELL_PATH + runtime-payload-dirs.txt should exist"

echo "PASS: tests/topbar-three-island.sh"
