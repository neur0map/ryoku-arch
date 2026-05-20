#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"

  rg -n -- "$pattern" "$ROOT_DIR/$file" >/dev/null || fail "$message"
}

assert_not_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"

  if rg -n -- "$pattern" "$ROOT_DIR/$file" >/dev/null; then
    fail "$message"
  fi
}

background_qml="shell/modules/background/Background.qml"
awww_backend_qml="shell/services/AwwwBackend.qml"
switchwall_sh="shell/scripts/colors/switchwall.sh"
coverflow_qml="shell/modules/wallpaperSelector/WallpaperCoverflow.qml"
crossfader_qml="shell/modules/common/widgets/WallpaperCrossfader.qml"

assert_contains "$background_qml" 'enableTransitions: !bgRoot\.externalMainWallpaperActive' \
  "internal wallpaper renderer should keep transitions enabled when awww is only available but not visibly driving the wallpaper"
assert_not_contains "$background_qml" 'enableTransitions: !AwwwBackend\.active' \
  "awww availability alone must not disable the QML crossfader"

assert_contains "$awww_backend_qml" 'readonly property bool dynamicParallaxRequested' \
  "awww backend should know when parallax requires internal rendering"
assert_contains "$awww_backend_qml" 'supportsVisibleMainWallpaper\([^)]*dynamicParallaxRequested' \
  "awww backend should only render visible wallpapers when it can match shell transforms"

# shellcheck disable=SC2016
assert_contains "$switchwall_sh" 'if \[\[ -z \$noswitch_flag \]\]; then' \
  "color-only --noswitch regeneration should not launch duplicate upscale prompts"
# shellcheck disable=SC2016
assert_contains "$switchwall_sh" 'check_and_prompt_upscale "\$imgpath" >/dev/null 2>&1 &' \
  "visible wallpaper switches should run upscale prompts in the background"
assert_contains "$switchwall_sh" 'disown \|\| true' \
  "background upscale prompts should be disowned so switchwall.sh can exit"
# shellcheck disable=SC2016
assert_not_contains "$switchwall_sh" '^[[:space:]]*check_and_prompt_upscale "\$imgpath" &$' \
  "upscale prompt background job should not keep switchwall.sh alive"

assert_contains "$coverflow_qml" 'property string _pendingWallpaperPath' \
  "coverflow should retain a pending wallpaper selection while its overlay closes"
assert_contains "$coverflow_qml" 'id: applyAfterCloseTimer' \
  "coverflow should delay applying selected wallpapers until after the close animation"
assert_contains "$coverflow_qml" 'onTriggered: root\._applyPendingSelection\(\)' \
  "coverflow delayed apply timer should flush the pending wallpaper selection"
assert_contains "$coverflow_qml" 'root\._pendingWallpaperPath,' \
  "coverflow should apply the pending wallpaper after the overlay is closing"
assert_not_contains "$coverflow_qml" 'Wallpapers\.applySelectionTarget\(normalizedPath' \
  "coverflow must not swap wallpapers while its fullscreen overlay is still visible"

if awk '
  /case "random":/ { in_random = 1; next }
  in_random && /case "/ { in_random = 0 }
  in_random && /return "zoom"/ { found = 1 }
  END { exit found ? 0 : 1 }
' "$ROOT_DIR/$crossfader_qml"; then
  fail "internal wallpaper crossfader must not collapse the Random setting to Zoom"
fi

assert_contains "$crossfader_qml" 'property string _activeRandomTransitionType' \
  "internal wallpaper crossfader should freeze a random transition type per switch"
assert_contains "$crossfader_qml" 'function _chooseRandomTransitionEffect\(\)' \
  "internal wallpaper crossfader should choose from available transition effects"
assert_contains "$crossfader_qml" 'root\._chooseRandomTransitionEffect\(\)' \
  "internal wallpaper crossfader should pick the random effect when a wallpaper switch starts"

echo "PASS: wallpaper transition routing"
