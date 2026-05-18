#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

require_file_contains() {
  local file="$1"
  local pattern="$2"
  local description="$3"

  grep -Eq "$pattern" "$ROOT_DIR/$file" \
    || fail "$description"
}

require_file_not_contains() {
  local file="$1"
  local pattern="$2"
  local description="$3"

  if grep -Eq "$pattern" "$ROOT_DIR/$file"; then
    fail "$description"
  fi
}

require_file_contains "shell/dots/sddm/pixel/Main.qml" 'Qt5Compat\.GraphicalEffects' \
  "pixel SDDM theme should use Qt6-compatible graphical effects"
require_file_not_contains "shell/dots/sddm/pixel/Main.qml" 'QtGraphicalEffects' \
  "pixel SDDM theme should not import QtGraphicalEffects"
require_file_contains "shell/dots/sddm/pixel/metadata.desktop" '^\[SddmGreeterTheme\]$' \
  "pixel SDDM metadata should use SddmGreeterTheme"
require_file_contains "shell/dots/sddm/pixel/metadata.desktop" '^QtVersion=6$' \
  "pixel SDDM metadata should declare QtVersion=6"

require_file_contains "shell/services/Audio.qml" 'wpctlSetMicMute' \
  "Audio service should have a wpctl mic mute process"
require_file_contains "shell/services/Audio.qml" 'wpctlSetSourceVolume' \
  "Audio service should have a wpctl source volume process"
require_file_contains "shell/services/Audio.qml" 'wpctl", "get-volume"' \
  "Audio service should refresh mic state from wpctl get-volume"
require_file_contains "shell/modules/controlPanel/SlidersSection.qml" 'value: Audio\.micVolume' \
  "mic slider should read Audio.micVolume"
require_file_contains "shell/modules/waffle/looks/WIcons.qml" 'Audio\?\.micMuted' \
  "waffle mic icon should read Audio.micMuted"

require_file_contains "shell/services/Booru.qml" 'https://api\.waifu\.im/images/' \
  "waifu.im should use the current images endpoint"
require_file_contains "shell/services/Booru.qml" 'response = response\.items' \
  "waifu.im should parse the current response items key"
require_file_contains "shell/services/Booru.qml" 'IncludedTags=' \
  "waifu.im should use IncludedTags params"
require_file_contains "shell/services/Booru.qml" 'url \+= "json"' \
  "t.alcy.cc should use the JSON API path"
require_file_contains "shell/services/Booru.qml" '"rating": "s"' \
  "zerochan normalized rating should be s"
require_file_contains "shell/modules/sidebarLeft/Anime.qml" 'name: "toggle-tags"' \
  "booru sidebar should expose /toggle-tags"

require_file_contains "shell/modules/bar/ShellUpdateIndicator.qml" 'maxW: 280' \
  "update popup should cap width at 280px"

for file in \
  shell/modules/clipboard/ClipboardPanel.qml \
  shell/modules/common/ThemePresets.qml \
  shell/modules/settings/InterfaceConfig.qml \
  shell/services/FontSyncService.qml \
  shell/services/WallpaperListener.qml; do
  require_file_contains "$file" 'function _log\(' "$file should expose a QS_DEBUG log helper"
done

echo "PASS: upstream audit static gaps covered"
