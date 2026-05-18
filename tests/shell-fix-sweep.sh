#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_file() {
  local path="$1"
  [[ -f "$ROOT_DIR/$path" ]] || fail "missing $path"
}

assert_contains() {
  local path="$1"
  local pattern="$2"
  local message="$3"
  rg -n -- "$pattern" "$ROOT_DIR/$path" >/dev/null || fail "$message"
}

assert_not_contains() {
  local path="$1"
  local pattern="$2"
  local message="$3"
  if rg -n -- "$pattern" "$ROOT_DIR/$path" >/dev/null; then
    fail "$message"
  fi
}

assert_file "shell/modules/settings/AuroraStyleEditor.qml"
assert_file "shell/scripts/colors/vscode_themegen/main.go"
assert_file "shell/defaults/matugen/templates/steam/millennium-material.css"
assert_file "config/matugen/templates/steam/millennium-material.css"

assert_contains "shell/defaults/config.json" '"enableSteam": false' \
  "defaults should expose enableSteam"
assert_contains "shell/modules/common/Config.qml" "property bool enableSteam" \
  "Config.qml should expose enableSteam"
assert_not_contains "shell/defaults/config.json" "enableAdwSteam" \
  "old Steam config key should be removed from defaults"
assert_not_contains "shell/modules/common/Config.qml" "enableAdwSteam" \
  "old Steam config key should be removed from Config.qml"
assert_contains "shell/scripts/colors/modules/70-steam.sh" "RYOKU_STEAM_THEME_FORCE" \
  "Steam theming should use the Ryoku force env var"
assert_contains "shell/scripts/colors/modules/70-steam.sh" "steam-millennium-material.css" \
  "Steam theming should deploy Millennium Material CSS"
assert_contains "shell/scripts/colors/targets/steam.json" "appearance.wallpaperTheming.enableSteam" \
  "Steam target manifest should use enableSteam"

assert_contains "shell/defaults/config.json" '"aurora"' \
  "defaults should include Aurora style config"
assert_contains "shell/modules/common/Appearance.qml" "aurora.layerTransparentize" \
  "Appearance should apply Aurora transparency"
assert_contains "shell/modules/settings/ThemesConfig.qml" "AuroraStyleEditor.qml" \
  "Themes settings should load the Aurora editor"

assert_contains "shell/modules/common/Directories.qml" "app-palette.json" \
  "ThemePresets should generate app-palette.json"
assert_contains "shell/modules/common/ThemePresets.qml" "generatedAppPalettePath" \
  "ThemePresets should write app-palette.json"
assert_contains "shell/scripts/colors/generate_colors_material.py" "--app-palette-output" \
  "color generator should write the app semantic palette"
assert_contains "shell/scripts/colors/generate_colors_material.py" "--scss-output" \
  "color generator should write SCSS in the unified pass"
assert_contains "shell/scripts/colors/switchwall.sh" "mapfile -t _cfg" \
  "switchwall should batch config reads"
assert_not_contains "shell/scripts/colors/switchwall.sh" "scheme_for_image.py" \
  "scheme detection should happen in the unified color generator"
assert_not_contains "shell/scripts/colors/switchwall.sh" "ILLOGICAL" \
  "switchwall should not use old environment variable names"

assert_contains "shell/modules/common/widgets/ThumbnailImage.qml" "Wallpapers.ensureThumbnailForPath" \
  "wallpaper thumbnails should be queued through Wallpapers service"
assert_not_contains "shell/modules/common/widgets/ThumbnailImage.qml" "Process \\{" \
  "thumbnail items should not spawn one process per image"
assert_contains "shell/services/Wallpapers.qml" "RYOKU_DEBUG_WALLPAPER_URLS" \
  "wallpaper URL debug logging should use a Ryoku env var"
assert_contains "shell/services/Wallpapers.qml" "--workers\", \"4\"" \
  "thumbnail batch generation should limit worker count"

assert_contains "shell/services/Weather.qml" "redactedLogCity" \
  "weather logs should redact city names"
assert_contains "shell/modules/controlPanel/WeatherSection.qml" "visibility" \
  "weather section should expose the location visibility toggle"
assert_contains "shell/services/WindowPreviewService.qml" "QS_DEBUG" \
  "window preview debug logging should be gated"

assert_contains "shell/scripts/colors/vscode/theme_generator.py" "ryoku-material-theme" \
  "Python VS Code theme generator should use the Ryoku extension id"
assert_contains "shell/scripts/colors/vscode/theme_generator.py" "_watch" \
  "Python VS Code theme generator should register a watched theme"
assert_contains "shell/scripts/colors/vscode_themegen/main.go" "ryoku-material-theme" \
  "Go VS Code theme generator should use the Ryoku extension id"
assert_contains "shell/scripts/colors/vscode_themegen/main.go" "extensions.json" \
  "Go VS Code theme generator should update extension registration"

tests/ryoku-upstream-name-scope.sh

echo "PASS: shell fix sweep"
