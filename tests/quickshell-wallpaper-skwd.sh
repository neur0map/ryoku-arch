#!/bin/bash

set -e
cd "$(dirname "$0")/.."

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

pass() {
  echo "OK: $1"
}

service="config/quickshell/ryoku/vendor/brain-shell/src/services/WallpaperService.qml"
popup="config/quickshell/ryoku/vendor/brain-shell/src/popups/WallpaperPopup.qml"
card="config/quickshell/ryoku/vendor/brain-shell/src/popups/WallpaperSkewCard.qml"
filter="config/quickshell/ryoku/vendor/brain-shell/src/popups/WallpaperFilterBar.qml"
settings="config/quickshell/ryoku/vendor/brain-shell/src/popups/WallpaperSettingsPane.qml"

[[ -f $service ]] || fail "$service missing"
[[ -f $popup ]] || fail "$popup missing"

grep -q 'property var wallpaperModel: ListModel' "$service" \
  || fail "WallpaperService should expose wallpaperModel"
grep -q 'property var filteredModel: ListModel' "$service" \
  || fail "WallpaperService should expose filteredModel"
grep -q 'property string selectedSourceFilter' "$service" \
  || fail "WallpaperService should expose selectedSourceFilter"
grep -q 'property string selectedTypeFilter' "$service" \
  || fail "WallpaperService should expose selectedTypeFilter"
grep -q 'property int selectedColorFilter' "$service" \
  || fail "WallpaperService should expose selectedColorFilter"
grep -q 'property string searchQuery' "$service" \
  || fail "WallpaperService should expose searchQuery"
grep -q 'property string statusText' "$service" \
  || fail "WallpaperService should expose statusText"
grep -q 'property bool cacheLoading' "$service" \
  || fail "WallpaperService should expose cacheLoading"
grep -q 'property bool wallhavenLoading' "$service" \
  || fail "WallpaperService should expose wallhavenLoading"
grep -q 'property string pendingApplyPath' "$service" \
  || fail "WallpaperService should hold pending apply path separately from currentWall"
grep -q 'ryoku-ipc' "$service" \
  || fail "WallpaperService should call ryoku-ipc"
grep -q 'wallpaper", "list", "--jsonl"' "$service" \
  || fail "WallpaperService should load JSONL wallpaper list"
grep -q 'JSON.parse(t)' "$service" \
  || fail "WallpaperService should parse JSONL rows"
grep -q 'function updateFilteredModel' "$service" \
  || fail "WallpaperService should update filtered model"
grep -q 'selectedSourceFilter !== ""' "$service" \
  || fail "WallpaperService should filter by source"
grep -q 'selectedTypeFilter !== ""' "$service" \
  || fail "WallpaperService should filter by type"
grep -q 'selectedColorFilter >= 0' "$service" \
  || fail "WallpaperService should filter by color"
grep -q 'onSearchQueryChanged: updateFilteredModel' "$service" \
  || fail "WallpaperService should react to search changes"
grep -q 'function searchWallhaven' "$service" \
  || fail "WallpaperService should support wallhaven search"
grep -q 'function clearWallhavenRows' "$service" \
  || fail "WallpaperService should clear stale Wallhaven rows"
grep -q 'item.source === "wallhaven"' "$service" \
  || fail "WallpaperService should only remove Wallhaven rows"
grep -q 'root.clearWallhavenRows()' "$service" \
  || fail "WallpaperService should clear stale Wallhaven rows before search"
grep -q 'wallpaper", "wallhaven", "search"' "$service" \
  || fail "WallpaperService should call ryoku-ipc Wallhaven search"
grep -q 'function applyItem' "$service" \
  || fail "WallpaperService should apply model items"
grep -q 'wallpaper", "apply", "--type"' "$service" \
  || fail "WallpaperService should apply through ryoku-ipc"
! grep -q 'root.currentWall = item.path' "$service" \
  || fail "WallpaperService should not change currentWall before apply success"
grep -q 'root.currentWall = root.pendingApplyPath' "$service" \
  || fail "WallpaperService should commit currentWall only after apply success"
grep -q 'root.statusText = "Could not apply wallpaper"' "$service" \
  || fail "WallpaperService should surface apply failures"
grep -q 'root.pendingApplyPath = ""' "$service" \
  || fail "WallpaperService should clear pending apply path after exit"
grep -q 'root.pendingApplyType = ""' "$service" \
  || fail "WallpaperService should clear pending apply type after exit"
grep -q 'function apply(path)' "$service" \
  || fail "WallpaperService should keep compatibility apply wrapper"

for path in "$card" "$filter" "$settings"; do
  [[ -f $path ]] || fail "$path missing"
done

grep -q 'import QtQuick.Shapes' "$card" \
  || fail "WallpaperSkewCard should use QtQuick Shapes for the skew mask"
grep -q 'import QtQuick.Effects' "$card" \
  || fail "WallpaperSkewCard should use QtQuick Effects for masking"
grep -q 'import QtMultimedia' "$card" \
  || fail "WallpaperSkewCard should support video previews"
grep -q 'required property var itemData' "$card" \
  || fail "WallpaperSkewCard should accept model item data"
grep -q 'MediaPlayer' "$card" \
  || fail "WallpaperSkewCard should use MediaPlayer for selected videos"
grep -q 'VideoOutput' "$card" \
  || fail "WallpaperSkewCard should render video output"
grep -q 'MultiEffect' "$card" \
  || fail "WallpaperSkewCard should apply the skew mask through MultiEffect"
grep -q 'root.itemData.type === "video"' "$card" \
  || fail "WallpaperSkewCard should branch on video wallpaper type"
grep -q 'signal activated' "$card" \
  || fail "WallpaperSkewCard should expose activation for popup integration"

grep -q 'signal settingsRequested' "$filter" \
  || fail "WallpaperFilterBar should expose settingsRequested"
grep -q 'signal rebuildRequested' "$filter" \
  || fail "WallpaperFilterBar should expose rebuildRequested"
grep -q 'implicitWidth:' "$filter" \
  || fail "WallpaperFilterBar should expose stable implicitWidth"
grep -q 'implicitHeight:' "$filter" \
  || fail "WallpaperFilterBar should expose stable implicitHeight"
grep -q 'Flickable' "$filter" \
  || fail "WallpaperFilterBar should keep overflow scrollable"
grep -q 'id: row' "$filter" \
  || fail "WallpaperFilterBar should give the content row a stable id"
grep -q 'contentWidth: row.implicitWidth' "$filter" \
  || fail "WallpaperFilterBar should size scroll content from the row"
grep -q 'clip: true' "$filter" \
  || fail "WallpaperFilterBar should clip constrained overflow"
grep -q 'WallpaperService.selectedTypeFilter' "$filter" \
  || fail "WallpaperFilterBar should update the type filter"
grep -q 'WallpaperService.selectedSourceFilter' "$filter" \
  || fail "WallpaperFilterBar should update the source filter"
grep -q 'WallpaperService.searchQuery' "$filter" \
  || fail "WallpaperFilterBar should update searchQuery"
grep -q 'WallpaperService.searchWallhaven' "$filter" \
  || fail "WallpaperFilterBar should trigger Wallhaven search"
grep -q 'WallpaperService.selectedColorFilter' "$filter" \
  || fail "WallpaperFilterBar should update color filtering"
grep -q 'model: 13' "$filter" \
  || fail "WallpaperFilterBar should render hue and neutral swatches"

grep -q 'property bool open' "$settings" \
  || fail "WallpaperSettingsPane should expose open state"
grep -q 'signal closeRequested' "$settings" \
  || fail "WallpaperSettingsPane should expose closeRequested"
grep -q 'videoBackend' "$settings" \
  || fail "WallpaperSettingsPane should show video backend status"
grep -q 'wallpaper", "cache", "rebuild"' "$settings" \
  || fail "WallpaperSettingsPane should rebuild cache through ryoku-ipc"
grep -q 'WallpaperService.refresh()' "$settings" \
  || fail "WallpaperSettingsPane should refresh the model after rebuild"
! grep -q 'rebuildRequested' "$settings" \
  || fail "WallpaperSettingsPane should not expose unused rebuild ownership"
grep -q 'anchors.margins: root.open ? 16 : 0' "$settings" \
  || fail "WallpaperSettingsPane should avoid negative inner width while closed"

if command -v qmllint >/dev/null; then
  qmllint -I config/quickshell/ryoku/vendor/brain-shell/src "$card" "$filter" "$settings"
fi

pass "quickshell skwd wallpaper service"
