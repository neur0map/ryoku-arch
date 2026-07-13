pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Ryoku.Blobs
import "Singletons"

// Draggable, shaped webcam bubble on a per-screen layer surface: it stays put
// across workspace switches and gsr captures it into recordings. The live feed
// is the native CameraFeed (a scene-graph texture, so it can be masked), shaped
// by a MultiEffect mask from square corners to a full circle. Interactive, so
// the input mask covers only the bubble and the rest of the screen stays
// click-through.
PanelWindow {
    id: win

    required property var modelData

    // this screen's Hyprland monitor, for global<->screen-local mapping (logical).
    readonly property var mon: {
        var mons = Hyprland.monitors.values;
        for (var i = 0; i < mons.length; i++)
            if (mons[i].name === (modelData ? modelData.name : ""))
                return mons[i];
        return null;
    }
    readonly property real monX: mon ? mon.x : 0
    readonly property real monY: mon ? mon.y : 0
    readonly property real monScale: mon && mon.scale > 0 ? mon.scale : 1
    readonly property real screenW: mon ? mon.width / win.monScale : (modelData ? modelData.width : 0)
    readonly property real screenH: mon ? mon.height / win.monScale : (modelData ? modelData.height : 0)

    // bubble size from aspect + scale (reference edge s; portrait is narrower,
    // landscape is shorter).
    readonly property real s: Camera.base * Camera.sizeScale
    readonly property real bw: Camera.aspect === "portrait" ? s * 0.75 : s
    readonly property real bh: Camera.aspect === "landscape" ? s * 0.75 : s

    // global logical position; default to the bottom-right corner when unplaced.
    readonly property real defX: win.monX + win.screenW - bw - 40
    readonly property real defY: win.monY + win.screenH - bh - 40
    readonly property real gx: isNaN(Camera.px) ? defX : Camera.px
    readonly property real gy: isNaN(Camera.py) ? defY : Camera.py
    // screen-local, clamped inside this screen.
    readonly property real bx: Math.max(0, Math.min(win.screenW - bw, gx - win.monX))
    readonly property real by: Math.max(0, Math.min(win.screenH - bh, gy - win.monY))
    // the bubble lives on whichever monitor its centre falls in.
    readonly property real cxLocal: gx + bw / 2 - win.monX
    readonly property real cyLocal: gy + bh / 2 - win.monY
    readonly property bool onScreen: cxLocal >= 0 && cxLocal < win.screenW && cyLocal >= 0 && cyLocal < win.screenH

    screen: modelData
    visible: Camera.active && win.onScreen
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "ryoku-camera"

    anchors { top: true; bottom: true; left: true; right: true }

    // input only on the bubble; the rest of the screen passes clicks through.
    mask: Region { item: bubble }

    Item {
        id: bubble

        x: win.bx
        y: win.by
        width: win.bw
        height: win.bh

        readonly property real rad: Camera.roundness * Math.min(width, height) / 2

        // rounded backdrop + cue, shown until the first camera frame arrives (the
        // feed is transparent while the camera warms up).
        Rectangle {
            anchors.fill: parent
            radius: bubble.rad
            color: Theme.frameBg
        }
        GlyphIcon {
            anchors.centerIn: parent
            width: 28
            height: 28
            name: "webcam"
            color: Theme.subtle
            stroke: 1.7
        }

        // live feed, rendered as a scene-graph texture so the mask applies.
        CameraFeed {
            anchors.fill: parent
            active: Camera.active
            mirror: Camera.flipped
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: maskRect
            }
        }
        Rectangle {
            id: maskRect
            anchors.fill: parent
            radius: bubble.rad
            visible: false
            layer.enabled: true
        }

        // rim tracing the same shape.
        Rectangle {
            anchors.fill: parent
            radius: bubble.rad
            color: "transparent"
            border.width: 2
            border.color: Theme.brand
        }

        // shape controls, revealed on hover and hidden while recording (never in
        // the shot); floats inside the bubble so it fits any shape incl. a circle.
        CameraControls {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.max(8, bubble.rad * 0.5)
            opacity: (bubbleHov.hovered && !Recorder.anyActive) ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 140 } }
        }

        HoverHandler {
            id: bubbleHov
            cursorShape: Qt.SizeAllCursor
        }

        // whole-bubble drag: writes the global logical position back to Camera so
        // every per-screen overlay tracks it and it survives workspace switches.
        DragHandler {
            id: drag
            target: null
            property real sx: 0
            property real sy: 0
            property real ax: 0
            property real ay: 0
            onActiveChanged: {
                if (drag.active) {
                    drag.sx = win.gx;
                    drag.sy = win.gy;
                    drag.ax = drag.centroid.scenePosition.x;
                    drag.ay = drag.centroid.scenePosition.y;
                }
            }
            onCentroidChanged: {
                if (!drag.active)
                    return;
                const nx = drag.sx + (drag.centroid.scenePosition.x - drag.ax);
                const ny = drag.sy + (drag.centroid.scenePosition.y - drag.ay);
                // clamp so the bubble stays fully on this monitor: no teleport
                // and no vanish when dragged past an edge.
                Camera.px = Math.max(win.monX, Math.min(win.monX + win.screenW - win.bw, nx));
                Camera.py = Math.max(win.monY, Math.min(win.monY + win.screenH - win.bh, ny));
            }
        }
    }
}
