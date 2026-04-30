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
theme_card="config/quickshell/ryoku/vendor/brain-shell/src/popups/ThemeCard.qml"
appearance_card="config/quickshell/ryoku/vendor/brain-shell/src/popups/AppearanceChoiceCard.qml"
filter="config/quickshell/ryoku/vendor/brain-shell/src/popups/WallpaperFilterBar.qml"
settings="config/quickshell/ryoku/vendor/brain-shell/src/popups/WallpaperSettingsPane.qml"
skwd_button="config/quickshell/ryoku/vendor/brain-shell/src/popups/SkwdButton.qml"
tag_cloud="config/quickshell/ryoku/vendor/brain-shell/src/popups/WallpaperTagCloud.qml"
wallhaven_browser="config/quickshell/ryoku/vendor/brain-shell/src/popups/WallpaperWallhavenBrowser.qml"
steam_browser="config/quickshell/ryoku/vendor/brain-shell/src/popups/WallpaperSteamWorkshopBrowser.qml"
monitor_picker="config/quickshell/ryoku/vendor/brain-shell/src/popups/WallpaperMonitorPicker.qml"
hex_card="config/quickshell/ryoku/vendor/brain-shell/src/popups/WallpaperHexCard.qml"
mosaic_card="config/quickshell/ryoku/vendor/brain-shell/src/popups/WallpaperMosaicCard.qml"
skwd_upstream="config/quickshell/ryoku/vendor/skwd-wall/UPSTREAM.md"
skwd_license="config/quickshell/ryoku/vendor/skwd-wall/LICENSE"
font_list="bin/ryoku-font-list"
cursor_list="bin/ryoku-cursor-list"
base_packages="install/ryoku-base.packages"
aur_packages="install/ryoku-aur.packages"

[[ -f $service ]] || fail "$service missing"
[[ -f $popup ]] || fail "$popup missing"
[[ -f $font_list ]] || fail "$font_list missing"
[[ -f $cursor_list ]] || fail "$cursor_list missing"
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
grep -q 'property string sortMode' "$service" \
  || fail "WallpaperService should expose skwd-style color/date sorting"
grep -q 'property var selectedTags' "$service" \
  || fail "WallpaperService should expose selected tag filters"
grep -q 'property var tagsDb' "$service" \
  || fail "WallpaperService should expose wallpaper tag metadata"
grep -q 'property var favouritesDb' "$service" \
  || fail "WallpaperService should expose favourite metadata"
grep -q 'property bool favouriteFilterActive' "$service" \
  || fail "WallpaperService should expose favourite filtering"
grep -q 'property string displayMode' "$service" \
  || fail "WallpaperService should expose skwd-style selector display mode"
grep -q 'property bool matugenEnabled' "$service" \
  || fail "WallpaperService should expose skwd-style matugen feature settings"
grep -q 'property bool ollamaEnabled' "$service" \
  || fail "WallpaperService should expose skwd-style ollama feature settings"
grep -q 'property bool steamEnabled' "$service" \
  || fail "WallpaperService should expose skwd-style Steam feature settings"
grep -q 'property bool wallhavenEnabled' "$service" \
  || fail "WallpaperService should expose skwd-style Wallhaven feature settings"
grep -q 'property int randomInterval' "$service" \
  || fail "WallpaperService should expose random rotation interval"
grep -q 'property bool randomRotationActive' "$service" \
  || fail "WallpaperService should expose random rotation state"
grep -q 'property string imageOptimizePreset' "$service" \
  || fail "WallpaperService should expose image optimization settings"
grep -q 'property string videoConvertPreset' "$service" \
  || fail "WallpaperService should expose video conversion settings"
grep -q 'property string externalWallpaperCommand' "$service" \
  || fail "WallpaperService should expose external wallpaper command settings"
grep -q 'property var postProcessingCommands' "$service" \
  || fail "WallpaperService should expose postprocessing settings"
grep -q 'property string selectedMonitor' "$service" \
  || fail "WallpaperService should expose monitor selection settings"
grep -q 'function toggleFavourite' "$service" \
  || fail "WallpaperService should toggle favourites"
grep -q 'function setWallpaperTags' "$service" \
  || fail "WallpaperService should write wallpaper tags"
grep -q 'function randomApply' "$service" \
  || fail "WallpaperService should support random wallpaper apply"
grep -q 'function toggleRandomRotation' "$service" \
  || fail "WallpaperService should support continuous random wallpaper rotation"
grep -q 'function optimizeImages' "$service" \
  || fail "WallpaperService should expose image optimization action"
grep -q 'function convertVideos' "$service" \
  || fail "WallpaperService should expose video conversion action"
grep -q 'function startOllamaTagging' "$service" \
  || fail "WallpaperService should expose automated Ollama tagging action"
grep -q 'function settingsSummary' "$service" \
  || fail "WallpaperService should expose settings summaries for the UI"
grep -q 'function deleteWallpaperItem' "$service" \
  || fail "WallpaperService should support skwd-style delete/remove actions"
grep -q 'function saveMeta' "$service" \
  || fail "WallpaperService should persist tags/favourites/display settings"
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

for path in "$card" "$theme_card" "$appearance_card" "$filter" "$settings" "$skwd_button" "$tag_cloud" "$wallhaven_browser" "$steam_browser" "$monitor_picker" "$hex_card" "$mosaic_card" "$skwd_upstream" "$skwd_license"; do
  [[ -f $path ]] || fail "$path missing"
done

grep -q 'liixini/skwd-wall' "$skwd_upstream" \
  || fail "Ryoku should attribute the skwd-wall design source"
grep -q 'Copyright (c) 2026 liixini' "$skwd_license" \
  || fail "Ryoku should carry skwd-wall's MIT copyright notice"

grep -q 'import QtQuick.Shapes' "$card" \
  || fail "WallpaperSkewCard should use QtQuick Shapes for the skew mask"
grep -q 'import QtQuick.Effects' "$card" \
  || fail "WallpaperSkewCard should use QtQuick Effects for masking"
grep -q 'import QtMultimedia' "$card" \
  || fail "WallpaperSkewCard should support video previews"
grep -q 'required property var itemData' "$card" \
  || fail "WallpaperSkewCard should accept model item data"
grep -q 'height: 278' "$card" \
  || fail "WallpaperSkewCard should fit the bottom-sheet slice height"
grep -q 'property bool hovered' "$card" \
  || fail "WallpaperSkewCard should track hover state"
grep -q 'property int skewOffset: 22' "$card" \
  || fail "WallpaperSkewCard should keep the tilted card mask"
grep -q 'property int expandedWidth' "$card" \
  || fail "WallpaperSkewCard should expose an expanded slice width"
grep -q 'property int hoverWidth' "$card" \
  || fail "WallpaperSkewCard should reveal more wallpaper on hover"
grep -q 'property int sliceWidth' "$card" \
  || fail "WallpaperSkewCard should expose a compact slice width"
grep -q 'width: root.selected ? root.expandedWidth : (root.hovered ? root.hoverWidth : root.sliceWidth)' "$card" \
  || fail "WallpaperSkewCard should animate between compact, hover, and selected slice widths"
grep -q 'readonly property real mediaScale' "$card" \
  || fail "WallpaperSkewCard should reveal more wallpaper by animating crop/scale"
grep -q 'Behavior on width' "$card" \
  || fail "WallpaperSkewCard should animate slice expansion"
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

grep -q 'liixini/skwd-wall' "$skwd_button" \
  || fail "SkwdButton should document its skwd-wall source"
grep -q 'Canvas' "$skwd_button" \
  || fail "SkwdButton should draw skewed buttons with Canvas"
grep -q 'ctx.moveTo(sk, 0)' "$skwd_button" \
  || fail "SkwdButton should draw a parallelogram shape"
grep -q 'import QtQuick.Shapes' "$appearance_card" \
  || fail "AppearanceChoiceCard should use Shapes for skewed font/cursor cards"
grep -q 'import QtQuick.Effects' "$appearance_card" \
  || fail "AppearanceChoiceCard should mask preview cards with MultiEffect"
grep -q 'property int skewOffset' "$appearance_card" \
  || fail "AppearanceChoiceCard should expose skew geometry"
grep -q 'width: root.selected || root.hovered ? root.expandedWidth : root.compactWidth' "$appearance_card" \
  || fail "AppearanceChoiceCard should use compact and expanded skew card widths"
grep -q 'MultiEffect' "$appearance_card" \
  || fail "AppearanceChoiceCard should render previews through the skew mask"

grep -q 'signal settingsRequested' "$filter" \
  || fail "WallpaperFilterBar should expose settingsRequested"
grep -q 'signal rebuildRequested' "$filter" \
  || fail "WallpaperFilterBar should expose rebuildRequested"
grep -q 'signal searchSubmitted' "$filter" \
  || fail "WallpaperFilterBar should notify the popup after submitting search"
grep -q 'property string activeMode' "$filter" \
  || fail "WallpaperFilterBar should track appearance mode"
grep -q 'signal modeRequested' "$filter" \
  || fail "WallpaperFilterBar should request mode switches"
grep -q 'function submitSearch' "$filter" \
  || fail "WallpaperFilterBar should centralize local-first search submission"
grep -q 'implicitWidth:' "$filter" \
  || fail "WallpaperFilterBar should expose stable implicitWidth"
grep -q 'implicitHeight: root.activeMode === "wallpaper" ? 34 : 32' "$filter" \
  || fail "WallpaperFilterBar should use a compact single-row wallpaper height"
grep -q 'Flickable' "$filter" \
  || fail "WallpaperFilterBar should keep overflow scrollable"
grep -q 'id: row' "$filter" \
  || fail "WallpaperFilterBar should give the content row a stable id"
grep -q 'contentWidth: row.width' "$filter" \
  || fail "WallpaperFilterBar should fit controls to the available bottom-sheet width"
grep -q 'Flow {' "$filter" \
  || fail "WallpaperFilterBar should wrap skwd controls instead of clipping them"
grep -q 'clip: true' "$filter" \
  || fail "WallpaperFilterBar should clip constrained overflow"
grep -q 'WallpaperService.selectedTypeFilter' "$filter" \
  || fail "WallpaperFilterBar should update the type filter"
grep -q 'WallpaperService.selectedSourceFilter' "$filter" \
  || fail "WallpaperFilterBar should update the source filter"
! grep -q 'root.modeRequested(modelData.mode)' "$filter" \
  || fail "WallpaperFilterBar should not own the fixed appearance section rail"
grep -q 'root.activeMode === "wallpaper"' "$filter" \
  || fail "WallpaperFilterBar should hide wallpaper-only controls in theme mode"
grep -q 'modelData.source === "wallhaven" && searchInput.text.trim() !== ""' "$filter" \
  || fail "WallpaperFilterBar should submit the typed query when switching to Web"
grep -q 'WallpaperService.selectedSourceFilter === "wallhaven"' "$filter" \
  || fail "WallpaperFilterBar should only search web when Web is selected"
grep -q 'WallpaperService.searchQuery' "$filter" \
  || fail "WallpaperFilterBar should update searchQuery"
grep -q 'ThemeService.searchQuery' "$filter" \
  || fail "WallpaperFilterBar should update theme searchQuery"
grep -q 'FontService.searchQuery' "$filter" \
  || fail "WallpaperFilterBar should update font searchQuery"
grep -q 'CursorService.searchQuery' "$filter" \
  || fail "WallpaperFilterBar should update cursor searchQuery"
grep -q 'WallpaperService.searchWallhaven' "$filter" \
  || fail "WallpaperFilterBar should trigger Wallhaven search"
grep -q 'root.searchSubmitted()' "$filter" \
  || fail "WallpaperFilterBar should emit after Wallhaven search submission"
grep -q 'event.accepted = true' "$filter" \
  || fail "WallpaperFilterBar should keep Return from bubbling to the popup apply shortcut"
grep -q 'WallpaperService.selectedColorFilter' "$filter" \
  && fail "WallpaperFilterBar should move color swatches into the settings card"
grep -q 'model: 13' "$filter" \
  && fail "WallpaperFilterBar should not render hue swatches in the top bar"
grep -q 'SkwdButton' "$filter" \
  || fail "WallpaperFilterBar should use skwd-style skewed controls"
grep -q 'sortMode' "$filter" \
  && fail "WallpaperFilterBar should move sort controls into the settings card"
grep -q 'displayModeRequested' "$filter" \
  && fail "WallpaperFilterBar should move display-mode controls into the settings card"
grep -q 'matugenMode' "$filter" \
  && fail "WallpaperFilterBar should move light/dark mode controls into the settings card"
grep -q 'favouriteFilterActive' "$filter" \
  || fail "WallpaperFilterBar should expose the favourite filter"
grep -q 'randomApply' "$filter" \
  || fail "WallpaperFilterBar should expose random wallpaper apply"
grep -q 'toggleRandomRotation' "$filter" \
  && fail "WallpaperFilterBar should move continuous random wallpaper rotation into settings"
grep -q 'tagCloudRequested' "$filter" \
  || fail "WallpaperFilterBar should expose tag cloud toggling"
grep -q 'wallhavenRequested' "$filter" \
  || fail "WallpaperFilterBar should expose the Wallhaven browser"
grep -q 'steamWorkshopRequested' "$filter" \
  && fail "WallpaperFilterBar should move Steam Workshop browsing behind settings/Wallhaven surfaces"
grep -q 'monitorPickerRequested' "$filter" \
  && fail "WallpaperFilterBar should move monitor picking into the settings card"
grep -q 'WallpaperService.settingsSummary' "$filter" \
  || fail "WallpaperFilterBar should show skwd-style count/status summaries"
grep -q 'startOllamaTagging' "$filter" \
  && fail "WallpaperFilterBar should move Ollama tagging into settings"
grep -q 'modelData.displayMode' "$filter" \
  && fail "WallpaperFilterBar should not keep SLC/HEX/WALL/MOS in the top bar"

grep -q 'property bool open' "$settings" \
  || fail "WallpaperSettingsPane should expose open state"
grep -q 'signal closeRequested' "$settings" \
  || fail "WallpaperSettingsPane should expose closeRequested"
grep -q 'activeTab: "selector"' "$settings" \
  || fail "WallpaperSettingsPane should start with skwd selector settings"
grep -q 'SELECTOR' "$settings" \
  || fail "WallpaperSettingsPane should expose the Selector tab"
grep -q 'GENERAL' "$settings" \
  || fail "WallpaperSettingsPane should expose the General tab"
grep -q 'PATHS' "$settings" \
  || fail "WallpaperSettingsPane should expose the Paths tab"
grep -q 'PERFORMANCE' "$settings" \
  || fail "WallpaperSettingsPane should expose the Performance tab"
grep -q 'EXTERNAL' "$settings" \
  || fail "WallpaperSettingsPane should expose the External/Postprocessing tab"
grep -q 'KEYBINDS' "$settings" \
  || fail "WallpaperSettingsPane should expose the Keybinds tab"
grep -q 'WALLHAVEN' "$settings" \
  || fail "WallpaperSettingsPane should expose the Wallhaven tab"
grep -q 'OLLAMA' "$settings" \
  || fail "WallpaperSettingsPane should expose the Ollama tab"
grep -q 'MATUGEN' "$settings" \
  || fail "WallpaperSettingsPane should expose the Matugen tab"
grep -q 'WallpaperService.rebuildCache()' "$settings" \
  || fail "WallpaperSettingsPane should rebuild through WallpaperService"
grep -q 'WallpaperService.optimizeImages()' "$settings" \
  || fail "WallpaperSettingsPane should expose image optimization"
grep -q 'WallpaperService.convertVideos()' "$settings" \
  || fail "WallpaperSettingsPane should expose video conversion"
grep -q 'WallpaperService.toggleRandomRotation()' "$settings" \
  || fail "WallpaperSettingsPane should expose continuous random rotation"
grep -q 'WallpaperService.startOllamaTagging()' "$settings" \
  || fail "WallpaperSettingsPane should expose Ollama tagging"
grep -q 'WallpaperService.setSetting' "$settings" \
  || fail "WallpaperSettingsPane should persist skwd-style setting changes"
grep -q 'component SettingsChoice' "$settings" \
  || fail "WallpaperSettingsPane should render settings with toggle/radio choice rows"
grep -q 'choiceDot' "$settings" \
  || fail "WallpaperSettingsPane should draw radio/check indicators for settings choices"
grep -q 'WallpaperService.sortMode = modelData.mode' "$settings" \
  || fail "WallpaperSettingsPane should own skwd-style sorting controls"
grep -q 'WallpaperService.displayMode = modelData.mode' "$settings" \
  || fail "WallpaperSettingsPane should own skwd-style display-mode controls"
grep -q 'WallpaperService.setSetting("matugenMode"' "$settings" \
  || fail "WallpaperSettingsPane should own light/dark mode controls"
grep -q 'WallpaperService.selectedColorFilter' "$settings" \
  || fail "WallpaperSettingsPane should own color filter controls"
grep -q 'model: 13' "$settings" \
  || fail "WallpaperSettingsPane should render hue and neutral choices"
grep -q 'Steam Workshop' "$settings" \
  || fail "WallpaperSettingsPane should expose Steam Workshop settings"
grep -q 'Postprocessing' "$settings" \
  || fail "WallpaperSettingsPane should expose postprocessing settings"
grep -q 'Wallpaper Engine' "$settings" \
  || fail "WallpaperSettingsPane should expose Wallpaper Engine settings"
! grep -q 'rebuildRequested' "$settings" \
  || fail "WallpaperSettingsPane should not expose unused rebuild ownership"
grep -q 'anchors.margins: root.open ? 16 : 0' "$settings" \
  || fail "WallpaperSettingsPane should avoid negative inner width while closed"

grep -q 'WallpaperFilterBar' "$popup" \
  || fail "WallpaperPopup should render the SKWD filter bar"
grep -q 'WallpaperSkewCard' "$popup" \
  || fail "WallpaperPopup should render skewed wallpaper cards"
grep -q 'AppearanceChoiceCard' "$popup" \
  || fail "WallpaperPopup should render font and cursor appearance cards"
grep -q 'id: modeRail' "$popup" \
  || fail "WallpaperPopup should keep appearance sections fixed in a left rail"
grep -q '{ label: "Fonts", mode: "font" }' "$popup" \
  || fail "WallpaperPopup should expose the font section in the fixed rail"
grep -q '{ label: "Cursors", mode: "cursor" }' "$popup" \
  || fail "WallpaperPopup should expose the cursor section in the fixed rail"
grep -q 'WallpaperSettingsPane' "$popup" \
  || fail "WallpaperPopup should render the settings pane"
grep -q 'WallpaperTagCloud' "$popup" \
  || fail "WallpaperPopup should render skwd-style tag cloud"
grep -q 'WallpaperWallhavenBrowser' "$popup" \
  || fail "WallpaperPopup should render skwd-style Wallhaven browser"
grep -q 'WallpaperSteamWorkshopBrowser' "$popup" \
  || fail "WallpaperPopup should render skwd-style Steam Workshop browser"
grep -q 'WallpaperMonitorPicker' "$popup" \
  || fail "WallpaperPopup should render skwd-style monitor picker"
grep -q 'WallpaperHexCard' "$popup" \
  || fail "WallpaperPopup should render skwd-style hex mode"
grep -q 'WallpaperMosaicCard' "$popup" \
  || fail "WallpaperPopup should render skwd-style mosaic mode"
grep -q 'GridView' "$popup" \
  || fail "WallpaperPopup should support the skwd wall/grid display mode"
grep -q 'displayMode' "$popup" \
  || fail "WallpaperPopup should switch wallpaper display modes"
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
grep -Eq 'readonly property int selectorMaxWidth:[[:space:]]+1120' "$popup" \
  || fail "WallpaperPopup should fit the wider skwd-style bottom selector"
grep -Eq 'readonly property int selectorHeight:[[:space:]]+480' "$popup" \
  || fail "WallpaperPopup should fit the full skwd-style controls inside the bottom sheet"
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
grep -q 'ThemeService.refresh()' "$popup" \
  || fail "WallpaperPopup should refresh themes through ThemeService"
grep -q 'FontService.refresh()' "$popup" \
  || fail "WallpaperPopup should refresh fonts through FontService"
grep -q 'CursorService.refresh()' "$popup" \
  || fail "WallpaperPopup should refresh cursors through CursorService"
grep -q 'WallpaperService.rebuildCache()' "$popup" \
  || fail "WallpaperPopup should rebuild cache from the filter bar"
grep -q 'clearTransientSearch()' "$popup" \
  || fail "WallpaperPopup should reset stale search state when closing/reopening"
grep -q 'Behavior on contentX' "$popup" \
  || fail "WallpaperPopup should animate selection-driven horizontal scrolling"
grep -q 'cacheBuffer: Math.max(width' "$popup" \
  || fail "WallpaperPopup should pre-buffer large wallpaper lists to reduce new-card jank"
grep -q 'reuseItems: true' "$popup" \
  || fail "WallpaperPopup should reuse list delegates for large wallpaper lists"
grep -q 'add: Transition' "$popup" \
  || fail "WallpaperPopup should animate newly-added list delegates"
grep -q 'displaced: Transition' "$popup" \
  || fail "WallpaperPopup should animate displaced list delegates"
grep -q 'function boostedScroll' "$popup" \
  || fail "WallpaperPopup should boost touchpad side-scroll sensitivity"
grep -q 'width: card.width' "$popup" \
  || fail "WallpaperPopup should size row slots from animated card width to avoid overlap"
grep -q 'SkwdButton' "$popup" \
  || fail "WallpaperPopup should use skwd-style apply/status controls"
grep -q 'expandedWidth: Math.min' "$popup" \
  || fail "WallpaperPopup should constrain slice expansion to the bottom sheet width"
grep -q 'required property string preview' "$popup" \
  || fail "WallpaperPopup should pass downloaded font/cursor preview assets into cards"
grep -q 'preview_for_family' "$font_list" \
  || fail "ryoku-font-list should map installed font families to downloaded preview assets"
grep -q 'jetbrains-mono.svg' "$font_list" \
  || fail "ryoku-font-list should expose the downloaded JetBrains Mono preview"
grep -q 'cascadia-mono.jpg' "$font_list" \
  || fail "ryoku-font-list should expose the downloaded Cascadia preview"
grep -q 'preview_for' "$cursor_list" \
  || fail "ryoku-cursor-list should map cursor themes to downloaded preview assets"
grep -q 'bibata-classic.png' "$cursor_list" \
  || fail "ryoku-cursor-list should expose the downloaded Bibata preview"
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

grep -q 'selectedTags' "$tag_cloud" \
  || fail "WallpaperTagCloud should manage selected tags"
grep -q 'popularTags' "$tag_cloud" \
  || fail "WallpaperTagCloud should render popular tags"
grep -q 'searchWallhaven' "$wallhaven_browser" \
  || fail "WallpaperWallhavenBrowser should search Wallhaven"
grep -q 'applyItem' "$wallhaven_browser" \
  || fail "WallpaperWallhavenBrowser should apply selected Wallhaven rows"
grep -q 'Steam Workshop' "$steam_browser" \
  || fail "WallpaperSteamWorkshopBrowser should expose Steam Workshop browsing"
grep -q 'steamEnabled' "$steam_browser" \
  || fail "WallpaperSteamWorkshopBrowser should bind to Steam feature settings"
grep -q 'selectedMonitor' "$monitor_picker" \
  || fail "WallpaperMonitorPicker should manage selected monitor state"
grep -q 'PathLine' "$hex_card" \
  || fail "WallpaperHexCard should draw hexagonal geometry"
grep -q 'PathLine' "$mosaic_card" \
  || fail "WallpaperMosaicCard should draw skewed mosaic geometry"
! grep -q 'width: selected ?' "$mosaic_card" \
  || fail "WallpaperMosaicCard should not grow beyond GridView cells when selected"
! grep -q 'height: selected ?' "$mosaic_card" \
  || fail "WallpaperMosaicCard should keep stable GridView cell height"
grep -q 'property int cardWidth' "$mosaic_card" \
  || fail "WallpaperMosaicCard should expose stable card width"
grep -q 'property int cardHeight' "$mosaic_card" \
  || fail "WallpaperMosaicCard should expose stable card height"
grep -q 'Behavior on opacity' "$card" \
  || fail "WallpaperSkewCard should fade newly-created delegates in"
grep -q 'Translate {' "$card" \
  || fail "WallpaperSkewCard should slide newly-created delegates in"

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
  qmllint -I config/quickshell/ryoku/vendor/brain-shell/src "$service" "$popup" "$card" "$theme_card" "$appearance_card" "$filter" "$settings" "$skwd_button" "$tag_cloud" "$wallhaven_browser" "$steam_browser" "$monitor_picker" "$hex_card" "$mosaic_card"
fi

pass "quickshell skwd wallpaper service"
