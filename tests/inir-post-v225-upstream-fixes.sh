#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
upstream_shell='i''nir'

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_file() {
  local path="$1"

  [[ -f "$ROOT_DIR/$path" ]] || fail "missing $path"
}

assert_executable() {
  local path="$1"

  [[ -x "$ROOT_DIR/$path" ]] || fail "$path should be executable"
}

assert_contains() {
  local path="$1"
  local pattern="$2"
  local message="$3"

  assert_file "$path"
  rg -n -- "$pattern" "$ROOT_DIR/$path" >/dev/null || fail "$message"
}

assert_not_contains() {
  local path="$1"
  local pattern="$2"
  local message="$3"

  assert_file "$path"
  if rg -n -- "$pattern" "$ROOT_DIR/$path" >/dev/null; then
    fail "$message"
  fi
}

# missioncenter is the command; mission-center is the Arch package.
assert_contains "shell/sdata/dist-arch/install-deps.sh" '\[missioncenter\]="mission-center"' \
  "Arch missing-dependency repair should install mission-center for the missioncenter command"
assert_contains "shell/sdata/dist-debian/install-deps.sh" '\[missioncenter\]="io\.missioncenter\.MissionCenter"' \
  "Debian missing-dependency repair should map missioncenter to the Flatpak/package id"
assert_contains "shell/sdata/dist-fedora/install-deps.sh" '\[missioncenter\]="io\.missioncenter\.MissionCenter"' \
  "Fedora missing-dependency repair should map missioncenter to the Flatpak/package id"
assert_contains "shell/modules/common/Config.qml" 'property string taskManager: "missioncenter"' \
  "runtime task-manager command should stay missioncenter"

# Static wallpaper decode must be capped to viewport-scale dimensions, not full wallpaper image dimensions.
assert_contains "shell/modules/background/Background.qml" 'Math\.max\(1, Math\.round\(bgRoot\.screen\.width \*' \
  "static wallpaper sourceSize width should be capped from viewport width"
assert_contains "shell/modules/background/Background.qml" 'Math\.max\(1, Math\.round\(bgRoot\.screen\.height \*' \
  "static wallpaper sourceSize height should be capped from viewport height"
assert_not_contains "shell/modules/background/Background.qml" 'sourceSize \{[[:space:][:print:]]*scaledWallpaperWidth' \
  "static wallpaper sourceSize should not request scaled wallpaper pixel dimensions"

# ThumbnailImage should not point Image.source at missing cache files until a lightweight existence check succeeds.
assert_contains "shell/modules/common/widgets/ThumbnailImage.qml" 'property string resolvedThumbnailSource' \
  "thumbnail image should load only a resolved thumbnail source"
assert_contains "shell/modules/common/widgets/ThumbnailImage.qml" 'property string _queuedThumbnailCheck' \
  "thumbnail image should queue cache-file existence checks"
assert_contains "shell/modules/common/widgets/ThumbnailImage.qml" 'Wallpapers\.forgetThumbnail' \
  "thumbnail image should forget stale session thumbnail cache entries"
assert_contains "shell/services/Wallpapers.qml" 'property var _knownThumbnailOutputs' \
  "wallpaper service should remember known thumbnail outputs"
assert_contains "shell/services/Wallpapers.qml" 'function forgetThumbnail' \
  "wallpaper service should expose stale thumbnail cache invalidation"
assert_contains "shell/services/Wallpapers.qml" 'root\.rememberThumbnail\(_singleThumbProc\._outputPath\)' \
  "single thumbnail generator should remember generated output paths"

# Quick wallpaper sidebar should not require fish and should reuse ThumbnailImage.
assert_not_contains "shell/modules/sidebarLeft/widgets/QuickWallpaper.qml" '/usr/bin/fish' \
  "quick wallpaper scanner should not require fish"
assert_contains "shell/modules/sidebarLeft/widgets/QuickWallpaper.qml" 'command: \["find", root\.wallpapersPath' \
  "quick wallpaper scanner should call find directly"
assert_contains "shell/modules/sidebarLeft/widgets/QuickWallpaper.qml" 'ThumbnailImage \{' \
  "quick wallpaper carousel should use ThumbnailImage"

# Config writes should not be dropped when a new write arrives while FileView is still saving.
assert_contains "shell/modules/common/Config.qml" 'property bool _pendingWrite' \
  "Config should track pending writes while a write is in flight"
assert_contains "shell/modules/common/Config.qml" 'id: customInjectTimer' \
  "Config should defer custom widget injection out of onSaved"
assert_contains "shell/modules/common/Config.qml" 'if \(root\._writeInFlight\) \{' \
  "Config write timer should guard in-flight writes"
assert_contains "shell/modules/common/Config.qml" 'property var _jsonMirror' \
  "Config should keep an in-memory JSON mirror for reliable writes"
assert_contains "shell/modules/common/Config.qml" 'function _applyToMirror' \
  "Config mutations should update the write mirror synchronously"
assert_contains "shell/modules/common/Config.qml" 'function _writeMirrorToDisk' \
  "Config should have a direct mirror write fallback"
assert_contains "shell/modules/common/Config.qml" 'id: writeFlightGuard' \
  "Config should recover when writeAdapter does not emit onSaved"
assert_contains "shell/modules/common/Config.qml" 'root\._jsonMirror = JSON\.parse\(configFileView\.text\(\)\)' \
  "Config should initialize the write mirror from disk on load"
assert_contains "shell/modules/common/Config.qml" 'writeFlightGuard\.stop\(\)' \
  "Config should stop the write watchdog when onSaved fires"

# Timer coordination must respect reduceAnimations through calcEffectiveDuration.
assert_contains "shell/modules/common/widgets/NotificationGroup.qml" 'Appearance\.calcEffectiveDuration\(Appearance\.animation\.elementMoveFast\.duration \+ 50\)' \
  "notification expand timer should use calcEffectiveDuration"
assert_contains "shell/modules/ii/overlay/Overlay.qml" 'interval: Appearance\.calcEffectiveDuration\(' \
  "overlay delayed focus timer should use calcEffectiveDuration"
assert_contains "shell/modules/mediaControls/MediaControls.qml" 'interval: Appearance\.calcEffectiveDuration\(350\)' \
  "media controls close timer should use calcEffectiveDuration"
assert_contains "shell/modules/sidebarRight/BottomWidgetGroup.qml" 'Appearance\.calcEffectiveDuration\(Appearance\.animation\.elementMove\.duration / 2\)' \
  "bottom widget collapse timer should use calcEffectiveDuration"
assert_contains "shell/modules/sidebarRight/todo/TaskList.qml" 'Appearance\.calcEffectiveDuration\(Appearance\.animation\.elementMoveFast\.duration\)' \
  "todo action timer should use calcEffectiveDuration"
assert_contains "shell/modules/wallpaperSelector/WallpaperCoverflow.qml" 'Appearance\.calcEffectiveDuration\(450\)' \
  "coverflow close timer should use calcEffectiveDuration"
assert_contains "shell/modules/wallpaperSelector/WallpaperCoverflow.qml" 'Appearance\.calcEffectiveDuration\(80\)' \
  "coverflow content entry timer should use calcEffectiveDuration"

# Low-risk perf fixes should avoid constant process/timer churn.
assert_contains "shell/modules/altSwitcher/AltSwitcher.qml" 'id: skewFocusTimer' \
  "skew alt switcher focus poll should be 100ms"
assert_contains "shell/modules/altSwitcher/AltSwitcher.qml" 'interval: 100' \
  "skew alt switcher focus poll should be 100ms"
assert_contains "shell/modules/bar/Workspaces.qml" 'property bool previousOccupied' \
  "workspace hot-path properties should be typed"
assert_contains "shell/modules/bar/Workspaces.qml" 'property real radiusPrev' \
  "workspace radius properties should be real"
assert_contains "shell/services/RecorderStatus.qml" 'id: idlePollTimer' \
  "recorder status should have a slow idle poll"
assert_contains "shell/services/RecorderStatus.qml" 'interval: 5000' \
  "recorder idle poll should run every 5 seconds"
assert_contains "shell/services/RecorderStatus.qml" 'function scheduleQuickCheck' \
  "recorder status should expose quick rechecks after recording actions"
assert_not_contains "shell/services/SystemInfo.qml" 'interval: 15000' \
  "system identity should not be refreshed every 15 seconds"
assert_contains "shell/services/Wallhaven.qml" 'root\.nowMs = Date\.now\(\)' \
  "Wallhaven should update rate-limit clock on demand"
assert_not_contains "shell/services/Wallhaven.qml" 'repeat: true[[:space:][:print:]]*running: root\._active[[:space:][:print:]]*onTriggered: root\.nowMs = Date\.now\(\)' \
  "Wallhaven should not keep a 500ms clock timer running"

# Resource sensors should prefer user-visible die/edge temperatures.
assert_contains "shell/services/ResourceUsage.qml" 'label.*Tdie|Tdie' \
  "AMD CPU temp detection should prefer Tdie over Tctl"
assert_contains "shell/services/ResourceUsage.qml" 'edge' \
  "AMD GPU temp detection should prefer edge over junction"

# Cava should follow music/MPRIS and support cover-art color refreshes.
assert_file "shell/services/CavaTheme.qml"
assert_file "shell/scripts/cava/resolve_audio_source.py"
assert_executable "shell/scripts/cava/apply_cover_theme.sh"
assert_contains "shell/modules/common/widgets/CavaProcess.qml" 'playerDesktopEntry' \
  "CavaProcess should pass the active player desktop entry to the resolver"
assert_contains "shell/modules/common/widgets/CavaProcess.qml" 'onTrackChanged' \
  "CavaProcess should restart when the active track changes"
assert_contains "shell/scripts/cava/generate_config.sh" 'DESKTOP_ENTRY="\$\{6:-\}"' \
  "cava config generator should accept an MPRIS desktop-entry hint"
assert_contains "shell/scripts/cava/generate_config.sh" 'resolve_audio_source\.py' \
  "cava config generator should use the audio source resolver"
assert_not_contains "shell/scripts/cava/generate_config.sh" "__${upstream_shell}_no_music__" \
  "cava generator should not keep the reverted no-music fallback"
assert_contains "shell/services/qmldir" 'singleton CavaTheme 1\.0 CavaTheme\.qml' \
  "CavaTheme singleton should be registered"
assert_contains "shell/shell.qml" '_cavaThemeService' \
  "shell should instantiate CavaTheme after startup"
assert_contains "shell/services/MprisController.qml" 'name\.includes\("zen"\)' \
  "MPRIS browser heuristics should include Zen browser"

# Spicetify should live-reload safely without watch mode or launching Spotify when closed.
assert_contains "shell/scripts/colors/apply-spicetify-theme.sh" 'ensure_spotify_desktop_override' \
  "Spicetify theme apply should create the CDP desktop override"
assert_contains "shell/scripts/colors/apply-spicetify-theme.sh" 'remote-debugging-port=' \
  "Spotify desktop override should enable a remote debugging port"
assert_contains "shell/scripts/colors/apply-spicetify-theme.sh" 'reload_running_spotify' \
  "Spicetify theme apply should reload a running Spotify client through CDP"
assert_contains "shell/scripts/colors/apply-spicetify-theme.sh" 'sync_live_user_css' \
  "Spicetify theme apply should sync generated user.css into the live xpui directory"
assert_contains "shell/scripts/colors/apply-spicetify-theme.sh" 'spicetify -n apply' \
  "Spicetify fallback apply should use no-launch mode"
assert_not_contains "shell/scripts/colors/apply-spicetify-theme.sh" 'spicetify watch' \
  "Spicetify theming should not rely on watch mode"
assert_not_contains "shell/scripts/colors/apply-spicetify-theme.sh" 'skipping apply' \
  "Spicetify should still apply to the bundle when Spotify is closed"
assert_contains "shell/scripts/colors/apply-spicetify-theme.sh" 'Killed Spotify spawned as side effect of spicetify apply' \
  "Spicetify should kill any Spotify instance spawned as a no-launch side effect"
assert_contains "shell/scripts/colors/apply-spicetify-theme.sh" 'Spotify not running - theme applied to bundle for next launch' \
  "Spicetify should report that the closed-client bundle was patched"

# Post-launch Quickshell/runtime fixes should keep startup and service behavior deterministic.
assert_contains "shell/shell.qml" 'pragma ShellId ryoku-shell' \
  "shell should pin a stable ShellId for Quickshell state/cache paths"
assert_contains "shell/shell.qml" 'pragma DefaultEnv QT_LOGGING_RULES=quickshell\.dbus\.properties=false' \
  "shell logging suppression should be overridable through DefaultEnv"
assert_contains "shell/scripts/ryoku-shell" 'check_qs_abi[[:space:]]+# fail early on Qt patch bumps before qs starts' \
  "session boot should run the Qt/Quickshell ABI check before launching qs"
assert_contains "shell/scripts/ryoku-shell" 'service logs --full' \
  "service help should advertise full Quickshell log output"
assert_contains "shell/scripts/ryoku-shell" 'qs_bin.*-p.*config_dir.*log' \
  "service logs --full should read the Quickshell binary log"

# Startup warning suppression for expected missing files/cache and early theme bindings.
assert_contains "shell/services/CalendarSync.qml" 'if \(!root\.enabled\) \{' \
  "CalendarSync should not touch cache files when external sync is disabled"
assert_contains "shell/services/CalendarSync.qml" 'printErrors: false' \
  "CalendarSync cache FileView should suppress expected missing-cache warnings"
assert_contains "shell/services/Translation.qml" 'printErrors: false' \
  "TranslationReader should suppress expected missing generated-locale warnings"
assert_contains "shell/modules/sidebarRight/sysmon/SysMonWidget.qml" 'Appearance\.colors\?\.colError' \
  "SysMonWidget warning colors should be null-safe during early startup"
assert_contains "shell/modules/sidebarRight/sysmon/SysMonWidget.qml" 'Appearance\.colors\?\.colWarning' \
  "SysMonWidget warning colors should be null-safe during early startup"
assert_contains "shell/modules/sidebarRight/sysmon/SysMonWidget.qml" 'Appearance\.colors\?\.colPrimary' \
  "SysMonWidget primary progress colors should be null-safe during early startup"

# Awww probing should not warn while the probe is in flight and should tolerate non-login PATHs.
assert_contains "shell/services/AwwwBackend.qml" '!warnedMissing && !probing' \
  "Awww backend should not warn until the binary probe has finished"
assert_contains "shell/services/AwwwBackend.qml" '/usr/bin/awww /usr/local/bin/awww' \
  "Awww probe should check well-known executable paths before PATH lookup"
assert_contains "shell/services/AwwwBackend.qml" '/usr/bin/awww-daemon /usr/local/bin/awww-daemon' \
  "Awww probe should check well-known daemon paths before PATH lookup"

# Launcher and UI binding fixes.
assert_contains "shell/services/AppLauncher.qml" 'DesktopEntries\.heuristicLookup\(command\)' \
  "AppLauncher should fall back to desktop entries for Flatpak-style app commands"
assert_contains "shell/services/AppLauncher.qml" 'entry\.execute\(\)' \
  "AppLauncher desktop-entry fallback should execute the resolved entry"
assert_contains "shell/modules/common/widgets/RippleButton.qml" 'typeof root\.startRipple === "function"' \
  "RippleButton should guard startRipple during teardown races"
assert_contains "shell/modules/common/widgets/NotificationItem.qml" 'contentColumn\.implicitHeight \+ root\.padding \* 2' \
  "NotificationItem expanded height should disambiguate root padding"
assert_contains "shell/modules/common/widgets/NotificationItem.qml" 'anchors\.left: parent\.left' \
  "NotificationItem content column should be anchored without fill-induced binding loops"
assert_contains "shell/modules/common/widgets/NotificationItem.qml" 'anchors\.right: parent\.right' \
  "NotificationItem content column should be anchored without fill-induced binding loops"
assert_contains "shell/modules/common/widgets/WallpaperCrossfader.qml" 'mipmap: false' \
  "WallpaperCrossfader should disable mipmap to avoid transition pixelation"
assert_not_contains "shell/modules/common/widgets/WallpaperCrossfader.qml" 'mipmap: true' \
  "WallpaperCrossfader should not enable mipmap"
assert_contains "shell/modules/mediaControls/BarMediaPopup.qml" 'readonly property bool _shouldShow' \
  "BarMediaPopup placeholder visibility should avoid direct binding-loop churn"
assert_contains "shell/modules/sidebarLeft/widgets/GlanceHeader.qml" 'Config\.options\?\.time\?\.dateFormat' \
  "GlanceHeader should honor the configured sidebar date format"

echo "OK: upstream post-v2.25 fixes"
