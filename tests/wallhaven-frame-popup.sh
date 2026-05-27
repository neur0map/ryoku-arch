#!/bin/bash

set -euo pipefail
cd "$(dirname "$0")/.."

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"

  [[ -f $file ]] || fail "missing file: $file"
  if ! grep -Eq "$pattern" "$file"; then
    fail "$message"
  fi
}

assert_contains shell/components/DrawerVisibilities.qml 'property bool wallhaven' \
  "drawer visibility state should include a Wallhaven panel"
assert_contains shell/modules/drawers/Panels.qml 'import qs\.modules\.wallhaven as Wallhaven' \
  "drawer panels should import the Wallhaven module"
assert_contains shell/modules/drawers/Panels.qml 'readonly property alias wallhaven: wallhaven' \
  "drawer panels should expose the Wallhaven panel for frame regions"
assert_contains shell/modules/drawers/Panels.qml 'Wallhaven\.Wrapper \{' \
  "drawer panels should instantiate the Wallhaven wrapper"
assert_contains shell/modules/wallhaven/Wrapper.qml 'readonly property int tileTargetWidth' \
  "Wallhaven wrapper should size itself around the intended three-column grid"
assert_contains shell/modules/wallhaven/Wrapper.qml 'tileTargetWidth \* 3 \+ Tokens\.spacing\.normal \* 2' \
  "Wallhaven wrapper should reserve room for three wallpaper tiles"
assert_contains shell/modules/drawers/ContentWindow.qml 'id: wallhavenBg' \
  "content window should give Wallhaven the native frame blob wrapper"
assert_contains shell/modules/drawers/ContentWindow.qml 'wallhaven\.transform: Matrix4x4' \
  "Wallhaven panel should receive the frame deformation transform"
assert_contains shell/modules/drawers/Regions.qml 'panel: root\.panels\.wallhaven' \
  "input regions should subtract the Wallhaven panel surface"
assert_contains shell/modules/drawers/Interactions.qml 'property bool wallhavenShortcutActive' \
  "drawer interactions should track Wallhaven hover ownership"
assert_contains shell/modules/drawers/Interactions.qml 'readonly property real wallhavenActivationWidth' \
  "Wallhaven closed-state hover activation should use a narrow top-right hitbox"
assert_contains shell/modules/drawers/Interactions.qml 'function inWallhavenPanel' \
  "drawer interactions should separate Wallhaven activation from the full open panel"
assert_contains shell/modules/drawers/Interactions.qml 'const showWallhaven = !visibilities\.settings && inWallhavenPanel\(panels\.wallhaven, x, y\)' \
  "top-right hover should use the narrow Wallhaven activation helper"
assert_contains shell/modules/Shortcuts.qml '"wallhaven"' \
  "IPC drawer toggles should treat Wallhaven as a fullscreen-sensitive drawer"
assert_contains shell/services/Wallhaven.qml 'ryoku-wallhaven-search' \
  "Wallhaven service should use the Ryoku command boundary"
assert_contains shell/services/Wallhaven.qml 'Wallpapers\.setWallpaper' \
  "Wallhaven service should apply downloads through the shared wallpaper service"
assert_contains shell/services/Wallhaven.qml 'property string topRange' \
  "Wallhaven service should track the active toplist range"
assert_contains shell/services/Wallhaven.qml 'property bool resultsExpanded' \
  "Wallhaven service should track whether the image results area is expanded"
assert_contains shell/services/Wallhaven.qml 'resultsExpanded = true' \
  "Wallhaven searches should expand the image results area"
assert_contains shell/services/Wallhaven.qml 'resultsExpanded = false' \
  "Wallhaven should collapse the image results area when clearing or reopening"
assert_contains shell/services/Wallhaven.qml '"--top-range", topRange' \
  "Wallhaven service should pass toplist ranges to the command boundary"
assert_contains shell/services/Wallhaven.qml 'function searchTop\(range: string\)' \
  "Wallhaven service should expose a top week/month search entrypoint"
assert_contains shell/modules/wallhaven/Wrapper.qml 'readonly property int compactHeight' \
  "Wallhaven wrapper should support a compact search-only opening height"
assert_contains shell/modules/wallhaven/Wrapper.qml 'readonly property int expandedHeight' \
  "Wallhaven wrapper should support an expanded image-results height"
assert_contains shell/modules/wallhaven/Wrapper.qml 'Wallhaven\.resultsExpanded \? expandedHeight : compactHeight' \
  "Wallhaven wrapper height should follow the result expansion state"
assert_contains shell/modules/wallhaven/Wrapper.qml 'Wallhaven\.resultsExpanded = false' \
  "Wallhaven wrapper should collapse results each time the popup opens"
assert_contains shell/modules/wallhaven/Content.qml 'readonly property int columns: 3' \
  "Wallhaven popup should render a three-column grid"
assert_contains shell/modules/wallhaven/Content.qml 'readonly property int visibleRows: 3' \
  "Wallhaven popup should size the grid around three visible rows"
assert_contains shell/modules/wallhaven/Content.qml 'readonly property real cellPitch: Math\.floor\(grid\.width / columns\)' \
  "Wallhaven popup should calculate a three-column GridView pitch that fits the available width"
assert_contains shell/modules/wallhaven/Content.qml 'readonly property real tileWidth: Math\.max\(1, cellPitch - cellSpacing\)' \
  "Wallhaven popup should keep tile width separate from GridView pitch"
assert_contains shell/modules/wallhaven/Content.qml 'cellWidth: root\.cellPitch' \
  "Wallhaven GridView should use the fitted three-column pitch"
assert_contains shell/modules/wallhaven/Content.qml 'width: root\.tileWidth' \
  "Wallhaven tile delegates should render inside the fitted pitch"
assert_contains shell/modules/wallhaven/Content.qml 'component PagerButton: StyledRect' \
  "Wallhaven pager controls should use larger shell-styled buttons"
assert_contains shell/modules/wallhaven/Content.qml 'FilterChip \{' \
  "Wallhaven popup should expose top-list filter chips"
assert_contains shell/modules/wallhaven/Content.qml 'text: qsTr\("Top week"\)' \
  "Wallhaven popup should include a top week search chip"
assert_contains shell/modules/wallhaven/Content.qml 'text: qsTr\("Top month"\)' \
  "Wallhaven popup should include a top month search chip"
assert_contains shell/modules/wallhaven/Content.qml 'root\.submitTopSearch\("1w"\)' \
  "Top week chip should request Wallhaven weekly toplist results"
assert_contains shell/modules/wallhaven/Content.qml 'root\.submitTopSearch\("1M"\)' \
  "Top month chip should request Wallhaven monthly toplist results"
assert_contains shell/modules/wallhaven/Content.qml 'visible: Wallhaven\.resultsExpanded' \
  "Wallhaven result viewport should stay hidden while the popup is compact"
assert_contains shell/modules/wallhaven/Content.qml 'Layout\.preferredHeight: Wallhaven\.resultsExpanded \?' \
  "Wallhaven result viewport height should animate from compact to expanded"
assert_contains shell/modules/wallhaven/Content.qml 'id: menuClickArea' \
  "Wallhaven image action button should have its own clickable hitbox"
assert_contains shell/modules/wallhaven/Content.qml 'acceptedButtons: Qt\.LeftButton \| Qt\.RightButton' \
  "Wallhaven image action button should open from left click and right click"
assert_contains shell/modules/wallhaven/Content.qml 'onClicked: imageMenu\.expanded = true' \
  "Wallhaven image action button should open the context menu"
assert_contains shell/modules/wallhaven/Content.qml 'StyledScrollBar\.vertical' \
  "Wallhaven popup grid should be scrollable"
assert_contains shell/modules/wallhaven/Content.qml 'text: qsTr\("Open in web"\)' \
  "right-click menu should offer opening the Wallhaven page"
assert_contains shell/modules/wallhaven/Content.qml 'text: qsTr\("Download"\)' \
  "right-click menu should offer downloading"
assert_contains shell/modules/wallhaven/Content.qml 'text: qsTr\("Set as wallpaper"\)' \
  "right-click menu should offer setting the wallpaper"

echo "PASS: wallhaven frame popup"
