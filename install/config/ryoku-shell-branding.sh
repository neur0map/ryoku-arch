#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)/lib/runtime-env.sh"

SHELL_PATH="${RYOKU_SHELL_PATH:-$HOME/.local/share/ryoku-shell}"
RUNTIME_SHELL_PATH="${RYOKU_SHELL_RUNTIME_PATH:-${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/ryoku-shell}"
REPLACEMENTS_FILE="$RYOKU_PATH/default/ryoku-shell/branding-replacements.tsv"
CONFIG_OVERRIDES_FILE="$RYOKU_PATH/default/ryoku-shell/config-overrides.json"

log() {
  printf 'Ryoku shell branding: %s\n' "$1"
}

install_asset() {
  local source="$1"
  local target="$2"

  [[ -f $source ]] || return 0
  mkdir -p "$(dirname "$target")"
  install -m 0644 "$source" "$target"
}

apply_replacements_to_file() {
  local relative="$1"
  local file="$2"
  local target search replace

  [[ -f $file ]] || return 0
  [[ -f $REPLACEMENTS_FILE ]] || return 0

  while IFS=$'\t' read -r target search replace || [[ -n $target ]]; do
    [[ -n $target ]] || continue
    [[ ${target:0:1} == "#" ]] && continue
    [[ $target == "$relative" ]] || continue

    SEARCH="$search" REPLACE="$replace" perl -0pi -e 's/\Q$ENV{SEARCH}\E/$ENV{REPLACE}/g' "$file"
  done <"$REPLACEMENTS_FILE"
}

apply_replacements_to_root_file() {
  local relative="$1"
  local file="$2"
  local mode temp_file

  [[ -f $file ]] || return 0

  if [[ -w $file ]]; then
    apply_replacements_to_file "$relative" "$file"
    return 0
  fi

  ryoku-cmd-present sudo || return 0
  sudo -n true >/dev/null 2>&1 || return 0

  temp_file=$(mktemp)
  cp "$file" "$temp_file"
  apply_replacements_to_file "$relative" "$temp_file"
  mode=$(stat -c '%a' "$file")
  sudo install -m "$mode" "$temp_file" "$file"
  rm -f "$temp_file"
}

apply_replacements_to_tree() {
  local tree="$1"
  local target search replace

  [[ -d $tree ]] || return 0
  [[ -f $REPLACEMENTS_FILE ]] || return 0

  while IFS=$'\t' read -r target search replace || [[ -n $target ]]; do
    [[ -n $target ]] || continue
    [[ ${target:0:1} == "#" ]] && continue
    apply_replacements_to_file "$target" "$tree/$target"
  done <"$REPLACEMENTS_FILE"
}

apply_service_cleanup() {
  local service="$1"
  local cleanup_cmd="$RYOKU_PATH/bin/ryoku-shell-cleanup-orphans"
  local cleanup_line

  [[ -f $service ]] || return 0
  [[ -x $cleanup_cmd ]] || cleanup_cmd="$HOME/.local/share/ryoku/bin/ryoku-shell-cleanup-orphans"

  cleanup_line="ExecStopPost=-$cleanup_cmd --quiet"

  if grep -q '^ExecStopPost=' "$service"; then
    RYOKU_CLEANUP_LINE="$cleanup_line" perl -0pi -e \
      's/^ExecStopPost=.*$/$ENV{RYOKU_CLEANUP_LINE}/mg' "$service"
  else
    printf '\n%s\n' "$cleanup_line" >>"$service"
  fi
}

apply_lock_security_guard_to_file() {
  local file="$1"

  [[ -f $file ]] || return 0
  grep -q 'Lock session did not become secure' "$file" && return 0
  grep -q 'running: GlobalStates.screenLocked && !lockSurfaceLoader.item' "$file" || return 0

  perl -0pi -e \
    's/running: GlobalStates\.screenLocked && !lockSurfaceLoader\.item/running: GlobalStates.screenLocked && (!lock.secure || !lockSurfaceLoader.item)/' \
    "$file"
  perl -0pi -e \
    's/console\.warn\("\[Lock\] Lock surface failed to load, using swaylock fallback"\)/console.warn(lock.secure ? "[Lock] Lock surface failed to load, using swaylock fallback" : "[Lock] Lock session did not become secure, using swaylock fallback")/' \
    "$file"
}

apply_lock_security_guard() {
  apply_lock_security_guard_to_file "$SHELL_PATH/modules/lock/Lock.qml"
  apply_lock_security_guard_to_file "$RUNTIME_SHELL_PATH/modules/lock/Lock.qml"
}

# Disable Ryoku's internal swayidle spawn. Replaced by hypridle.service
# (managed by install/config/ryoku-hypridle.sh + config/hypr/hypridle.conf).
# hypridle's lock_cmd fires the standalone hyprlock binary which renders
# <100ms, fast enough to beat niri's ~1-second ext_session_lock_v1
# secure-surface timeout. Ryoku's embedded Lock.qml could not, leading to
# self-release races on lid-close. Mod+Alt+L still uses Ryoku Lock (the
# interactive path doesn't race against suspend).
apply_idle_disable_swayidle_to_file() {
  local file="$1"

  [[ -f $file ]] || return 0
  grep -q 'RYOKU: swayidle replaced by hypridle' "$file" && return 0
  grep -qF 'function _startSwayidle()' "$file" || return 0

  perl -0pi -e '
    s|(    function _startSwayidle\(\)\s*\{\n)(\s+if\s*\(\s*inhibit\s*\)\s*return\n)|$1        // RYOKU: swayidle replaced by hypridle (managed via systemd user unit\n        // hypridle.service). hypridle has `inhibit_sleep = 3` which blocks\n        // suspend until the lock surface is secure on the compositor.\n        // This is the race-protection swayidle lacks.\n        // See ~/.config/hypr/hypridle.conf.\n        return\n\n$2|s;
  ' "$file"
}

apply_idle_disable_swayidle() {
  apply_idle_disable_swayidle_to_file "$SHELL_PATH/services/Idle.qml"
  apply_idle_disable_swayidle_to_file "$RUNTIME_SHELL_PATH/services/Idle.qml"
}

install_visible_assets() {
  local background="$RYOKU_PATH/themes/ryoku/backgrounds/1-ryoku.png"
  local icon_dir="$HOME/.local/share/icons/hicolor/scalable/apps"

  install_asset "$RYOKU_PATH/logo-mark.svg" "$SHELL_PATH/assets/icons/ryoku.svg"
  install_asset "$RYOKU_PATH/logo-mark.svg" "$SHELL_PATH/assets/icons/desktop-symbolic.svg"
  install_asset "$RYOKU_PATH/logo-mark.svg" "$icon_dir/ryoku.svg"
  install_asset "$RYOKU_PATH/logo-mark.svg" "$icon_dir/ryoku-shell.svg"
  install_asset "$background" "$SHELL_PATH/dots/sddm/pixel/assets/background.png"

  if [[ -d /usr/share/sddm/themes/ii-pixel ]]; then
    if [[ -w /usr/share/sddm/themes/ii-pixel ]]; then
      install_asset "$background" "/usr/share/sddm/themes/ii-pixel/assets/background.png"
    elif ryoku-cmd-present sudo && sudo -n true >/dev/null 2>&1; then
      sudo install -d -m 0755 /usr/share/sddm/themes/ii-pixel/assets
      sudo install -m 0644 "$background" /usr/share/sddm/themes/ii-pixel/assets/background.png
    fi
  fi
}

restore_shell_panels_original_frame_state_to_file() {
  local file="$1"

  [[ -f $file ]] || return 0

  perl -0pi -e '
    s/^import qs\.modules\.frame\n//mg;
    s/^\s*PanelLoader \{ identifier: "iiScreenFrame"; component: ScreenFrame \{\} \}\n//mg;
  ' "$file"
}

restore_shell_panels_original_frame_state() {
  restore_shell_panels_original_frame_state_to_file "$SHELL_PATH/ShellIiPanels.qml"
  restore_shell_panels_original_frame_state_to_file "$RUNTIME_SHELL_PATH/ShellIiPanels.qml"
}

apply_screen_corners_input_mask_guard_to_file() {
  local file="$1"

  [[ -f $file ]] || return 0
  grep -q 'id: emptyMask' "$file" && return 0
  grep -q 'item: sidebarCornerOpenInteractionLoader.active ? sidebarCornerOpenInteractionLoader : null' "$file" || return 0

  perl -0pi -e '
    s/(        exclusionMode: ExclusionMode\.Ignore\n)        mask: Region \{\n            item: sidebarCornerOpenInteractionLoader\.active \? sidebarCornerOpenInteractionLoader : null\n        \}/$1        Item { id: emptyMask; width: 0; height: 0 }\n        mask: Region {\n            item: sidebarCornerOpenInteractionLoader.active ? sidebarCornerOpenInteractionLoader : emptyMask\n        }/s
  ' "$file"
}

apply_screen_corners_input_mask_guard() {
  apply_screen_corners_input_mask_guard_to_file "$SHELL_PATH/modules/screenCorners/ScreenCorners.qml"
  apply_screen_corners_input_mask_guard_to_file "$RUNTIME_SHELL_PATH/modules/screenCorners/ScreenCorners.qml"
}

apply_wallpaper_resolution_patch_to_file() {
  local file="$1"

  [[ -f $file ]] || return 0

  perl -0pi -e '
    s/    readonly property string _resolvedMainWallpaperPath: \{\n        if \(WallpaperListener\.multiMonitorEnabled\) \{\n            const focused = WallpaperListener\.getFocusedMonitor\(\)\n            if \(focused\) \{\n                const data = WallpaperListener\.effectivePerMonitor\[focused\]\n                if \(data && data\.path\) return data\.path\n            \}\n        \}\n        return Config\.options\?\.background\?\.wallpaperPath \?\? ""\n    \}/    readonly property string _resolvedMainWallpaperPath: Config.options?.background?.wallpaperPath ?? ""/s
  ' "$file"

  perl -0pi -e '
    s/        const targetMonitor = monitorName \|\| \(WallpaperListener\.multiMonitorEnabled \? WallpaperListener\.getFocusedMonitor\(\) : ""\)/        const targetMonitor = monitorName/s
  ' "$file"
}

apply_wallpaper_resolution_patch() {
  apply_wallpaper_resolution_patch_to_file "$SHELL_PATH/services/Wallpapers.qml"
  apply_wallpaper_resolution_patch_to_file "$RUNTIME_SHELL_PATH/services/Wallpapers.qml"
}

# Workaround for Qt 6.11.0 use-after-free in updatePixelRatioHelper.
#
# niri sends wl_surface.preferred_buffer_scale on every layer-shell surface
# (re)map, which makes Qt walk the entire QQuickItem tree to fire
# ItemDevicePixelRatioHasChanged on each.  In Qt 6.11.0 that walk hits a
# dangling pointer on a freed item, pure-virtual abort or SIGSEGV depending
# on heap luck.  See distro/arch/qt6-qiooperation-patch/README.md for the
# full diagnosis.
#
# Mitigation here: keep the SidebarRight PanelWindow's surface mapped at all
# times (visible: true), and use a Region mask sized 0×0 when "closed" so
# clicks fall through.  The existing slide animation still hides content
# visually.  This eliminates the user-reported reproduction (rapid clicks on
# the empty space between weather and the bluetooth cluster).
#
# A second, defence-in-depth fix lives at
# distro/arch/qt6-qiooperation-patch/, a binary patch of libQt6Core scoped
# to ryoku-shell.service via LD_LIBRARY_PATH.  That one isn't run from this script
# because it's a system-library patch, not a shell-tree patch.
apply_sidebar_right_keep_mapped_workaround_to_file() {
  local file="$1"

  [[ -f $file ]] || return 0
  grep -q 'id: _emptyMask' "$file" && return 0
  grep -q 'visible = GlobalStates.sidebarRightOpen' "$file" || return 0

  perl -0pi -e '
    s/        Component\.onCompleted: \{\n            visible = GlobalStates\.sidebarRightOpen\n            root\._sidebarShown = GlobalStates\.sidebarRightOpen\n        \}\n\n        Connections \{\n            target: GlobalStates\n            function onSidebarRightOpenChanged\(\) \{\n                if \(GlobalStates\.sidebarRightOpen\) \{\n                    _closeTimer\.stop\(\)\n                    sidebarRoot\.visible = true\n                    \/\/ Let the surface map for one frame before sliding in\n                    Qt\.callLater\(\(\) => \{ root\._sidebarShown = true \}\)\n                \} else if \(root\.instantOpen \|\| !Appearance\.animationsEnabled\) \{\n                    root\._sidebarShown = false\n                    _closeTimer\.stop\(\)\n                    sidebarRoot\.visible = false\n                \} else \{\n                    root\._sidebarShown = false\n                    _closeTimer\.restart\(\)\n                \}\n            \}\n        \}\n\n        Timer \{\n            id: _closeTimer\n            interval: 300\n            onTriggered: sidebarRoot\.visible = false\n        \}/        \/\/ Workaround for Qt 6.11.0 UAF in updatePixelRatioHelper: niri sends\n        \/\/ wl_surface.preferred_buffer_scale on every layer-shell surface\n        \/\/ (re)map, which triggers a recursive QML tree walk that can hit a\n        \/\/ freed item, pure-virtual abort or SIGSEGV depending on heap luck.\n        \/\/ Keep the surface mapped at all times; control input\/visibility via\n        \/\/ the mask region below and the existing slide animation.\n        visible: true\n\n        \/\/ _emptyMask shrinks the surface\x27s input region to zero when the\n        \/\/ sidebar is closed so clicks fall through.  _fullMask covers the\n        \/\/ whole panel when open so the backdropClickArea (close-on-click-\n        \/\/ outside) and sidebarContentLoader (interactive widgets) both\n        \/\/ receive input.  Region \{ item: null \} would mean \"no mask\" and\n        \/\/ is interpreted by Quickshell as zero-input here, breaking both.\n        Item \{ id: _emptyMask; width: 0; height: 0 \}\n        Item \{ id: _fullMask;  anchors.fill: parent \}\n        mask: Region \{\n            item: GlobalStates.sidebarRightOpen ? _fullMask : _emptyMask\n        \}\n\n        Component.onCompleted: \{\n            root._sidebarShown = GlobalStates.sidebarRightOpen\n        \}\n\n        Connections \{\n            target: GlobalStates\n            function onSidebarRightOpenChanged\(\) \{\n                if \(GlobalStates.sidebarRightOpen\) \{\n                    _closeTimer.stop\(\)\n                    Qt.callLater\(\(\) => \{ root._sidebarShown = true \}\)\n                \} else if \(root.instantOpen \|\| !Appearance.animationsEnabled\) \{\n                    root._sidebarShown = false\n                    _closeTimer.stop\(\)\n                \} else \{\n                    root._sidebarShown = false\n                    _closeTimer.restart\(\)\n                \}\n            \}\n        \}\n\n        Timer \{\n            id: _closeTimer\n            interval: 300\n            \/\/ surface stays mapped; nothing to do on close-animation finish\n        \}/s
  ' "$file"
}

apply_sidebar_right_keep_mapped_workaround() {
  apply_sidebar_right_keep_mapped_workaround_to_file "$SHELL_PATH/modules/sidebarRight/SidebarRight.qml"
  apply_sidebar_right_keep_mapped_workaround_to_file "$RUNTIME_SHELL_PATH/modules/sidebarRight/SidebarRight.qml"
}

qml_file_contains() {
  local file="$1"
  local pattern="$2"

  perl -0ne 'BEGIN { $pattern = shift; $found = 0 } $found = 1 if index($_, $pattern) >= 0; END { exit($found ? 0 : 1) }' \
    "$pattern" "$file"
}

apply_installed_labels() {
  local installed_service="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/ryoku-shell.service"

  apply_replacements_to_file "assets/applications/ryoku-shell.desktop" \
    "${XDG_DATA_HOME:-$HOME/.local/share}/applications/ryoku-shell.desktop"
  apply_replacements_to_file "assets/systemd/ryoku-shell.service" \
    "$installed_service"
  apply_service_cleanup "$installed_service"

  if [[ -d /usr/share/sddm/themes/ii-pixel ]]; then
    apply_replacements_to_root_file "dots/sddm/pixel/metadata.desktop" \
      "/usr/share/sddm/themes/ii-pixel/metadata.desktop"
    apply_replacements_to_root_file "dots/sddm/pixel/theme.conf" \
      "/usr/share/sddm/themes/ii-pixel/theme.conf"
    apply_replacements_to_root_file "dots/sddm/pixel/Main.qml" \
      "/usr/share/sddm/themes/ii-pixel/Main.qml"
    apply_replacements_to_root_file "dots/sddm/pixel/VirtualKeyboard.qml" \
      "/usr/share/sddm/themes/ii-pixel/VirtualKeyboard.qml"
  fi
}

merge_config_overrides() {
  local config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/ryoku-shell"
  local config_file="$config_dir/config.json"
  local temp_file temp_file_with_wallpaper wallpaper_path existing_wallpaper_path

  [[ -f $CONFIG_OVERRIDES_FILE ]] || return 0

  if ryoku-cmd-missing jq; then
    log "jq missing, skipped shell config merge"
    return 0
  fi

  mkdir -p "$config_dir"
  if [[ ! -f $config_file ]]; then
    if [[ -f $SHELL_PATH/defaults/config.json ]]; then
      cp "$SHELL_PATH/defaults/config.json" "$config_file"
    else
      printf '{}\n' >"$config_file"
    fi
  fi

  existing_wallpaper_path=$(jq -r '.background.wallpaperPath // empty' "$config_file" 2>/dev/null || true)

  temp_file=$(mktemp)
  jq -s '.[0] * .[1]' "$config_file" "$CONFIG_OVERRIDES_FILE" >"$temp_file"

  temp_file_with_wallpaper=$(mktemp)
  if [[ -n $existing_wallpaper_path ]]; then
    cp "$temp_file" "$temp_file_with_wallpaper"
  else
    wallpaper_path="$RYOKU_CONFIG_PATH/current/background"
    if [[ ! -e $wallpaper_path && -f $RYOKU_PATH/themes/ryoku/backgrounds/1-ryoku.png ]]; then
      wallpaper_path="$RYOKU_PATH/themes/ryoku/backgrounds/1-ryoku.png"
    fi

    jq --arg path "$wallpaper_path" \
      '.background.wallpaperPath = $path
        | .background.thumbnailPath = ""
        | .background.backdrop.wallpaperPath = $path
        | .background.backdrop.thumbnailPath = ""' \
      "$temp_file" >"$temp_file_with_wallpaper"
  fi

  mv "$temp_file_with_wallpaper" "$config_file"
  rm -f "$temp_file"
}

merge_default_config_overrides() {
  local defaults_file temp_file

  [[ -f $CONFIG_OVERRIDES_FILE ]] || return 0

  if ryoku-cmd-missing jq; then
    return 0
  fi

  for defaults_file in "$SHELL_PATH/defaults/config.json" "$RUNTIME_SHELL_PATH/defaults/config.json"; do
    [[ -f $defaults_file ]] || continue
    temp_file=$(mktemp)
    jq -s '.[0] * .[1]' "$defaults_file" "$CONFIG_OVERRIDES_FILE" >"$temp_file"
    mv "$temp_file" "$defaults_file"
  done
}

main() {
  if [[ ! -d $SHELL_PATH ]]; then
    log "checkout not found, branding will apply after shell install"
    return 0
  fi

  install_visible_assets
  restore_shell_panels_original_frame_state
  apply_screen_corners_input_mask_guard
  apply_wallpaper_resolution_patch
  apply_sidebar_right_keep_mapped_workaround
  apply_replacements_to_tree "$SHELL_PATH"
  apply_replacements_to_tree "$RUNTIME_SHELL_PATH"
  apply_lock_security_guard
  apply_idle_disable_swayidle
  apply_installed_labels
  merge_default_config_overrides
  merge_config_overrides

  log "applied"
}

main "$@"
