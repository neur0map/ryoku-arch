#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)/lib/runtime-env.sh"

SHELL_PATH="${RYOKU_SHELL_PATH:-${RYOKU_INIR_PATH:-$HOME/.local/share/inir}}"
RUNTIME_SHELL_PATH="${RYOKU_SHELL_RUNTIME_PATH:-${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/inir}"
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

# Disable iNiR's internal swayidle spawn. Replaced by hypridle.service
# (managed by install/config/ryoku-hypridle.sh + config/hypr/hypridle.conf).
# hypridle's lock_cmd fires the standalone hyprlock binary which renders
# <100ms, fast enough to beat niri's ~1-second ext_session_lock_v1
# secure-surface timeout. iNiR's embedded Lock.qml could not, leading to
# self-release races on lid-close. Mod+Alt+L still uses iNiR Lock (the
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
  install_asset "$RYOKU_PATH/logo-mark.svg" "$icon_dir/inir.svg"
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
# to inir.service via LD_LIBRARY_PATH.  That one isn't run from this script
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

apply_topbar_hug_frame_to_file() {
  local file="$1"
  local frame_properties frame_component frame_instance

  [[ -f $file ]] || return 0
  grep -q 'property alias backgroundItem: barBackground' "$file" || return 0
  grep -q 'id: leftSectionRowLayout' "$file" || return 0
  grep -q 'id: rightSectionRowLayout' "$file" || return 0
  grep -q 'id: leftCenterGroup' "$file" || return 0
  grep -q 'id: middleCenterGroup' "$file" || return 0
  grep -q 'id: rightCenterGroupContent' "$file" || return 0
  qml_file_contains "$file" 'visible: (Config.options?.bar?.showBackground ?? true) && !gameModeMinimal' || \
    qml_file_contains "$file" 'visible: (Config.options?.bar?.showBackground ?? true) && !gameModeMinimal && !root.ryokuThreeIslandFrame' || return 0

  frame_properties=$(cat <<'QML'
    readonly property bool ryokuTopbarHugFrame: (Config.options?.bar?.ryokuTopbarHugFrame ?? true) && !(Config.options?.bar?.bottom ?? false) && !(Config.options?.bar?.vertical ?? false)
    readonly property real ryokuFrameHeight: Appearance.sizes.baseBarHeight
    readonly property real ryokuFrameRadius: Math.min(Appearance.rounding.screenRounding, Math.max(8, ryokuFrameHeight / 2 - 2))
    readonly property real ryokuTopBorderWidth: Math.max(4, Math.round(ryokuFrameHeight * 0.15))
    readonly property int ryokuNotchPadding: 20
    readonly property int ryokuIslandSpacing: 10
    readonly property int ryokuLeftContentWidth: (leftSidebarButton.visible ? leftSidebarButton.implicitWidth : 0)
        + ((leftSidebarButton.visible && (activeWindowWidget.visible || taskbarLoader.visible)) ? leftSectionRowLayout.spacing : 0)
        + (activeWindowWidget.visible ? activeWindowWidget.Layout.preferredWidth : 0)
        + (taskbarLoader.visible ? taskbarLoader.Layout.preferredWidth : 0)
    readonly property int ryokuRightContentWidth: (rightSidebarButton.visible ? rightSidebarButton.implicitWidth : 0)
        + (workspacesWidget.visible ? workspacesWidget.implicitWidth + rightSectionRowLayout.spacing : 0)
        + (weatherBarLoader.visible ? weatherBarLoader.implicitWidth + rightSectionRowLayout.spacing : 0)
    readonly property int ryokuLeftNotchWidth: Math.min(Math.max(ryokuLeftContentWidth + Appearance.rounding.screenRounding + ryokuNotchPadding, 180), Math.min(520, Math.max(240, (root.screen?.width ?? 1920) * 0.24)))
    readonly property int ryokuCenterNotchWidth: Math.min(Math.max(middleCenterGroup.implicitWidth + ryokuNotchPadding * 2, 96), 220)
    readonly property int ryokuRightNotchWidth: Math.min(Math.max(ryokuRightContentWidth + Appearance.rounding.screenRounding + ryokuNotchPadding, 150), 560)
    readonly property color ryokuFrameColor: {
        if (Appearance.angelEverywhere) return Appearance.angel.colGlassCard
        if (Appearance.inirEverywhere) return Appearance.inir.colLayer0
        if (Appearance.auroraEverywhere) return Appearance.aurora.colPopupSurface
        return Appearance.colors.colLayer0
    }
QML
)

  frame_component=$(cat <<'QML'
    component RyokuTopbarHugFrame: Canvas {
        id: frame
        property int leftWidth: root.ryokuLeftNotchWidth
        property int centerWidth: root.ryokuCenterNotchWidth
        property int rightWidth: root.ryokuRightNotchWidth
        property int notchHeight: root.ryokuFrameHeight
        property int radius: root.ryokuFrameRadius
        property int topBorderWidth: root.ryokuTopBorderWidth
        property color frameColor: root.ryokuFrameColor
        readonly property int rightStart: width - rightWidth
        readonly property int minimumGap: radius * 2
        readonly property int centerStart: Math.max(leftWidth + minimumGap, (width / 2) - (centerWidth / 2))
        readonly property int centerEnd: Math.min(rightStart - minimumGap, (width / 2) + (centerWidth / 2))

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onLeftWidthChanged: requestPaint()
        onCenterWidthChanged: requestPaint()
        onRightWidthChanged: requestPaint()
        onNotchHeightChanged: requestPaint()
        onRadiusChanged: requestPaint()
        onTopBorderWidthChanged: requestPaint()
        onFrameColorChanged: requestPaint()

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();

            var leftW = frame.leftWidth;
            var centerW = frame.centerWidth;
            var rightW = frame.rightWidth;
            var r = Math.min(frame.radius, Math.max(1, (frame.notchHeight - frame.topBorderWidth) / 2 - 1));
            var h = frame.notchHeight;
            var b = frame.topBorderWidth;
            var w = width;

            var centerStart = Math.max(leftW + r * 2, (w / 2) - (centerW / 2));
            var centerEnd = Math.min(w - rightW - r * 2, (w / 2) + (centerW / 2));
            var rightStart = w - rightW;
            if (centerStart >= centerEnd) {
                centerStart = w / 2;
                centerEnd = w / 2;
            }

            ctx.beginPath();
            ctx.fillStyle = frame.frameColor;

            ctx.moveTo(0, h);
            ctx.lineTo(leftW - r, h);
            ctx.arcTo(leftW, h, leftW, h - r, r);
            ctx.lineTo(leftW, b + r);
            ctx.arcTo(leftW, b, leftW + r, b, r);

            ctx.lineTo(centerStart - r, b);
            if (centerStart < centerEnd) {
                ctx.arcTo(centerStart, b, centerStart, b + r, r);
                ctx.lineTo(centerStart, h - r);
                ctx.arcTo(centerStart, h, centerStart + r, h, r);
                ctx.lineTo(centerEnd - r, h);
                ctx.arcTo(centerEnd, h, centerEnd, h - r, r);
                ctx.lineTo(centerEnd, b + r);
                ctx.arcTo(centerEnd, b, centerEnd + r, b, r);
            }

            ctx.lineTo(rightStart - r, b);
            ctx.arcTo(rightStart, b, rightStart, b + r, r);
            ctx.lineTo(rightStart, h - r);
            ctx.arcTo(rightStart, h, rightStart + r, h, r);
            ctx.lineTo(w, h);

            ctx.lineTo(w, 0);
            ctx.lineTo(0, 0);
            ctx.lineTo(0, h);

            ctx.fill();
        }
    }
QML
)

  frame_instance=$(cat <<'QML'
    RyokuTopbarHugFrame {
        id: ryokuTopbarHugFrameCanvas
        anchors.fill: parent
        leftWidth: root.ryokuLeftNotchWidth
        centerWidth: root.ryokuCenterNotchWidth
        rightWidth: root.ryokuRightNotchWidth
        visible: root.ryokuTopbarHugFrame && !Appearance.gameModeMinimal
        z: 1
    }
QML
)

  RYOKU_FRAME_PROPERTIES="$frame_properties" \
    RYOKU_FRAME_COMPONENT="$frame_component" \
    RYOKU_FRAME_INSTANCE="$frame_instance" \
    perl -0pi -e '
    BEGIN {
      $props = $ENV{RYOKU_FRAME_PROPERTIES} . "\n";
      $component = $ENV{RYOKU_FRAME_COMPONENT};
      $instance = $ENV{RYOKU_FRAME_INSTANCE};
    }
    s/\n    readonly property bool ryokuThreeIslandFrame: true\n    readonly property int ryokuIslandVerticalMargin: 4\n    readonly property int ryokuIslandHorizontalPadding: 10\n/\n/s;
    s/\n        Rectangle \{\n            id: leftIslandBackground\n.*?\n        \}\n\n(        RowLayout \{\n            id: leftSectionRowLayout)/\n$1/s;
    s/\n        Rectangle \{\n            id: rightIslandBackground\n.*?\n        \}\n\n(        RowLayout \{\n            id: rightSectionRowLayout)/\n$1/s;
    s/root\.ryokuThreeIslandFrame/root.ryokuTopbarHugFrame/g;
    s/^import QtQuick\.Shapes\n//mg;
    s/\n    readonly property color ryokuGapColor: [^\n]+\n//g;

    if (/readonly property bool ryokuTopbarHugFrame:/) {
      s/    readonly property bool ryokuTopbarHugFrame:.*?\n    \/\/ Right-click context menu anchor/$props\n    \/\/ Right-click context menu anchor/s;
    } else {
      s/(    property alias backgroundItem: barBackground\n)/$1$props/s;
    }

    if (/component RyokuTopbarHugFrame: /) {
      s#    component RyokuTopbarHugFrame: (?:Canvas|Shape) \{.*?\n    \}\n\n    // Background shadow#$component\n\n    // Background shadow#s;
    } else {
      s/(    component VerticalBarSeparator: Rectangle \{.*?    \}\n)/$1\n$component\n/s;
    }

    s/(&& \(Config\.options\?\.bar\?\.showBackground \?\? true\)\n            && )/$1!root.ryokuTopbarHugFrame\n            \&\& /;
    s/visible: \(Config\.options\?\.bar\?\.showBackground \?\? true\) && !gameModeMinimal(?: && !root\.ryokuTopbarHugFrame)?/visible: (Config.options?.bar?.showBackground ?? true) \&\& !gameModeMinimal \&\& !root.ryokuTopbarHugFrame/;

    s/\n    Rectangle \{\n        id: ryoku(?:Left|Right)TopbarGap\n.*?    \}\n//gs;
    if (/id: ryokuTopbarHugFrameCanvas/) {
      s#    RyokuTopbarHugFrame \{\n        id: ryokuTopbarHugFrameCanvas\n.*?    \}\n#$instance\n#s;
    } else {
      s/(\n    FocusedScrollMouseArea \{ \/\/ Left side)/\n$instance\n$1/s;
    }
    s/(    FocusedScrollMouseArea \{ \/\/ Left side \| scroll to change brightness\n        id: barLeftSideMouseArea\n)(?!        z: root\.ryokuTopbarHugFrame)/$1        z: root.ryokuTopbarHugFrame ? 2 : 0\n/s;
    s/(    Row \{ \/\/ Middle section\n        id: middleSection\n)(?!        z: root\.ryokuTopbarHugFrame)/$1        z: root.ryokuTopbarHugFrame ? 2 : 0\n/s;
    s/(    FocusedScrollMouseArea \{ \/\/ Right side \| scroll to change volume\n        id: barRightSideMouseArea\n)(?!        z: root\.ryokuTopbarHugFrame)/$1        z: root.ryokuTopbarHugFrame ? 2 : 0\n/s;

    s/(            LeftSidebarButton \{ \/\/ Left sidebar button\n)(?!                id: leftSidebarButton\n)/$1                id: leftSidebarButton\n/s;
    s/(            ActiveWindow \{\n)(?!                id: activeWindowWidget\n)/$1                id: activeWindowWidget\n/s;
    s/(            ActiveWindow \{\n                id: activeWindowWidget\n                visible: \(Config\.options\?\.bar\?\.modules\?\.activeWindow \?\? true\) && root\.useShortenedForm === 0 && !root\.taskbarEnabled\n                Layout\.fillWidth: )!root\.taskbarEnabled(\n                Layout\.fillHeight: true\n            \})/$1!root.ryokuTopbarHugFrame \&\& !root.taskbarEnabled\n                Layout.preferredWidth: root.ryokuTopbarHugFrame ? Math.min(300, Math.max(160, (root.screen?.width ?? 1920) * 0.16)) : -1$2/s;

    s/(            Loader \{\n                active: root\.taskbarEnabled\n)(?!                id: taskbarLoader\n)/            Loader {\n                id: taskbarLoader\n                active: root.taskbarEnabled\n/s;
    s/(            Loader \{\n                id: taskbarLoader\n                active: root\.taskbarEnabled\n                visible: active\n                Layout\.fillWidth: )true(\n                Layout\.fillHeight: true)/$1!root.ryokuTopbarHugFrame\n                Layout.preferredWidth: root.ryokuTopbarHugFrame ? Math.min(300, Math.max(160, (root.screen?.width ?? 1920) * 0.16)) : -1$2/s;

    s/(        BarGroup \{\n            id: leftCenterGroup\n)(?!            opacity:)/$1            opacity: root.ryokuTopbarHugFrame ? 0 : 1\n/s;
    s/(            Loader \{\n                active: )Config\.options\?\.bar\?\.modules\?\.resources \?\? true/$1!root.ryokuTopbarHugFrame \&\& (Config.options?.bar?.modules?.resources ?? true)/;
    s/(            Loader \{\n                active: )\(Config\.options\?\.bar\?\.modules\?\.media \?\? true\) && root\.useShortenedForm < 2/$1!root.ryokuTopbarHugFrame \&\& (Config.options?.bar?.modules?.media ?? true) \&\& root.useShortenedForm < 2/;
    s/visible: Config\.options\?\.bar\.borderless/visible: (Config.options?.bar.borderless) \&\& !root.ryokuTopbarHugFrame/g;

    # Already-patched: replace old workspacesWidget-derived formula with fixed placeholder
    s/(            id: middleCenterGroup\n            )implicitWidth: root\.ryokuTopbarHugFrame \? Math\.min\(workspacesWidget\.implicitWidth \+ middleCenterGroup\.padding \* 2, 180\) : workspacesWidget\.implicitWidth \+ middleCenterGroup\.padding \* 2\n/$1implicitWidth: root.ryokuTopbarHugFrame ? 100 : 0\n/s;
    # Fresh source: insert fixed implicitWidth + clip
    s/(        BarGroup \{\n            id: middleCenterGroup\n)(?!            implicitWidth: )/$1            implicitWidth: root.ryokuTopbarHugFrame ? 100 : 0\n            clip: root.ryokuTopbarHugFrame\n/s;
    s/(            Workspaces \{\n                id: workspacesWidget\n)(?!                clip: root\.ryokuTopbarHugFrame\n)/$1                clip: root.ryokuTopbarHugFrame\n/s;
    # Move Workspaces from middleCenterGroup to rightSectionRowLayout (idempotent via sentinel).
    # In RTL layout, the second declared child of rightSectionRowLayout renders one slot
    # left of the first; placing Workspaces immediately before SysTray puts it visually
    # adjacent to rightSidebarButton, inside the dark notch interior.
    unless (/\/\/ Ryoku: workspaces relocated to right notch/) {
        # Inner alternation hard-codes 16-space body indent (12-space block close).
        # If iNiR upstream re-indents BarContent.qml the extraction silently fails,
        # the sentinel is never written, and Workspaces stays in middleCenterGroup.
        my $workspaces_block = "";
        if (s{\n(            Workspaces \{\n                id: workspacesWidget\n(?:(?:                [^\n]+|)\n)+?            \})\n}{\n}s) {
            $workspaces_block = $1;
        }
        if ($workspaces_block) {
            my $insertion = "\n            // Ryoku: workspaces relocated to right notch\n${workspaces_block}\n";
            s/(\n            SysTray \{)/$insertion$1/s;
        }
    }
    s/(            BarGroup \{\n                id: rightCenterGroupContent\n)(?!                opacity:)/$1                opacity: root.ryokuTopbarHugFrame ? 0 : 1\n/s;
    s/visible: Config\.options\?\.bar\?\.modules\?\.clock \?\? true/visible: !root.ryokuTopbarHugFrame \&\& (Config.options?.bar?.modules?.clock ?? true)/;
    s/visible: \(Config\.options\?\.bar\?\.modules\?\.utilButtons \?\? true\) && \(\(Config\.options\?\.bar\?\.verbose \?\? true\) && root\.useShortenedForm === 0\)/visible: !root.ryokuTopbarHugFrame \&\& (Config.options?.bar?.modules?.utilButtons ?? true) \&\& ((Config.options?.bar?.verbose ?? true) \&\& root.useShortenedForm === 0)/;
    s/visible: \(Config\.options\?\.bar\?\.modules\?\.battery \?\? true\) && \(root\.useShortenedForm < 2 && Battery\.available\)/visible: !root.ryokuTopbarHugFrame \&\& (Config.options?.bar?.modules?.battery ?? true) \&\& (root.useShortenedForm < 2 \&\& Battery.available)/;

    s/visible: \(Config\.options\?\.bar\?\.modules\?\.sysTray \?\? true\) && root\.useShortenedForm === 0/visible: !root.ryokuTopbarHugFrame \&\& (Config.options?.bar?.modules?.sysTray ?? true) \&\& root.useShortenedForm === 0/;
    # Regress force-hide: TimerIndicator visible whenever its own logic says so
    s/(            TimerIndicator \{\n)                visible: !root\.ryokuTopbarHugFrame\n/$1/s;
    # Gap on TimerIndicator visual-left so it does not butt against ShellUpdateIndicator under hug frame
    s/(            TimerIndicator \{\n)(?!                Layout\.leftMargin: root\.ryokuTopbarHugFrame)/$1                Layout.leftMargin: root.ryokuTopbarHugFrame ? 12 : 0\n/s;
    # Regress force-hide: ShellUpdateIndicator visible whenever its own logic says so
    s/(            ShellUpdateIndicator \{\n)                visible: !root\.ryokuTopbarHugFrame\n/$1/s;
    # Restore spacer Item fill so it absorbs slack and keeps weather + workspaces packed
    # inside the right notch; on-demand indicators float to the left of the notch in the gap.
    s/(            Item \{\n                Layout\.fillWidth: )!root\.ryokuTopbarHugFrame(\n                Layout\.fillHeight: )!root\.ryokuTopbarHugFrame/$1true$2true/;
    s/(            Loader \{\n                Layout\.leftMargin: 4\n                active: \(Config\.options\?\.bar\?\.modules\?\.weather \?\? true\) && \(Config\.options\?\.bar\?\.weather\?\.enable \?\? false\)\n)(?!                id: weatherBarLoader\n)/            Loader {\n                id: weatherBarLoader\n                Layout.leftMargin: 4\n                active: (Config.options?.bar?.modules?.weather ?? true) && (Config.options?.bar?.weather?.enable ?? false)\n/s;
    # Regress: drop the Layout.rightMargin we briefly used; weather is now relocated next to workspaces inside the notch.
    s/(                id: weatherBarLoader\n                Layout\.leftMargin: 4\n)                Layout\.rightMargin: root\.ryokuTopbarHugFrame \? 32 : 0\n/$1/s;
    # Push on-demand indicators away from weather under hug frame by widening weather visual-left margin.
    s/(                id: weatherBarLoader\n                Layout\.leftMargin: )4(\n                active:)/$1root.ryokuTopbarHugFrame ? 48 : 4$2/s;
    # Move weatherBarLoader from after the spacer to immediately after the relocated Workspaces (idempotent via sentinel).
    # Pairs with the restored spacer fillWidth: weather sits inside the right notch interior next to workspaces;
    # TimerIndicator and ShellUpdateIndicator float in the gap to the left of the notch when active.
    unless (/\/\/ Ryoku: weather relocated to right notch interior/) {
        my $weather_block = "";
        if (s{\n            // Weather\n(            Loader \{\n                id: weatherBarLoader\n(?:(?:                [^\n]+|)\n)+?            \})\n}{\n}s) {
            $weather_block = $1;
        }
        if ($weather_block) {
            my $insertion = "\n            // Ryoku: weather relocated to right notch interior\n${weather_block}\n";
            s{(\n            SysTray \{)}{$insertion$1}s;
        }
    }
    s/root\.ryokuThreeIslandFrame/root.ryokuTopbarHugFrame/g;
  ' "$file"
}

apply_topbar_hug_frame_to_workspaces_file() {
  local file="$1"

  [[ -f $file ]] || return 0
  grep -q 'readonly property bool dynamicCount:' "$file" || return 0
  if grep -q 'Config.options?.bar?.ryokuTopbarHugFrame' "$file"; then
    perl -0pi -e '
      s/Config\.options\?\.bar\?\.ryokuTopbarHugFrame \?\? false/Config.options?.bar?.ryokuTopbarHugFrame ?? true/g;
    ' "$file"
    return 0
  fi

  perl -0pi -e '
    s/readonly property bool dynamicCount: \(wsConfig\.dynamicCount \?\? true\) && CompositorService\.isNiri/readonly property bool dynamicCount: !(Config.options?.bar?.ryokuTopbarHugFrame ?? true) \&\& (wsConfig.dynamicCount ?? true) \&\& CompositorService.isNiri/s;
  ' "$file"
}

apply_topbar_hug_frame_to_bar_file() {
  local file="$1"

  [[ -f $file ]] || return 0
  grep -q 'id: barRoot' "$file" || return 0
  grep -q 'exclusiveZone: GameMode.shouldHidePanels' "$file" || return 0

  if grep -q 'ryokuTopbarReservedHeight' "$file"; then
    perl -0pi -e '
      s/Config\.options\?\.bar\?\.ryokuTopbarHugFrame \?\? false/Config.options?.bar?.ryokuTopbarHugFrame ?? true/g;
    ' "$file"
    return 0
  fi

  perl -0pi -e '
    s/(                readonly property int centerSideModuleWidth: \(useShortenedForm == 2\) \? Appearance\.sizes\.barCenterSideModuleWidthHellaShortened : \(useShortenedForm == 1\) \? Appearance\.sizes\.barCenterSideModuleWidthShortened : Appearance\.sizes\.barCenterSideModuleWidth\n)/$1                readonly property bool ryokuTopbarHugFrame: (Config.options?.bar?.ryokuTopbarHugFrame ?? true) \&\& !(Config.options?.bar?.bottom ?? false) \&\& !(Config.options?.bar?.vertical ?? false)\n                readonly property real ryokuTopbarReservedHeight: ryokuTopbarHugFrame\n                    ? Math.round(Appearance.sizes.baseBarHeight * 0.55)\n                    : Appearance.sizes.baseBarHeight + ((((Config.options?.bar?.cornerStyle ?? 0) === 1) || ((Config.options?.bar?.cornerStyle ?? 0) === 3)) ? (Appearance.sizes.hyprlandGapsOut * 2) : 0)\n/s;
    s/(                exclusiveZone: GameMode\.shouldHidePanels \? 0 :\n                    \(GlobalStates\.coverflowSelectorOpen \|\| \(Config\?\.options\.bar\.autoHide\.enable && \(!mustShow \|\| !Config\?\.options\.bar\.autoHide\.pushWindows\)\)\) \? 0 :\n                    )Appearance\.sizes\.baseBarHeight \+ \(\(\(\(Config\.options\?\.bar\?\.cornerStyle \?\? 0\) === 1\) \|\| \(\(Config\.options\?\.bar\?\.cornerStyle \?\? 0\) === 3\)\) \? \(Appearance\.sizes\.hyprlandGapsOut \* 2\) : 0\)/$1ryokuTopbarReservedHeight/s;
  ' "$file"
}

apply_weather_bar_dynamic_color_to_file() {
  local file="$1"

  [[ -f $file ]] || return 0
  grep -qF 'wallpaperBlendedColors?.colOnLayer1' "$file" && return 0

  perl -0pi -e '
    s/color: Appearance\.angelEverywhere \? Appearance\.angel\.colText[ \t]*\n[ \t]*: Appearance\.inirEverywhere \? Appearance\.inir\.colText : Appearance\.colors\.colOnLayer1/color: (Appearance.wallpaperBlendedColors?.colOnLayer1) ?? (Appearance.angelEverywhere ? Appearance.angel.colText : Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer1)/g;
  ' "$file"
}

apply_topbar_hug_frame() {
  apply_topbar_hug_frame_to_file "$SHELL_PATH/modules/bar/BarContent.qml"
  apply_topbar_hug_frame_to_file "$RUNTIME_SHELL_PATH/modules/bar/BarContent.qml"
  apply_topbar_hug_frame_to_bar_file "$SHELL_PATH/modules/bar/Bar.qml"
  apply_topbar_hug_frame_to_bar_file "$RUNTIME_SHELL_PATH/modules/bar/Bar.qml"
  apply_topbar_hug_frame_to_workspaces_file "$SHELL_PATH/modules/bar/Workspaces.qml"
  apply_topbar_hug_frame_to_workspaces_file "$RUNTIME_SHELL_PATH/modules/bar/Workspaces.qml"
  apply_weather_bar_dynamic_color_to_file "$SHELL_PATH/modules/bar/weather/WeatherBar.qml"
  apply_weather_bar_dynamic_color_to_file "$RUNTIME_SHELL_PATH/modules/bar/weather/WeatherBar.qml"
}

apply_installed_labels() {
  local installed_service="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/inir.service"

  apply_replacements_to_file "assets/applications/inir.desktop" \
    "${XDG_DATA_HOME:-$HOME/.local/share}/applications/inir.desktop"
  apply_replacements_to_file "assets/systemd/inir.service" \
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
  local config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/inir"
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
  apply_topbar_hug_frame
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
