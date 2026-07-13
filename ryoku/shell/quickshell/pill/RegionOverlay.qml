pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "Singletons"

// Persistent region-capture boundary. While a region recording runs (Quick or
// Studio), everything outside the captured box is dimmed and the box stays clear,
// so you see exactly what is being recorded and can keep moving windows around it.
// Fully click-through and on the Top layer -- below the shell's own chrome (the
// recording control bar), above app windows. gsr crops to the same box, and the
// box interior has no overlay pixels, so the dim never lands in the recording.
PanelWindow {
    id: win

    required property var modelData

    // this screen's Hyprland monitor: layout position is in logical coordinates,
    // the same space slurp reports the box in, so we can map global -> screen-local.
    readonly property var mon: {
        var mons = Hyprland.monitors.values;
        for (var i = 0; i < mons.length; i++)
            if (mons[i].name === (modelData ? modelData.name : ""))
                return mons[i];
        return null;
    }
    readonly property real monX: mon ? mon.x : 0
    readonly property real monY: mon ? mon.y : 0

    // Recorder.regionGeom is "WxH+X+Y" (global logical); parse to this screen's coords.
    readonly property var box: {
        var m = /^(\d+)x(\d+)\+(\d+)\+(\d+)$/.exec(Recorder.regionGeom);
        if (!m)
            return null;
        return {
            x: parseInt(m[3]) - win.monX,
            y: parseInt(m[4]) - win.monY,
            w: parseInt(m[1]),
            h: parseInt(m[2])
        };
    }
    readonly property bool onScreen: box && box.x < win.width && box.y < win.height && (box.x + box.w) > 0 && (box.y + box.h) > 0

    // the clear box clamped to this screen.
    readonly property real bx: box ? Math.max(0, box.x) : 0
    readonly property real by: box ? Math.max(0, box.y) : 0
    readonly property real bw: box ? Math.min(win.width, box.x + box.w) - bx : 0
    readonly property real bh: box ? Math.min(win.height, box.y + box.h) - by : 0
    readonly property color dim: Qt.rgba(0, 0, 0, 0.45)

    screen: modelData
    visible: Recorder.anyActive && Recorder.regionGeom !== "" && onScreen
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "ryoku-region"

    anchors { top: true; bottom: true; left: true; right: true }

    // click-through: purely a visual boundary, never eats a press.
    mask: Region {}

    // four dim bands framing the clear box (top / bottom / left / right).
    Rectangle { color: win.dim; x: 0; y: 0; width: win.width; height: win.by }
    Rectangle { color: win.dim; x: 0; y: win.by + win.bh; width: win.width; height: win.height - (win.by + win.bh) }
    Rectangle { color: win.dim; x: 0; y: win.by; width: win.bx; height: win.bh }
    Rectangle { color: win.dim; x: win.bx + win.bw; y: win.by; width: win.width - (win.bx + win.bw); height: win.bh }
}
