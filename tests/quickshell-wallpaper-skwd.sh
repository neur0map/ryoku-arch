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
base_packages="install/ryoku-base.packages"
aur_packages="install/ryoku-aur.packages"

[[ -f $service ]] || fail "$service missing"
[[ -f $popup ]] || fail "$popup missing"
[[ -f $base_packages ]] || fail "$base_packages missing"
[[ -f $aur_packages ]] || fail "$aur_packages missing"

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
grep -q 'property string activeWallhavenQuery' "$service" \
  || fail "WallpaperService should track the query that produced Wallhaven rows"
grep -q 'property string statusText' "$service" \
  || fail "WallpaperService should expose statusText"
grep -q 'property bool cacheLoading' "$service" \
  || fail "WallpaperService should expose cacheLoading"
grep -q 'property bool listLoading' "$service" \
  || fail "WallpaperService should track list loading separately"
grep -q 'property bool cacheRebuilding' "$service" \
  || fail "WallpaperService should track cache rebuild separately"
grep -q 'property bool reloadAfterRebuild' "$service" \
  || fail "WallpaperService should queue reloads after overlapping rebuilds"
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
grep -q 'function searchMatchesItem' "$service" \
  || fail "WallpaperService should centralize local vs Wallhaven search filtering"
grep -q 'item.source === "wallhaven" && q === root.activeWallhavenQuery' "$service" \
  || fail "WallpaperService should show Wallhaven rows for the API query that produced them"
grep -q 'function rebuildCache()' "$service" \
  || fail "WallpaperService should expose cache rebuild"
grep -q 'wallpaper", "cache", "rebuild"' "$service" \
  || fail "WallpaperService should rebuild cache through ryoku-ipc"
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
grep -q 'root.activeWallhavenQuery = trimmedQuery.toLowerCase()' "$service" \
  || fail "WallpaperService should remember the normalized Wallhaven query before loading results"
grep -q 'root.searchQuery = trimmedQuery' "$service" \
  || fail "WallpaperService should keep UI filtering synchronized with submitted Wallhaven searches"
grep -q 'wallpaper", "wallhaven", "search"' "$service" \
  || fail "WallpaperService should call ryoku-ipc Wallhaven search"
grep -q 'wallpaper", "wallhaven", "download"' "$service" \
  || fail "WallpaperService should download Wallhaven rows before applying"
grep -q 'function isRemotePath' "$service" \
  || fail "WallpaperService should detect remote Wallhaven paths"
grep -q 'root.startApply(root.downloadedWallhavenPath, "image")' "$service" \
  || fail "WallpaperService should apply downloaded Wallhaven files"
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
grep -q 'height: 236' "$card" \
  || fail "WallpaperSkewCard should use slimmer card height"
grep -q 'property bool hovered' "$card" \
  || fail "WallpaperSkewCard should track hover state"
grep -q 'readonly property bool expanded: root.selected || root.hovered' "$card" \
  || fail "WallpaperSkewCard should expand on hover without changing selection"
grep -q 'width: expanded ? 300 : 92' "$card" \
  || fail "WallpaperSkewCard should use hover/selection expansion width"
grep -q 'scale: root.hovered && !root.selected ? 1.025 : 1.0' "$card" \
  || fail "WallpaperSkewCard should subtly lift hovered cards"
grep -q 'Behavior on scale' "$card" \
  || fail "WallpaperSkewCard should animate hover lift"
grep -q 'onHoveredChanged: root.hovered = hovered' "$card" \
  || fail "WallpaperSkewCard should update hover state from HoverHandler"
grep -q 'MediaPlayer' "$card" \
  || fail "WallpaperSkewCard should use MediaPlayer for selected videos"
grep -q 'AudioOutput' "$card" \
  || fail "WallpaperSkewCard should mute video previews through AudioOutput"
grep -q 'audioOutput: mutedOutput' "$card" \
  || fail "WallpaperSkewCard should attach muted AudioOutput to MediaPlayer"
if grep -A8 'MediaPlayer {' "$card" | grep -Eq '^[[:space:]]*muted:'; then
  fail "WallpaperSkewCard should not assign unsupported MediaPlayer.muted"
fi
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
grep -q 'signal searchSubmitted' "$filter" \
  || fail "WallpaperFilterBar should notify the popup after submitting search"
grep -q 'function submitWallhavenSearch' "$filter" \
  || fail "WallpaperFilterBar should centralize Wallhaven search submission"
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
grep -q 'modelData.source === "wallhaven" && searchInput.text.trim() !== ""' "$filter" \
  || fail "WallpaperFilterBar should submit the typed query when switching to Web"
grep -q 'WallpaperService.searchQuery' "$filter" \
  || fail "WallpaperFilterBar should update searchQuery"
grep -q 'WallpaperService.searchWallhaven' "$filter" \
  || fail "WallpaperFilterBar should trigger Wallhaven search"
grep -q 'root.searchSubmitted()' "$filter" \
  || fail "WallpaperFilterBar should emit after Wallhaven search submission"
grep -q 'event.accepted = true' "$filter" \
  || fail "WallpaperFilterBar should keep Return from bubbling to the popup apply shortcut"
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
grep -q 'WallpaperService.rebuildCache()' "$settings" \
  || fail "WallpaperSettingsPane should rebuild through WallpaperService"
! grep -q 'rebuildRequested' "$settings" \
  || fail "WallpaperSettingsPane should not expose unused rebuild ownership"
grep -q 'anchors.margins: root.open ? 16 : 0' "$settings" \
  || fail "WallpaperSettingsPane should avoid negative inner width while closed"

grep -q 'WallpaperFilterBar' "$popup" \
  || fail "WallpaperPopup should render the SKWD filter bar"
grep -q 'WallpaperSkewCard' "$popup" \
  || fail "WallpaperPopup should render skewed wallpaper cards"
grep -q 'WallpaperSettingsPane' "$popup" \
  || fail "WallpaperPopup should render the settings pane"
grep -q 'model: WallpaperService.filteredModel' "$popup" \
  || fail "WallpaperPopup should bind cards to the filtered model"
grep -q 'WallpaperService.applyItem(item)' "$popup" \
  || fail "WallpaperPopup should apply selected model items"
grep -q 'WallpaperService.previewWall = item.path' "$popup" \
  || fail "WallpaperPopup should preview using model item paths"
grep -q 'anchors.fill: parent' "$popup" \
  || fail "WallpaperPopup should keep a transparent outside-click surface"
grep -q 'attachedEdge: "bottom"' "$popup" \
  || fail "WallpaperPopup should attach the selector shape to the bottom edge"
grep -Eq 'readonly property int selectorMaxWidth:[[:space:]]+1040' "$popup" \
  || fail "WallpaperPopup should use a slimmer selector width"
grep -Eq 'readonly property int selectorHeight:[[:space:]]+380' "$popup" \
  || fail "WallpaperPopup should use a slimmer selector height"
grep -q 'y: Popups.wallpaperOpen ? parent.height - height : parent.height + Theme.borderWidth' "$popup" \
  || fail "WallpaperPopup should slide up from the bottom"
! grep -q 'id: scrim' "$popup" \
  || fail "WallpaperPopup should not use a dimming fullscreen scrim"
! grep -q 'Behavior on opacity' "$popup" \
  || fail "WallpaperPopup should not fade in or out"
! grep -q 'scale: Popups.wallpaperOpen' "$popup" \
  || fail "WallpaperPopup should not scale-fade"
grep -q 'WlrKeyboardFocus.Exclusive' "$popup" \
  || fail "WallpaperPopup should keep exclusive keyboard focus"
grep -q 'Keys.onEscapePressed: Popups.wallpaperOpen = false' "$popup" \
  || fail "WallpaperPopup should close on Escape"
grep -q 'onClicked: Popups.wallpaperOpen = false' "$popup" \
  || fail "WallpaperPopup should close on outside click"
grep -q 'WallpaperService.refresh()' "$popup" \
  || fail "WallpaperPopup should refresh wallpapers on open"
grep -q 'WallpaperService.rebuildCache()' "$popup" \
  || fail "WallpaperPopup should rebuild cache from the filter bar"
grep -q 'onSearchSubmitted: keyScope.forceActiveFocus()' "$popup" \
  || fail "WallpaperPopup should restore selector keyboard navigation after searches"
grep -q 'anchors.top:    true' "$popup" \
  || fail "WallpaperPopup should be a fullscreen overlay"
grep -q 'anchors.bottom: true' "$popup" \
  || fail "WallpaperPopup should cover the bottom edge"
! grep -q 'model: content.filteredWallpapers' "$popup" \
  || fail "WallpaperPopup should not use the old path-array filtered wallpaper model"
! grep -q 'WallpaperService.wallpapers' "$popup" \
  || fail "WallpaperPopup should not depend on the old wallpaper path array"

grep -q '^curl$' "$base_packages" \
  || fail "curl should be explicitly installed for Wallhaven integration"
grep -q '^jq$' "$base_packages" \
  || fail "jq should be installed for wallpaper JSON helpers"
grep -q '^imagemagick$' "$base_packages" \
  || fail "imagemagick should be installed for image thumbnails"
grep -q '^ffmpegthumbnailer$' "$base_packages" \
  || fail "ffmpegthumbnailer should be installed for video thumbnails"
grep -q '^qt6-multimedia-ffmpeg$' "$base_packages" \
  || fail "qt6 multimedia ffmpeg backend should be installed for QML video preview"
grep -q '^mpvpaper$' "$aur_packages" \
  || fail "mpvpaper should be installed for video wallpaper apply"

if command -v qmllint >/dev/null; then
  qmllint -I config/quickshell/ryoku/vendor/brain-shell/src "$service" "$popup" "$card" "$filter" "$settings"
fi

pass "quickshell skwd wallpaper service"
