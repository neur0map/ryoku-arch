pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "Singletons"

// Volume / brightness OSD in its own small layer window, bottom-centre just
// above the bar. Re-homed from the floating pill: the Osd component still
// drives its own flashing on volume/brightness change (via Pipewire), so this
// window only maps while it flashes. Click-through, never takes focus, never
// reserves space.
PanelWindow {
    id: win

    required property var modelData
    readonly property real s: (modelData ? modelData.height / 1080 : 1) * Math.max(0.7, Math.min(1.6, Config.fontScale))

    // top/bottom bar (left/right collapse to top, as the overlay does).
    readonly property string barPos: Config.barEnabled ? (Config.barPosition === "bottom" ? "bottom" : "top") : ""
    readonly property bool barBottom: barPos === "bottom"
    // clear the bottom bar band (or just the bottom frame lip), matching the
    // overlay's barVisibleH, then float a small gap above it.
    readonly property real frameLip: Math.max(0, Config.frameBorder - 50)
    readonly property real barVisibleH: frameLip + Config.barHeight * s
    readonly property real bottomInset: (barBottom ? barVisibleH : frameLip) + 12 * s

    // this monitor's active workspace has a fullscreen window: the whole shell
    // hides then, so the OSD stays down too (suppressed clears its flashing).
    readonly property bool monFullscreen: {
        var mons = Hyprland.monitors.values;
        for (var i = 0; i < mons.length; i++)
            if (mons[i].name === (modelData ? modelData.name : ""))
                return mons[i].activeWorkspace ? mons[i].activeWorkspace.hasFullscreen : false;
        return false;
    }

    screen: modelData
    visible: osd.flashing
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "ryoku-osd"

    anchors.bottom: true
    margins.bottom: bottomInset

    implicitWidth: osd.desiredW
    implicitHeight: osd.desiredH

    // the surface material: warm surface fill + hairline border, fully
    // rounded like a small panel; no shadow (only the frame's inverted rect
    // casts one).
    Rectangle {
        anchors.fill: parent
        radius: Config.osdRadius * win.s
        color: Config.matchWallpaper ? Wallust.surface : Config.surfaceColor
        opacity: Config.osdOpacity
        border.width: 1.5
        border.color: Wallust.border
        antialiasing: true
    }

    Osd {
        id: osd
        anchors.fill: parent
        anchors.topMargin: 12 * win.s
        anchors.bottomMargin: 12 * win.s
        anchors.leftMargin: 18 * win.s
        anchors.rightMargin: 18 * win.s
        s: win.s
        suppressed: win.monFullscreen
    }

    // click-through: the OSD is a passive readout, never eats a press.
    mask: Region {}
}
